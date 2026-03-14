# frozen_string_literal: true

module Legion
  module Extensions
    module PredictiveCoding
      module Helpers
        class GenerativeModel
          attr_reader :model_id, :created_at

          def initialize(model_id: nil)
            @model_id        = model_id || SecureRandom.uuid
            @created_at      = Time.now.utc
            @predictions     = {}    # domain -> { value, confidence, updated_at }
            @error_history   = []    # array of PredictionError objects (capped)
            @precisions      = {}    # domain -> float (0..1)
            @free_energy_ema = 0.0
            @domain_models   = {}    # domain -> simple weighted mean tracker
          end

          def predict(domain:, context: {})
            prior = @domain_models[domain]
            if prior
              confidence = @precisions.fetch(domain, Constants::DEFAULT_PRECISION)
              value      = prior[:mean]
            else
              confidence = Constants::DEFAULT_PRECISION
              value      = context[:expected] || context[:baseline] || 0.5
            end

            @predictions[domain] = { value: value, confidence: confidence, updated_at: Time.now.utc }

            { domain: domain, predicted: value, confidence: confidence }
          end

          def update(domain:, predicted:, actual:)
            precision = @precisions.fetch(domain, Constants::DEFAULT_PRECISION)
            error     = PredictionError.new(domain: domain, predicted: predicted, actual: actual, precision: precision)

            record_error(error)
            update_precision(domain, error.error_magnitude)
            update_domain_model(domain, actual)
            update_free_energy(error.error_magnitude)

            error
          end

          def precision_for(domain:)
            @precisions.fetch(domain, Constants::DEFAULT_PRECISION)
          end

          def free_energy
            prediction_error_term = average_weighted_error
            complexity_term       = @domain_models.size * Constants::COMPLEXITY_PENALTY
            @free_energy_ema      = ema(@free_energy_ema, prediction_error_term + complexity_term, Constants::FREE_ENERGY_ALPHA)
            @free_energy_ema
          end

          def free_energy_level
            fe = free_energy
            Constants::FREE_ENERGY_LEVELS.find { |_k, range| range.cover?(fe) }&.first || :unknown
          end

          def active_inference_candidates
            @domain_models.keys.select do |domain|
              precision = @precisions.fetch(domain, Constants::DEFAULT_PRECISION)
              recent_errors = recent_errors_for(domain)
              next false if recent_errors.empty?

              avg_error = recent_errors.sum(&:error_magnitude) / recent_errors.size
              avg_error > Constants::SURPRISE_THRESHOLD && precision < 0.6
            end
          end

          def surprising_errors
            @error_history.select(&:surprising?)
          end

          def all_errors
            @error_history
          end

          def decay_all
            @precisions.each_key do |domain|
              current = @precisions[domain]
              decayed = [current - Constants::PRECISION_DECAY, Constants::PRECISION_FLOOR].max
              @precisions[domain] = decayed
            end

            prune_old_errors
          end

          def domain_count
            @domain_models.size
          end

          def error_count
            @error_history.size
          end

          def to_h
            {
              model_id:          @model_id,
              created_at:        @created_at,
              domain_count:      @domain_models.size,
              error_count:       @error_history.size,
              free_energy:       free_energy.round(4),
              free_energy_level: free_energy_level,
              surprising_count:  surprising_errors.size,
              domains:           domain_stats
            }
          end

          private

          def record_error(error)
            @error_history << error
            @error_history.shift while @error_history.size > Constants::MAX_ERROR_HISTORY
          end

          def update_precision(domain, error_magnitude)
            current   = @precisions.fetch(domain, Constants::DEFAULT_PRECISION)
            # High error -> precision decreases; low error -> precision increases
            signal    = 1.0 - error_magnitude
            updated   = ema(current, signal, Constants::PRECISION_ALPHA)
            @precisions[domain] = [updated, Constants::PRECISION_FLOOR].max
          end

          def update_domain_model(domain, actual)
            if @domain_models[domain]
              model = @domain_models[domain]
              model[:count] += 1
              model[:mean] = ema(model[:mean], actual.to_f, Constants::MODEL_LEARNING_RATE)
            else
              @domain_models[domain] = { mean: actual.to_f, count: 1 }
            end

            return unless @domain_models.size > Constants::MAX_MODELS

            oldest_domain = @domain_models.keys.first
            @domain_models.delete(oldest_domain)
            @precisions.delete(oldest_domain)
          end

          def update_free_energy(error_magnitude)
            complexity = @domain_models.size * Constants::COMPLEXITY_PENALTY
            raw        = error_magnitude + complexity
            @free_energy_ema = ema(@free_energy_ema, raw, Constants::FREE_ENERGY_ALPHA)
          end

          def average_weighted_error
            return 0.0 if @error_history.empty?

            recent = @error_history.last(50)
            recent.sum(&:weighted_error) / recent.size
          end

          def recent_errors_for(domain)
            @error_history.select { |e| e.domain == domain }.last(10)
          end

          def prune_old_errors
            @error_history.shift while @error_history.size > Constants::MAX_ERROR_HISTORY
          end

          def ema(current, new_value, alpha)
            (alpha * new_value) + ((1.0 - alpha) * current)
          end

          def domain_stats
            @domain_models.map do |domain, model|
              {
                domain:    domain,
                mean:      model[:mean].round(4),
                count:     model[:count],
                precision: @precisions.fetch(domain, Constants::DEFAULT_PRECISION).round(4)
              }
            end
          end
        end
      end
    end
  end
end
