# HTTP Capture Recording Example

This example demonstrates how to use `async-http-capture` with Falcon to record HTTP interactions.

## Files

- `falcon.rb` - Falcon server configuration with recording middleware and simple HelloWorld app
- `config.ru` - Alternative Rack application with multiple endpoints (for use with rackup)

## Usage

1. **Run Falcon**:
   ```bash
   bundle exec ./falcon.rb
   ```

2. **Make some requests**:
   ```bash
   curl http://localhost:9292/
   curl http://localhost:9292/test
   curl -X POST http://localhost:9292/api -d '{"test": true}'
   ```

3. **Check the results**:
   - **Console output**: See real-time JSON logging of each interaction
   - **Recordings directory**: Check `recordings/` for saved JSON files

Each unique request gets saved as a content-addressed JSON file for parallel-safe recording.
