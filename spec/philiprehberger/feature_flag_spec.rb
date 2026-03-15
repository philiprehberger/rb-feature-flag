# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::FeatureFlag do
  before { described_class.reset! }

  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::FeatureFlag::VERSION).not_to be_nil
    end

    it 'follows semver format' do
      expect(Philiprehberger::FeatureFlag::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '.enabled?' do
    context 'with memory backend' do
      before do
        described_class.configure do |c|
          c.use(:memory)
        end
      end

      it 'returns true for enabled flags' do
        described_class.configuration.backend.set(:dark_mode, true)
        expect(described_class.enabled?(:dark_mode)).to be true
      end

      it 'returns false for disabled flags' do
        described_class.configuration.backend.set(:dark_mode, false)
        expect(described_class.enabled?(:dark_mode)).to be false
      end

      it 'returns false for unknown flags' do
        expect(described_class.enabled?(:unknown)).to be false
      end
    end

    context 'with percentage rollout' do
      before do
        described_class.configure { |c| c.use(:memory) }
        described_class.configuration.backend.set(:gradual, { 'percentage' => 50 })
      end

      it 'returns consistent results for the same user' do
        result = described_class.enabled?(:gradual, user_id: 'user-42')
        expect(described_class.enabled?(:gradual, user_id: 'user-42')).to eq(result)
      end

      it 'returns false without user_id' do
        expect(described_class.enabled?(:gradual)).to be false
      end

      it 'enables for 100 percent rollout' do
        described_class.configuration.backend.set(:all_users, { 'percentage' => 100 })
        expect(described_class.enabled?(:all_users, user_id: 'anyone')).to be true
      end

      it 'disables for 0 percent rollout' do
        described_class.configuration.backend.set(:no_users, { 'percentage' => 0 })
        expect(described_class.enabled?(:no_users, user_id: 'anyone')).to be false
      end
    end
  end

  describe '.variant' do
    before do
      described_class.configure { |c| c.use(:memory) }
      described_class.configuration.backend.set(:button_color, {
                                                  'variants' => %w[red blue green]
                                                })
    end

    it 'returns a variant for a user' do
      result = described_class.variant(:button_color, user_id: 'user-1')
      expect(%w[red blue green]).to include(result)
    end

    it 'returns consistent variant for the same user' do
      first = described_class.variant(:button_color, user_id: 'user-1')
      second = described_class.variant(:button_color, user_id: 'user-1')
      expect(first).to eq(second)
    end

    it 'returns nil for flags without variants' do
      described_class.configuration.backend.set(:simple, true)
      expect(described_class.variant(:simple, user_id: 'user-1')).to be_nil
    end
  end

  describe '.with' do
    before do
      described_class.configure { |c| c.use(:memory) }
      described_class.configuration.backend.set(:feature, false)
    end

    it 'overrides flag value within block' do
      described_class.with(:feature, true) do
        expect(described_class.enabled?(:feature)).to be true
      end
    end

    it 'restores original value after block' do
      described_class.with(:feature, true) { nil }
      expect(described_class.enabled?(:feature)).to be false
    end
  end

  describe 'ENV backend' do
    before do
      described_class.configure { |c| c.use(:env) }
    end

    it 'reads from environment variables' do
      allow(ENV).to receive(:fetch).with('FEATURE_DARK_MODE', nil).and_return('true')
      expect(described_class.enabled?(:dark_mode)).to be true
    end

    it 'returns false for unset variables' do
      allow(ENV).to receive(:fetch).with('FEATURE_MISSING', nil).and_return(nil)
      expect(described_class.enabled?(:missing)).to be false
    end
  end
end
