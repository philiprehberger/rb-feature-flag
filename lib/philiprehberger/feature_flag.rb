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

      def configure
        yield(configuration)
      end

      def enabled?(flag, user_id: nil, user: nil)
        return @overrides[flag.to_s] if overridden?(flag)

        result = evaluate_flag(flag, user_id, user)
        record_metric(flag, result)
        result
      end

      def variant(flag, user_id:)
        value = configuration.backend.get(flag)
        return nil unless variant_value?(value)

        variants = value['variants']
        bucket = Zlib.crc32("#{flag}:#{user_id}") % variants.size
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

      def reset!
        @configuration = nil
        @overrides = nil
        reset_dependencies!
        reset_schedules!
        reset_metrics!
        reset_targets!
        reset_groups!
      end

      private

      def evaluate_flag(flag, user_id, user)
        return false unless dependencies_met?(flag)
        return false unless scheduled_active?(flag)
        return true if targeted?(flag, user)

        resolve_backend_value(flag, user_id)
      end

      def resolve_backend_value(flag, user_id)
        value = configuration.backend.get(flag)
        return false if value.nil?
        return Rollout.enabled_for?(flag, user_id, value['percentage']) if rollout?(value)

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
