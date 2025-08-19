# frozen_string_literal: true

require_relative "lib/async/http/recorder/version"

Gem::Specification.new do |spec|
	spec.name = "async-http"
	spec.version = Async::HTTP::Recorder::VERSION
	
	spec.summary = "A HTTP request and response recorder."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/async-http"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-http-recorder/",
		"source_code_uri" => "https://github.com/socketry/async-http-recorder.git",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "async-http", "~> 0.90"
end
