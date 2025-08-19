# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "console"
require "json"

module Async
	module HTTP
		module Capture
			# Store implementation that logs interactions to the console.
			# 
			# This store outputs complete interaction data via the Console gem,
			# particularly useful for debugging network errors and monitoring HTTP traffic.
			class ConsoleStore
				
				# Initialize the console store.
				# @parameter logger [Console::Logger] The logger to use (defaults to Console).
				def initialize(logger: Console)
					@logger = logger
				end
				
				# Log an interaction to the console with full fidelity.
				# The output includes complete interaction data to enable debugging and reconstruction.
				# @parameter interaction [Interaction] The interaction to log.
				def call(interaction)
					# Let the interaction serialize itself:
					serializable_data = interaction.serialize
					
					request_info = extract_request_info(serializable_data)
					
					if serializable_data[:error]
						# Log errors with full interaction data:
						@logger.error(self, "HTTP Error: #{request_info}") {JSON.pretty_generate(serializable_data)}
					elsif serializable_data[:response]
						# Log successful interactions with summary + full data:
						status = serializable_data[:response][:status]
						@logger.info(self, "#{request_info} -> #{status}") {JSON.pretty_generate(serializable_data)}
					else
						# Log request-only interactions:
						@logger.debug(self, "Recorded: #{request_info}") {JSON.pretty_generate(serializable_data)}
					end
				end
				
				private
				
				# Extract request info for summary logging.
				# @parameter data [Hash] The serialized interaction data.
				# @returns [String] A summary of the request.
				def extract_request_info(data)
					return "Unknown request" unless data[:request]
					
					method = data[:request][:method] || "UNKNOWN"
					path = data[:request][:path] || "/"
					"#{method} #{path}"
				end
			end
		end
	end
end
