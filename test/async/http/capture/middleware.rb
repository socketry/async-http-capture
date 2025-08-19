# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/middleware"
require "async/http/capture/cassette_store"
require "protocol/http/request"
require "protocol/http/response"
require "protocol/http/body/buffered"
require "tmpdir"

describe Async::HTTP::Capture::Middleware do
	around do |&block|
		Dir.mktmpdir do |tmpdir|
			@tmpdir = tmpdir
			block.call
		end
	end
	
	let(:cassette_path) {File.join(@tmpdir, "test_cassette")}
	let(:cassette_store) {Async::HTTP::Capture::CassetteStore.new(cassette_path)}
	
	let(:simple_app) do
		->(request) do
			Protocol::HTTP::Response[200, {}, ["Hello, World!"]]
		end
	end
	
	let(:echo_app) do
		->(request) do
			body = []
			if request.body
				request.body.each {|chunk| body << chunk}
			end
			
			Protocol::HTTP::Response[200, {"Content-Type" => "text/plain"}, body]
		end
	end
	
	with "#initialize" do
		it "initializes with required parameters" do
			middleware = subject.new(simple_app, store: cassette_store)
			
			expect(middleware).to be_a(subject)
		end
		
		it "initializes with just required parameters" do
			middleware = subject.new(simple_app, store: cassette_store)
			
			expect(middleware).to be_a(subject)
		end
	end
	
	with "#call" do
		let(:get_request) do
			Protocol::HTTP::Request["GET", "/test", {"User-Agent" => "Test"}]
		end
		
		let(:post_request) do
			Protocol::HTTP::Request[
				"POST",
				"/users",
				{"Content-Type" => "application/json"},
				['{"name": "John"}']
			]
		end
		
		with "complete interaction recording" do
			let(:middleware) {subject.new(simple_app, store: cassette_store)}
			
			it "records GET requests without body" do
				response = middleware.call(get_request)
				
				# Verify the response is passed through:
				expect(response.status).to be == 200
				
				# Consume the response body to trigger completion callbacks:
				if response.body
					response.body.each {|chunk|}
				end
				
				# Verify the interaction was recorded:
				expect(File).to be(:directory?, cassette_path)
				
				# Check that interaction files were created:
				json_files = Dir.glob(File.join(cassette_path, "*.json"))
				expect(json_files).to have_attributes(length: be == 1)
				
				cassette = Async::HTTP::Capture::Cassette.load(cassette_path)
				expect(cassette.interactions).to have_attributes(length: be == 1)
				
				interaction = cassette.interactions.first
				request_data = interaction.to_h[:request]
				expect(request_data[:method]).to be == "GET"
				expect(request_data[:path]).to be == "/test"
				expect(request_data[:headers][:fields]).to be == [["User-Agent", "Test"]]
				expect(request_data[:headers][:tail]).to be_nil
				
				# Response should now be recorded too:
				response_data = interaction.to_h[:response]
				expect(response_data[:status]).to be == 200
			end
			
			it "records POST requests with body" do
				# Use echo_app which actually consumes the request body:
				echo_middleware = subject.new(echo_app, store: cassette_store)
				response = echo_middleware.call(post_request)
				
				expect(response.status).to be == 200
				
				# The echo app consumes request body and returns it as response body
				# Consume the response body to trigger completion callbacks:
				if response.body
					response.body.each {|chunk|}
				end
				
				cassette = Async::HTTP::Capture::Cassette.load(cassette_path)
				interaction = cassette.interactions.first
				request_data = interaction.to_h[:request]
				
				expect(request_data[:method]).to be == "POST"
				expect(request_data[:body]).to be == ['{"name": "John"}']
				expect(request_data[:headers][:fields]).to be == [["Content-Type", "application/json"]]
				
				# Response should now be recorded too:
				response_data = interaction.to_h[:response]
				expect(response_data[:status]).to be == 200
			end
		end
		
		with "async completion handling" do
			let(:middleware) do
				subject.new(simple_app, store: cassette_store)
			end
			
			it "waits for both request and response completion before recording" do
				response = middleware.call(get_request)
				
				expect(response.status).to be == 200
				
				# Consume response body to trigger completion:
				if response.body
					response.body.each {|chunk|}
				end
				
				# Both request and response should be recorded:
				cassette = Async::HTTP::Capture::Cassette.load(cassette_path)
				interaction = cassette.interactions.first
				
				expect(interaction.to_h[:request][:method]).to be == "GET"
				expect(interaction.to_h[:response][:status]).to be == 200
			end
		end
		
		with "completion-based saving" do
			let(:middleware) {subject.new(simple_app, store: cassette_store)}
			
			it "saves each interaction after both sides complete" do
				# First request with response body consumption:
				response1 = middleware.call(get_request)
				response1.body.each {|chunk|} if response1.body
				
				expect(File).to be(:directory?, cassette_path)
				json_files = Dir.glob(File.join(cassette_path, "*.json"))
				expect(json_files).to have_attributes(length: be == 1)
				
				# Second request (different path for different content hash):
				different_request = Protocol::HTTP::Request["GET", "/different", {"User-Agent" => "Test"}]
				response2 = middleware.call(different_request)
				response2.body.each {|chunk|} if response2.body
				
				json_files = Dir.glob(File.join(cassette_path, "*.json"))
				expect(json_files).to have_attributes(length: be == 2)
			end
		end
		
		it "preserves request body for downstream middleware" do
			middleware = subject.new(echo_app, store: cassette_store)
			response = middleware.call(post_request)
			
			# The echo app should receive the request body:
			body_content = []
			response.body.each {|chunk| body_content << chunk}
			expect(body_content).to be == ['{"name": "John"}']
			
			# Verify that the interaction was recorded with both request and response:
			cassette = Async::HTTP::Capture::Cassette.load(cassette_path)
			interaction = cassette.interactions.first
			expect(interaction.to_h[:request][:method]).to be == "POST"
			expect(interaction.to_h[:response][:status]).to be == 200
		end
	end
end
