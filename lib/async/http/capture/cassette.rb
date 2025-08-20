# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "json"
require "time"
require "fileutils"
require "console"

module Async
	module HTTP
		module Capture
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
					
					return self.new(interactions)
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
				
				# Replay all interactions against the provided application.
				# This is useful for warming up applications by replaying recorded traffic.
				# @parameter app [#call] The application to replay interactions against.
				def replay(app)
					count = @interactions.length
					Console.info(self) {"Replaying #{count} interactions for warmup..."}
					
					@interactions.each do |interaction|
						Console.debug(self, "Replaying interaction:", interaction)
						
						# Replay the interaction against the app:
						if request = interaction.request
							begin
								response = app.call(request)
								response.finish if response.respond_to?(:finish)
							rescue => error
								Console.warn(self, "Failed to replay interaction:", error)
							end
						end
					end
					
					Console.info(self) {"Warmup complete."}
				end
			end
		end
	end
end
