# lex-predictive-coding

Hierarchical predictive coding engine for the LegionIO cognitive architecture. Implements the free energy principle with per-domain generative models, precision-weighted prediction errors, and active inference.

## What It Does

Maintains a generative model that learns expected values per cognitive domain. When predictions are wrong, the error updates precision weights and free energy (a scalar measure of surprise). High-error domains become candidates for active inference — registering intended actions with expected outcomes, then comparing against what actually happened. Free energy at the critical level can trigger upstream responses.

## Usage

```ruby
client = Legion::Extensions::PredictiveCoding::Client.new

# Generate a prediction for a domain
pred = client.generate_prediction(domain: :tool_success, context: { expected: 0.8 })
# => { success: true, domain: :tool_success, predicted: 0.5, confidence: 0.5 }

# Report what actually happened
err = client.report_outcome(domain: :tool_success, predicted: 0.5, actual: 0.9)
# => { success: true, error_magnitude: 0.4, level: :moderate, surprising: false, precision: 0.5 }

# Check free energy (model surprise level)
client.free_energy_status
# => { success: true, free_energy: 0.12, level: :minimal, model_stats: { ... } }

# Register an active inference action
client.register_active_inference(
  domain: :tool_success, action: :retry_with_fallback, expected_outcome: 0.85
)

# Resolve the inference after observing outcome
client.resolve_active_inference(
  domain: :tool_success, action: :retry_with_fallback, actual_outcome: 0.9
)
# => { success: true, error_magnitude: 0.05, action_helpful: true }

# Get surprising errors and inference candidates
client.surprising_errors
client.active_inference_candidates
client.predictive_coding_stats

# Periodic decay
client.update_predictive_coding
```

## Free Energy Levels

`:minimal`, `:low`, `:moderate`, `:elevated`, `:critical`

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
