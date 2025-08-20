# frozen_string_literal: true

require_relative "lib/async/http/capture/version"

Gem::Specification.new do |spec|
	spec.name = "async-http-capture"
	spec.version = Async::HTTP::Capture::VERSION
	
	spec.summary = "A HTTP request and response capture."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/async-http-capture"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-http-capture/",
		"source_code_uri" => "https://github.com/socketry/async-http-capture.git",
	}
	
	spec.files = Dir.glob(["{context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "async-http", "~> 0.90"
end
