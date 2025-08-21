# Async::HTTP::Capture

A Ruby gem for recording and replaying HTTP requests using `Protocol::HTTP`. Features timestamped storage, parallel-safe recording, and flexible store backends.

[![Development Status](https://github.com/socketry/async-http-capture/workflows/Test/badge.svg)](https://github.com/socketry/async-http-capture/actions?workflow=Test)

## Features

  - **Pure Protocol::HTTP**: Works directly with Protocol::HTTP objects, no lossy conversions
  - **Timestamped Storage**: Each interaction saved as separate JSON file with timestamp
  - **Parallel-Safe**: Multiple processes can record simultaneously without conflicts
  - **Flexible Stores**: Pluggable storage backends (files, console logging, etc.)
  - **Complete Headers**: Full round-trip serialization including `fields` and `tail`
  - **Error Handling**: Captures network errors and connection issues

## Usage

Please see the [project documentation](https://socketry.github.io/async-http-capture/) for more details.

  - [Getting Started](https://socketry.github.io/async-http-capture/guides/getting-started/index) - This guide explains how to get started with `async-http-capture`, a Ruby gem for recording and replaying HTTP requests using Protocol::HTTP.

### Basic Recording to Files

``` ruby
require "async/http/capture"

# Create a store that saves to timestamped files:
store = Async::HTTP::Capture::CassetteStore.new("interactions")

# Create middleware:
app = ->(request) { Protocol::HTTP::Response[200, {}, ["OK"]] }
middleware = Async::HTTP::Capture::Middleware.new(app, store: store)

# Record interactions:
request = Protocol::HTTP::Request["GET", "/users"]
response = middleware.call(request)
```

### Recording to Console Log

``` ruby
# Create a console store for debugging:
console_store = Async::HTTP::Capture::ConsoleStore.new
middleware = Async::HTTP::Capture::Middleware.new(app, store: console_store)

# This will log interactions to console:
middleware.call(request)
# Output: "Recorded: GET /users"
```

### Loading and Replaying

``` ruby
# Load recorded interactions:
cassette = Async::HTTP::Capture::Cassette.load("interactions")

# Replay them:
cassette.each do |interaction|
  request = interaction.request  # Lazy construction
  response = app.call(request)   # Send to your app
end
```

### Recording with Responses

``` ruby
# Record both requests and responses:
middleware = Async::HTTP::Capture::Middleware.new(
  app, 
  store: store,
  record_response: true
)

response = middleware.call(request)
# Both request and response are now recorded
```

## Architecture

    Middleware -> Store.call(interaction) -> [CassetteStore | ConsoleStore | ...]

  - **Middleware**: Pure capture logic, creates Interaction objects with Protocol::HTTP data
  - **Store Interface**: Generic `call(interaction)` method for pluggable backends
  - **Stores**: Handle serialization, filtering, persistence, or logging
  - **Interaction**: Simple data container with lazy Protocol::HTTP object construction

## Timestamped Storage

Each interaction is saved to a file named with timestamp, process ID, and object ID:

    recordings/
    ├── 20250821-105406-271633-12345-67890.json  # GET /users
    ├── 20250821-105006-257022-12346-67891.json  # POST /orders
    └── 20250820-101234-567890-12347-67892.json  # GET /health

Benefits:

  - **Chronological ordering**: Files sorted by timestamp
  - **Parallel-safe**: Multiple processes can write without conflicts
  - **Human-readable**: Timestamps are easy to understand

## Store Implementations

### CassetteStore

Saves interactions to timestamped JSON files in a directory.

### ConsoleStore

Logs interactions via the Console gem with different levels based on success/failure.

### Custom Stores

Implement the `Store` interface:

``` ruby
class MyStore
  include Async::HTTP::Capture::Store
  
  def call(interaction)
    # Handle the interaction as needed
  end
end
```

## Testing

``` bash
bundle exec sus
```

The gem includes comprehensive tests using the Sus testing framework with 41 tests and 101 assertions.
