# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
