# Async::HTTP::Record Design Document

## Overview

The `async-http-record` gem provides pure, immutable components for recording and replaying HTTP requests. Uses Protocol::HTTP::Middleware for recording and simple iteration for replay. This avoids data loss from Rack's header munging and body conversions, keeping everything in the Protocol::HTTP domain.

## Goals

- **Pure Components**: Immutable, stateless classes without global configuration
- **High Fidelity Recording**: Capture all relevant aspects of HTTP requests and responses using Protocol::HTTP directly
- **Protocol::HTTP Native**: Work directly with Protocol::HTTP objects, avoiding Rack's lossy conversions
- **Leverage Existing APIs**: Use Protocol::HTTP's native JSON serialization capabilities
- **Simple API**: Clear, explicit interfaces without magic or hidden state
- **Performance**: Fast loading and replay of cassettes using simple iteration
- **Format Focused**: JSON-first approach leveraging Protocol::HTTP's built-in serialization

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────┐
│              Async::HTTP::Record                    │
├─────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────┐   │
│  │            Interaction                        │   │
│  │           (immutable)                         │   │
│  │  - Protocol::HTTP::Request (with body)       │   │
│  │  - Protocol::HTTP::Response (with body)      │   │
│  └───────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────────────┐          │
│  │  Cassette   │  │ Protocol::HTTP::     │          │
│  │ (immutable) │  │ Middleware           │          │
│  └─────────────┘  │ (Recording)          │          │
│                   └──────────────────────┘          │
└─────────────────────────────────────────────────────┘
		 │                         │               │
		 ▼                         ▼               ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│ JSON Files   │  │ Protocol::HTTP   │  │ HTTP         │
│ (cassettes)  │  │ Applications     │  │ Requests     │
└──────────────┘  └──────────────────┘  └──────────────┘
```

### Component Responsibilities

1. **Interaction**: Data container with lazy Protocol::HTTP object construction via `request` and `response` methods
2. **Cassette**: Simple collection of interactions with JSON loading/saving - just iterates, no factory methods needed
3. **Protocol::HTTP::Middleware (Recording)**: Records live HTTP interactions using Protocol::HTTP::Body::Buffered, with optional response recording

## API Design

### Core Classes

```ruby
require "protocol/http/body/buffered"

# Simple data container with lazy Protocol::HTTP object construction
class Async::HTTP::Record::Interaction
	def initialize(data)
		@data = data
	end
	
	def make_request
		if request_data = @data[:request]
			build_request(**request_data)
		end
	end
	
	def make_response
		if response_data = @data[:response]
			build_response(**response_data)
		end
	end
	
	def to_h
		@data
	end
	
	private
	
	def build_request(scheme: nil, authority: nil, method:, path:, version: nil, headers: nil, body: nil, protocol: nil)
		body = Protocol::HTTP::Body::Buffered.wrap(body) if body
		headers = Protocol::HTTP::Headers[headers] if headers
		
		Protocol::HTTP::Request.new(
			scheme,
			authority,
			method, 
			path,
			version,
			headers,
			body,
			protocol
		)
	end
	
	def build_response(version: nil, status:, headers: nil, body: nil, protocol: nil)
		body = Protocol::HTTP::Body::Buffered.wrap(body) if body
		headers = Protocol::HTTP::Headers[headers] if headers
		
		Protocol::HTTP::Response.new(
			version,
			status,
			headers,
			body,
			protocol
		)
	end
end
```

### Cassette Usage

```ruby
# Load recorded interactions and replay them (no middleware needed)
cassette = Async::HTTP::Capture::Cassette.load("recordings")

# Simple replay: interactions construct Protocol::HTTP objects lazily
cassette.each do |interaction|
	request = interaction.request  # Constructs Protocol::HTTP::Request on first access
	app_response = app.call(request)
	# Your app handles the request normally (warming up caches, etc.)
end

# Manual cassette creation using data hashes:
interactions = [
	Async::HTTP::Record::Interaction.new({
		request: {
			method: "GET",
			path: "/users/123", 
			headers: [["Accept", "application/json"], ["User-Agent", "MyApp/1.0"]]
		}
	}),
	Async::HTTP::Record::Interaction.new({
		request: {
			method: "POST",
			path: "/orders",
			headers: [["Content-Type", "application/json"]],
			body: ['{"product_id": 456}']
		}
	})
]

