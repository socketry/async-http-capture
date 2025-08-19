# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "covered/sus"
include Covered::Sus

def before_tests(assertions)
	# Starts the clock and sets up the test environment:
	super
end

def after_tests(assertions)
	# Stops the clock and prints the test results:
	super
end
