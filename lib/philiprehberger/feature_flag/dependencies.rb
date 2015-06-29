# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Dependencies
      def depends_on(flag, requires:)
        @dependencies ||= {}
        @dependencies[flag.to_sym] = requires.to_sym
      end

      def dependency_for(flag)
        @dependencies&.dig(flag.to_sym)
      end

      def dependencies_met?(flag)
        dep = dependency_for(flag)
        return true if dep.nil?
        return false unless enabled?(dep)

        dependencies_met?(dep)
      end

      def reset_dependencies!
        @dependencies = nil
      end
    end
  end
end