cassette = Async::HTTP::Record::Cassette.new(interactions)
cassette.save("recordings")
```

### Recording Middleware

Simplified middleware with optional response recording:

```ruby
require "protocol/http/body/rewindable"
require "protocol/http/body/completable"
require "protocol/http/body/buffered"

# Protocol::HTTP::Middleware for recording
class Async::HTTP::Record::Middleware < Protocol::HTTP::Middleware
	def initialize(app, cassette_path:, record_response: false, **options)
		super(app)
		@cassette_path = cassette_path
		@record_response = record_response
		@interactions = []
		@options = options
	end
	
	def call(request)
		# Capture request body if present
		captured_request = capture_request_body(request)
		
		# Get response from downstream middleware/app
		response = super(captured_request)
		
		if @record_response
			# Capture response body if present and record interaction
			capture_response_and_record(captured_request, response)
		else
			# Record request only
			record_interaction(captured_request)
		end
		
		response
	end
	
	private
	
	def capture_request_body(request)
		return request unless request.body && !request.body.empty?
		
		# Read request body into array of chunks
		chunks = []
		request.body.each { |chunk| chunks << chunk }
		
		# Create new request with buffered body
		Protocol::HTTP::Request.new(
			request.method,
			request.path,
			request.headers.dup,
			Protocol::HTTP::Body::Buffered.new(chunks)
		)
	end
	
	def capture_response_and_record(request, response)
		if response.body && !response.body.empty?
			# Use rewindable to capture response body
			rewindable = ::Protocol::HTTP::Body::Rewindable.wrap(response)
			
			# Use completable to get callback when body is fully read
			::Protocol::HTTP::Body::Completable.wrap(response) do |error|
				unless error
					record_interaction_with_response_body(request, response, rewindable.buffered)
				end
			end
		else
			# No response body, record immediately
			record_interaction(request, response)
		end
	end
	
	def record_interaction_with_response_body(request, original_response, buffered_body)
		# Create response with captured body
		response_with_body = Protocol::HTTP::Response.new(
			original_response.version,
			original_response.status,
			original_response.headers.dup,
			buffered_body
		)
		
		record_interaction(request, response_with_body)
	end
	
	def record_interaction(request, response = nil)
		interaction = Async::HTTP::Record::Interaction.new(
			request: request,
			response: response
		)
		
		@interactions << interaction
		save_cassette if should_save?
	end
	
	def save_cassette
		cassette = Async::HTTP::Record::Cassette.new(@interactions)
		cassette.save(@cassette_path)
	end
	
	def should_save?
		@interactions.size >= (@options[:batch_size] || 1)
	end
end
```

### Usage with Async::HTTP

```ruby
# Request-only recording (for warmup scenarios)
require "async/http/record"

endpoint = Async::HTTP::Endpoint.parse("https://api.example.com")

middleware = [
	Async::HTTP::Record::Middleware.new(
		nil, # will be set by client
		cassette_path: "recordings/warmup.json"
		# record_response: false is the default
	)
]

client = Async::HTTP::Client.new(endpoint, middleware: middleware)

# Make requests - only requests will be recorded
Async do
	response1 = client.get("/users")
	response2 = client.post("/users", {"name" => "John"})
	# etc...
end

# Full request/response recording (for testing/mocking scenarios)
full_middleware = [
	Async::HTTP::Record::Middleware.new(
		nil,
		cassette_path: "recordings/full_interactions.json",
		record_response: true,
		batch_size: 5
	)
]

full_client = Async::HTTP::Client.new(endpoint, middleware: full_middleware)
```

### Simplified Recording Examples

```ruby
# Default: Request-only recording (perfect for warmup)
middleware = Async::HTTP::Record::Middleware.new(
	nil,
	cassette_path: "warmup.json"
)

# With response recording enabled
middleware = Async::HTTP::Record::Middleware.new(
	nil,
	cassette_path: "full_session.json", 
	record_response: true
)

# With batch saving
middleware = Async::HTTP::Record::Middleware.new(
	nil,
	cassette_path: "batch_session.json",
	record_response: true,
	batch_size: 10
)
```

### Cassette Implementation

```ruby
class Async::HTTP::Record::Cassette
	include Enumerable
	
	attr_reader :interactions
	
	def initialize(interactions = [])
		@interactions = interactions.map do |item|
			case item
			when Hash
				Interaction.from_hash(item)
			when Interaction
				item
			else
				raise ArgumentError, "Invalid interaction: #{item}"
			end
		end.freeze
		freeze
	end
	
	# Simple iteration over interactions
	def each(&block)
		@interactions.each(&block)
	end
	
	def self.load(path)
		data = JSON.parse(File.read(path), symbolize_names: true)
		interactions = data[:interactions].map { |i| Interaction.from_hash(i) }
		new(interactions)
	end
	
	def save(path)
		data = {
			version: "1.0",
			recorded_at: Time.now.iso8601,
			interactions: interactions.map(&:to_h)
		}
		File.write(path, JSON.pretty_generate(data))
	end
