# frozen_string_literal: true

module Philiprehberger
  module FeatureFlag
    module Metrics
      def metrics(flag)
        @metrics_data ||= {}
        data = @metrics_data[flag.to_sym] || default_metrics
        data.dup
      end

      def record_metric(flag, result)
        @metrics_data ||= {}
        @metrics_data[flag.to_sym] ||= default_metrics
        increment_metric(flag, result)
      end

      def reset_metrics!
        @metrics_data = nil
      end

      private

      def default_metrics
        { checks: 0, enabled: 0, disabled: 0 }
      end

      def increment_metric(flag, result)
        data = @metrics_data[flag.to_sym]
        data[:checks] += 1
        result ? data[:enabled] += 1 : data[:disabled] += 1
      end
    end
  end
end
