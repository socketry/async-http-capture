# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http/middleware"
require "protocol/http/body/rewindable"
require "protocol/http/body/completable"

require_relative "interaction_tracker"

module Async
	module HTTP
		module Capture
			# Protocol::HTTP::Middleware for recording complete HTTP interactions.
			# 
			# This middleware captures both HTTP requests and responses, waiting for both
			# to be fully processed before recording the complete interaction.
			class Middleware < ::Protocol::HTTP::Middleware
				# Initialize the recording middleware.
				# @parameter app [Protocol::HTTP::Middleware] The next middleware in the chain.
				# @parameter store [Object] An object that responds to #call(interaction) to handle recorded interactions.
				def initialize(app, store:)
					super(app)
					@store = store
				end
				
				# Process an HTTP request, capturing both request and response.
				# @parameter request [Protocol::HTTP::Request] The incoming HTTP request.
				# @returns [Protocol::HTTP::Response] The response from the next middleware.
				def call(request)
					# Check if we should capture this request:
					unless capture?(request)
						return super(request)
					end
					
					# Create completion tracker for this interaction:
					tracker = create_interaction_tracker(request)
					
					# Capture request body with completion tracking:
					captured_request = capture_request_with_completion(request, tracker)
					
					# Get response from downstream middleware/app:
					response = super(captured_request)
					
					# Capture response body with completion tracking:
					capture_response_with_completion(captured_request, response, tracker)
				end
				
				# Determine whether to capture the given request.
				# Override this method in subclasses to implement custom filtering logic.
				# @parameter request [Protocol::HTTP::Request] The incoming HTTP request.
				# @returns [Boolean] True if the request should be captured, false otherwise.
				def capture?(request)
					true
				end
				
				private
				
				# Create a completion tracker for a single interaction.
				# @parameter request [Protocol::HTTP::Request] The original request.
				# @returns [InteractionTracker] A new tracker instance.
				def create_interaction_tracker(request)
					InteractionTracker.new(@store, request)
				end
				
				# Capture the request body with completion tracking.
				# @parameter request [Protocol::HTTP::Request] The original request.
				# @parameter tracker [InteractionTracker] The completion tracker.
				# @returns [Protocol::HTTP::Request] A request with rewindable body.
				def capture_request_with_completion(request, tracker)
					return tracker.mark_request_ready(request) unless request.body && !request.body.empty?
					
					# Make the request body rewindable:
					rewindable_body = ::Protocol::HTTP::Body::Rewindable.wrap(request)
					
					# Wrap with completion callback:
					::Protocol::HTTP::Body::Completable.wrap(request) do |error|
						# Always capture whatever body data we have, even if there was an error
						captured_body = rewindable_body.buffered rescue nil
						
						if error
							tracker.request_completed(body: captured_body, error: error)
						else
							tracker.request_completed(body: captured_body)
						end
					end
					
					return request
				end
				
				# Capture the response body with completion tracking.
				# @parameter request [Protocol::HTTP::Request] The captured request.
				# @parameter response [Protocol::HTTP::Response] The response to capture.
				# @parameter tracker [InteractionTracker] The completion tracker.
				# @returns [Protocol::HTTP::Response] The wrapped response.
				def capture_response_with_completion(request, response, tracker)
					# Set the response on the tracker:
					tracker.set_response(response)
					
					return tracker.mark_response_ready(response) unless response.body && !response.body.empty?
					
					# Make the response body rewindable:
					rewindable_body = ::Protocol::HTTP::Body::Rewindable.wrap(response)
					
					# Wrap with completion callback:
					::Protocol::HTTP::Body::Completable.wrap(response) do |error|
						# Always capture whatever body data we have, even if there was an error
						captured_body = rewindable_body.buffered rescue nil
						
						if error
							tracker.response_completed(body: captured_body, error: error)
						else
							tracker.response_completed(body: captured_body)
						end
					end
					
					return response
				end
			end
		end
	end
end
