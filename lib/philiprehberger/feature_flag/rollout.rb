# frozen_string_literal: true

require 'zlib'

module Philiprehberger
  module FeatureFlag
    module Rollout
      module_function

      def enabled_for?(flag, user_id, percentage)
        return false if user_id.nil? || percentage.nil?
        return false if percentage <= 0
        return true if percentage >= 100

        bucket = Zlib.crc32("#{flag}:#{user_id}") % 100
        bucket < percentage
      end
    end
  end
end
