# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/recorder/interaction"

describe Async::HTTP::Recorder::Interaction do
	let(:simple_request_data) do
		{
			request: {
				method: "GET",
				path: "/test",
				scheme: "https",
				authority: "example.com"
			}
		}
	end
	
	let(:request_with_headers_data) do
		{
			request: {
				method: "POST",
				path: "/users",
				scheme: "https",
				authority: "example.com",
				headers: {
					fields: [["Content-Type", "application/json"], ["Accept", "application/json"]],
					tail: nil
				}
			}
		}
	end
	
	let(:request_with_body_data) do
		{
			request: {
				method: "POST",
				path: "/users",
				scheme: "https",
				authority: "example.com",
				headers: {
					fields: [["Content-Type", "application/json"]],
					tail: nil
				},
				body: ['{"name": "John Doe"}']
			}
		}
	end
	
	let(:interaction_with_response_data) do
		{
			request: {
				method: "GET",
				path: "/users/123",
				scheme: "https",
				authority: "example.com"
			},
			response: {
				status: 200,
				headers: {
					fields: [["Content-Type", "application/json"]],
					tail: nil
				},
				body: ['{"id": 123, "name": "John Doe"}']
			}
		}
	end
	
	with "#request" do
		it "creates a Protocol::HTTP::Request from simple request data" do
			interaction = subject.new(simple_request_data)
			request = interaction.request
			
			expect(request).to be_a(Protocol::HTTP::Request)
			expect(request.method).to be == "GET"
			expect(request.path).to be == "/test"
			expect(request.scheme).to be == "https"
			expect(request.authority).to be == "example.com"
		end
		
		it "creates a request with headers when provided" do
			interaction = subject.new(request_with_headers_data)
			request = interaction.request
			
			expect(request.headers).to be_a(Protocol::HTTP::Headers)
			expect(request.headers["content-type"]).to be == "application/json"
			
			# Headers can have multiple values, so we check if it's a single value or array:
			accept_values = request.headers["accept"]
			if accept_values.is_a?(Array)
				expect(accept_values).to be(:include?, "application/json")
			else
				expect(accept_values).to be == "application/json"
			end
		end
		
		it "creates a request with body when provided" do
			interaction = subject.new(request_with_body_data)
			request = interaction.request
			
			expect(request.body).to be_a(Protocol::HTTP::Body::Buffered)
			expect(request.body.chunks).to be == ['{"name": "John Doe"}']
		end
		
		it "returns nil when no request data is present" do
			interaction = subject.new({})
			request = interaction.request
			
			expect(request).to be_nil
		end
		
		it "caches the constructed request object" do
			interaction = subject.new(simple_request_data)
			request1 = interaction.request
			request2 = interaction.request
			
			expect(request1).to be_equal(request2)
		end
	end
	
	with "#response" do
		it "creates a Protocol::HTTP::Response from response data" do
			interaction = subject.new(interaction_with_response_data)
			response = interaction.response
			
			expect(response).to be_a(Protocol::HTTP::Response)
			expect(response.status).to be == 200
			expect(response.headers["content-type"]).to be == "application/json"
			expect(response.body.chunks).to be == ['{"id": 123, "name": "John Doe"}']
		end
		
		it "returns nil when no response data is present" do
			interaction = subject.new(simple_request_data)
			response = interaction.response
			
			expect(response).to be_nil
		end
		
		it "caches the constructed response object" do
			interaction = subject.new(interaction_with_response_data)
			response1 = interaction.response
			response2 = interaction.response
			
			expect(response1).to be_equal(response2)
		end
	end
	
	with "#to_h" do
		it "returns the raw interaction data" do
			interaction = subject.new(simple_request_data)
			
			expect(interaction.to_h).to be == simple_request_data
		end
	end
end
