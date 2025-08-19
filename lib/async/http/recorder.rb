# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "recorder/version"
require_relative "recorder/interaction"
require_relative "recorder/cassette"
require_relative "recorder/cassette_store"
require_relative "recorder/console_store"
require_relative "recorder/middleware"

module Async
	module HTTP
		# @namespace
		module Recorder
		end
	end
end
