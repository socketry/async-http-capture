# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/middleware"
require "async/http/capture/console_store"
require "protocol/http/request"
require "protocol/http/response"
require "protocol/http/body/buffered"
require "sus/fixtures/console/captured_logger"

describe "Async::HTTP::Capture Error Context" do
	include_context Sus::Fixtures::Console::CapturedLogger
	
	let(:console_store) {Async::HTTP::Capture::ConsoleStore.new}
	
	let(:error_app) do
		->(request) do
			# Simulate an app that causes EPIPE during response body:
			response_body = Class.new do
				def each
					yield "First chunk"
					yield "Second chunk"
					raise Errno::EPIPE, "Broken pipe during response"
				end
				
				def empty?; false; end
				def close; end
			end.new
			
			Protocol::HTTP::Response[200, {"content-length" => "100"}, response_body]
		end
	end
	
	it "captures basic interactions without errors first" do
		simple_app = ->(request) do
			Protocol::HTTP::Response[200, {}, ["Simple response"]]
		end
		
		middleware = Async::HTTP::Capture::Middleware.new(simple_app, store: console_store)
		request = Protocol::HTTP::Request["GET", "/test"]
		
		response = middleware.call(request)
		response.body.each {|chunk|}  # Consume body to trigger completion
		
		# Should have logged the interaction:
		expect(console_capture).not.to be(:empty?)
		last_log = console_capture.last
		expect(last_log[:severity]).to be == :info
		expect(last_log[:arguments].first).to be(:include?, "GET /test -> 200")
	end
end
