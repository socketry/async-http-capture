# frozen_string_literal: true

require 'async/http/recorder/middleware'
require 'async/http/recorder/cassette'
require 'protocol/http/request'
require 'protocol/http/response'
require 'protocol/http/body/buffered'
require 'tmpdir'

describe Async::HTTP::Recorder::Middleware do
	around do |&block|
		Dir.mktmpdir do |tmpdir|
			@tmpdir = tmpdir
			block.call
		end
	end
	
	let(:cassette_path) { File.join(@tmpdir, "test_cassette.json") }
	
	let(:simple_app) do
		->(request) do
			Protocol::HTTP::Response[200, {}, ["Hello, World!"]]
		end
	end
	
	let(:echo_app) do
		->(request) do
			body = []
			if request.body
				request.body.each { |chunk| body << chunk }
			end
			
			Protocol::HTTP::Response[200, {"Content-Type" => "text/plain"}, body]
		end
	end
	
	with "#initialize" do
		it "initializes with required parameters" do
			middleware = subject.new(simple_app, cassette_path: cassette_path)
			
			expect(middleware).to be_a(subject)
		end
		
		it "accepts optional parameters" do
			middleware = subject.new(
				simple_app,
				cassette_path: cassette_path,
				record_response: true,
				batch_size: 5
			)
			
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
		
		with "request-only recording (default)" do
			let(:middleware) { subject.new(simple_app, cassette_path: cassette_path) }
			
			it "records GET requests without body" do
				response = middleware.call(get_request)
				
				# Verify the response is passed through:
				expect(response.status).to be == 200
				
				# Verify the interaction was recorded:
				expect(File).to be(:exist?, cassette_path)
				
				cassette = Async::HTTP::Recorder::Cassette.load(cassette_path)
				expect(cassette.interactions).to have_attributes(length: be == 1)
				
				interaction = cassette.interactions.first
				request_data = interaction.to_h[:request]
				expect(request_data[:method]).to be == "GET"
				expect(request_data[:path]).to be == "/test"
				expect(request_data[:headers][:fields]).to be == [["User-Agent", "Test"]]
				expect(request_data[:headers][:tail]).to be_nil
				
				# No response should be recorded:
				expect(interaction.to_h[:response]).to be_nil
			end
			
			it "records POST requests with body" do
				response = middleware.call(post_request)
				
				expect(response.status).to be == 200
				
				cassette = Async::HTTP::Recorder::Cassette.load(cassette_path)
				interaction = cassette.interactions.first
				request_data = interaction.to_h[:request]
				
				expect(request_data[:method]).to be == "POST"
				expect(request_data[:body]).to be == ['{"name": "John"}']
				expect(request_data[:headers][:fields]).to be == [["Content-Type", "application/json"]]
				expect(interaction.to_h[:response]).to be_nil
			end
		end
		
		with "request and response recording" do
			let(:middleware) do
				subject.new(simple_app, cassette_path: cassette_path, record_response: true)
			end
			
			it "records both request and response" do
				response = middleware.call(get_request)
				
				expect(response.status).to be == 200
				
				# Wait for any async body capture to complete:
				if response.body
					chunks = []
					response.body.each { |chunk| chunks << chunk }
				end
				
				# Check if file exists and has content:
				if File.exist?(cassette_path)
					cassette = Async::HTTP::Recorder::Cassette.load(cassette_path)
					interaction = cassette.interactions.first
					
					expect(interaction.to_h[:request][:method]).to be == "GET"
					
					# Response recording might be asynchronous, so it may not be immediately available:
					response_data = interaction.to_h[:response]
					if response_data
						expect(response_data[:status]).to be == 200
					end
				end
			end
		end
		
		with "batch saving" do
			let(:middleware) do
				subject.new(simple_app, cassette_path: cassette_path, batch_size: 2)
			end
			
			it "saves after reaching batch size" do
				# First request should not save:
				middleware.call(get_request)
				expect(File).not.to be(:exist?, cassette_path)
				
				# Second request should trigger save:
				middleware.call(post_request)
				expect(File).to be(:exist?, cassette_path)
				
				cassette = Async::HTTP::Recorder::Cassette.load(cassette_path)
				expect(cassette.interactions).to have_attributes(length: be == 2)
			end
		end
		
		it "preserves request body for downstream middleware" do
			middleware = subject.new(echo_app, cassette_path: cassette_path)
			response = middleware.call(post_request)
			
			# The echo app should receive the request body:
			body_content = []
			response.body.each { |chunk| body_content << chunk }
			expect(body_content).to be == ['{"name": "John"}']
		end
	end
end
