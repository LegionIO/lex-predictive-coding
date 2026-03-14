# frozen_string_literal: true

RSpec.describe Legion::Extensions::PredictiveCoding::Helpers::PredictionError do
  let(:constants) { Legion::Extensions::PredictiveCoding::Helpers::Constants }

  describe '#initialize' do
    it 'stores domain, predicted, actual' do
      error = described_class.new(domain: :vision, predicted: 0.8, actual: 0.9)
      expect(error.domain).to eq(:vision)
      expect(error.predicted).to eq(0.8)
      expect(error.actual).to eq(0.9)
    end

    it 'stores a timestamp' do
      error = described_class.new(domain: :vision, predicted: 0.5, actual: 0.5)
      expect(error.timestamp).to be_a(Time)
    end

    it 'uses DEFAULT_PRECISION when none provided' do
      error = described_class.new(domain: :vision, predicted: 0.5, actual: 0.5)
      expect(error.precision).to eq(constants::DEFAULT_PRECISION)
    end

    it 'accepts explicit precision' do
      error = described_class.new(domain: :vision, predicted: 0.5, actual: 0.5, precision: 0.9)
      expect(error.precision).to eq(0.9)
    end
  end

  describe '#error_magnitude' do
    it 'computes absolute difference for numeric values' do
      error = described_class.new(domain: :x, predicted: 0.3, actual: 0.8)
      expect(error.error_magnitude).to be_within(0.001).of(0.5)
    end

    it 'clamps error magnitude to 1.0 for values differing by more than 1' do
      error = described_class.new(domain: :x, predicted: 0.0, actual: 2.0)
      expect(error.error_magnitude).to eq(1.0)
    end

    it 'returns 0.0 when predicted equals actual for numeric values' do
      error = described_class.new(domain: :x, predicted: 0.5, actual: 0.5)
      expect(error.error_magnitude).to eq(0.0)
    end

    it 'returns 0.0 when predicted equals actual for non-numeric values' do
      error = described_class.new(domain: :x, predicted: :foo, actual: :foo)
      expect(error.error_magnitude).to eq(0.0)
    end

    it 'returns 1.0 when non-numeric predicted differs from actual' do
      error = described_class.new(domain: :x, predicted: :foo, actual: :bar)
      expect(error.error_magnitude).to eq(1.0)
    end
  end

  describe '#weighted_error' do
    it 'equals error_magnitude * precision' do
      error = described_class.new(domain: :x, predicted: 0.2, actual: 0.6, precision: 0.8)
      expected = (0.6 - 0.2).abs * 0.8
      expect(error.weighted_error).to be_within(0.001).of(expected)
    end
  end

  describe '#surprising?' do
    it 'returns true when error_magnitude >= SURPRISE_THRESHOLD' do
      error = described_class.new(domain: :x, predicted: 0.0, actual: 1.0)
      expect(error.surprising?).to be true
    end

    it 'returns false when error_magnitude < SURPRISE_THRESHOLD' do
      error = described_class.new(domain: :x, predicted: 0.5, actual: 0.55)
      expect(error.surprising?).to be false
    end
  end

  describe '#level' do
    it 'returns :negligible for very small errors' do
      error = described_class.new(domain: :x, predicted: 0.5, actual: 0.505)
      expect(error.level).to eq(:negligible)
    end

    it 'returns :surprising for large errors' do
      error = described_class.new(domain: :x, predicted: 0.0, actual: 1.0)
      expect(error.level).to eq(:surprising)
    end

    it 'returns :moderate for mid-range errors' do
      error = described_class.new(domain: :x, predicted: 0.0, actual: 0.4)
      expect(error.level).to eq(:moderate)
    end
  end

  describe '#to_h' do
    it 'returns a hash with all fields' do
      error = described_class.new(domain: :vision, predicted: 0.3, actual: 0.7, precision: 0.6)
      h = error.to_h
      expect(h[:domain]).to eq(:vision)
      expect(h[:predicted]).to eq(0.3)
      expect(h[:actual]).to eq(0.7)
      expect(h[:error_magnitude]).to be_a(Float)
      expect(h[:precision]).to eq(0.6)
      expect(h[:weighted_error]).to be_a(Float)
      expect(h[:surprising]).to be(true).or be(false)
      expect(h[:level]).to be_a(Symbol)
      expect(h[:timestamp]).to be_a(Time)
    end
  end
end
