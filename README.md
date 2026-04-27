# philiprehberger-feature_flag

[![Tests](https://github.com/philiprehberger/rb-feature-flag/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-feature-flag/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-feature_flag.svg)](https://rubygems.org/gems/philiprehberger-feature_flag)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-feature-flag)](https://github.com/philiprehberger/rb-feature-flag/commits/main)

Minimal feature flag system with YAML, ENV, and in-memory backends

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-feature_flag"
```

Or install directly:

```bash
gem install philiprehberger-feature_flag
```

## Usage

### Configuration

```ruby
require "philiprehberger/feature_flag"

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

### Context-aware rollouts

`enabled?` and `variant` accept a `context:` hash that flows through targeting
and rollout bucketing. Targeting predicates can match on context values, and
rollout bucketing can include context keys via a per-flag `rollout_by` list.

```ruby
flags = Philiprehberger::FeatureFlag

# Whitelist everyone in a region (context predicate — no user id required)
flags.enable_for(:regional_ui, context: { region: 'us-west' })

flags.enabled?(:regional_ui, context: { region: 'us-west' }) # => true
flags.enabled?(:regional_ui, context: { region: 'eu-east' }) # => false (falls
# back to backend)
```

Rollouts can mix context keys into the bucket key — so the same user gets a
different rollout assignment per region, tenant, etc.

```ruby
# Backend value (e.g. from YAML)
flags.configuration.backend.set(:new_search, {
  'percentage' => 50,
  'rollout_by' => %w[user_id region]
})

flags.enabled?(:new_search, user_id: 'u-1', context: { region: 'us-west' })
flags.enabled?(:new_search, user_id: 'u-1', context: { region: 'eu-east' })
# The two calls may return different values — a user's bucket is now per-region.
```

When `rollout_by` is omitted the default stays `[:user_id]`, preserving the
original single-bucket-per-user behavior.

### Dependencies

Gate a flag behind another flag. The dependent flag is only enabled when its required flag is also enabled.

```ruby
flags = Philiprehberger::FeatureFlag
flags.depends_on(:new_ui, requires: :beta_users)

# :new_ui will only be enabled if :beta_users is also enabled
flags.enabled?(:new_ui) # => false (unless :beta_users is enabled)
```

Dependencies can be chained:

```ruby
flags.depends_on(:beta, requires: :alpha)
flags.depends_on(:gamma, requires: :beta)
# :gamma requires :beta, which requires :alpha
```

### Scheduling

Enable or disable flags at specific times. Flags are only active within the scheduled window.

```ruby
flags = Philiprehberger::FeatureFlag

flags.schedule(:holiday_banner,
               enable_at: Time.new(2026, 12, 24),
               disable_at: Time.new(2026, 12, 26))

# Only enabled between Dec 24 and Dec 26
flags.enabled?(:holiday_banner)
```

You can also use `enable_at` or `disable_at` individually:

```ruby
# Enable after a certain time (no end)
flags.schedule(:new_feature, enable_at: Time.new(2026, 4, 1))

# Disable after a certain time (active until then)
flags.schedule(:old_feature, disable_at: Time.new(2026, 6, 1))
```

### Metrics

Track how often each flag is evaluated and whether it was enabled or disabled.

```ruby
flags = Philiprehberger::FeatureFlag

flags.enabled?(:feature_x)
flags.enabled?(:feature_x)

flags.metrics(:feature_x)
# => { checks: 2, enabled: 1, disabled: 1 }
```

Metrics are reset when `reset!` is called.

### User targeting

Whitelist specific users for a flag, independent of the backend value.

```ruby
flags = Philiprehberger::FeatureFlag

flags.enable_for(:feature, users: ["user_1", "user_2"])

flags.enabled?(:feature, user: "user_1") # => true
flags.enabled?(:feature, user: "user_3") # => false (falls back to backend)
```

Remove users from the whitelist:

```ruby
flags.disable_for(:feature, users: ["user_1"])
```

### Groups

Group flags together for bulk enable/disable operations.

```ruby
flags = Philiprehberger::FeatureFlag

flags.group(:beta, [:feature_a, :feature_b, :feature_c])

flags.enable_group(:beta)   # enables all three flags
flags.disable_group(:beta)  # disables all three flags

flags.group_flags(:beta)    # => [:feature_a, :feature_b, :feature_c]
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

### Test Helpers

`with` scopes a single override to a block — the original value is restored
when the block exits.

```ruby
Philiprehberger::FeatureFlag.with(:dark_mode, true) do
  # flag is forced to true within this block
  assert Philiprehberger::FeatureFlag.enabled?(:dark_mode)
end
# original value restored after block
```

`reset_all!` clears every piece of registry state — backend-stored flags,
overrides, metrics, dependencies, schedules, targets, and groups. Pair it
with `flags` to assert a clean slate at the start of each example.

```ruby
RSpec.configure do |config|
  config.before(:each) { Philiprehberger::FeatureFlag.reset_all! }
end

# In a spec
Philiprehberger::FeatureFlag.configuration.backend.set(:dark_mode, true)
Philiprehberger::FeatureFlag.flags # => [:dark_mode]

Philiprehberger::FeatureFlag.reset_all!
Philiprehberger::FeatureFlag.flags # => []
```

### Reloading

```ruby
Philiprehberger::FeatureFlag.reload!
```

### Introspecting known flags

List every flag name the configuration knows about — pulling from the backend, registered dependencies, schedules, targeted users, and groups. The result is deduplicated, sorted ascending, and returned as an array of symbols.

```ruby
flags = Philiprehberger::FeatureFlag

flags.configuration.backend.set(:dark_mode, true)
flags.schedule(:holiday_banner, enable_at: Time.new(2026, 12, 24))
flags.depends_on(:new_ui, requires: :beta_users)
flags.enable_for(:vip_only, users: %w[user_1])

flags.flag_names
# => [:beta_users, :dark_mode, :holiday_banner, :new_ui, :vip_only]
```

## API

| Method | Description |
|--------|-------------|
| `.configure { \|c\| ... }` | Configure the backend |
| `.enabled?(flag, user_id: nil, user: nil, context: {})` | Check if a flag is enabled |
| `.variant(flag, user_id:, context: {})` | Get A/B variant for a user |
| `.with(flag, value) { }` | Override a flag in a block |
| `.reload!` | Reload flags from the backend |
| `.reset!` | Reset configuration and overrides |
| `.reset_all!` | Reset every piece of registry state (flags, overrides, metrics, dependencies, schedules, targets, groups) — intended for test cleanup |
| `.flags` | List registered flag names (alias of `.flag_names`) |
| `.flag_names` | Sorted, deduplicated list of all known flag names |
| `.depends_on(flag, requires:)` | Declare a flag dependency |
| `.schedule(flag, enable_at:, disable_at:)` | Schedule flag activation window |
| `.metrics(flag)` | Get check/enabled/disabled counts |
| `.enable_for(flag, users: nil, context: nil)` | Whitelist users or a context predicate for a flag |
| `.disable_for(flag, users:)` | Remove users from whitelist |
| `.group(name, flags)` | Define a flag group |
| `.enable_group(name)` | Enable all flags in a group |
| `.disable_group(name)` | Disable all flags in a group |
| `.group_flags(name)` | List flags in a group |
| `Rollout.enabled_for?(flag, user_id, percentage, context: {}, rollout_by: [:user_id])` | Low-level rollout check |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-feature-flag)

🐛 [Report issues](https://github.com/philiprehberger/rb-feature-flag/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-feature-flag/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
