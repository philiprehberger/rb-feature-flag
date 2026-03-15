# frozen_string_literal: true

require 'yaml'

module Philiprehberger
  module FeatureFlag
    module Backends
      class YamlBackend
        def initialize(path)
          raise ArgumentError, 'path is required for YAML backend' if path.nil?

          @path = path
          load_flags
        end

        def get(flag)
          @flags[flag.to_s]
        end

        def set(_flag, _value)
          raise NotImplementedError, 'YAML backend is read-only'
        end

        def all
          @flags.dup
        end

        def reload!
          load_flags
        end

        private

        def load_flags
          @flags = if File.exist?(@path)
                     YAML.safe_load_file(@path) || {}
                   else
                     {}
                   end
        end
      end
    end
  end
end
