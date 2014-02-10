# frozen_string_literal: true

require_relative 'lib/philiprehberger/feature_flag/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-feature_flag'
  spec.version       = Philiprehberger::FeatureFlag::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['philiprehberger@users.noreply.github.com']

  spec.summary       = 'Minimal feature flag system with YAML, ENV, and in-memory backends'
  spec.description   = 'A lightweight feature flag library supporting in-memory, ENV, and YAML backends ' \
                       'with percentage rollout and A/B variant support.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-feature-flag'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir.glob('lib/**/*') + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ['lib']
end
