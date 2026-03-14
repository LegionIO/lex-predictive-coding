# lex-predictive-coding

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Gem**: `lex-predictive-coding`
- **Version**: 0.1.0
- **Namespace**: `Legion::Extensions::PredictiveCoding`

## Purpose

Hierarchical predictive coding engine based on the free energy principle. Maintains a `GenerativeModel` that tracks per-domain predictions, precision weights, and prediction errors. Computes free energy (a measure of surprise) via EMA. Supports active inference: registering intended actions with expected outcomes, then resolving them against actual outcomes to update the model. Surprising errors (error_magnitude > 0.7) trigger candidate domains for active inference.

## Gem Info

- **Homepage**: https://github.com/LegionIO/lex-predictive-coding
- **License**: MIT
- **Ruby**: >= 3.4

## File Structure

```
lib/legion/extensions/predictive_coding/
  version.rb
  client.rb
  helpers/
    constants.rb          # Limits, alphas, thresholds, FREE_ENERGY_LEVELS, PREDICTION_ERROR_LEVELS
    prediction_error.rb   # PredictionError class — single error observation
    generative_model.rb   # GenerativeModel — per-domain predictions, precision, free energy
  runners/
    predictive_coding.rb  # Runner module
  actors/
    decay.rb              # Decay actor (periodic)
spec/
  helpers/prediction_error_spec.rb
  helpers/generative_model_spec.rb
  runners/predictive_coding_spec.rb
  client_spec.rb
```

## Key Constants

From `Helpers::Constants`:
- `MAX_PREDICTIONS = 200`, `MAX_ERROR_HISTORY = 500`, `MAX_MODELS = 20`, `MAX_ACTIVE_INFERENCES = 50`
- `DEFAULT_PRECISION = 0.5`, `PRECISION_FLOOR = 0.05`
- `PRECISION_ALPHA = 0.12` (EMA for precision), `ERROR_ALPHA = 0.15`, `FREE_ENERGY_ALPHA = 0.1`
- `MODEL_LEARNING_RATE = 0.1`, `COMPLEXITY_PENALTY = 0.05`, `PREDICTION_DECAY = 0.01`, `PRECISION_DECAY = 0.005`
- `SURPRISE_THRESHOLD = 0.7`
- `PREDICTION_ERROR_LEVELS`: `:negligible` (0–0.1), `:low`, `:moderate`, `:high`, `:surprising` (0.7–1.0)
- `FREE_ENERGY_LEVELS`: `:minimal` (0–0.2), `:low`, `:moderate`, `:elevated`, `:critical` (0.8+)

## Runners

| Method | Key Parameters | Returns |
|---|---|---|
| `generate_prediction` | `domain:`, `context: {}` | `{ success:, domain:, predicted:, confidence: }` |
| `report_outcome` | `domain:`, `predicted:`, `actual:` | error magnitude, weighted_error, precision, surprising flag, level |
| `precision_for` | `domain:` | `{ success:, domain:, precision: }` |
| `surprising_errors` | — | `{ success:, errors:, count: }` |
| `free_energy_status` | — | `{ success:, free_energy:, level:, model_stats: }` |
| `active_inference_candidates` | — | domains with high error and low precision |
| `register_active_inference` | `domain:`, `action:`, `expected_outcome:` | `{ success:, inference_id:, domain:, status: :pending }` |
| `resolve_active_inference` | `domain:`, `action:`, `actual_outcome:`, `inference_id:` | error magnitude + `action_helpful` bool |
| `update_predictive_coding` | — | applies precision decay, prunes resolved inferences |
| `predictive_coding_stats` | — | model stats + active inference counts |

## Helpers

### `Helpers::PredictionError`
Single prediction error observation: `domain`, `predicted`, `actual`, `precision`, `error_magnitude` = abs(predicted - actual), `weighted_error` = error_magnitude * precision, `surprising?` = error_magnitude > `SURPRISE_THRESHOLD`, `level` mapped from `PREDICTION_ERROR_LEVELS`.

### `Helpers::GenerativeModel`
Per-domain generative model. `predict(domain:, context:)` returns EMA-tracked mean or context baseline. `update(domain:, predicted:, actual:)` creates `PredictionError`, updates precision via EMA (high error decreases precision), updates domain model mean, updates free energy EMA. `free_energy` = precision-weighted error + complexity penalty (domain count * 0.05). `active_inference_candidates` = domains with avg recent error > 0.7 and precision < 0.6. `decay_all` applies `PRECISION_DECAY` to all domains, prunes error history.

## Integration Points

- `generate_prediction` + `report_outcome` pair integrates with `lex-prediction` for forward-model comparison
- `surprising_errors` can feed `lex-reflection` as a calibration health signal
- `free_energy_status` `:critical` level can trigger `lex-cortex` mode escalation
- `active_inference_candidates` domains can feed `lex-volition` for targeted action selection
- `resolve_active_inference` feeds back into precision updating — supports closed-loop learning
- `update_predictive_coding` called via `actors/decay.rb` periodic actor

## Development Notes

- Precision update: high error -> signal = 1.0 - error_magnitude -> precision decreases via EMA
- Free energy = EMA of (weighted_prediction_error + domain_count * COMPLEXITY_PENALTY)
- Domain model eviction: when > MAX_MODELS, the oldest domain key is deleted
- Active inference resolution can be found by `inference_id` or by matching `domain + action + :pending`
- `action_helpful` = error_magnitude < SURPRISE_THRESHOLD after resolution
- All state is in-memory; reset on process restart
