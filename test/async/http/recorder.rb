# frozen_string_literal: true

require 'async/http/recorder'

describe Async::HTTP::Recorder do
	it "has a version number" do
		expect(Async::HTTP::Recorder::VERSION).to be =~ /^\d+\.\d+\.\d+$/
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
		
		interaction = Async::HTTP::Recorder::Interaction.new(interaction_data)
		request = interaction.request
		
		expect(request).to be_a(Protocol::HTTP::Request)
		expect(request.method).to be == "GET"
		expect(request.path).to be == "/test"
	end
end
