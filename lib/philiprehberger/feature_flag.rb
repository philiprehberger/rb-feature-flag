# frozen_string_literal: true

require_relative 'feature_flag/version'
require_relative 'feature_flag/configuration'
require_relative 'feature_flag/backends/memory_backend'
require_relative 'feature_flag/backends/env_backend'
require_relative 'feature_flag/backends/yaml_backend'
require_relative 'feature_flag/rollout'

module Philiprehberger
  module FeatureFlag
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def enabled?(flag, user_id: nil)
        return @overrides[flag.to_s] if overridden?(flag)

        value = configuration.backend.get(flag)
        return false if value.nil?
        return Rollout.enabled_for?(flag, user_id, value['percentage']) if rollout?(value)

        !!value
      end

      def variant(flag, user_id:)
        value = configuration.backend.get(flag)
        return nil unless value.is_a?(Hash) && value['variants']

        variants = value['variants']
        bucket = Zlib.crc32("#{flag}:#{user_id}") % variants.size
        variants[bucket]
      end

      def with(flag, value)
        @overrides ||= {}
        @overrides[flag.to_s] = value
        yield
      ensure
        @overrides&.delete(flag.to_s)
      end

      def reload!
        configuration.backend.reload!
      end

      def reset!
        @configuration = nil
        @overrides = nil
      end

      private

      def overridden?(flag)
        @overrides&.key?(flag.to_s)
      end

      def rollout?(value)
        value.is_a?(Hash) && value.key?('percentage')
      end
    end
  end
end
