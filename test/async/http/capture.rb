# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture"

describe Async::HTTP::Capture do
	it "has a version number" do
		expect(Async::HTTP::Capture::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end
	
	it "provides a working integration" do
		# Create a simple interaction:
		interaction_data = {
			request: {
				method: "GET",
				path: "/test",
				scheme: "https",
				authority: "example.com"
			}
		}
		
		interaction = Async::HTTP::Capture::Interaction.new(interaction_data)
		request = interaction.request
		
		expect(request).to be_a(Protocol::HTTP::Request)
		expect(request.method).to be == "GET"
		expect(request.path).to be == "/test"
	end
end
