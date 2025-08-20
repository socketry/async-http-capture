# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "cassette"
require_relative "cassette_store"
require_relative "console_store"
require_relative "middleware"
require "console"

module Async
	module HTTP
		module Capture
			# A flat environment module for HTTP capture services.
			# 
			# Provides simple, declarative configuration for recording and replaying HTTP interactions.
			# Override these methods in your service to customize behavior.
			module Environment
				# Directory path to load cassettes from for replay warmup.
				# Override this method to specify a different directory.
				def capture_cassette_directory
					"cassette/warmup"
				end
				
				# Directory path to save recordings to.
				# Override this method to specify where recordings should be saved.
				def capture_recordings_directory
					"cassette/recordings"
				end
				
				# Whether to enable console logging of interactions (default: false).
				# Override this method to enable console output.
				def capture_console_logging
					true
				end
				
				# Load the cassette for replay if configured
				def capture_cassette
					if capture_cassette_directory && File.directory?(capture_cassette_directory)
						Cassette.load(capture_cassette_directory)
					end
				end
				
				# Get the recording store if configured
				def capture_recording_store
					stores = []
					
					# Add file storage if directory configured
					if capture_recordings_directory
						stores << CassetteStore.new(capture_recordings_directory)
					end
					
					# Add console logging if enabled
					if capture_console_logging
						stores << ConsoleStore.new
					end
					
					# Return combined store or nil
					case stores.length
					when 0
						nil
					when 1
						stores.first
					else
						# Multiple stores - combine them
						proc do |interaction|
							stores.each {|store| store.call(interaction)}
						end
					end
				end
				
				# Set up middleware chain with recording support.
				def middleware
					# Get the underlying application by calling super:
					middleware = super
					
					# Warm up the application with recorded interactions if available:
					capture_cassette&.replay(middleware)
					
					# Wrap with recording middleware if store is configured
					if store = capture_recording_store
						middleware = Middleware.new(middleware, store: store)
					end
					
					return middleware
				end
			end
		end
	end
end
