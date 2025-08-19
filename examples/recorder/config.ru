#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Rack application demonstrating async-http-capture recording
# This application provides several endpoints that generate different types of responses

require 'json'
require 'time'

# Simple hello world application with multiple endpoints
app = lambda do |env|
	request = Rack::Request.new(env)
	
	case request.path_info
	when '/'
		# Simple homepage
		body = <<~HTML
			<html>
			<head><title>Recorder Example</title></head>
			<body>
				<h1>HTTP Capture Recording Example</h1>
				<p>This application demonstrates async-http-capture recording.</p>
				<ul>
					<li><a href="/hello">Simple Hello</a></li>
					<li><a href="/json">JSON Response</a></li>
					<li><a href="/headers">Show Request Headers</a></li>
					<li><a href="/post" onclick="postExample()">POST Example</a></li>
				</ul>
				<script>
				function postExample() {
					fetch('/post', {
						method: 'POST',
						headers: {'Content-Type': 'application/json'},
						body: JSON.stringify({message: 'Hello from browser!'})
					}).then(r => r.text()).then(alert);
				}
				</script>
			</body>
			</html>
		HTML
		
		[200, {'Content-Type' => 'text/html'}, [body]]
		
	when '/hello'
		# Simple text response
		[200, {'Content-Type' => 'text/plain'}, ["Hello, World! #{Time.now}"]]
		
	when '/json'
		# JSON response
		data = {
			message: "Hello from JSON API",
			timestamp: Time.now.iso8601,
			random: rand(1000)
		}
		[200, {'Content-Type' => 'application/json'}, [JSON.generate(data)]]
		
	when '/headers'
		# Show request headers
		headers_info = env.select { |k, _| k.start_with?('HTTP_') }
			.transform_keys { |k| k.sub('HTTP_', '').split('_').map(&:capitalize).join('-') }
		
		response = {
			method: request.request_method,
			path: request.path_info,
			query: request.query_string,
			headers: headers_info
		}
		
		[200, {'Content-Type' => 'application/json'}, [JSON.pretty_generate(response)]]
		
	when '/post'
		# Handle POST requests
		if request.request_method == 'POST'
			# Read request body
			body = request.body.read
			
			response = {
				message: "Received POST request",
				content_type: request.content_type,
				body_length: body.length,
				body_preview: body[0..100], # First 100 chars
				timestamp: Time.now.iso8601
			}
			
			[200, {'Content-Type' => 'application/json'}, [JSON.pretty_generate(response)]]
		else
			[405, {'Content-Type' => 'text/plain'}, ['Method Not Allowed - Use POST']]
		end
		
	when '/error'
		# Generate an error for testing error recording
		raise "Intentional error for testing"
		
	when '/slow'
		# Simulate a slow response
		sleep(1)
		[200, {'Content-Type' => 'text/plain'}, ["Slow response after 1 second delay"]]
		
	else
		# 404 Not Found
		[404, {'Content-Type' => 'text/plain'}, ['Not Found']]
	end
end

# If running with plain rackup (not Falcon), we can add the middleware here
# But when using Falcon with falcon.rb, the middleware is configured there
if ENV['CAPTURE_ENABLED'] == 'true'
	require 'async/http/capture'
	
	# Create stores for recording
	store = Async::HTTP::Capture::CassetteStore.new("recordings")
	console_store = Async::HTTP::Capture::ConsoleStore.new
	
	combined_store = proc do |interaction|
		store.call(interaction)
		console_store.call(interaction)
	end
	
	# Wrap the app with capture middleware
	app = Async::HTTP::Capture::Middleware.new(
		app,
		store: combined_store,
		record_response: true
	)
end

run app
