# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/interaction_tracker"
require "protocol/http/request"
require "protocol/http/response"
require "protocol/http/body/buffered"

describe Async::HTTP::Capture::InteractionTracker do
	let(:mock_store) do
		Class.new do
			def initialize
				@calls = []
			end
			
			def call(interaction)
				@calls << interaction
			end
			
			def calls
				@calls
			end
		end.new
	end
	
	let(:request) {Protocol::HTTP::Request["GET", "/test"]}
	let(:tracker) {subject.new(mock_store, request)}
	
	with "#mark_request_ready and #mark_response_ready" do
		it "records interaction when both request and response are ready" do
			response = Protocol::HTTP::Response[200, {}, ["Response body"]]
			
			# Mark both as ready:
			tracker.mark_request_ready(request)
			tracker.set_response(response)
			tracker.mark_response_ready(response)
			
			# Verify interaction was recorded:
			expect(mock_store.calls).to have_attributes(length: be == 1)
			interaction = mock_store.calls.first
			expect(interaction.request.path).to be == "/test"
			expect(interaction.response.status).to be == 200
		end
		
		it "does not record until both sides are complete" do
			response = Protocol::HTTP::Response[200, {}, ["Response body"]]
			
			# Mark only request as ready:
			tracker.mark_request_ready(request)
			
			# Should not have recorded yet:
			expect(mock_store.calls).to be(:empty?)
			
			# Complete the response:
			tracker.set_response(response)
			tracker.mark_response_ready(response)
			
			# Now should have recorded:
			expect(mock_store.calls).to have_attributes(length: be == 1)
		end
	end
	
	with "#request_completed and #response_completed" do
		it "records interaction when both bodies are completed" do
			request_body = Protocol::HTTP::Body::Buffered.new(["Request data"])
			response_body = Protocol::HTTP::Body::Buffered.new(["Response data"])
			response = Protocol::HTTP::Response[200, {}, []]
			
			# Complete both bodies:
			tracker.request_completed(body: request_body)
			tracker.set_response(response)
			tracker.response_completed(body: response_body)
			
			# Verify interaction was recorded with bodies:
			expect(mock_store.calls).to have_attributes(length: be == 1)
			interaction = mock_store.calls.first
			expect(interaction.request.body.chunks).to be == ["Request data"]
			expect(interaction.response.body.chunks).to be == ["Response data"]
		end
		
		it "captures error context when errors occur" do
			error = Errno::EPIPE.new("Connection broken")
			response = Protocol::HTTP::Response[200, {}, []]
			
			# Complete request, error on response:
			tracker.request_completed
			tracker.set_response(response)
			tracker.response_completed(error: error)
			
			# Verify error context was captured:
			expect(mock_store.calls).to have_attributes(length: be == 1)
			interaction = mock_store.calls.first
			expect(interaction.error).to be_a(Hash)
			expect(interaction.error[:error_type]).to be == "Errno::EPIPE"
			expect(interaction.error[:error_message]).to be(:include?, "Connection broken")
			expect(interaction.error[:phase]).to be == :response_body
			expect(interaction.error[:elapsed_ms]).to be >= 0
		end
	end
end
