# frozen_string_literal: true

RSpec.describe Legion::Extensions::PredictiveCoding::Helpers::GenerativeModel do
  let(:model) { described_class.new }
  let(:constants) { Legion::Extensions::PredictiveCoding::Helpers::Constants }

  describe '#initialize' do
    it 'assigns a model_id' do
      expect(model.model_id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'starts with zero domain models' do
      expect(model.domain_count).to eq(0)
    end

    it 'starts with zero errors' do
      expect(model.error_count).to eq(0)
    end

    it 'accepts an explicit model_id' do
      m = described_class.new(model_id: 'custom-id')
      expect(m.model_id).to eq('custom-id')
    end
  end

  describe '#predict' do
    it 'returns a prediction hash with domain and confidence' do
      result = model.predict(domain: :vision)
      expect(result[:domain]).to eq(:vision)
      expect(result[:predicted]).to be_a(Numeric)
      expect(result[:confidence]).to be_a(Float)
    end

    it 'uses DEFAULT_PRECISION for an unknown domain' do
      result = model.predict(domain: :new_domain)
      expect(result[:confidence]).to eq(constants::DEFAULT_PRECISION)
    end

    it 'uses context[:expected] as initial value for unknown domain' do
      result = model.predict(domain: :touch, context: { expected: 0.9 })
      expect(result[:predicted]).to be_within(0.001).of(0.9)
    end

    it 'improves prediction after learning from updates' do
      5.times { model.update(domain: :sensor, predicted: 0.5, actual: 0.8) }
      result = model.predict(domain: :sensor)
      expect(result[:predicted]).to be > 0.5
    end
  end

  describe '#update' do
    it 'returns a PredictionError object' do
      error = model.update(domain: :vision, predicted: 0.5, actual: 0.9)
      expect(error).to be_a(Legion::Extensions::PredictiveCoding::Helpers::PredictionError)
    end

    it 'increments error count' do
      model.update(domain: :vision, predicted: 0.5, actual: 0.9)
      expect(model.error_count).to eq(1)
    end

    it 'creates a domain model entry' do
      model.update(domain: :vision, predicted: 0.5, actual: 0.9)
      expect(model.domain_count).to eq(1)
    end

    it 'adjusts precision downward on high error' do
      initial = model.precision_for(domain: :vision)
      model.update(domain: :vision, predicted: 0.0, actual: 1.0)
      expect(model.precision_for(domain: :vision)).to be < initial
    end

    it 'adjusts precision upward on zero error' do
      # First update to initialize the domain
      model.update(domain: :vision, predicted: 0.5, actual: 0.5)
      # Second perfect prediction should raise precision
      after_init = model.precision_for(domain: :vision)
      model.update(domain: :vision, predicted: 0.5, actual: 0.5)
      expect(model.precision_for(domain: :vision)).to be >= after_init
    end
  end

  describe '#precision_for' do
    it 'returns DEFAULT_PRECISION for unknown domain' do
      expect(model.precision_for(domain: :unknown)).to eq(constants::DEFAULT_PRECISION)
    end

    it 'returns updated precision after updates' do
      model.update(domain: :motor, predicted: 0.5, actual: 0.5)
      expect(model.precision_for(domain: :motor)).to be_a(Float)
    end
  end

  describe '#free_energy' do
    it 'returns a float' do
      expect(model.free_energy).to be_a(Float)
    end

    it 'increases after surprising errors' do
      initial = model.free_energy
      5.times { model.update(domain: :x, predicted: 0.0, actual: 1.0) }
      expect(model.free_energy).to be > initial
    end
  end

  describe '#free_energy_level' do
    it 'returns a symbol' do
      expect(model.free_energy_level).to be_a(Symbol)
    end

    it 'returns :minimal for a fresh model' do
      expect(model.free_energy_level).to eq(:minimal)
    end
  end

  describe '#active_inference_candidates' do
    it 'returns an empty array for a fresh model' do
      expect(model.active_inference_candidates).to eq([])
    end

    it 'returns domains with high error and low precision' do
      10.times { model.update(domain: :faulty, predicted: 0.0, actual: 1.0) }
      candidates = model.active_inference_candidates
      expect(candidates).to include(:faulty)
    end
  end

  describe '#surprising_errors' do
    it 'returns an empty array when no surprising errors' do
      model.update(domain: :x, predicted: 0.5, actual: 0.5)
      expect(model.surprising_errors).to be_empty
    end

    it 'returns errors above the surprise threshold' do
      model.update(domain: :x, predicted: 0.0, actual: 1.0)
      expect(model.surprising_errors).not_to be_empty
    end
  end

  describe '#decay_all' do
    it 'decreases precision for all known domains' do
      model.update(domain: :vision, predicted: 0.8, actual: 0.9)
      before = model.precision_for(domain: :vision)
      model.decay_all
      expect(model.precision_for(domain: :vision)).to be <= before
    end

    it 'does not drop precision below PRECISION_FLOOR' do
      50.times { model.decay_all }
      model.update(domain: :x, predicted: 0.5, actual: 0.5)
      50.times { model.decay_all }
      expect(model.precision_for(domain: :x)).to be >= constants::PRECISION_FLOOR
    end
  end

  describe '#to_h' do
    it 'returns a summary hash' do
      h = model.to_h
      expect(h[:model_id]).to eq(model.model_id)
      expect(h[:domain_count]).to be_a(Integer)
      expect(h[:error_count]).to be_a(Integer)
      expect(h[:free_energy]).to be_a(Float)
      expect(h[:free_energy_level]).to be_a(Symbol)
      expect(h[:domains]).to be_an(Array)
    end

    it 'includes domain stats after updates' do
      model.update(domain: :vision, predicted: 0.5, actual: 0.7)
      h = model.to_h
      expect(h[:domain_count]).to eq(1)
      vision_stat = h[:domains].find { |d| d[:domain] == :vision }
      expect(vision_stat).not_to be_nil
      expect(vision_stat[:mean]).to be_a(Float)
    end
  end

  describe 'MAX_MODELS eviction' do
    it 'does not exceed MAX_MODELS domains' do
      (constants::MAX_MODELS + 5).times do |i|
        model.update(domain: :"domain_#{i}", predicted: 0.5, actual: 0.5)
      end
      expect(model.domain_count).to be <= constants::MAX_MODELS
    end
  end

  describe 'MAX_ERROR_HISTORY cap' do
    it 'caps error history at MAX_ERROR_HISTORY' do
      (constants::MAX_ERROR_HISTORY + 10).times do
        model.update(domain: :x, predicted: 0.5, actual: 0.5)
      end
      expect(model.error_count).to be <= constants::MAX_ERROR_HISTORY
    end
  end
end
