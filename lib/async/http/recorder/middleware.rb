# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http/middleware"
require "protocol/http/body/buffered"

module Async
	module HTTP
		module Recorder
			# Protocol::HTTP::Middleware for recording HTTP interactions to a cassette file.
			# 
			# This middleware captures HTTP requests and optionally responses, storing them
			# in a format that can be replayed later. By default, only requests are recorded,
			# making it suitable for warmup scenarios.
			class Middleware < Protocol::HTTP::Middleware
				# Initialize the recording middleware.
				# @parameter app [Protocol::HTTP::Middleware] The next middleware in the chain.
				# @parameter cassette_path [String] The path where recorded interactions should be saved.
				# @parameter record_response [Boolean] Whether to record responses in addition to requests.
				# @parameter **options [Hash] Additional options for recording behavior.
				# @option batch_size [Integer] Number of interactions to accumulate before saving (default: 1).
				def initialize(app, cassette_path:, record_response: false, **options)
					super(app)
					@cassette_path = cassette_path
					@record_response = record_response
					@interactions = []
					@options = options
				end
				
				# Process an HTTP request, capturing it and optionally the response.
				# @parameter request [Protocol::HTTP::Request] The incoming HTTP request.
				# @returns [Protocol::HTTP::Response] The response from the next middleware.
				def call(request)
					# Capture request body if present:
					captured_request = capture_request_body(request)
					
					# Get response from downstream middleware/app:
					response = super(captured_request)
					
					if @record_response
						# Capture response body if present and record interaction:
						capture_response_and_record(captured_request, response)
					else
						# Record request only:
						record_interaction(captured_request)
					end
					
					response
				end
				
				private
				
				# Capture the request body to ensure it can be recorded.
				# @parameter request [Protocol::HTTP::Request] The original request.
				# @returns [Protocol::HTTP::Request] A new request with captured body.
				def capture_request_body(request)
					return request unless request.body && !request.body.empty?
					
					# Read request body into array of chunks:
					chunks = []
					request.body.each {|chunk| chunks << chunk}
					
					# Create new request with buffered body:
					Protocol::HTTP::Request.new(
						request.scheme,
						request.authority,
						request.method,
						request.path,
						request.version,
						request.headers.dup,
						Protocol::HTTP::Body::Buffered.new(chunks),
						request.protocol
					)
				end
				
				# Capture the response body and record the complete interaction.
				# @parameter request [Protocol::HTTP::Request] The captured request.
				# @parameter response [Protocol::HTTP::Response] The response to capture.
				def capture_response_and_record(request, response)
					if response.body && !response.body.empty?
						# Read response body into buffered chunks:
						chunks = []
						response.body.each {|chunk| chunks << chunk}
						
						# Create response with captured body:
						response_with_body = Protocol::HTTP::Response.new(
							response.version,
							response.status,
							response.headers.dup,
							Protocol::HTTP::Body::Buffered.new(chunks),
							response.protocol
						)
						
						# Record the interaction with captured body:
						record_interaction(request, response_with_body)
						
						# Return original response:
						response
					else
						# No response body, record immediately:
						record_interaction(request, response)
						response
					end
				end
				
				# Record an interaction with the given request and optional response.
				# @parameter request [Protocol::HTTP::Request] The request to record.
				# @parameter response [Protocol::HTTP::Response | Nil] The optional response to record.
				def record_interaction(request, response = nil)
					# Convert Protocol::HTTP objects to serializable format:
					interaction_data = {
						request: serialize_request(request)
					}
					
					if response
						interaction_data[:response] = serialize_response(response)
					end
					
					interaction = Interaction.new(interaction_data)
					@interactions << interaction
					save_cassette if should_save?
				end
				
				# Serialize a Protocol::HTTP::Request to a hash.
				# @parameter request [Protocol::HTTP::Request] The request to serialize.
				# @returns [Hash] The serialized request data.
				def serialize_request(request)
					data = {
						scheme: request.scheme,
						authority: request.authority,
						method: request.method,
						path: request.path,
						version: request.version,
						protocol: request.protocol
					}
					
					# Add headers if present:
					if request.headers && !request.headers.empty?
						data[:headers] = {
							fields: request.headers.fields,
							tail: request.headers.tail
						}
					end
					
					# Add body chunks if present:
					if request.body && request.body.is_a?(Protocol::HTTP::Body::Buffered)
						data[:body] = request.body.chunks
					end
					
					data
				end
				
				# Serialize a Protocol::HTTP::Response to a hash.
				# @parameter response [Protocol::HTTP::Response] The response to serialize.
				# @returns [Hash] The serialized response data.
				def serialize_response(response)
					data = {
						version: response.version,
						status: response.status,
						protocol: response.protocol
					}
					
					# Add headers if present:
					if response.headers && !response.headers.empty?
						data[:headers] = {
							fields: response.headers.fields,
							tail: response.headers.tail
						}
					end
					
					# Add body chunks if present:
					if response.body && response.body.is_a?(Protocol::HTTP::Body::Buffered)
						data[:body] = response.body.chunks
					end
					
					data
				end
				
				# Save the current interactions to the cassette file.
				def save_cassette
					cassette = Cassette.new(@interactions)
					cassette.save(@cassette_path)
				end
				
				# Determine if the cassette should be saved now.
				# @returns [Boolean] True if the cassette should be saved.
				def should_save?
					@interactions.size >= (@options[:batch_size] || 1)
				end
			end
		end
	end
end
