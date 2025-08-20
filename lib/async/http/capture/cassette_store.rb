# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "fileutils"
require "json"
require "time"

require_relative "cassette"

module Async
	module HTTP
		module Capture
			# Store implementation that saves interactions to content-addressed files in a directory.
			# 
			# Each interaction is saved as a separate JSON file named by its content hash,
			# providing automatic de-duplication and parallel-safe recording.
			class CassetteStore
				# Initialize the cassette store.
				# @parameter directory_path [String] The directory path where interactions should be saved.
				def initialize(directory_path)
					@directory_path = directory_path
				end
				
				# @returns [Cassette] A cassette object representing the recorded interactions.
				def cassette
					Cassette.load(@directory_path)
				end
				
				# Save an interaction to a content-addressed file with timestamp prefix.
				# @parameter interaction [Interaction] The interaction to save.
				def call(interaction)
					FileUtils.mkdir_p(@directory_path)
					
					# Create filename with timestamp prefix for chronological ordering:
					timestamp = Time.now.strftime("%Y%m%d-%H%M%S-%6N")  # Include microseconds
					content_hash = interaction.content_hash
					filename = "#{timestamp}-#{content_hash}.json"
					file_path = File.join(@directory_path, filename)
					
					File.write(file_path, JSON.pretty_generate(interaction.serialize))
				end
			end
		end
	end
end
