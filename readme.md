# Async::HTTP::Recorder

A Ruby gem for recording and replaying HTTP requests using `Protocol::HTTP`. Features content-addressed storage, parallel-safe recording, and flexible store backends.

[![Development Status](https://github.com/socketry/async-http-recorder/workflows/Test/badge.svg)](https://github.com/socketry/async-http-recorder/actions?workflow=Test)

## Features

  - **Pure Protocol::HTTP**: Works directly with Protocol::HTTP objects, no lossy conversions
  - **Content-Addressed Storage**: Each interaction saved as separate JSON file with content hash
  - **Parallel-Safe**: Multiple processes can record simultaneously without conflicts
  - **Flexible Stores**: Pluggable storage backends (files, console logging, etc.)
  - **Complete Headers**: Full round-trip serialization including `fields` and `tail`
  - **Error Handling**: Captures network errors and connection issues

## Usage

### Basic Recording to Files

``` ruby
require "async/http/recorder"

# Create a store that saves to content-addressed files:
store = Async::HTTP::Recorder::CassetteStore.new("interactions")

# Create middleware:
app = ->(request) { Protocol::HTTP::Response[200, {}, ["OK"]] }
middleware = Async::HTTP::Recorder::Middleware.new(app, store: store)

# Record interactions:
request = Protocol::HTTP::Request["GET", "/users"]
response = middleware.call(request)
```

### Recording to Console Log

``` ruby
# Create a console store for debugging:
console_store = Async::HTTP::Recorder::ConsoleStore.new
middleware = Async::HTTP::Recorder::Middleware.new(app, store: console_store)

# This will log interactions to console:
middleware.call(request)
# Output: "Recorded: GET /users"
```

### Loading and Replaying

``` ruby
# Load recorded interactions:
cassette = Async::HTTP::Recorder::Cassette.load("interactions")

# Replay them:
cassette.each do |interaction|
  request = interaction.request  # Lazy construction
  response = app.call(request)   # Send to your app
end
```

### Recording with Responses

``` ruby
# Record both requests and responses:
middleware = Async::HTTP::Recorder::Middleware.new(
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

## Content-Addressed Storage

Each interaction is saved to a file named by its content hash:

    interactions/
    ├── a1b2c3d4e5f67890.json  # GET /users
    ├── f67890a1b2c3d4e5.json  # POST /orders  
    └── 1234567890abcdef.json  # GET /health

Benefits:

  - **Automatic de-duplication**: Identical interactions → same filename
  - **Parallel-safe**: Multiple processes can write without conflicts
  - **Content integrity**: Hash verifies file contents
  - **Git-friendly**: Stable filenames for version control

## Store Implementations

### CassetteStore

Saves interactions to content-addressed JSON files in a directory.

### ConsoleStore

Logs interactions via the Console gem with different levels based on success/failure.

### Custom Stores

Implement the `Store` interface:

``` ruby
class MyStore
  include Async::HTTP::Recorder::Store
  
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
