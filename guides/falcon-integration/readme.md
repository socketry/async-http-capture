# Falcon Integration

This guide explains how to integrate `async-http-capture` with Falcon web server for recording and replaying HTTP interactions.

## Core Concepts

Falcon integration with `async-http-capture` uses the {ruby Async::HTTP::Capture::Environment} to provide clean, declarative configuration for both recording and replay functionality.

## Usage

Create a `falcon.rb` configuration file:

~~~ ruby
#!/usr/bin/env falcon-host
# frozen_string_literal: true

require "falcon/environment/rack"
require "async/http/capture"

service "my-app" do
	include Falcon::Environment::Rack
	include Async::HTTP::Capture::Environment
end
~~~

This minimal configuration automatically:

- **Records interactions** to `cassette/recordings/` directory
- **Replays existing recordings** from `cassette/warmup/` for application warmup
- **Logs interactions** to console for visibility

### Custom Configuration

Override the environment methods to customize behavior:

~~~ ruby
service "my-app" do
	include Falcon::Environment::Rack
	include Async::HTTP::Capture::Environment
		
	def capture_cassette_directory
		# Custom warmup directory:
		"recordings/warmup"
	end
	
	def capture_recordings_directory
		# Custom recording directory:
		"recordings/production"
	end
	
	def capture_console_logging
		# Disable console output for production:
		false
	end
end
~~~

## Running the Server

Start your Falcon server with recording enabled:

~~~ bash
$ bundle exec ./falcon.rb
~~~

The server will:

1. **Start up**: Load and replay any existing recordings for warmup
2. **Accept requests**: Process incoming HTTP requests normally  
3. **Record interactions**: Save all new interactions to timestamped files
4. **Log activity**: Show recording activity in console (if enabled)

## Application Warmup

One of the most powerful features is automatic application warmup using recorded interactions:

### Recording Phase

During development or testing, make requests to capture typical usage patterns:

~~~ bash
# Make various requests to capture typical traffic patterns
curl http://localhost:9292/health
curl http://localhost:9292/api/users
curl -X POST http://localhost:9292/api/orders \
  -H "content-type: application/json" \
  -d '{"product_id": 123, "quantity": 2}'
~~~

These requests are recorded to `cassette/recordings/` as:

~~~ 
cassette/recordings/
├── 20250821-105406-271633-12345-67890.json  # GET /health
├── 20250821-105407-123456-12345-67890.json  # GET /api/users
└── 20250821-105408-654321-12345-67890.json  # POST /api/orders
~~~

Files are named: `YYYYMMDD-HHMMSS-MICROSECONDS-PID-OBJECT_ID.json`

Where:
- `YYYYMMDD-HHMMSS-MICROSECONDS` = timestamp with microsecond precision.
- `PID` = process ID.
- `OBJECT_ID` = store instance object ID.

### Warmup Phase

On subsequent server starts, the Environment automatically replays recorded interactions to warm up:

- **Database connections**
- **Application caches** 
- **JIT compilation**
- **Service dependencies**

This dramatically improves first-request latency and provides predictable application startup behavior in production.
