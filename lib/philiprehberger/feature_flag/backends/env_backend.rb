# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Backends
      class EnvBackend
        def get(flag)
          value = ENV.fetch("FEATURE_#{flag.to_s.upcase}", nil)
          return nil if value.nil?

          parse_value(value)
        end

        def set(_flag, _value)
          raise NotImplementedError, 'ENV backend is read-only'
        end

        def all
          ENV.select { |k, _| k.start_with?('FEATURE_') }
             .transform_keys { |k| k.delete_prefix('FEATURE_').downcase }
        end

        def reload!
          # no-op, ENV is always live
        end

        private

        def parse_value(value)
          case value.downcase
          when 'true', '1'  then true
          when 'false', '0' then false
          else value
          end
        end
      end
    end
  end
end