end
```

## Data Format

### Simplified Cassette Structure

Using Protocol::HTTP::Body::Buffered with arrays of strings:

```json
{
	"version": "1.0", 
	"recorded_at": "2025-01-27T10:30:00Z",
	"interactions": [
		{
			"request": {
				"method": "GET",
				"uri": "/users/123",
				"headers": [
					["Accept", "application/json"],
					["Authorization", "Bearer token123"],
					["User-Agent", "MyApp/1.0"]
				],
				"body": null
			},
			"response": {
				"status": 200,
				"headers": [
					["Content-Type", "application/json"],
					["Content-Length", "28"]
				],
				"body": ["{\"id\":123,\"name\":\"John Doe\"}"]
			}
		},
		{
			"request": {
				"method": "POST",
				"uri": "/orders",
				"headers": [
					["Content-Type", "application/json"]
				],
				"body": ["{\"product_id\": 456, \"quantity\": 2}"]
			}
		}
	]
}
```

### Streaming Response Example

For streaming responses like SSE, chunks are stored as array elements:

```json
{
	"version": "1.0",
	"interactions": [
		{
			"request": {
				"method": "GET",
				"uri": "/events",
				"headers": [
					["Accept", "text/event-stream"]
				],
				"body": null
			},
			"response": {
				"status": 200,
				"headers": [
					["Content-Type", "text/event-stream"],
					["Cache-Control", "no-cache"]
				],
				"body": [
					"data: {\"event\": \"start\"}\n\n",
					"data: {\"event\": \"update\", \"value\": 42}\n\n",
					"data: {\"event\": \"end\"}\n\n"
				]
			}
		}
	]
}
```

### Request-Only Structure for Warmup

For warmup scenarios where you only need requests:

```json
{
	"version": "1.0",
	"interactions": [
		{
			"request": {
				"method": "GET", 
				"uri": "/health",
				"headers": [],
				"body": null
			}
		},
		{
			"request": {
				"method": "GET",
				"uri": "/api/popular-items",
				"headers": [
					["Accept", "application/json"]
				],
				"body": null
			}
		},
		{
			"request": {
				"method": "POST",
				"uri": "/orders",
				"headers": [
					["Content-Type", "application/json"]
				],
				"body": ["chunk1", "chunk2", "chunk3"]
			}
		}
	]
}
```

## Implementation Strategy

### Phase 1: Core Components
- [ ] `Interaction` class as immutable data holder using Protocol::HTTP objects with bodies
- [ ] `Cassette` class with JSON serialization and loading

### Phase 2: Replay Integration
- [ ] Simple replay by iterating through interactions and calling `app.call(request)`
- [ ] No middleware needed - direct request sending to your application
- [ ] Proper error handling during replay for robust warmup scenarios

### Phase 3: Recording Middleware
- [ ] `Protocol::HTTP::Middleware` base class following async-http-cache patterns
- [ ] Request body capture using Protocol::HTTP::Body::Buffered (always)
- [ ] Optional response body capture using Rewindable + Completable + Buffered wrappers
- [ ] `record_response: false` default for warmup scenarios
- [ ] Configurable save strategies (batch size, timing)

### Phase 4: Utilities
- [ ] Cassette creation helpers
- [ ] Request builders for common patterns
- [ ] Validation and error handling

## Usage Examples

### Creating a Warmup Cassette

```ruby
# Manual cassette creation using Protocol::HTTP objects
interactions = [
	Async::HTTP::Record::Interaction.new(
		request: Protocol::HTTP::Request.new("GET", "/health")
	),
	Async::HTTP::Record::Interaction.new(
		request: Protocol::HTTP::Request.new(
			"GET", 
			"/api/popular-products",
			Protocol::HTTP::Headers.new([["Accept", "application/json"]])
		)
	),
	Async::HTTP::Record::Interaction.new(
		request: Protocol::HTTP::Request.new(
			"POST",
			"/api/analytics/pageview",
			Protocol::HTTP::Headers.new([["Content-Type", "application/json"]]),
			Protocol::HTTP::Body::Buffered.new(['{"page": "/homepage", "user_agent": "warmup"}'])
		)
	)
]

