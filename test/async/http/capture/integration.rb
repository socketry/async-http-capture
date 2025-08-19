# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture"
require "sus/fixtures/async/http/server_context"
require "tmpdir"

describe "Async::HTTP::Capture Integration" do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	around do |&block|
		Dir.mktmpdir do |tmpdir|
			@tmpdir = tmpdir
			super(&block)
		end
	end
	
	let(:cassette_path) {File.join(@tmpdir, "integration_test")}
	let(:cassette_store) {Async::HTTP::Capture::CassetteStore.new(cassette_path)}
	
	# Define the app with recording middleware:
	let(:app) do
		base_app = Protocol::HTTP::Middleware.for do |request|
			Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello, World!"]]
		end
		
		# Wrap with recording middleware:
		Async::HTTP::Capture::Middleware.new(base_app, store: cassette_store)
	end
	
	it "can make basic HTTP requests" do
		response = client.get("/")
		expect(response.status).to be == 200
		body = response.read
		expect(body).to be == "Hello, World!"
		
		# Verify interactions were recorded:
		expect(File).to be(:directory?, cassette_path)
		cassette = Async::HTTP::Capture::Cassette.load(cassette_path)
		expect(cassette.interactions.length).to be >= 1
		
		# Check recorded interaction:
		interaction = cassette.interactions.first
		expect(interaction.request.method).to be == "GET"
		expect(interaction.request.path).to be == "/"
		expect(interaction.response.status).to be == 200
		expect(interaction.response.body.chunks.join).to be == "Hello, World!"
	end
end
