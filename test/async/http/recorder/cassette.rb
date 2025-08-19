# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/http/recorder/cassette"
require "async/http/recorder/interaction"
require "tmpdir"

describe Async::HTTP::Recorder::Cassette do
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
		Async::HTTP::Recorder::Interaction.new(sample_interaction_data)
	end
	
	with "#initialize" do
		it "accepts an array of Interaction objects" do
			cassette = subject.new([sample_interaction])
			
			expect(cassette.interactions).to have_attributes(length: be == 1)
			expect(cassette.interactions.first).to be_a(Async::HTTP::Recorder::Interaction)
		end
		
		it "accepts an array of hash objects" do
			cassette = subject.new([sample_interaction_data])
			
			expect(cassette.interactions).to have_attributes(length: be == 1)
			expect(cassette.interactions.first).to be_a(Async::HTTP::Recorder::Interaction)
		end
		
		it "creates an empty cassette by default" do
			cassette = subject.new
			
			expect(cassette.interactions).to be(:empty?)
		end
		
		it "raises an error for invalid interaction types" do
			expect do
				subject.new(["invalid"])
			end.to raise_exception(ArgumentError, message: be(:include?, "Invalid interaction"))
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
			expect(interactions.first).to be_a(Async::HTTP::Recorder::Interaction)
		end
	end
	
	with ".load and #save" do
		around do |&block|
			Dir.mktmpdir do |tmpdir|
				@tmpdir = tmpdir
				block.call
			end
		end
		
		let(:test_file_path) {File.join(@tmpdir, "test_cassette.json")}
		
		it "saves and loads a cassette to/from JSON" do
			original_cassette = subject.new([sample_interaction])
			original_cassette.save(test_file_path)
			
			expect(File).to be(:exist?, test_file_path)
			
			loaded_cassette = subject.load(test_file_path)
			expect(loaded_cassette.interactions).to have_attributes(length: be == 1)
			
			# Verify the data round-tripped correctly:
			loaded_interaction = loaded_cassette.interactions.first
			expect(loaded_interaction.to_h).to be == sample_interaction_data
		end
		
		it "includes version and timestamp in saved file" do
			cassette = subject.new([sample_interaction])
			cassette.save(test_file_path)
			
			data = JSON.parse(File.read(test_file_path), symbolize_names: true)
			expect(data[:version]).to be == "1.0"
			expect(data[:recorded_at]).to be_a(String)
			expect(data[:interactions]).to be_a(Array)
		end
		
		it "raises an error when loading non-existent file" do
			expect do
				subject.load("/non/existent/path")
			end.to raise_exception(Errno::ENOENT)
		end
	end
	
	with "Enumerable behavior" do
		it "supports map operation" do
			cassette = subject.new([sample_interaction])
			paths = cassette.map {|interaction| interaction.to_h[:request][:path]}
			
			expect(paths).to be == ["/test"]
		end
		
		it "supports select operation" do
			get_interaction = Async::HTTP::Recorder::Interaction.new({
				request: { method: "GET", path: "/test" }
			})
			post_interaction = Async::HTTP::Recorder::Interaction.new({
				request: { method: "POST", path: "/create" }
			})
			
			cassette = subject.new([get_interaction, post_interaction])
			get_interactions = cassette.select {|i| i.to_h[:request][:method] == "GET"}
			
			expect(get_interactions).to have_attributes(length: be == 1)
		end
	end
end
