# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "digest/sha2"
require "json"
require "protocol/http/request"
require "protocol/http/response"
require "protocol/http/headers"
require "protocol/http/body/buffered"

module Async
	module HTTP
		module Capture
			# Represents a single HTTP interaction containing request and optional response data.
			# 
			# This class serves as a simple data container that stores the raw interaction data
			# and provides factory methods to construct {Protocol::HTTP::Request} and 
			# {Protocol::HTTP::Response} objects on demand. May also contain error information
			# if the interaction failed.
			class Interaction
				# Initialize a new interaction with the provided data.
				# @parameter data [Hash] The interaction data containing serialized request and optional response information.
				# @parameter request [Protocol::HTTP::Request | Nil] A pre-constructed request object.
				# @parameter response [Protocol::HTTP::Response | Nil] A pre-constructed response object.
				def initialize(data, request: nil, response: nil)
					@data = data
					@request = request
					@response = response
				end
				
				# Get the Protocol::HTTP::Request object, constructing it lazily if not already provided.
				# @returns [Protocol::HTTP::Request | Nil] The request object, or nil if no request data is present.
				def request
					@request ||= make_request
				end
				
				# Get the Protocol::HTTP::Response object, constructing it lazily if not already provided.
				# @returns [Protocol::HTTP::Response | Nil] The response object, or nil if no response data is present.
				def response
					@response ||= make_response
				end
				
				# Get any error that occurred during the interaction.
				# @returns [Exception | String | Nil] The error information, or nil if no error occurred.
				def error
					@data[:error]
				end
				
				# Convert the interaction to a hash representation.
				# @returns [Hash] The raw interaction data.
				def to_h
					@data
				end
				
				# Create an interaction from a hash of data.
				# @parameter hash [Hash] The interaction data hash.
				# @returns [Interaction] A new interaction instance.
				def self.from_hash(hash)
					new(hash)
				end
				
				# Generate a content-addressed hash for this interaction.
				# This hash can be used as a unique filename for content-addressed storage.
				# @returns [String] A 16-character hexadecimal hash of the interaction content.
				def content_hash
					# Create a consistent JSON representation for hashing:
					json_string = JSON.generate(serialize, sort_keys: true)
					Digest::SHA256.hexdigest(json_string)[0, 16]
				end
				
				# Serialize the interaction to a data format suitable for storage or hashing.
				# Converts Protocol::HTTP objects to plain data structures.
				# @returns [Hash] The serialized interaction data.
				def serialize
					data = @data.dup
					
					if request_obj = self.request
						data[:request] = serialize_request(request_obj)
					end
					
					if response_obj = self.response  
						data[:response] = serialize_response(response_obj)
					end
					
					if error = self.error
						data[:error] = error.is_a?(Exception) ? error.message : error.to_s
					end
					
					data
				end
			
				# Provide a reasonable string representation of this interaction.
				# @returns [String] A human-readable description of the interaction.
				def to_s
					parts = []
					
					# Add request information
					if request_data = @data[:request]
						method = request_data[:method] || "?"
						path = request_data[:path] || "/"
						parts << "#{method} #{path}"
					end
					
					# Add response status if available
					if response_data = @data[:response]
						status = response_data[:status]
						parts << "-> #{status}" if status
					end
					
					# Add error if present
					if error_data = @data[:error]
						parts << "(ERROR: #{error_data})"
					end
					
					# Add timestamp if available
					if timestamp = @data[:timestamp]
						parts << "[#{timestamp}]"
					end
					
					parts.join(" ")
				end
				
				private
				
				# Serialize a Protocol::HTTP::Request to a hash.
				# @parameter request [Protocol::HTTP::Request] The request to serialize.
				# @returns [Hash] The serialized request data.
				def serialize_request(request)
					data = {
						scheme: request.scheme,
						authority: request.authority,
						method: request.method,
						path: request.path,
						version: request.version,
						protocol: request.protocol
					}
					
					# Add headers if present:
					if request.headers && !request.headers.empty?
						data[:headers] = {
							fields: request.headers.fields,
							tail: request.headers.tail
						}
					end
					
					# Add body chunks if present:
					if request.body && request.body.is_a?(::Protocol::HTTP::Body::Buffered)
						data[:body] = request.body.chunks
					end
					
					data
				end
				
				# Serialize a Protocol::HTTP::Response to a hash.
				# @parameter response [Protocol::HTTP::Response] The response to serialize.
				# @returns [Hash] The serialized response data.
				def serialize_response(response)
					data = {
						version: response.version,
						status: response.status,
						protocol: response.protocol
					}
					
					# Add headers if present:
					if response.headers && !response.headers.empty?
						data[:headers] = {
							fields: response.headers.fields,
							tail: response.headers.tail
						}
					end
					
					# Add body chunks if present:
					if response.body && response.body.is_a?(::Protocol::HTTP::Body::Buffered)
						data[:body] = response.body.chunks
					end
					
					data
				end
				
				# Create a Protocol::HTTP::Request from the stored request data.
				# @returns [Protocol::HTTP::Request] The constructed request object.
				def make_request
					if request_data = @data[:request]
						build_request(**request_data)
					end
				end
				
				# Create a Protocol::HTTP::Response from the stored response data.
				# @returns [Protocol::HTTP::Response] The constructed response object.
				def make_response
					if response_data = @data[:response]
						build_response(**response_data)
					end
				end
				
				# Build a Protocol::HTTP::Request from the provided parameters.
				# @parameter scheme [String | Nil] The request scheme (e.g. "https").
				# @parameter authority [String | Nil] The request authority (e.g. "example.com").
				# @parameter method [String] The HTTP method (e.g. "GET", "POST").
				# @parameter path [String] The request path (e.g. "/users/123").
				# @parameter version [String | Nil] The HTTP version (e.g. "HTTP/1.1").
				# @parameter headers [Array | Nil] Array of header name-value pairs.
				# @parameter body [Array | Nil] Array of body chunks.
				# @parameter protocol [String | Array | Nil] The protocol information.
				# @returns [Protocol::HTTP::Request] The constructed request object.
				def build_request(scheme: nil, authority: nil, method:, path:, version: nil, headers: nil, body: nil, protocol: nil)
					body = ::Protocol::HTTP::Body::Buffered.wrap(body) if body
					headers = build_headers(headers) if headers
					
					::Protocol::HTTP::Request.new(
						scheme,
						authority,
						method, 
						path,
						version,
						headers,
						body,
						protocol
					)
				end
				
				# Build a Protocol::HTTP::Response from the provided parameters.
				# @parameter version [String | Nil] The HTTP version (e.g. "HTTP/1.1").
				# @parameter status [Integer] The HTTP status code (e.g. 200, 404).
				# @parameter headers [Array | Nil] Array of header name-value pairs.
				# @parameter body [Array | Nil] Array of body chunks.
				# @parameter protocol [String | Array | Nil] The protocol information.
				# @returns [Protocol::HTTP::Response] The constructed response object.
				def build_response(version: nil, status:, headers: nil, body: nil, protocol: nil)
					body = ::Protocol::HTTP::Body::Buffered.wrap(body) if body
					headers = build_headers(headers) if headers
					
					::Protocol::HTTP::Response.new(
						version,
						status,
						headers,
						body,
						protocol
					)
				end
				
				# Build Protocol::HTTP::Headers from serialized data.
				# @parameter headers_data [Hash | Array] The serialized headers data.
				# @returns [Protocol::HTTP::Headers] The constructed headers object.
				def build_headers(headers_data)
					case headers_data
					when Hash
						# Hash format with fields and tail for complete header reconstruction:
						if headers_data.key?(:fields) || headers_data.key?("fields")
							fields = headers_data[:fields] || headers_data["fields"]
							tail = headers_data[:tail] || headers_data["tail"]
							::Protocol::HTTP::Headers.new(fields, tail)
						else
							# Simple hash format:
							::Protocol::HTTP::Headers[headers_data]
						end
					when Array
						# Array format of [name, value] pairs:
						::Protocol::HTTP::Headers[headers_data]
					else
						::Protocol::HTTP::Headers[headers_data]
					end
				end
			end
		end
	end
end
