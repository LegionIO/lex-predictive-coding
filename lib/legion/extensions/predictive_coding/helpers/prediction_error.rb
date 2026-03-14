# frozen_string_literal: true

module Legion
  module Extensions
    module PredictiveCoding
      module Helpers
        class PredictionError
          attr_reader :domain, :predicted, :actual, :error_magnitude, :precision, :weighted_error, :timestamp

          def initialize(domain:, predicted:, actual:, precision: Constants::DEFAULT_PRECISION)
            @domain          = domain
            @predicted       = predicted
            @actual          = actual
            @error_magnitude = compute_error_magnitude(predicted, actual)
            @precision       = precision
            @weighted_error  = @error_magnitude * @precision
            @timestamp       = Time.now.utc
          end

          def surprising?
            @error_magnitude >= Constants::SURPRISE_THRESHOLD
          end

          def level
            Constants::PREDICTION_ERROR_LEVELS.find { |_k, range| range.cover?(@error_magnitude) }&.first || :unknown
          end

          def to_h
            {
              domain:          @domain,
              predicted:       @predicted,
              actual:          @actual,
              error_magnitude: @error_magnitude,
              precision:       @precision,
              weighted_error:  @weighted_error,
              surprising:      surprising?,
              level:           level,
              timestamp:       @timestamp
            }
          end

          private

          def compute_error_magnitude(predicted, actual)
            if predicted.is_a?(Numeric) && actual.is_a?(Numeric)
              (predicted - actual).abs.clamp(0.0, 1.0)
            else
              predicted == actual ? 0.0 : 1.0
            end
          end
        end
      end
    end
  end
end
