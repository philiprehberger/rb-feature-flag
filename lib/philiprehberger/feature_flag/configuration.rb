# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    class Configuration
      attr_accessor :backend

      def initialize
        @backend = Backends::MemoryBackend.new
      end

      def use(type, **options)
        @backend = case type
                   when :memory then Backends::MemoryBackend.new
                   when :env    then Backends::EnvBackend.new
                   when :yaml   then Backends::YamlBackend.new(options[:path])
                   else raise ArgumentError, "unknown backend: #{type}"
                   end
      end
    end
  end
end
