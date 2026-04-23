# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Dependencies
      # Declare that +flag+ depends on +requires+. A dependent flag is only
      # enabled when every flag in its dependency chain is also enabled.
      #
      # @param flag [Symbol, String] dependent flag name
      # @param requires [Symbol, String] parent flag name
      # @return [Symbol] the normalized parent name
      def depends_on(flag, requires:)
        @dependencies ||= {}
        @dependencies[flag.to_sym] = requires.to_sym
      end

      def dependency_for(flag)
        @dependencies&.dig(flag.to_sym)
      end

      def dependencies_met?(flag, context = {})
        dep = dependency_for(flag)
        return true if dep.nil?
        return false unless enabled?(dep, context: context)

        dependencies_met?(dep, context)
      end

      def reset_dependencies!
        @dependencies = nil
      end
    end
  end
end
