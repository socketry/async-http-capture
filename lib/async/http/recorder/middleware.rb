# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http/middleware"
require "protocol/http/body/buffered"
require "protocol/http/body/rewindable"
require "protocol/http/body/completable"

module Async
	module HTTP
		module Recorder
			# Protocol::HTTP::Middleware for recording HTTP interactions.
			# 
			# This middleware captures HTTP requests and optionally responses, then delegates
			# storage to a provided store object. The middleware handles Protocol::HTTP object
			# capture, while the store handles serialization, filtering, and persistence.
			class Middleware < Protocol::HTTP::Middleware
				# Initialize the recording middleware.
				# @parameter app [Protocol::HTTP::Middleware] The next middleware in the chain.
				# @parameter store [Object] An object that responds to #call(interaction) to handle recorded interactions.
				# @parameter record_response [Boolean] Whether to record responses in addition to requests.
				def initialize(app, store:, record_response: false)
					super(app)
					@store = store
					@record_response = record_response
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
					return Protocol::HTTP::Request.new(
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
				# Uses non-blocking streaming capture to avoid interfering with response consumption.
				# @parameter request [Protocol::HTTP::Request] The captured request.
				# @parameter response [Protocol::HTTP::Response] The response to capture.
				# @returns [Protocol::HTTP::Response] The wrapped response.
				def capture_response_and_record(request, response)
					if response.body && !response.body.empty?
						# Use streaming capture to avoid blocking:
						return wrap_response_body(request, response) do |response, body|
							# body is the buffered content available after completion:
							record_interaction(request, response, body)
						end
					else
						# No response body, record immediately:
						record_interaction(request, response)
						return response
					end
				end
				
				# Wrap response body for non-blocking capture.
				# @parameter request [Protocol::HTTP::Request] The request.
				# @parameter response [Protocol::HTTP::Response] The response to wrap.
				# @yields {|response, body| ...} Called when body capture is complete.
				#   @parameter response [Protocol::HTTP::Response] The original response.
				#   @parameter body [Protocol::HTTP::Body::Buffered] The captured body content.
				# @returns [Protocol::HTTP::Response] The wrapped response.
				def wrap_response_body(request, response, &block)
					# Insert a rewindable body so that we can capture the response body:
					rewindable = ::Protocol::HTTP::Body::Rewindable.wrap(response)
					
					# Wrap the response with the completion callback:
					::Protocol::HTTP::Body::Completable.wrap(response) do |error|
						if error
							# Record interaction with error:
							record_interaction(request, response, error: error)
						else
							# Record interaction with captured body:
							yield response, rewindable.buffered
						end
					end
					
					return response
				end
				
				# Record an interaction with the given request and optional response.
				# @parameter request [Protocol::HTTP::Request] The request to record.
				# @parameter response [Protocol::HTTP::Response | Nil] The optional response to record.
				# @parameter body [Protocol::HTTP::Body::Buffered | Nil] The captured response body, if any.
				# @parameter error [Exception | Nil] Any error that occurred during the interaction.
				def record_interaction(request, response = nil, body = nil, error: nil)
					# Create response with captured body if provided:
					final_response = response
					if response && body
						final_response = Protocol::HTTP::Response.new(
							response.version,
							response.status,
							response.headers,
							body,
							response.protocol
						)
					end
					
					# Create interaction with Protocol::HTTP objects and minimal data:
					interaction_data = {}
					interaction_data[:error] = error if error
					
					interaction = Interaction.new(
						interaction_data,
						request: request,
						response: final_response
					)
					
					# Delegate to store:
					@store.call(interaction)
				end
			end
		end
	end
end
