# frozen_string_literal: true

module Legion
  module Extensions
    module PredictiveCoding
      module Helpers
        module Constants
          MAX_PREDICTIONS    = 200
          MAX_ERROR_HISTORY  = 500
          MAX_MODELS         = 20
          DEFAULT_PRECISION  = 0.5
          PRECISION_FLOOR    = 0.05
          PRECISION_ALPHA    = 0.12  # EMA for precision updates
          ERROR_ALPHA        = 0.15  # EMA for prediction error smoothing
          MODEL_LEARNING_RATE = 0.1
          FREE_ENERGY_ALPHA  = 0.1   # EMA for free energy tracking
          COMPLEXITY_PENALTY = 0.05  # penalizes overly complex models
          PREDICTION_DECAY   = 0.01
          PRECISION_DECAY    = 0.005
          MAX_ACTIVE_INFERENCES = 50
          SURPRISE_THRESHOLD = 0.7   # above this, prediction error is "surprising"

          PREDICTION_ERROR_LEVELS = {
            negligible: 0.0..0.1,
            low:        0.1..0.3,
            moderate:   0.3..0.5,
            high:       0.5..0.7,
            surprising: 0.7..1.0
          }.freeze

          FREE_ENERGY_LEVELS = {
            minimal:  0.0..0.2,
            low:      0.2..0.4,
            moderate: 0.4..0.6,
            elevated: 0.6..0.8,
            critical: 0.8..Float::INFINITY
          }.freeze
        end
      end
    end
  end
end
