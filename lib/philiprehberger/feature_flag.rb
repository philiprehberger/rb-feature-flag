# frozen_string_literal: true

require_relative 'feature_flag/version'
require_relative 'feature_flag/configuration'
require_relative 'feature_flag/backends/memory_backend'
require_relative 'feature_flag/backends/env_backend'
require_relative 'feature_flag/backends/yaml_backend'
require_relative 'feature_flag/rollout'
require_relative 'feature_flag/dependencies'
require_relative 'feature_flag/scheduling'
require_relative 'feature_flag/metrics'
require_relative 'feature_flag/targeting'
require_relative 'feature_flag/groups'

module Philiprehberger
  module FeatureFlag
    class << self
      include Dependencies
      include Scheduling
      include Metrics
      include Targeting
      include Groups

      def configuration
        @configuration ||= Configuration.new
      end

      # Configure the feature flag system. Yields the shared
      # {Configuration} instance so callers can pick a backend or mutate
      # settings.
      #
      # @yieldparam config [Configuration]
      # @return [void]
      def configure
        yield(configuration)
      end

      # Check whether +flag+ is enabled. The lookup honors (in order):
      # in-flight overrides from {.with}, dependency gates, scheduling
      # windows, user targeting, and finally the backend value — which may
      # be a boolean, a percentage rollout, or any truthy value.
      #
      # @param flag [Symbol, String] flag name
      # @param user_id [String, Integer, nil] used for percentage rollouts
      # @param user [String, Integer, nil] used for user-list targeting
      # @param context [Hash] optional context passed to targeting
      #   predicates and rollout bucketing (see +rollout_by+ on the flag
      #   configuration)
      # @return [Boolean, Object] boolean for normal flags; whatever was
      #   stored (including +nil+) when an override is active
      def enabled?(flag, user_id: nil, user: nil, context: {})
        return @overrides[flag.to_s] if overridden?(flag)

        result = evaluate_flag(flag, user_id, user, context)
        record_metric(flag, result)
        result
      end

      # Return the A/B variant for +user_id+ on +flag+. Variants are
      # stored as +{ 'variants' => [...] }+ on the backend and selected
      # deterministically from the user id (optionally combined with
      # +context+ when the flag declares +rollout_by+).
      #
      # @param flag [Symbol, String] flag name
      # @param user_id [String, Integer] bucket key
      # @param context [Hash] optional context hash; used with the flag's
      #   +rollout_by+ to diversify variant selection
      # @return [String, nil] the selected variant, or +nil+ when the flag
      #   is not a variant-shaped hash
      def variant(flag, user_id:, context: {})
        value = configuration.backend.get(flag)
        return nil unless variant_value?(value)

        variants = value['variants']
        rollout_by = Array(value['rollout_by']).map(&:to_sym)
        rollout_by = [:user_id] if rollout_by.empty?
        key = Rollout.bucket_key(user_id, context, rollout_by) || user_id.to_s
        bucket = Zlib.crc32("#{flag}:#{key}") % variants.size
        variants[bucket]
      end

      def with(flag, value)
        @overrides ||= {}
        key = flag.to_s
        had_previous = @overrides.key?(key)
        previous = @overrides[key]
        @overrides[key] = value
        yield
      ensure
        if had_previous
          @overrides[key] = previous
        else
          @overrides&.delete(key)
        end
      end

      def reload!
        configuration.backend.reload!
      end

      # Return the sorted, deduplicated union of every flag name known to the
      # configured backend and the registered dependency, schedule, targeting,
      # and group subsystems.
      #
      # Backends that do not expose their flag names (for example, opaque
      # remote backends without an +all+ accessor) are skipped silently.
      #
      # @return [Array<Symbol>] ascending-sorted unique flag names
      def flag_names
        names = []
        names.concat(backend_flag_names)
        names.concat(Array(@dependencies&.keys))
        names.concat(Array(@dependencies&.values))
        names.concat(Array(@schedules&.keys))
        names.concat(Array(@targets&.keys))
        names.concat(Array(@groups&.values).flatten)
        names.map(&:to_sym).uniq.sort
      end

      def reset!
        @configuration = nil
        @overrides = nil
        reset_dependencies!
        reset_schedules!
        reset_metrics!
        reset_targets!
        reset_groups!
      end

      # Fully reset every piece of registry state — backend-stored flags,
      # in-flight overrides, recorded metrics, dependencies, schedules,
      # targets, context predicates, and groups. Intended for use in test
      # suites (e.g. +before(:each) { FeatureFlag.reset_all! }+) so each
      # example starts from a clean slate. Safe to call when nothing is
      # registered.
      #
      # @return [void]
      def reset_all!
        @configuration = nil
        @overrides = nil
        reset_dependencies!
        reset_schedules!
        reset_metrics!
        reset_targets!
        reset_groups!
        nil
      end

      # Return the array of registered flag names. A flag is considered
      # registered when it has been stored on the backend or referenced by
      # any of the dependency, schedule, targeting, or group subsystems.
      # Equivalent to {.flag_names} — kept as a shorter alias for callers
      # that want the registered list without thinking about ordering.
      #
      # @return [Array<Symbol>] sorted, deduplicated registered flag names
      def flags
        flag_names
      end

      private

      def backend_flag_names
        backend = configuration.backend
        return [] unless backend.respond_to?(:all)

        entries = backend.all
        return [] unless entries.respond_to?(:keys)

        entries.keys
      rescue StandardError
        []
      end

      def evaluate_flag(flag, user_id, user, context)
        return false unless dependencies_met?(flag, context)
        return false unless scheduled_active?(flag)
        return true if targeted?(flag, user, context: context)

        resolve_backend_value(flag, user_id, context)
      end

      def resolve_backend_value(flag, user_id, context)
        value = configuration.backend.get(flag)
        return false if value.nil?

        if rollout?(value)
          rollout_by = Array(value['rollout_by']).map(&:to_sym)
          rollout_by = [:user_id] if rollout_by.empty?
          return Rollout.enabled_for?(flag, user_id, value['percentage'],
                                      context: context, rollout_by: rollout_by)
        end

        !!value
      end

      def overridden?(flag)
        @overrides&.key?(flag.to_s)
      end

      def rollout?(value)
        value.is_a?(Hash) && value.key?('percentage')
      end

      def variant_value?(value)
        value.is_a?(Hash) && !value['variants'].nil?
      end
    end
  end
end
