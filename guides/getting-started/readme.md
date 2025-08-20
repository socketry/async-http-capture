# Getting Started

This guide explains how to get started with `async-http-capture`, a Ruby gem for recording and replaying HTTP requests using Protocol::HTTP.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async-http-capture
~~~

## Core Concepts

`async-http-capture` has several core concepts:

- A {ruby Async::HTTP::Capture::Middleware} which captures HTTP requests and responses as they pass through your application.
- An {ruby Async::HTTP::Capture::Interaction} which represents a single HTTP request/response pair with lazy Protocol::HTTP object construction.
- A {ruby Async::HTTP::Capture::Cassette} which is a collection of interactions that can be loaded from and saved to JSON files.
- A {ruby Async::HTTP::Capture::CassetteStore} which provides content-addressed storage, saving each interaction to a separate file named by its content hash.
- A {ruby Async::HTTP::Capture::ConsoleStore} which logs interactions to the console for debugging purposes.

## Usage

The basic workflow involves:

1. **Recording**: Capture HTTP interactions using middleware
2. **Storage**: Save interactions using pluggable store backends
3. **Replay**: Load and replay recorded interactions

### Basic Recording

Here's how to record HTTP interactions to files:

~~~ ruby
require "async/http/capture"

# Create a store that saves to content-addressed files:
store = Async::HTTP::Capture::CassetteStore.new("interactions")

# Create your application
app = ->(request) { Protocol::HTTP::Response[200, {}, ["OK"]] }

# Wrap it with recording middleware:
middleware = Async::HTTP::Capture::Middleware.new(app, store: store)

# Make requests - they will be automatically recorded:
request = Protocol::HTTP::Request["GET", "/users"]
response = middleware.call(request)
# This creates a file like recordings/20250821-105406-271633-4b51df4bdd5089b1.json
~~~

### Recording with Console Output

For debugging, you can log interactions to the console:

~~~ ruby
# Create a console store for debugging:
console_store = Async::HTTP::Capture::ConsoleStore.new
middleware = Async::HTTP::Capture::Middleware.new(app, store: console_store)

# This will log interactions to console:
middleware.call(request)
# Output: "Recorded: GET /users"
~~~

### Loading and Replaying Interactions

~~~ ruby
# Load recorded interactions:
cassette = Async::HTTP::Capture::Cassette.load("interactions")

# Option 1: Use the built-in replay method for application warmup
cassette.replay(app)

# Option 2: Manual iteration for custom processing
cassette.each do |interaction|
  request = interaction.request  # Lazy Protocol::HTTP::Request construction
  response = app.call(request)   # Send to your app
  puts "#{request.method} #{request.path} -> #{response.status}"
end
~~~

## Recording HTTP Requests and Responses

The middleware automatically records both requests and responses:

~~~ ruby
middleware = Async::HTTP::Capture::Middleware.new(
  app, 
  store: store
)

response = middleware.call(request)
# Both request and response are recorded.
~~~

## Content-Addressed Storage

Each interaction is saved to a file named with timestamp and content hash, providing several benefits:

~~~ 
recordings/
├── 20250821-105406-271633-4b51df4bdd5089b1.json  # GET /users
├── 20250821-105006-257022-fbbb5beb8add436b.json  # POST /orders
└── 20250820-101234-567890-9876543210fedcba.json  # GET /health
~~~

Benefits:
- **Automatic de-duplication**: Identical interactions → same filename
- **Parallel-safe**: Multiple processes can write without conflicts
- **Content integrity**: Hash verifies file contents
- **Git-friendly**: Stable filenames for version control

## Application Warmup

A common use case is warming up your application with recorded traffic:

~~~ ruby
require "async/http/capture"

# Step 1: Record requests during development/testing
endpoint = Async::HTTP::Endpoint.parse("https://api.example.com")
store = Async::HTTP::Capture::CassetteStore.new("warmup_interactions")

recording_middleware = Async::HTTP::Capture::Middleware.new(
  nil,
  store: store
)

client = Async::HTTP::Client.new(endpoint, middleware: [recording_middleware])

# Make the requests you want to record
Async do
  client.get("/health")
  client.get("/api/popular-items") 
  client.post("/api/user-sessions", {user_id: 123})
end

# Step 2: Use recorded interactions to warm up your application
cassette = Async::HTTP::Capture::Cassette.load("warmup_interactions")
app = MyApplication.new

puts "Warming up with #{cassette.interactions.size} recorded interactions..."
cassette.each do |interaction|
  request = interaction.request
  begin
    app_response = app.call(request)
    puts "Warmed up #{request.method} #{request.path} -> #{app_response.status}"
  rescue => error
    puts "Warning: #{request.method} #{request.path} -> #{error.message}"
  end
end

puts "Warmup complete!"
~~~

## Custom Storage Backends

You can create custom storage backends by implementing the {ruby Async::HTTP::Capture::Store} interface:

~~~ ruby
class MyCustomStore
  include Async::HTTP::Capture::Store
  
  def call(interaction)
    # Handle the interaction as needed
    # e.g., send to a database, external service, etc.
    puts "Custom handling: #{interaction.request.method} #{interaction.request.path}"
  end
end

# Use your custom store
custom_store = MyCustomStore.new
middleware = Async::HTTP::Capture::Middleware.new(app, store: custom_store)
~~~

## Key Features

- **Pure Protocol::HTTP**: Works directly with Protocol::HTTP objects, no lossy conversions
- **Content-Addressed Storage**: Each interaction saved as separate JSON file with content hash
- **Parallel-Safe**: Multiple processes can record simultaneously without conflicts
- **Flexible Stores**: Pluggable storage backends (files, console logging, etc.)
- **Complete Headers**: Full round-trip serialization including `fields` and `tail`
- **Error Handling**: Captures network errors and connection issues
- **Lazy Construction**: Protocol::HTTP objects are constructed on-demand for memory efficiency

This makes `async-http-capture` ideal for testing, debugging, application warmup, and HTTP traffic analysis scenarios.
