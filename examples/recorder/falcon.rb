#!/usr/bin/env falcon-host
# frozen_string_literal: true

require "falcon/environment/rack"
require "async/http/capture"

# Configure the service with capture environment
service "recorder-example" do
	include Falcon::Environment::Rack

	# The Environment automatically sets up middleware and replay
	# No manual middleware configuration needed!
	include Async::HTTP::Capture::Environment
	
	# Bind to localhost on port 9292
	endpoint Async::HTTP::Endpoint.parse("http://localhost:9292")
end
