# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "json"
require "time"
require "fileutils"

module Async
	module HTTP
		module Recorder
			# Represents a collection of HTTP interactions using content-addressed storage.
			# 
			# A cassette serves as a container for multiple {Interaction} objects, storing each
			# interaction as a separate JSON file in a directory. Files are named using the
			# content hash of the interaction, providing automatic de-duplication and 
			# parallel-safe recording.
			class Cassette
				include Enumerable
				
				# @attribute [Array(Interaction)] The collection of interactions.
				attr_reader :interactions
				
				# Initialize a new cassette with the provided interactions.
				# @parameter interactions [Array(Interaction)] The interactions to include in the cassette.
				def initialize(interactions = [])
					@interactions = interactions
				end
				
				# Iterate over each interaction in the cassette.
				# @yields {|interaction| ...} Each interaction in the cassette.
				#   @parameter interaction [Interaction] The current interaction being yielded.
				def each(&block)
					@interactions.each(&block)
				end
				
				# Load a cassette from a directory of JSON interaction files.
				# @parameter directory_path [String] The path to the directory containing JSON interaction files.
				# @returns [Cassette] A new cassette instance with the loaded interactions.
				# @raises [JSON::ParserError] If any file contains invalid JSON.
				def self.load(directory_path)
					return new([]) unless File.directory?(directory_path)
					
					json_files = Dir.glob(File.join(directory_path, "*.json"))
					interactions = json_files.map do |file_path|
						data = JSON.parse(File.read(file_path), symbolize_names: true)
						Interaction.new(data)
					end
					new(interactions)
				end
				
				# Save the cassette to a directory using content-addressed storage.
				# Each interaction is saved as a separate JSON file named by its content hash.
				# This approach provides de-duplication and parallel-safe recording.
				# @parameter directory_path [String] The path to the directory where interactions should be saved.
				def save(directory_path)
					FileUtils.mkdir_p(directory_path)
					
					@interactions.each do |interaction|
						filename = "#{interaction.content_hash}.json"
						file_path = File.join(directory_path, filename)
						File.write(file_path, JSON.pretty_generate(interaction.to_h))
					end
				end
			end
		end
	end
end
