# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module PredictiveCoding
      module Runners
        module PredictiveCoding
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def generate_prediction(domain:, context: {}, **)
            prediction = generative_model.predict(domain: domain, context: context)
            Legion::Logging.debug "[predictive_coding] generate_prediction domain=#{domain} " \
                                  "predicted=#{prediction[:predicted]} confidence=#{prediction[:confidence].round(3)}"
            { success: true, domain: domain, predicted: prediction[:predicted], confidence: prediction[:confidence] }
          end

          def report_outcome(domain:, predicted:, actual:, **)
            error = generative_model.update(domain: domain, predicted: predicted, actual: actual)
            Legion::Logging.debug "[predictive_coding] report_outcome domain=#{domain} " \
                                  "error_magnitude=#{error.error_magnitude.round(3)} surprising=#{error.surprising?}"
            {
              success:         true,
              domain:          domain,
              error_magnitude: error.error_magnitude,
              weighted_error:  error.weighted_error,
              precision:       error.precision,
              surprising:      error.surprising?,
              level:           error.level
            }
          end

          def precision_for(domain:, **)
            value = generative_model.precision_for(domain: domain)
            Legion::Logging.debug "[predictive_coding] precision_for domain=#{domain} precision=#{value.round(3)}"
            { success: true, domain: domain, precision: value }
          end

          def surprising_errors(**)
            errors = generative_model.surprising_errors
            Legion::Logging.debug "[predictive_coding] surprising_errors count=#{errors.size}"
            { success: true, errors: errors.map(&:to_h), count: errors.size }
          end

          def free_energy_status(**)
            fe    = generative_model.free_energy
            level = generative_model.free_energy_level
            Legion::Logging.debug "[predictive_coding] free_energy_status fe=#{fe.round(3)} level=#{level}"
            {
              success:     true,
              free_energy: fe,
              level:       level,
              model_stats: generative_model.to_h
            }
          end

          def active_inference_candidates(**)
            candidates = generative_model.active_inference_candidates
            Legion::Logging.debug "[predictive_coding] active_inference_candidates count=#{candidates.size}"
            { success: true, candidates: candidates, count: candidates.size }
          end

          def register_active_inference(domain:, action:, expected_outcome:, **)
            inference_id = SecureRandom.uuid
            active_inferences[inference_id] = {
              inference_id:     inference_id,
              domain:           domain,
              action:           action,
              expected_outcome: expected_outcome,
              status:           :pending,
              registered_at:    Time.now.utc
            }

            prune_active_inferences

            Legion::Logging.debug "[predictive_coding] register_active_inference domain=#{domain} id=#{inference_id[0..7]}"
            { success: true, inference_id: inference_id, domain: domain, status: :pending }
          end

          def resolve_active_inference(domain:, action:, actual_outcome:, inference_id: nil, **)
            record = find_inference(domain, action, inference_id)
            unless record
              Legion::Logging.debug "[predictive_coding] resolve_active_inference not found domain=#{domain}"
              return { success: false, reason: :not_found }
            end

            expected = record[:expected_outcome]
            error    = generative_model.update(
              domain:    domain,
              predicted: expected,
              actual:    actual_outcome
            )

            record[:status]           = :resolved
            record[:actual_outcome]   = actual_outcome
            record[:resolved_at]      = Time.now.utc
            record[:error_magnitude]  = error.error_magnitude

            Legion::Logging.info "[predictive_coding] resolve_active_inference domain=#{domain} " \
                                 "error=#{error.error_magnitude.round(3)} id=#{record[:inference_id][0..7]}"

            {
              success:         true,
              inference_id:    record[:inference_id],
              domain:          domain,
              error_magnitude: error.error_magnitude,
              action_helpful:  error.error_magnitude < Legion::Extensions::PredictiveCoding::Helpers::Constants::SURPRISE_THRESHOLD
            }
          end

          def update_predictive_coding(**)
            generative_model.decay_all
            pruned = prune_resolved_inferences
            Legion::Logging.debug "[predictive_coding] update_predictive_coding pruned_inferences=#{pruned}"
            { success: true, pruned_inferences: pruned }
          end

          def predictive_coding_stats(**)
            {
              success:            true,
              model:              generative_model.to_h,
              active_inferences:  active_inferences.size,
              pending_inferences: active_inferences.count { |_, v| v[:status] == :pending }
            }
          end

          private

          def generative_model
            @generative_model ||= Helpers::GenerativeModel.new
          end

          def active_inferences
            @active_inferences ||= {}
          end

          def prune_active_inferences
            max = Legion::Extensions::PredictiveCoding::Helpers::Constants::MAX_ACTIVE_INFERENCES
            return unless active_inferences.size > max

            sorted    = active_inferences.sort_by { |_, v| v[:registered_at] }
            ids       = sorted.first(active_inferences.size - max).map(&:first)
            ids.each { |id| active_inferences.delete(id) }
          end

          def prune_resolved_inferences
            resolved = active_inferences.select { |_, v| v[:status] == :resolved }.keys
            resolved.each { |id| active_inferences.delete(id) }
            resolved.size
          end

          def find_inference(domain, action, inference_id)
            if inference_id
              active_inferences[inference_id]
            else
              active_inferences.values.find do |r|
                r[:domain] == domain && r[:action] == action && r[:status] == :pending
              end
            end
          end
        end
      end
    end
  end
end