cassette = Async::HTTP::Record::Cassette.new(interactions)
cassette.save("warmup.json")
```

### Simple Replay Usage

```ruby
# Load recorded interactions and replay them
require "async/http/record"

# Load recorded interactions
cassette = Async::HTTP::Capture::Cassette.load("recordings")

# Your application
app = MyApplication.new

# Simple replay: interactions construct Protocol::HTTP objects lazily
puts "Replaying #{cassette.interactions.size} interactions..."
cassette.each do |interaction|
	request = interaction.request  # Constructs Protocol::HTTP::Request on first access
	puts "Sending #{request.method} #{request.path}"
	
	begin
		app_response = app.call(request)
		puts "  -> #{app_response.status}"
	rescue => error
		puts "  -> Error: #{error.message}"
	end
end
```

### Complete Recording → Replay Workflow

```ruby
# Step 1: Record requests during development/testing
require "async/http/record"

# Set up client with request-only recording (default)
endpoint = Async::HTTP::Endpoint.parse("https://api.example.com")
recording_middleware = Async::HTTP::Record::Middleware.new(
	nil,
	cassette_path: "recordings"
)

client = Async::HTTP::Client.new(endpoint, middleware: [recording_middleware])

# Make the requests you want to record
Async do
	client.get("/health")
	client.get("/api/popular-items") 
	client.post("/api/user-sessions", {user_id: 123})
	client.get("/api/recommendations")
end

# Step 2: Use recorded interactions to warm up your application
require "async/http/record"

# Load recorded interactions
cassette = Async::HTTP::Capture::Cassette.load("recordings")

# Your application
app = MyApplication.new

# Simple warmup: interactions construct Protocol::HTTP objects lazily
puts "Warming up with #{cassette.interactions.size} recorded interactions..."
cassette.each do |interaction|
	request = interaction.request  # Constructs Protocol::HTTP::Request on first access
	begin
		app_response = app.call(request)
		puts "Warmed up #{request.method} #{request.path} -> #{app_response.status}"
	rescue => error
		puts "Warning: #{request.method} #{request.path} -> #{error.message}"
	end
end

puts "Warmup complete! Starting server..."
```

## Error Handling

### Simple Error Strategy
- Missing cassette file: raise clear error with path
- Invalid JSON: raise parsing error with line number
- Invalid request data: raise validation error
- Keep error messages focused and actionable

## Testing Strategy

### Unit Tests
```ruby
describe Async::HTTP::Record::Interaction do
	it "is immutable after initialization" do
		request = Protocol::HTTP::Request.new("GET", "/test")
		interaction = described_class.new(request: request)
		
		expect(interaction).to be_frozen
		expect(interaction.request).to be_frozen
	end
	
	it "applies to Rack app safely" do
		body = Protocol::HTTP::Body::Buffered.new(['{"name": "test"}'])
		request = Protocol::HTTP::Request.new(
			"POST", 
			"/users",
			Protocol::HTTP::Headers.new([["Content-Type", "application/json"]]),
			body
		)
		interaction = described_class.new(request: request)
		
		# Mock Rack app
		app = ->(env) do
			expect(env["REQUEST_METHOD"]).to eq("POST")
			expect(env["PATH_INFO"]).to eq("/users") 
			expect(env["HTTP_CONTENT_TYPE"]).to eq("application/json")
			[200, {}, ["OK"]]
		end
		
		adapter = Async::HTTP::Record::Rack::InteractionAdapter.new(interaction)
		status, headers, body = adapter.apply(app)
		expect(status).to eq(200)
	end
	
	it "serializes request with body to hash" do
		body = Protocol::HTTP::Body::Buffered.new(["chunk1", "chunk2"])
		request = Protocol::HTTP::Request.new("POST", "/test", nil, body)
		interaction = described_class.new(request: request)
		
		hash = interaction.to_h
		expect(hash[:request][:body]).to eq(["chunk1", "chunk2"])
	end
	
	it "deserializes from hash with body" do
		hash = {
			"request" => {
				"method" => "POST",
				"uri" => "/test", 
				"headers" => [["Content-Type", "application/json"]],
				"body" => ["chunk1", "chunk2"]
			}
		}
		
		interaction = described_class.from_hash(hash)
		expect(interaction.request.method).to eq("POST")
		expect(interaction.request.body).to be_a(Protocol::HTTP::Body::Buffered)
		expect(interaction.request.body.chunks).to eq(["chunk1", "chunk2"])
	end
