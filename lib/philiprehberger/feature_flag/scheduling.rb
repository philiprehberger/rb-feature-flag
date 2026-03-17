# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Scheduling
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
        after_start = sched[:enable_at].nil? || now >= sched[:enable_at]
        before_end = sched[:disable_at].nil? || now < sched[:disable_at]
        after_start && before_end
      end
    end
  end
end
