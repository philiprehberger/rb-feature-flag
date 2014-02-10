# philiprehberger-feature_flag

[![Gem Version](https://badge.fury.io/rb/philiprehberger-feature_flag.svg)](https://rubygems.org/gems/philiprehberger-feature_flag)
[![CI](https://github.com/philiprehberger/rb-feature-flag/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-feature-flag/actions/workflows/ci.yml)

Minimal feature flag system with YAML, ENV, and in-memory backends. Supports percentage rollout and A/B variant assignment.

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-feature_flag'
```

Or install directly:

```bash
gem install philiprehberger-feature_flag
```

## Usage

### Configuration

```ruby
require 'philiprehberger/feature_flag'

# In-memory backend (default)
Philiprehberger::FeatureFlag.configure do |c|
  c.use(:memory)
end

# ENV backend (reads FEATURE_* environment variables)
Philiprehberger::FeatureFlag.configure do |c|
  c.use(:env)
end

# YAML backend
Philiprehberger::FeatureFlag.configure do |c|
  c.use(:yaml, path: 'config/features.yml')
end
```

### Checking flags

```ruby
# Simple boolean check
if Philiprehberger::FeatureFlag.enabled?(:dark_mode)
  render_dark_theme
end

# Percentage rollout (requires user_id)
if Philiprehberger::FeatureFlag.enabled?(:new_checkout, user_id: current_user.id)
  render_new_checkout
end
```

### A/B variants

```ruby
variant = Philiprehberger::FeatureFlag.variant(:button_color, user_id: current_user.id)
# => 'red', 'blue', or 'green' (consistent per user)
```

### YAML file format

```yaml
dark_mode: true
beta_search: false
new_checkout:
  percentage: 25
button_color:
  variants:
    - red
    - blue
    - green
```

### ENV backend

Set environment variables prefixed with `FEATURE_`:

```bash
export FEATURE_DARK_MODE=true
export FEATURE_BETA_SEARCH=false
```

### Test helper

```ruby
Philiprehberger::FeatureFlag.with(:dark_mode, true) do
  # flag is forced to true within this block
  assert Philiprehberger::FeatureFlag.enabled?(:dark_mode)
end
# original value restored after block
```

### Reloading

```ruby
Philiprehberger::FeatureFlag.reload!
```

## API

| Method | Description |
|--------|-------------|
| `.configure { \|c\| ... }` | Configure the backend |
| `.enabled?(flag, user_id: nil)` | Check if a flag is enabled |
| `.variant(flag, user_id:)` | Get A/B variant for a user |
| `.with(flag, value) { }` | Override a flag in a block |
| `.reload!` | Reload flags from the backend |
| `.reset!` | Reset configuration and overrides |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT License. See [LICENSE](LICENSE) for details.
