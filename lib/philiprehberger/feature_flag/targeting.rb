# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Targeting
      # Whitelist users or a context predicate for +flag+. Either (or
      # both) may be passed. Context predicates are matched against the
      # hash supplied to {FeatureFlag.enabled?}.
      #
      # @param flag [Symbol, String] flag name
      # @param users [Array<String, Integer, Symbol>, nil] user identifiers
      #   to add to the whitelist (normalized to strings)
      # @param context [Hash, nil] optional predicate hash. A request
      #   matches when every key/value in the predicate equals the value
      #   in the supplied context (Array values match any element).
      # @return [void]
      def enable_for(flag, users: nil, context: nil)
        @targets ||= {}
        @targets[flag.to_sym] ||= []
        @targets[flag.to_sym] |= users.map(&:to_s) if users

        @context_predicates ||= {}
        @context_predicates[flag.to_sym] ||= []
        @context_predicates[flag.to_sym] << context if context.is_a?(Hash)
      end

      def disable_for(flag, users:)
        @targets ||= {}
        return unless @targets.key?(flag.to_sym)

        @targets[flag.to_sym] -= users.map(&:to_s)
      end

      def targeted_users(flag)
        @targets&.dig(flag.to_sym) || []
      end

      def targeted_contexts(flag)
        @context_predicates&.dig(flag.to_sym) || []
      end

      def targeted?(flag, user, context: {})
        return true if targeted_by_context?(flag, context)
        return false if user.nil?

        targeted_users(flag).include?(user.to_s)
      end

      def reset_targets!
        @targets = nil
        @context_predicates = nil
      end

      private

      def targeted_by_context?(flag, context)
        return false if context.nil? || context.empty?

        predicates = targeted_contexts(flag)
        return false if predicates.empty?

        predicates.any? { |pred| context_matches?(pred, context) }
      end

      def context_matches?(predicate, context)
        predicate.all? do |key, expected|
          actual = context[key] || context[key.to_s] || context[key.to_sym]
          if expected.is_a?(Array)
            expected.include?(actual)
          else
            actual == expected
          end
        end
      end
    end
  end
end
