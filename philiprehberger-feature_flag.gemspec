# frozen_string_literal: true

require_relative 'lib/philiprehberger/feature_flag/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-feature_flag'
  spec.version       = Philiprehberger::FeatureFlag::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Minimal feature flag system with YAML, ENV, and in-memory backends'
  spec.description   = 'A lightweight feature flag library supporting in-memory, ENV, and YAML backends ' \
                       'with percentage rollout and A/B variant support.'
  spec.homepage      = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-feature_flag'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/philiprehberger/rb-feature-flag',
    'changelog_uri' => 'https://github.com/philiprehberger/rb-feature-flag/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/philiprehberger/rb-feature-flag/issues',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
