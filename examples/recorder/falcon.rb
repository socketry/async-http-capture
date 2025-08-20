#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Load the capture library
require "async/http/capture"
require "falcon/environment/application"

# Configure the host and port for the server
service "recorder-example" do
	include Falcon::Environment::Application
	
	# Bind to localhost on port 9292
	endpoint Async::HTTP::Endpoint.parse(
		"http://localhost:9292"
	)
	
	# This is where we set up the recording middleware
	# The middleware will automatically capture all requests and responses
	middleware do
		# Create a cassette store for recording interactions
		store = Async::HTTP::Capture::CassetteStore.new("recordings")
		
		# Also create a console store for debugging
		console_store = Async::HTTP::Capture::ConsoleStore.new
		
		# You can chain multiple stores if needed
		combined_store = proc do |interaction|
			store.call(interaction)
			console_store.call(interaction)
		end
		
		application = Protocol::HTTP::Middleware.build do
			run ::Protocol::HTTP::Middleware::HelloWorld
		end
		
		middleware = Async::HTTP::Capture::Middleware.new(
			application,
			store: combined_store
		)
		
		# Replay interactions:
		cassette = store.cassette
		cassette.each do |interaction|
			puts "Replaying interaction: #{interaction}"
			response = application.call(interaction.request)
			response.finish
		end
		
		middleware
	end
end
