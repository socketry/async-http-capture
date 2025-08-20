# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/capture/cassette"
require "async/http/capture/interaction"
require "tmpdir"

describe Async::HTTP::Capture::Cassette do
	let(:sample_interaction_data) do
		{
			request: {
				method: "GET",
				path: "/test",
				scheme: "https",
				authority: "example.com"
			}
		}
	end
	
	let(:sample_interaction) do
		Async::HTTP::Capture::Interaction.new(sample_interaction_data)
	end
	
	with "#initialize" do
		it "accepts an array of Interaction objects" do
			cassette = subject.new([sample_interaction])
			
			expect(cassette.interactions).to have_attributes(length: be == 1)
			expect(cassette.interactions.first).to be_a(Async::HTTP::Capture::Interaction)
		end
		
		it "accepts an array of Interaction objects directly" do
			cassette = subject.new([sample_interaction])
			
			expect(cassette.interactions).to have_attributes(length: be == 1)
			expect(cassette.interactions.first).to be_a(Async::HTTP::Capture::Interaction)
		end
		
		it "creates an empty cassette by default" do
			cassette = subject.new
			
			expect(cassette.interactions).to be(:empty?)
		end
		
		it "stores whatever interactions are provided" do
			# Constructor no longer validates - just stores what's given
			cassette = subject.new(["anything"])
			
			expect(cassette.interactions).to be == ["anything"]
		end
	end
	
	with "#each" do
		it "iterates over all interactions" do
			cassette = subject.new([sample_interaction])
			interactions = []
			
			cassette.each do |interaction|
				interactions << interaction
			end
			
			expect(interactions).to have_attributes(length: be == 1)
			expect(interactions.first).to be_a(Async::HTTP::Capture::Interaction)
		end
	end
	
	with ".load and #save" do
		around do |&block|
			Dir.mktmpdir do |root|
				@root = root
				block.call
			end
		end
		
		let(:test_directory_path) {File.join(@root, "test_cassette")}
		
		it "saves and loads a cassette to/from directory" do
			original_cassette = subject.new([sample_interaction])
			original_cassette.save(test_directory_path)
			
			expect(File).to be(:directory?, test_directory_path)
			
			# Check that interaction files were created:
			json_files = Dir.glob(File.join(test_directory_path, "*.json"))
			expect(json_files).to have_attributes(length: be == 1)
			
			loaded_cassette = subject.load(test_directory_path)
			expect(loaded_cassette.interactions).to have_attributes(length: be == 1)
			
			# Verify the data round-tripped correctly:
			loaded_interaction = loaded_cassette.interactions.first
			expect(loaded_interaction.to_h).to be == sample_interaction_data
		end
		
		it "saves each interaction as a separate file using content hash" do
			interaction1 = Async::HTTP::Capture::Interaction.new({
				request: { method: "GET", path: "/test1" }
			})
			interaction2 = Async::HTTP::Capture::Interaction.new({
				request: { method: "GET", path: "/test2" }
			})
			
			cassette = subject.new([interaction1, interaction2])
			cassette.save(test_directory_path)
			
			# Check that two separate files were created:
			json_files = Dir.glob(File.join(test_directory_path, "*.json"))
			expect(json_files).to have_attributes(length: be == 2)
			
			# Check that files are named with content hashes:
			expected_filename1 = "#{interaction1.content_hash}.json"
			expected_filename2 = "#{interaction2.content_hash}.json"
			
			filenames = json_files.map {|path| File.basename(path)}
			expect(filenames).to be(:include?, expected_filename1)
			expect(filenames).to be(:include?, expected_filename2)
		end
		
		it "handles loading from non-existent directory" do
			# Loading from a non-existent directory should return an empty cassette:
			cassette = subject.load("/non/existent/path")
			expect(cassette.interactions).to be(:empty?)
		end
	end
	
	with "Enumerable behavior" do
		it "supports map operation" do
			cassette = subject.new([sample_interaction])
			paths = cassette.map {|interaction| interaction.to_h[:request][:path]}
			
			expect(paths).to be == ["/test"]
		end
		
		it "supports select operation" do
			get_interaction = Async::HTTP::Capture::Interaction.new({
				request: { method: "GET", path: "/test" }
			})
			post_interaction = Async::HTTP::Capture::Interaction.new({
				request: { method: "POST", path: "/create" }
			})
			
			cassette = subject.new([get_interaction, post_interaction])
			get_interactions = cassette.select {|i| i.to_h[:request][:method] == "GET"}
			
			expect(get_interactions).to have_attributes(length: be == 1)
		end
	end
end
