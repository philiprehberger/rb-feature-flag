# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Scheduling
      # Register a time-bounded activation window for +flag+. A flag is
      # considered active when +Time.now+ is at or after +enable_at+ (if
      # set) and strictly before +disable_at+ (if set).
      #
      # @param flag [Symbol, String] flag name
      # @param enable_at [Time, nil] inclusive start of the window
      # @param disable_at [Time, nil] exclusive end of the window
      # @raise [ArgumentError] if either bound is non-nil and not a +Time+
      #   (validated at check time via {#scheduled_active?})
      # @return [Hash] the stored schedule entry
      def schedule(flag, enable_at: nil, disable_at: nil)
        @schedules ||= {}
        @schedules[flag.to_sym] = { enable_at: enable_at, disable_at: disable_at }
      end

      def schedule_for(flag)
        @schedules&.dig(flag.to_sym)
      end

      def scheduled_active?(flag)
        sched = schedule_for(flag)
        return true if sched.nil?

        now = Time.now
        check_schedule_window(now, sched)
      end

      def reset_schedules!
        @schedules = nil
      end

      private

      def check_schedule_window(now, sched)
        validate_schedule_types!(sched)
        after_start = sched[:enable_at].nil? || now >= sched[:enable_at]
        before_end = sched[:disable_at].nil? || now < sched[:disable_at]
        after_start && before_end
      end

      def validate_schedule_types!(sched)
        raise ArgumentError, 'enable_at must be a Time' unless sched[:enable_at].nil? || sched[:enable_at].is_a?(Time)
        raise ArgumentError, 'disable_at must be a Time' unless sched[:disable_at].nil? || sched[:disable_at].is_a?(Time)
      end
    end
  end
end
