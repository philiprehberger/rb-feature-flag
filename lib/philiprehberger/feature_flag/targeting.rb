# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Targeting
      def enable_for(flag, users:)
        @targets ||= {}
        @targets[flag.to_sym] ||= []
        @targets[flag.to_sym] |= users.map(&:to_s)
      end

      def disable_for(flag, users:)
        @targets ||= {}
        return unless @targets.key?(flag.to_sym)

        @targets[flag.to_sym] -= users.map(&:to_s)
      end

      def targeted_users(flag)
        @targets&.dig(flag.to_sym) || []
      end

      def targeted?(flag, user)
        return false if user.nil?

        targeted_users(flag).include?(user.to_s)
      end

      def reset_targets!
        @targets = nil
      end
    end
  end
end
