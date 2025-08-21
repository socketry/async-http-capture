# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/cassette_store"
require "async/http/capture/interaction"
require "protocol/http/request"
require "protocol/http/response"
require "protocol/http/body/buffered"
require "tmpdir"

describe Async::HTTP::Capture::CassetteStore do
	around do |&block|
		Dir.mktmpdir do |root|
			@root = root
			block.call
		end
	end
	
	let(:directory_path) {File.join(@root, "cassette")}
	let(:store) {subject.new(directory_path)}
	
	let(:simple_request) do
		Protocol::HTTP::Request["GET", "/test", {"user-agent" => "Test"}]
	end
	
	let(:request_with_body) do
		Protocol::HTTP::Request[
			"POST", 
			"/users",
			{"content-type" => "application/json"},
			['{"name": "John"}']
		]
	end
	
	let(:simple_response) do
		Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello"]]
	end
	
	with "#call" do
		it "saves request-only interactions to content-addressed files" do
			interaction = Async::HTTP::Capture::Interaction.new({}, request: simple_request)
			
			store.call(interaction)
			
			# Verify directory was created:
			expect(File).to be(:directory?, directory_path)
			
			# Verify interaction file was created:
			json_files = Dir.glob(File.join(directory_path, "*.json"))
			expect(json_files).to have_attributes(length: be == 1)
			
			# Verify content:
			file_content = JSON.parse(File.read(json_files.first), symbolize_names: true)
			expect(file_content[:request][:method]).to be == "GET"
			expect(file_content[:request][:path]).to be == "/test"
		end
		
		it "saves request and response interactions" do
			interaction = Async::HTTP::Capture::Interaction.new(
				{},
				request: simple_request,
				response: simple_response
			)
			
			store.call(interaction)
			
			json_files = Dir.glob(File.join(directory_path, "*.json"))
			file_content = JSON.parse(File.read(json_files.first), symbolize_names: true)
			
			expect(file_content[:request][:method]).to be == "GET"
			expect(file_content[:response][:status]).to be == 200
		end
		
		it "saves interactions with errors" do
			interaction = Async::HTTP::Capture::Interaction.new(
				{ error: "Connection broken" },
				request: simple_request
			)
			
			store.call(interaction)
			
			json_files = Dir.glob(File.join(directory_path, "*.json"))
			file_content = JSON.parse(File.read(json_files.first), symbolize_names: true)
			
			expect(file_content[:error]).to be == "Connection broken"
		end
		
		it "stores identical interactions with different timestamps" do
			interaction1 = Async::HTTP::Capture::Interaction.new({}, request: simple_request)
			interaction2 = Async::HTTP::Capture::Interaction.new({}, request: simple_request)
			
			store.call(interaction1)
			store.call(interaction2)
			
			# With timestamp prefixes, identical content creates separate files at different times:
			json_files = Dir.glob(File.join(directory_path, "*.json"))
			expect(json_files).to have_attributes(length: be == 2)
			
			# Both files should have different timestamps:
			filenames = json_files.map {|path| File.basename(path)}
			expect(filenames[0]).not.to be == filenames[1]  # Different timestamps
			
			# Should match pattern: `YYYYMMDD-HHMMSS-MICROSECONDS-PID-OBJECTID.json`:
			filenames.each do |filename|
				expect(filename).to be(:match?, /^\d{8}-\d{6}-\d{6}-\d+-\d+\.json$/)
			end
		end
		
		it "handles different interactions separately with timestamp-prefixed filenames" do
			request1 = Protocol::HTTP::Request["GET", "/test1"]
			request2 = Protocol::HTTP::Request["GET", "/test2"]
			
			interaction1 = Async::HTTP::Capture::Interaction.new({}, request: request1)
			interaction2 = Async::HTTP::Capture::Interaction.new({}, request: request2)
			
			store.call(interaction1)
			store.call(interaction2)
			
			# Should create two files since content is different:
			json_files = Dir.glob(File.join(directory_path, "*.json"))
			expect(json_files).to have_attributes(length: be == 2)
			
			# Check that filenames follow timestamp pattern:
			filenames = json_files.map {|path| File.basename(path)}
			filenames.each do |filename|
				# Format should be: YYYYMMDD-HHMMSS-MICROSECONDS-PID-OBJECTID.json
				expect(filename).to be(:match?, /^\d{8}-\d{6}-\d{6}-\d+-\d+\.json$/)
			end
			
			# Different interactions should create different files (by timestamp)
			expect(filenames[0]).not.to be == filenames[1]
		end
	end
end
