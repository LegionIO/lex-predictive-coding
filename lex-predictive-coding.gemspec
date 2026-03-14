# frozen_string_literal: true

require_relative 'lib/legion/extensions/predictive_coding/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-predictive-coding'
  spec.version       = Legion::Extensions::PredictiveCoding::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Predictive Coding'
  spec.description   = "Karl Friston's Free Energy Principle / Predictive Processing framework for brain-modeled agentic AI"
  spec.homepage      = 'https://github.com/LegionIO/lex-predictive-coding'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']        = spec.homepage
  spec.metadata['source_code_uri']     = 'https://github.com/LegionIO/lex-predictive-coding'
  spec.metadata['documentation_uri']   = 'https://github.com/LegionIO/lex-predictive-coding'
  spec.metadata['changelog_uri']       = 'https://github.com/LegionIO/lex-predictive-coding'
  spec.metadata['bug_tracker_uri']     = 'https://github.com/LegionIO/lex-predictive-coding/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-predictive-coding.gemspec Gemfile]
  end
  spec.require_paths = ['lib']
end
