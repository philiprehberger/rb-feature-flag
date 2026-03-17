# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Groups
      def group(name, flags)
        @groups ||= {}
        @groups[name.to_sym] = flags.map(&:to_sym)
      end

      def group_flags(name)
        @groups&.dig(name.to_sym) || []
      end

      def enable_group(name)
        set_group_flags(name, true)
      end

      def disable_group(name)
        set_group_flags(name, false)
      end

      def reset_groups!
        @groups = nil
      end

      private

      def set_group_flags(name, value)
        group_flags(name).each do |flag|
          configuration.backend.set(flag, value)
        end
      end
    end
  end
end
