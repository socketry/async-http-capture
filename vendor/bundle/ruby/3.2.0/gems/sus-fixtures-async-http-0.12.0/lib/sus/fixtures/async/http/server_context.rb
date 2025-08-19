# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "sus/fixtures/async/reactor_context"

require "async/http/server"
require "async/http/client"
require "async/http/endpoint"

module Sus::Fixtures
	module Async
		module HTTP
			# ServerContext provides a test fixture for HTTP server and client testing.
			# It sets up an HTTP server with a bound endpoint and provides a corresponding client
			# for making requests. This context handles the lifecycle of both server and client,
			# ensuring proper setup and teardown.
			#
			# The context automatically:
			# - Binds to an available port
			# - Starts an HTTP server with configurable middleware
			# - Creates a client configured to connect to the server
			# - Handles cleanup of resources after tests
			module ServerContext
				include ReactorContext
				
				# The HTTP protocol version to use for the server.
				# @returns [Class] The protocol class (defaults to HTTP/1.1).
				def protocol
					::Async::HTTP::Protocol::HTTP1
				end
				
				# The base URL for the HTTP server.
				# @returns [String] The URL string with host and port (defaults to localhost:0 for auto-assigned port).
				def url
					"http://localhost:0"
				end
				
				# Get all bound URLs for the server endpoints.
				# @returns [Array(String)] Array of URLs the server is bound to, sorted alphabetically.
				def bound_urls
					urls = []
					
					@client_endpoint.each do |address_endpoint|
						address = address_endpoint.address
						
						host = address.ip_address
						if address.ipv6?
							host = "[#{host}]"
						end
						
						port = address.ip_port
						
						urls << "#{endpoint.scheme}://#{host}:#{port}"
					end
					
					urls.sort!
					
					return urls
				end
				
				# Get the first bound URL for the server.
				# @returns [String] The first bound URL, typically used for single-endpoint testing.
				def bound_url
					bound_urls.first
				end
				
				# Options for configuring the HTTP endpoint.
				# @returns [Hash] Hash of endpoint options including port reuse and protocol settings.
				def endpoint_options
					{reuse_port: true, protocol: protocol}
				end
				
				# The HTTP endpoint configuration.
				# @returns [Async::HTTP::Endpoint] Parsed endpoint with configured options.
				def endpoint
					::Async::HTTP::Endpoint.parse(url, **endpoint_options)
				end
				
				# Number of retries for client requests.
				# @returns [Integer] Number of retry attempts (defaults to 1).
				def retries
					1
				end
				
				# The HTTP application/middleware to serve.
				# @returns [Object] The application object that handles HTTP requests (defaults to HelloWorld middleware).
				def app
					::Protocol::HTTP::Middleware::HelloWorld
				end
				
				# The middleware stack for the HTTP server.
				# @returns [Object] The middleware configuration (defaults to the app).
				def middleware
					app
				end
				
				# Create the server endpoint from a bound endpoint.
				# @parameter bound_endpoint [Async::HTTP::Endpoint] The bound endpoint.
				# @returns [Async::HTTP::Endpoint] The server endpoint configuration.
				def make_server_endpoint(bound_endpoint)
					bound_endpoint
				end
				
				# Create an HTTP server instance.
				# @parameter endpoint [Async::HTTP::Endpoint] The endpoint to bind the server to.
				# @returns [Async::HTTP::Server] The configured HTTP server.
				def make_server(endpoint)
					::Async::HTTP::Server.new(middleware, endpoint)
				end
				
				# The HTTP server instance.
				# @returns [Async::HTTP::Server] The running HTTP server.
				def server
					@server
				end
				
				# The HTTP client instance.
				# @returns [Async::HTTP::Client] The HTTP client configured to connect to the server.
				def client
					@client
				end
				
				# The client endpoint configuration.
				# @returns [Async::HTTP::Endpoint] The endpoint the client uses to connect to the server.
				def client_endpoint
					@client_endpoint
				end
				
				# Create a client endpoint from a bound endpoint.
				# @parameter bound_endpoint [Async::HTTP::Endpoint] The bound server endpoint.
				# @returns [Async::HTTP::Endpoint] The client endpoint with local address and timeout.
				def make_client_endpoint(bound_endpoint)
					# Pass through the timeout:
					bound_endpoint.local_address_endpoint(timeout: endpoint.timeout)
				end
				
				# Create an HTTP client instance.
				# @parameter endpoint [Async::HTTP::Endpoint] The endpoint to connect to.
				# @parameter options [Hash] Additional client options.
				# @returns [Async::HTTP::Client] The configured HTTP client.
				def make_client(endpoint, **options)
					options[:retries] = retries unless options.key?(:retries)
					
					::Async::HTTP::Client.new(endpoint, **options)
				end
				
				# Set up the server and client before running tests.
				# This method binds the endpoint, starts the server, and creates a client.
				def before
					super
					
					# We bind the endpoint before running the server so that we know incoming connections will be accepted:
					@bound_endpoint = endpoint.bound
					
					@server_endpoint = make_server_endpoint(@bound_endpoint)
					mock(@server_endpoint) do |wrapper|
						wrapper.replace(:protocol) {endpoint.protocol}
						wrapper.replace(:scheme) {endpoint.scheme}
						wrapper.replace(:authority) {endpoint.authority}
						wrapper.replace(:path) {endpoint.path}
					end
					
					@server = make_server(@server_endpoint)
					
					@server_task = @server.run
					
					@client_endpoint = make_client_endpoint(@bound_endpoint)
					mock(@client_endpoint) do |wrapper|
						wrapper.replace(:protocol) {endpoint.protocol}
						wrapper.replace(:scheme) {endpoint.scheme}
						wrapper.replace(:authority) {endpoint.authority}
						wrapper.replace(:path) {endpoint.path}
					end
					
					@client = make_client(@client_endpoint)
				end
				
				# Clean up resources after running tests.
				# This method closes the client, stops the server, and closes the bound endpoint.
				# @parameter error [Exception | Nil] Any error that occurred during the test.
				def after(error = nil)
					# We add a timeout here, to avoid hanging in `@client.close`:
					::Async::Task.current.with_timeout(1) do
						@client&.close
						@server_task&.stop
						@server_task&.wait
						@bound_endpoint&.close
					end
					
					super
				end
			end
		end
	end
end
