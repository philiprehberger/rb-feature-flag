# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-04-26

### Added
- `FeatureFlag.reset_all!` — clear all registered flags, overrides, and metrics in one call (intended for test cleanup)
- `FeatureFlag.flags` — list registered flag names

## [0.4.0] - 2026-04-23

### Added
- `context:` keyword argument on `enabled?` and `variant` for context-aware targeting and rollouts.
- `rollout_by:` option on rollout configuration — hash bucketing can include context keys (default: `[:user_id]`).
- YARD documentation on top-level public API methods.

### Changed
- `Scheduling` now raises `ArgumentError` if `enable_at` or `disable_at` are set to non-Time values.
- Bug report template `gem-version` field is now required.

## [0.3.0] - 2026-04-17

### Added
- `FeatureFlag.flag_names` returns a sorted, deduplicated list of all known flag names across backends, schedules, dependencies, and scoped rules

## [0.2.7] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.6] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.5] - 2026-03-26

### Changed

- Add Sponsor badge and fix License link format in README

## [0.2.4] - 2026-03-24

### Changed
- Expand test coverage to 70+ examples covering edge cases and error paths

## [0.2.3] - 2026-03-24

### Fixed
- Align README one-liner with gemspec summary

## [0.2.2] - 2026-03-24

### Fixed
- Standardize README code examples to use double-quote require statements

## [0.2.1] - 2026-03-24

### Fixed
- Fix Installation section quote style to double quotes

## [0.2.0] - 2026-03-17

### Added
- Flag dependencies — `depends_on(:new_ui, requires: :beta_users)` to gate flags behind other flags
- Scheduled enable/disable — `schedule(:banner, enable_at: time, disable_at: time)` for time-based activation
- Flag metrics — `metrics(:feature_x)` returns check counts with enabled/disabled breakdown
- User targeting — `enable_for(:feature, users: ["user_1"])` to whitelist specific users
- Flag groups — `group(:beta, [:feature_a, :feature_b])` for bulk enable/disable

## [0.1.2] - 2026-03-16

### Changed
- Add License badge to README
- Add bug_tracker_uri to gemspec
- Add Requirements section to README

## [0.1.1] - 2026-03-15

## [0.1.0] - 2026-03-15

### Added
- Initial release
- YAML/ENV/in-memory backends
- Percentage-based rollouts with consistent hashing
- A/B variant support
- Hot-reload of YAML config and test helpers
