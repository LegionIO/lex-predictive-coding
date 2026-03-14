# frozen_string_literal: true

require 'legion/extensions/predictive_coding/client'

RSpec.describe Legion::Extensions::PredictiveCoding::Client do
  subject(:client) { described_class.new }

  it 'responds to all runner methods' do
    expect(client).to respond_to(:generate_prediction)
    expect(client).to respond_to(:report_outcome)
    expect(client).to respond_to(:precision_for)
    expect(client).to respond_to(:surprising_errors)
    expect(client).to respond_to(:free_energy_status)
    expect(client).to respond_to(:active_inference_candidates)
    expect(client).to respond_to(:register_active_inference)
    expect(client).to respond_to(:resolve_active_inference)
    expect(client).to respond_to(:update_predictive_coding)
    expect(client).to respond_to(:predictive_coding_stats)
  end

  it 'accepts an injected generative_model' do
    model = Legion::Extensions::PredictiveCoding::Helpers::GenerativeModel.new
    custom_client = described_class.new(generative_model: model)
    expect(custom_client).to respond_to(:generate_prediction)
  end

  it 'isolates state between separate client instances' do
    client_a = described_class.new
    client_b = described_class.new

    client_a.report_outcome(domain: :x, predicted: 0.0, actual: 1.0)
    result_b = client_b.surprising_errors

    expect(result_b[:count]).to eq(0)
  end

  describe 'full predictive coding lifecycle' do
    it 'predicts, reports outcome, then updates stats correctly' do
      prediction = client.generate_prediction(domain: :proprioception, context: { expected: 0.6 })
      expect(prediction[:success]).to be true

      outcome = client.report_outcome(domain: :proprioception, predicted: prediction[:predicted], actual: 0.65)
      expect(outcome[:success]).to be true

      status = client.free_energy_status
      expect(status[:free_energy]).to be_a(Float)

      stats = client.predictive_coding_stats
      expect(stats[:model][:domain_count]).to eq(1)
    end

    it 'runs a full active inference cycle' do
      reg = client.register_active_inference(
        domain:           :motor_cortex,
        action:           :amplify_signal,
        expected_outcome: 0.75
      )

      expect(reg[:status]).to eq(:pending)

      resolved = client.resolve_active_inference(
        domain:         :motor_cortex,
        action:         :amplify_signal,
        actual_outcome: 0.78,
        inference_id:   reg[:inference_id]
      )

      expect(resolved[:success]).to be true

      after_update = client.update_predictive_coding
      expect(after_update[:pruned_inferences]).to eq(1)
    end
  end
end
