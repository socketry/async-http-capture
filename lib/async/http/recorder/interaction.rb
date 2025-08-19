# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require 'protocol/http/request'
require 'protocol/http/response'
require 'protocol/http/headers'
require 'protocol/http/body/buffered'

module Async
	module HTTP
		module Recorder
			# Represents a single HTTP interaction containing request and optional response data.
			# 
			# This class serves as a simple data container that stores the raw interaction data
			# and provides factory methods to construct {Protocol::HTTP::Request} and 
			# {Protocol::HTTP::Response} objects on demand.
			class Interaction
				# Initialize a new interaction with the provided data.
				# @parameter data [Hash] The interaction data containing request and optional response information.
				def initialize(data)
					@data = data
				end
				
				# Get the Protocol::HTTP::Request object, constructing it lazily on first access.
				# @returns [Protocol::HTTP::Request | Nil] The constructed request object, or nil if no request data is present.
				def request
					@request ||= make_request if @data[:request]
				end
				
				# Get the Protocol::HTTP::Response object, constructing it lazily on first access.
				# @returns [Protocol::HTTP::Response | Nil] The constructed response object, or nil if no response data is present.
				def response
					@response ||= make_response if @data[:response]
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
				
				private
				
				# Create a Protocol::HTTP::Request from the stored request data.
				# @returns [Protocol::HTTP::Request] The constructed request object.
				def make_request
					build_request(**@data[:request])
				end
				
				# Create a Protocol::HTTP::Response from the stored response data.
				# @returns [Protocol::HTTP::Response] The constructed response object.
				def make_response
					build_response(**@data[:response])
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
					body = Protocol::HTTP::Body::Buffered.wrap(body) if body
					headers = build_headers(headers) if headers
					
					Protocol::HTTP::Request.new(
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
					body = Protocol::HTTP::Body::Buffered.wrap(body) if body
					headers = build_headers(headers) if headers
					
					Protocol::HTTP::Response.new(
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
						# New format with fields and tail for complete round-trip:
						if headers_data.key?(:fields) || headers_data.key?('fields')
							fields = headers_data[:fields] || headers_data['fields']
							tail = headers_data[:tail] || headers_data['tail']
							Protocol::HTTP::Headers.new(fields, tail)
						else
							# Fallback for old format:
							Protocol::HTTP::Headers[headers_data]
						end
					when Array
						# Legacy array format:
						Protocol::HTTP::Headers[headers_data]
					else
						Protocol::HTTP::Headers[headers_data]
					end
				end
			end
		end
	end
end