end

describe Async::HTTP::Record::Cassette do
	it "loads from JSON file" do
		cassette = described_class.load("fixtures/sample.json")
		expect(cassette.interactions.size).to eq(2)
	end
	
	it "saves to JSON file" do
		request = Protocol::HTTP::Request.new("GET", "/")
		interactions = [described_class::Interaction.new(request: request)]
		cassette = described_class.new(interactions)
		
		cassette.save("tmp/test.json")
		loaded = described_class.load("tmp/test.json")
		
		expect(loaded.interactions.first.request.path).to eq("/")
	end
	
	it "handles interactions with bodies" do
		body = Protocol::HTTP::Body::Buffered.new(["Hello", " ", "World"])
		request = Protocol::HTTP::Request.new("POST", "/test", nil, body)
		interactions = [described_class::Interaction.new(request: request)]
		cassette = described_class.new(interactions)
		
		cassette.save("tmp/test_body.json")
		loaded = described_class.load("tmp/test_body.json")
		
		expect(loaded.interactions.first.request.body.chunks).to eq(["Hello", " ", "World"])
	end
end
```

## Key Design Decisions

### 1. Immutable Components
All classes are frozen after initialization to prevent accidental mutations and ensure thread safety.

### 2. Lazy Object Construction
`Interaction` stores data and constructs Protocol::HTTP objects lazily via `request` and `response` methods, using `||=` for caching.

### 3. Leverages Protocol::HTTP APIs
Uses `Protocol::HTTP::Body::Buffered.wrap()` and `Protocol::HTTP::Headers[]` for proper object construction following library conventions.

### 4. Protocol::HTTP::Body Pattern
Following async-http-cache's proven approach:
- Use `Protocol::HTTP::Body::Rewindable` to wrap responses for chunk capture
- Use `Protocol::HTTP::Body::Completable` for completion callbacks
- Use `Protocol::HTTP::Body::Buffered` for final storage as arrays of strings

### 5. Simple Replay Pattern
No middleware needed for replay - just iterate through recorded interactions and call `app.call(request)` to warm up your application directly.

### 6. Optional Response Recording
Responses are not recorded by default (`record_response: false`) since many use cases only need request recording for testing or mocking.

### 7. JSON-Only Storage
Simple, human-readable format that's easy to inspect and version control.

### 8. No Global State
All components are explicit about their dependencies and configuration.

---

## Questions for Implementation

1. **URI Handling**: Should we normalize URIs (trailing slashes, query param order) or keep them exactly as provided?

2. **Header Case**: Should we normalize header names to lowercase or preserve original casing? Protocol-rack preserves case.

3. **RackInput Interface**: Should we implement the full IO interface or just the minimum required methods (read, gets, each, rewind)?

4. **Authority Parsing**: How should we handle malformed authority strings in request.authority?

5. **Content-Length**: Should we always calculate and set CONTENT_LENGTH from body.length, or only when present in headers?

6. **Memory Efficiency**: For large streaming responses during recording, should we consider streaming-to-disk?

7. **Save Strategy**: Default to save-after-each-request or batch saves? What's the right balance for the recording use case?

8. **Protocol-Rack Dependency**: Should we depend on protocol-rack directly or just follow its patterns?

## Complete Workflow

This design enables a clean workflow:

1. **Recording**: Use `Middleware` with default `record_response: false` to capture requests during development/testing
2. **Replay**: Simple iteration - `cassette.each { |interaction| app.call(interaction.request) }` with lazy Protocol::HTTP object construction
3. **Lazy Construction**: `Interaction` stores data and builds Protocol::HTTP objects on first access via `request`/`response` methods
4. **Leverages Existing APIs**: Uses `Protocol::HTTP::Body::Buffered.wrap()` and standard Protocol::HTTP constructors
5. **Direct Protocol::HTTP**: No lossy conversions, keeps everything in Protocol::HTTP domain
6. **Optional Responses**: Only record what you need - requests by default, responses when needed
7. **No Global State**: Everything is explicit and configurable per-instance

The design is dramatically simplified while maintaining the pure, functional approach and leveraging Protocol::HTTP's native capabilities throughout the recording and replay pipeline.
