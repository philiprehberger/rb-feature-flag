# frozen_string_literal: true

require 'zlib'

module Philiprehberger
  module FeatureFlag
    module Rollout
      module_function

      # Determine whether +flag+ is enabled for a user given a percentage
      # rollout. The bucket key defaults to the user id, matching the historic
      # behavior. Pass +rollout_by+ to mix additional context values into the
      # bucket key — e.g. +rollout_by: [:user_id, :region]+ assigns a user
      # differently per region.
      #
      # @param flag [Symbol, String] flag name
      # @param user_id [String, Integer, nil] primary bucket key
      # @param percentage [Integer, nil] rollout percentage in +0..100+
      # @param context [Hash] optional context hash whose values may be
      #   combined into the bucket key via +rollout_by+
      # @param rollout_by [Array<Symbol>] ordered list of context keys
      #   (plus the implicit +:user_id+) that form the bucket key. Defaults
      #   to +[:user_id]+ — preserving historic behavior.
      # @return [Boolean]
      def enabled_for?(flag, user_id, percentage, context: {}, rollout_by: [:user_id])
        return false if percentage.nil?
        return false if percentage <= 0
        return true if percentage >= 100

        key = bucket_key(user_id, context, rollout_by)
        return false if key.nil?

        bucket = Zlib.crc32("#{flag}:#{key}") % 100
        bucket < percentage
      end

      # Build the bucket key from +user_id+ and +context+ guided by
      # +rollout_by+. When +rollout_by+ is +[:user_id]+ (the default) and the
      # user id is missing, returns nil to preserve the historic "nil user_id
      # disables rollout" behavior.
      #
      # @return [String, nil]
      def bucket_key(user_id, context, rollout_by)
        keys = Array(rollout_by).map(&:to_sym)
        keys = [:user_id] if keys.empty?

        if keys == [:user_id]
          return nil if user_id.nil?

          return user_id.to_s
        end

        parts = keys.map do |k|
          if k == :user_id
            user_id
          else
            context[k] || context[k.to_s]
          end
        end
        return nil if parts.all?(&:nil?)

        parts.join('|')
      end
    end
  end
end
