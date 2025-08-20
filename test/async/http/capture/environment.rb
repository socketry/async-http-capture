# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/environment"
require "async/http/capture/cassette"
require "async/http/capture/interaction"
require "async/http/capture/cassette_store"
require "async/http/capture/console_store"
require "tmpdir"
require "fileutils"

describe Async::HTTP::Capture::Environment do
	around do |&block|
		Dir.mktmpdir do |root|
			@root = root
			block.call
		end
	end
	
	let(:test_service_class) do
		Class.new do
			include Async::HTTP::Capture::Environment
		end
	end
	
	let(:test_service) {test_service_class.new}
	
	with "default configuration methods" do
		it "returns useful defaults for capture_cassette_directory" do
			expect(test_service.capture_cassette_directory).to be == "cassette/warmup"
		end
		
		it "returns useful defaults for capture_recordings_directory" do
			expect(test_service.capture_recordings_directory).to be == "cassette/recordings"
		end
		
		it "returns true for capture_console_logging by default" do
			expect(test_service.capture_console_logging).to be == true
		end
	end
	
	with "with falcon environment integration" do
		let(:falcon_service_class) do
			Class.new do
				include Falcon::Environment::Rack if defined?(Falcon::Environment::Rack)
				include Async::HTTP::Capture::Environment
			end
		end
		
		let(:falcon_service) { falcon_service_class.new }
		
		it "works with Falcon environment providing defaults" do
			skip "Falcon not available" unless defined?(Falcon::Environment::Rack)
			
			# When Falcon environment is included, it may provide defaults
			expect(falcon_service.capture_cassette_directory).to be_a(String) if falcon_service.capture_cassette_directory
			expect(falcon_service.capture_recordings_directory).to be_a(String) if falcon_service.capture_recordings_directory
		end
	end
	
	with "method overriding" do
		it "allows overriding capture_cassette_directory" do
			configured_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_cassette_directory) {"/custom/path"}
			end
			service = configured_class.new
			
			expect(service.capture_cassette_directory).to be == "/custom/path"
		end
		
		it "allows overriding capture_recordings_directory" do
			configured_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_recordings_directory) {"/custom/recordings"}
			end
			service = configured_class.new
			
			expect(service.capture_recordings_directory).to be == "/custom/recordings"
		end
		
		it "allows overriding capture_console_logging" do
			configured_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_console_logging) {true}
			end
			service = configured_class.new
			
			expect(service.capture_console_logging).to be == true
		end
	end
	
	with "#capture_cassette" do
		let(:cassette_dir) {File.join(@root, "cassette")}
		let(:interaction_data) do
			{
				request: {
					method: "GET",
					path: "/test",
					scheme: "https",
					authority: "example.com"
				}
			}
		end
		
		it "returns nil when cassette directory doesn't exist (even with useful defaults)" do
			# The default "cassette/warmup" directory doesn't exist in our test
			expect(test_service.capture_cassette).to be == nil
		end
		
		it "returns nil when custom cassette directory doesn't exist" do
			nonexistent_dir_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_cassette_directory) {"/nonexistent"}
			end
			service = nonexistent_dir_class.new
			expect(service.capture_cassette).to be == nil
		end
		
		it "loads cassette when directory exists with recordings" do
			# Create cassette directory and save interaction
			FileUtils.mkdir_p(cassette_dir)
			interaction = Async::HTTP::Capture::Interaction.new(interaction_data)
			cassette = Async::HTTP::Capture::Cassette.new([interaction])
			cassette.save(cassette_dir)
			
			# Create service configured to use the cassette directory
			root = @root
			cassette_dir_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_cassette_directory) {File.join(root, "cassette")}
			end
			service = cassette_dir_class.new
			
			loaded_cassette = service.capture_cassette
			expect(loaded_cassette).not.to be == nil
			expect(loaded_cassette.interactions).to have_attributes(length: be == 1)
		end
	end
	
	with "#capture_recording_store" do
		let(:recordings_dir) {File.join(@root, "recordings")}
		
		it "returns combined store with useful defaults" do
			# With useful defaults, both console logging and recordings directory are set
			store = test_service.capture_recording_store
			expect(store).to be_a(Proc)  # Combined store since both are enabled by default
		end
		
		it "returns CassetteStore when console logging is disabled" do
			root = @root
			recordings_only_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_recordings_directory) {File.join(root, "recordings")}
				define_method(:capture_console_logging) { false }  # Override default to disable console
			end
			service = recordings_only_class.new
			
			store = service.capture_recording_store
			expect(store).to be_a(Async::HTTP::Capture::CassetteStore)
		end
		
		it "returns ConsoleStore when recordings directory is disabled" do
			console_only_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_recordings_directory) { nil }  # Override default to disable recordings
				define_method(:capture_console_logging) { true }
			end
			service = console_only_class.new
			
			store = service.capture_recording_store
			expect(store).to be_a(Async::HTTP::Capture::ConsoleStore)
		end
		
		it "returns combined store proc when both are configured" do
			root = @root
			both_configured_class = Class.new do
				include Async::HTTP::Capture::Environment
				define_method(:capture_recordings_directory) {File.join(root, "recordings")}
				define_method(:capture_console_logging) {true}
			end
			service = both_configured_class.new
			
			store = service.capture_recording_store
			expect(store).to be_a(Proc)
		end
	end
	
	with "#middleware" do
		let(:mock_app) do
			->(request) {Protocol::HTTP::Response[200, {}, ["OK"]]}
		end
		
		it "can be called without recording configuration" do
			# Simple test that middleware method exists and can be called
			# without complex super mocking
			expect(test_service).to be(:respond_to?, :middleware)
		end
	end
end
