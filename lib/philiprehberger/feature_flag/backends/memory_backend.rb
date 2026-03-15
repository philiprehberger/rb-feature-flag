# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Backends
      class MemoryBackend
        def initialize
          @store = {}
        end

        def get(flag)
          @store[flag.to_s]
        end

        def set(flag, value)
          @store[flag.to_s] = value
        end

        def all
          @store.dup
        end

        def reload!
          # no-op for in-memory
        end
      end
    end
  end
end
