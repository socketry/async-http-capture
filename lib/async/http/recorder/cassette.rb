# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require 'json'
require 'time'

module Async
	module HTTP
		module Recorder
			# Represents a collection of HTTP interactions that can be loaded from and saved to JSON files.
			# 
			# A cassette serves as a container for multiple {Interaction} objects, providing functionality
			# to serialize and deserialize interaction data to and from JSON format.
			class Cassette
				include Enumerable
				
				# @attribute [Array(Interaction)] The collection of interactions.
				attr_reader :interactions
				
				# Initialize a new cassette with the provided interactions.
				# @parameter interactions [Array(Interaction | Hash)] The interactions to include in the cassette.
				def initialize(interactions = [])
					@interactions = interactions.map do |item|
						case item
						when Hash
							Interaction.new(item)
						when Interaction
							item
						else
							raise ArgumentError, "Invalid interaction: #{item}"
						end
					end.freeze
					freeze
				end
				
				# Iterate over each interaction in the cassette.
				# @yields {|interaction| ...} Each interaction in the cassette.
				#   @parameter interaction [Interaction] The current interaction being yielded.
				def each(&block)
					@interactions.each(&block)
				end
				
				# Load a cassette from a JSON file.
				# @parameter path [String] The path to the JSON file to load.
				# @returns [Cassette] A new cassette instance with the loaded interactions.
				# @raises [JSON::ParserError] If the file contains invalid JSON.
				# @raises [Errno::ENOENT] If the file does not exist.
				def self.load(path)
					data = JSON.parse(File.read(path), symbolize_names: true)
					interactions = data[:interactions].map { |i| Interaction.new(i) }
					new(interactions)
				end
				
				# Save the cassette to a JSON file.
				# @parameter path [String] The path where the JSON file should be saved.
				def save(path)
					data = {
						version: "1.0",
						recorded_at: Time.now.iso8601,
						interactions: interactions.map(&:to_h)
					}
					File.write(path, JSON.pretty_generate(data))
				end
			end
		end
	end
end
