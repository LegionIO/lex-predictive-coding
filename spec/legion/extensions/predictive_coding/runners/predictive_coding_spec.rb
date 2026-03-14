# frozen_string_literal: true

require 'legion/extensions/predictive_coding/client'

RSpec.describe Legion::Extensions::PredictiveCoding::Runners::PredictiveCoding do
  let(:client) { Legion::Extensions::PredictiveCoding::Client.new }

  describe '#generate_prediction' do
    it 'returns success with domain and prediction' do
      result = client.generate_prediction(domain: :vision)
      expect(result[:success]).to be true
      expect(result[:domain]).to eq(:vision)
      expect(result[:predicted]).to be_a(Numeric)
      expect(result[:confidence]).to be_a(Float)
    end

    it 'passes context to the generative model' do
      result = client.generate_prediction(domain: :audio, context: { expected: 0.7 })
      expect(result[:success]).to be true
      expect(result[:predicted]).to be_within(0.001).of(0.7)
    end

    it 'accepts extra keyword arguments without error' do
      expect { client.generate_prediction(domain: :x, extra: :ignored) }.not_to raise_error
    end
  end

  describe '#report_outcome' do
    it 'returns success with error details' do
      result = client.report_outcome(domain: :vision, predicted: 0.5, actual: 0.9)
      expect(result[:success]).to be true
      expect(result[:error_magnitude]).to be_a(Float)
      expect(result[:weighted_error]).to be_a(Float)
      expect(result[:precision]).to be_a(Float)
      expect(result[:surprising]).to be(true).or be(false)
      expect(result[:level]).to be_a(Symbol)
    end

    it 'marks zero-error outcomes as non-surprising' do
      result = client.report_outcome(domain: :x, predicted: 0.5, actual: 0.5)
      expect(result[:surprising]).to be false
      expect(result[:error_magnitude]).to eq(0.0)
    end

    it 'marks large-error outcomes as surprising' do
      result = client.report_outcome(domain: :x, predicted: 0.0, actual: 1.0)
      expect(result[:surprising]).to be true
    end
  end

  describe '#precision_for' do
    it 'returns DEFAULT_PRECISION for unknown domain' do
      result = client.precision_for(domain: :unknown_domain_xyz)
      expect(result[:success]).to be true
      expect(result[:precision]).to eq(Legion::Extensions::PredictiveCoding::Helpers::Constants::DEFAULT_PRECISION)
    end

    it 'returns updated precision after reporting outcomes' do
      client.report_outcome(domain: :sensor, predicted: 0.5, actual: 0.5)
      result = client.precision_for(domain: :sensor)
      expect(result[:precision]).to be_a(Float)
    end
  end

  describe '#surprising_errors' do
    it 'returns empty list when no surprising errors' do
      result = client.surprising_errors
      expect(result[:success]).to be true
      expect(result[:errors]).to be_an(Array)
      expect(result[:count]).to eq(0)
    end

    it 'returns errors above surprise threshold' do
      client.report_outcome(domain: :x, predicted: 0.0, actual: 1.0)
      result = client.surprising_errors
      expect(result[:count]).to be >= 1
      expect(result[:errors].first[:surprising]).to be true
    end
  end

  describe '#free_energy_status' do
    it 'returns free energy value and level' do
      result = client.free_energy_status
      expect(result[:success]).to be true
      expect(result[:free_energy]).to be_a(Float)
      expect(result[:level]).to be_a(Symbol)
      expect(result[:model_stats]).to be_a(Hash)
    end

    it 'reflects accumulated errors in free energy' do
      initial = client.free_energy_status[:free_energy]
      5.times { client.report_outcome(domain: :x, predicted: 0.0, actual: 1.0) }
      elevated = client.free_energy_status[:free_energy]
      expect(elevated).to be > initial
    end
  end

  describe '#active_inference_candidates' do
    it 'returns empty list for fresh client' do
      result = client.active_inference_candidates
      expect(result[:success]).to be true
      expect(result[:candidates]).to be_an(Array)
    end

    it 'includes domains with persistent high errors' do
      10.times { client.report_outcome(domain: :faulty, predicted: 0.0, actual: 1.0) }
      result = client.active_inference_candidates
      expect(result[:candidates]).to include(:faulty)
    end
  end

  describe '#register_active_inference' do
    it 'registers and returns an inference_id' do
      result = client.register_active_inference(domain: :motor, action: :increase_gain, expected_outcome: 0.8)
      expect(result[:success]).to be true
      expect(result[:inference_id]).to match(/\A[0-9a-f-]{36}\z/)
      expect(result[:status]).to eq(:pending)
    end

    it 'accepts extra keyword arguments' do
      expect do
        client.register_active_inference(domain: :x, action: :test, expected_outcome: 0.5, extra: :ignored)
      end.not_to raise_error
    end
  end

  describe '#resolve_active_inference' do
    it 'resolves a registered inference and returns error details' do
      reg = client.register_active_inference(domain: :motor, action: :increase_gain, expected_outcome: 0.8)
      result = client.resolve_active_inference(
        domain:         :motor,
        action:         :increase_gain,
        actual_outcome: 0.85,
        inference_id:   reg[:inference_id]
      )
      expect(result[:success]).to be true
      expect(result[:error_magnitude]).to be_a(Float)
      expect(result).to have_key(:action_helpful)
    end

    it 'returns not_found when inference does not exist' do
      result = client.resolve_active_inference(
        domain:         :missing,
        action:         :noop,
        actual_outcome: 0.5,
        inference_id:   'nonexistent-id'
      )
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:not_found)
    end

    it 'marks action_helpful true when error is below surprise threshold' do
      reg = client.register_active_inference(domain: :x, action: :nudge, expected_outcome: 0.5)
      result = client.resolve_active_inference(
        domain:         :x,
        action:         :nudge,
        actual_outcome: 0.51,
        inference_id:   reg[:inference_id]
      )
      expect(result[:action_helpful]).to be true
    end

    it 'marks action_helpful false when error is above surprise threshold' do
      reg = client.register_active_inference(domain: :x, action: :nudge, expected_outcome: 0.0)
      result = client.resolve_active_inference(
        domain:         :x,
        action:         :nudge,
        actual_outcome: 1.0,
        inference_id:   reg[:inference_id]
      )
      expect(result[:action_helpful]).to be false
    end
  end

  describe '#update_predictive_coding' do
    it 'returns success' do
      result = client.update_predictive_coding
      expect(result[:success]).to be true
    end

    it 'prunes resolved inferences' do
      reg = client.register_active_inference(domain: :x, action: :test, expected_outcome: 0.5)
      client.resolve_active_inference(domain: :x, action: :test, actual_outcome: 0.5, inference_id: reg[:inference_id])
      result = client.update_predictive_coding
      expect(result[:pruned_inferences]).to be >= 1
    end

    it 'returns pruned count of zero when nothing resolved' do
      result = client.update_predictive_coding
      expect(result[:pruned_inferences]).to eq(0)
    end
  end

  describe '#predictive_coding_stats' do
    it 'returns full stats hash' do
      result = client.predictive_coding_stats
      expect(result[:success]).to be true
      expect(result[:model]).to be_a(Hash)
      expect(result[:active_inferences]).to be_a(Integer)
      expect(result[:pending_inferences]).to be_a(Integer)
    end

    it 'counts active inferences correctly' do
      client.register_active_inference(domain: :x, action: :test, expected_outcome: 0.5)
      result = client.predictive_coding_stats
      expect(result[:active_inferences]).to eq(1)
      expect(result[:pending_inferences]).to eq(1)
    end
  end
end
