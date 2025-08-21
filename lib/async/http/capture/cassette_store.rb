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
			# Store implementation that saves interactions to timestamped files in a directory.
			# 
			# Each interaction is saved as a separate JSON file named by timestamp,
			# using atomic write + move operations for parallel-safe recording.
			class CassetteStore
				# Initialize the cassette store.
				# @parameter directory_path [String] The directory path where interactions should be saved.
				def initialize(directory_path)
					@directory_path = directory_path
					@suffix = "#{Process.pid}-#{self.object_id}"
				end
				
				# @returns [Cassette] A cassette object representing the recorded interactions.
				def cassette
					Cassette.load(@directory_path)
				end
				
				# Save an interaction to a timestamped file using PID and object ID for uniqueness.
				# @parameter interaction [Interaction] The interaction to save.
				def call(interaction)
					FileUtils.mkdir_p(@directory_path)
					
					# Create filename with timestamp, PID, and object ID for complete uniqueness:
					timestamp = Time.now.strftime("%Y%m%d-%H%M%S-%6N")  # Include microseconds
					filename = "#{timestamp}-#{@suffix}.json"
					file_path = File.join(@directory_path, filename)
					
					File.write(file_path, JSON.pretty_generate(interaction.serialize))
				end
			end
		end
	end
end
