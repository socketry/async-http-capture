# HTTP Capture Recording Example

This example demonstrates how to use `async-http-capture` with Falcon to record HTTP interactions.

## Files

- `falcon.rb` - Falcon server configuration using `Async::HTTP::Capture::Environment` for clean, declarative setup
- `config.ru` - Alternative Rack application with multiple endpoints (for use with rackup)

## Usage

The `Async::HTTP::Capture::Environment` provides a clean, declarative way to configure both recording and replay:

1. **Run Falcon**:
   ```bash
   bundle exec ./falcon.rb
   ```
   
   Configuration is simple and declarative:
   ```ruby
   service "recorder-example" do
     include Async::HTTP::Capture::Environment
     
     def capture_cassette_directory; "recordings"; end     # Load for warmup
     def capture_recordings_directory; "recordings"; end   # Save new interactions
     def capture_console_logging; true; end                # Enable logging
   end
   ```

2. **Make requests to record new interactions**:
   ```bash
   curl http://localhost:9292/
   curl http://localhost:9292/test
   curl -X POST http://localhost:9292/api -d '{"test": true}'
   ```

3. **Restart to see replay in action**:
   The environment will automatically replay existing recordings on startup for application warmup.

### Alternative: Using Rackup

You can also run with rackup (though Falcon is recommended for better performance):

```bash
CAPTURE_ENABLED=true bundle exec rackup config.ru -p 9292
```

## Features

- **Automatic Replay**: Environment loads and replays existing recordings for warmup
- **Content-Addressed Storage**: Each unique request gets saved as a separate JSON file
- **Parallel-Safe Recording**: Multiple processes can record simultaneously
- **Console Logging**: Real-time visibility into recorded interactions
