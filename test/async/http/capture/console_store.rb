# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/console_store"
require "async/http/capture/interaction"
require "protocol/http/request"
require "protocol/http/response"
require "sus/fixtures/console/captured_logger"

describe Async::HTTP::Capture::ConsoleStore do
	include_context Sus::Fixtures::Console::CapturedLogger
	
	let(:simple_request) do
		Protocol::HTTP::Request["GET", "/test"]
	end
	
	let(:simple_response) do
		Protocol::HTTP::Response[200, {"Content-Type" => "text/plain"}, ["Hello"]]
	end
	
	with "#call" do
		it "logs request-only interactions with full data" do
			store = subject.new
			interaction = Async::HTTP::Capture::Interaction.new({}, request: simple_request)
			
			store.call(interaction)
			
			# Check that debug log was created:
			expect(console_capture.last).to have_keys(
				severity: be == :debug,
				arguments: have_value(be(:start_with?, "Recorded: GET /test"))
			)
			
			# Extract the full message including JSON from console capture:
			log_message = console_capture.last[:message]
			expect(log_message).to be(:include?, '"method": "GET"')
			expect(log_message).to be(:include?, '"path": "/test"')
			
			# Verify the output contains parseable interaction JSON:
			json_start = log_message.index("{")
			json_end = log_message.rindex("}")
			expect(json_start).not.to be_nil
			expect(json_end).not.to be_nil
			
			json_string = log_message[json_start..json_end]
			parsed_json = JSON.parse(json_string, symbolize_names: true)
			expect(parsed_json[:request][:method]).to be == "GET"
			expect(parsed_json[:request][:path]).to be == "/test"
		end
		
		it "logs request-response interactions with full data" do
			store = subject.new
			interaction = Async::HTTP::Capture::Interaction.new(
				{},
				request: simple_request,
				response: simple_response
			)
			
			store.call(interaction)
			
			# Check that info log was created:
			expect(console_capture.last).to have_keys(
				severity: be == :info,
				arguments: have_value(be(:start_with?, "GET /test -> 200"))
			)
			
			# Extract the full message including JSON:
			log_message = console_capture.last[:message]
			expect(log_message).to be(:include?, '"status": 200')
			
			# Verify complete interaction data is logged:
			json_start = log_message.index("{")
			json_end = log_message.rindex("}")
			expect(json_start).not.to be_nil
			expect(json_end).not.to be_nil
			
			json_string = log_message[json_start..json_end]
			parsed_json = JSON.parse(json_string, symbolize_names: true)
			expect(parsed_json[:request][:method]).to be == "GET"
			expect(parsed_json[:response][:status]).to be == 200
		end
		
		it "logs error interactions with full data" do
			store = subject.new
			interaction = Async::HTTP::Capture::Interaction.new(
				{ error: "EPIPE: Broken pipe" },
				request: simple_request
			)
			
			store.call(interaction)
			
			# Check that error log was created:
			expect(console_capture.last).to have_keys(
				severity: be == :error,
				arguments: have_value(be(:start_with?, "HTTP Error: GET /test"))
			)
			
			# Extract the full message including JSON:
			log_message = console_capture.last[:message]
			expect(log_message).to be(:include?, '"error": "EPIPE: Broken pipe"')
			
			# Verify complete interaction data including error is logged:
			json_start = log_message.index("{")
			json_end = log_message.rindex("}")
			expect(json_start).not.to be_nil
			expect(json_end).not.to be_nil
			
			json_string = log_message[json_start..json_end]
			parsed_json = JSON.parse(json_string, symbolize_names: true)
			expect(parsed_json[:request][:method]).to be == "GET"
			expect(parsed_json[:error]).to be == "EPIPE: Broken pipe"
		end
		
		it "outputs parseable JSON that can recreate interactions" do
			store = subject.new
			interaction = Async::HTTP::Capture::Interaction.new(
				{ error: "Connection timeout" },
				request: simple_request,
				response: simple_response
			)
			
			store.call(interaction)
			
			# Extract JSON from console log:
			log_message = console_capture.last[:message]
			json_start = log_message.index("{")
			json_end = log_message.rindex("}")
			json_string = log_message[json_start..json_end]
			
			# Should be able to recreate the interaction from logged JSON:
			parsed_json = JSON.parse(json_string, symbolize_names: true)
			recreated_interaction = Async::HTTP::Capture::Interaction.new(parsed_json)
			
			expect(recreated_interaction.request.method).to be == "GET"
			expect(recreated_interaction.response.status).to be == 200
			expect(recreated_interaction.error).to be == "Connection timeout"
		end
	end
end
