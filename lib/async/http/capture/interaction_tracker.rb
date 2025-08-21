# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/clock"
require "protocol/http/request"
require "protocol/http/response"

require_relative "interaction"

module Async
	module HTTP
		module Capture
			# Tracks the completion of both request and response bodies for a single interaction. Records the interaction only when both sides are complete, capturing rich error context.
			class InteractionTracker
				# Initialize the tracker.
				# @parameter store [Object] The store to record the interaction to.
				# @parameter original_request [Protocol::HTTP::Request] The original request.
				def initialize(store, original_request)
					@store = store
					@original_request = original_request
					@original_response = nil
					@request_complete = false
					@response_complete = false
					@request_body = nil
					@response_body = nil
					@error = nil
					@clock = Async::Clock.start
					
					# Will capture body as_json data at completion time for accurate state:
					@debug_request_body = nil
					@debug_response_body = nil
				end
				
				# Mark the request as ready (no body to process).
				# @parameter request [Protocol::HTTP::Request] The request.
				# @returns [Protocol::HTTP::Request] The same request.
				def mark_request_ready(request)
					@request_complete = true
					check_completion
					request
				end
				
				# Mark the response as ready (no body to process).
				# @parameter response [Protocol::HTTP::Response] The response.
				# @returns [Protocol::HTTP::Response] The same response.
				def mark_response_ready(response)
					@original_response = response
					@response_complete = true
					check_completion
					response
				end
				
				# Called when request body processing completes.
				# @parameter body [Protocol::HTTP::Body::Buffered | Nil] The captured body.
				# @parameter error [Exception | Nil] Any error that occurred.
				def request_completed(body: nil, error: nil)
					@request_complete = true
					@request_body = body
					
					# Capture as_json at completion time for accurate stateful information:
					@debug_request_body = @original_request.body&.as_json
					
					if error
						@error = capture_error_context(error, :request_body)
					end
					
					check_completion
				end
				
				# Called when response body processing completes.
				# @parameter body [Protocol::HTTP::Body::Buffered | Nil] The captured body.
				# @parameter error [Exception | Nil] Any error that occurred.
				def response_completed(body: nil, error: nil)
					@response_complete = true
					@response_body = body
					
					# Capture as_json at completion time for accurate stateful information:
					@debug_response_body = @original_response&.body&.as_json
					
					if error
						@error = capture_error_context(error, :response_body)
					end
					
					check_completion
				end
				
				# Set the response for this interaction.
				# @parameter response [Protocol::HTTP::Response] The response to associate.
				def set_response(response)
					@original_response = response
				end
				
				private
				
				# Capture raw error context for post-processing analysis.
				# @parameter error [Exception] The error that occurred.
				# @parameter phase [Symbol] The phase where the error occurred.
				# @returns [Hash] Raw error context data for external analysis.
				def capture_error_context(error, phase)
					{
						error_type: error.class.name,
						error_message: error.message,
						phase: phase,
						elapsed_ms: (@clock.total * 1000).round(2),
						timestamp: Time.now.iso8601
					}
				end
				
				# Check if both request and response are complete, and record if so.
				def check_completion
					return unless @request_complete && @response_complete
					
					# Create final request with buffered body:
					final_request = ::Protocol::HTTP::Request.new(
						@original_request.scheme,
						@original_request.authority,
						@original_request.method,
						@original_request.path,
						@original_request.version,
						@original_request.headers,
						@request_body,
						@original_request.protocol
					)
					
					# Create final response with buffered body:
					final_response = nil
					if @original_response
						final_response = ::Protocol::HTTP::Response.new(
							@original_response.version,
							@original_response.status,
							@original_response.headers,
							@response_body,
							@original_response.protocol
						)
					end
					
					# Create and record the interaction:
					interaction_data = {}
					interaction_data[:error] = @error if @error
					
					# Add as_json data for debugging (captured at completion time):
					interaction_data[:debug] = {}
					interaction_data[:debug][:request_body] = @debug_request_body if @debug_request_body
					interaction_data[:debug][:response_body] = @debug_response_body if @debug_response_body
					
					interaction = Interaction.new(
						interaction_data,
						request: final_request,
						response: final_response
					)
					
					@store.call(interaction)
				end
			end
		end
	end
end
