# frozen_string_literal: true

require_relative 'lib/active_call/api/version'

Gem::Specification.new do |spec|
  spec.name = 'active_call-api'
  spec.version = ActiveCall::Api::VERSION
  spec.authors = ['Kobus Joubert']
  spec.email = ['kobus@translate3d.com']

  spec.summary = 'Active Call - API'
  spec.description = 'Active Call - API is an extension of Active Call that provides a standardized way to create service objects for REST API endpoints.'
  spec.homepage = 'https://github.com/activecall/active_call-api'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/activecall/active_call-api'
  spec.metadata['changelog_uri'] = 'https://github.com/activecall/active_call-api/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'active_call', '~> 0.2'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-retry', '~> 2.0'
  spec.add_dependency 'faraday-logging-color_formatter', '~> 0.2'
end
