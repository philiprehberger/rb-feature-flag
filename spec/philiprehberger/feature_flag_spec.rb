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

  describe 'flag dependencies' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'enables flag when dependency is met' do
      described_class.configuration.backend.set(:beta_users, true)
      described_class.configuration.backend.set(:new_ui, true)
      described_class.depends_on(:new_ui, requires: :beta_users)
      expect(described_class.enabled?(:new_ui)).to be true
    end

    it 'disables flag when dependency is not met' do
      described_class.configuration.backend.set(:beta_users, false)
      described_class.configuration.backend.set(:new_ui, true)
      described_class.depends_on(:new_ui, requires: :beta_users)
      expect(described_class.enabled?(:new_ui)).to be false
    end

    it 'disables flag when dependency is missing' do
      described_class.configuration.backend.set(:new_ui, true)
      described_class.depends_on(:new_ui, requires: :beta_users)
      expect(described_class.enabled?(:new_ui)).to be false
    end

    it 'supports chained dependencies' do
      described_class.configuration.backend.set(:alpha, true)
      described_class.configuration.backend.set(:beta, true)
      described_class.configuration.backend.set(:gamma, true)
      described_class.depends_on(:gamma, requires: :beta)
      described_class.depends_on(:beta, requires: :alpha)
      expect(described_class.enabled?(:gamma)).to be true
    end

    it 'fails chained dependencies when root is disabled' do
      described_class.configuration.backend.set(:alpha, false)
      described_class.configuration.backend.set(:beta, true)
      described_class.configuration.backend.set(:gamma, true)
      described_class.depends_on(:gamma, requires: :beta)
      described_class.depends_on(:beta, requires: :alpha)
      expect(described_class.enabled?(:gamma)).to be false
    end

    it 'works without any dependencies set' do
      described_class.configuration.backend.set(:standalone, true)
      expect(described_class.enabled?(:standalone)).to be true
    end
  end

  describe 'scheduled enable/disable' do
    before do
      described_class.configure { |c| c.use(:memory) }
      described_class.configuration.backend.set(:holiday_banner, true)
    end

    it 'enables flag within the scheduled window' do
      described_class.schedule(:holiday_banner,
                               enable_at: Time.now - 3600,
                               disable_at: Time.now + 3600)
      expect(described_class.enabled?(:holiday_banner)).to be true
    end

    it 'disables flag before the enable_at time' do
      described_class.schedule(:holiday_banner,
                               enable_at: Time.now + 3600,
                               disable_at: Time.now + 7200)
      expect(described_class.enabled?(:holiday_banner)).to be false
    end

    it 'disables flag after the disable_at time' do
      described_class.schedule(:holiday_banner,
                               enable_at: Time.now - 7200,
                               disable_at: Time.now - 3600)
      expect(described_class.enabled?(:holiday_banner)).to be false
    end

    it 'works with only enable_at' do
      described_class.schedule(:holiday_banner,
                               enable_at: Time.now - 3600)
      expect(described_class.enabled?(:holiday_banner)).to be true
    end

    it 'works with only disable_at' do
      described_class.schedule(:holiday_banner,
                               disable_at: Time.now + 3600)
      expect(described_class.enabled?(:holiday_banner)).to be true
    end

    it 'disables when only disable_at is in the past' do
      described_class.schedule(:holiday_banner,
                               disable_at: Time.now - 3600)
      expect(described_class.enabled?(:holiday_banner)).to be false
    end

    it 'works without any schedule set' do
      expect(described_class.enabled?(:holiday_banner)).to be true
    end
  end

  describe 'flag metrics' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'tracks enabled checks' do
      described_class.configuration.backend.set(:feature_x, true)
      3.times { described_class.enabled?(:feature_x) }
      result = described_class.metrics(:feature_x)
      expect(result).to eq({ checks: 3, enabled: 3, disabled: 0 })
    end

    it 'tracks disabled checks' do
      described_class.configuration.backend.set(:feature_x, false)
      2.times { described_class.enabled?(:feature_x) }
      result = described_class.metrics(:feature_x)
      expect(result).to eq({ checks: 2, enabled: 0, disabled: 2 })
    end

    it 'tracks mixed results' do
      described_class.configuration.backend.set(:feature_x, true)
      described_class.enabled?(:feature_x)
      described_class.configuration.backend.set(:feature_x, false)
      described_class.enabled?(:feature_x)
      result = described_class.metrics(:feature_x)
      expect(result).to eq({ checks: 2, enabled: 1, disabled: 1 })
    end

    it 'returns zero metrics for unchecked flags' do
      result = described_class.metrics(:never_checked)
      expect(result).to eq({ checks: 0, enabled: 0, disabled: 0 })
    end

    it 'tracks metrics independently per flag' do
      described_class.configuration.backend.set(:flag_a, true)
      described_class.configuration.backend.set(:flag_b, false)
      described_class.enabled?(:flag_a)
      described_class.enabled?(:flag_b)
      expect(described_class.metrics(:flag_a)[:enabled]).to eq(1)
      expect(described_class.metrics(:flag_b)[:disabled]).to eq(1)
    end

    it 'resets metrics on reset!' do
      described_class.configuration.backend.set(:feature_x, true)
      described_class.enabled?(:feature_x)
      described_class.reset!
      result = described_class.metrics(:feature_x)
      expect(result).to eq({ checks: 0, enabled: 0, disabled: 0 })
    end
  end

  describe 'user targeting' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'enables flag for targeted users' do
      described_class.enable_for(:feature, users: %w[user_1 user_2])
      expect(described_class.enabled?(:feature, user: 'user_1')).to be true
    end

    it 'disables flag for non-targeted users' do
      described_class.enable_for(:feature, users: %w[user_1])
      expect(described_class.enabled?(:feature, user: 'user_3')).to be false
    end

    it 'falls back to backend when no user is provided' do
      described_class.enable_for(:feature, users: %w[user_1])
      described_class.configuration.backend.set(:feature, true)
      expect(described_class.enabled?(:feature)).to be true
    end

    it 'falls back to backend when user is not targeted' do
      described_class.enable_for(:feature, users: %w[user_1])
      described_class.configuration.backend.set(:feature, true)
      expect(described_class.enabled?(:feature, user: 'user_99')).to be true
    end

    it 'enables for targeted user even when backend is disabled' do
      described_class.configuration.backend.set(:feature, false)
      described_class.enable_for(:feature, users: %w[user_1])
      expect(described_class.enabled?(:feature, user: 'user_1')).to be true
    end

    it 'appends users on multiple calls' do
      described_class.enable_for(:feature, users: %w[user_1])
      described_class.enable_for(:feature, users: %w[user_2])
      expect(described_class.enabled?(:feature, user: 'user_1')).to be true
      expect(described_class.enabled?(:feature, user: 'user_2')).to be true
    end

    it 'removes users with disable_for' do
      described_class.enable_for(:feature, users: %w[user_1 user_2])
      described_class.disable_for(:feature, users: %w[user_1])
      expect(described_class.enabled?(:feature, user: 'user_1')).to be false
      expect(described_class.enabled?(:feature, user: 'user_2')).to be true
    end

    it 'does not duplicate users' do
      described_class.enable_for(:feature, users: %w[user_1])
      described_class.enable_for(:feature, users: %w[user_1])
      expect(described_class.targeted_users(:feature)).to eq(%w[user_1])
    end
  end

  describe 'flag groups' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'enables all flags in a group' do
      described_class.group(:beta, %i[feature_a feature_b])
      described_class.enable_group(:beta)
      expect(described_class.enabled?(:feature_a)).to be true
      expect(described_class.enabled?(:feature_b)).to be true
    end

    it 'disables all flags in a group' do
      described_class.configuration.backend.set(:feature_a, true)
      described_class.configuration.backend.set(:feature_b, true)
      described_class.group(:beta, %i[feature_a feature_b])
      described_class.disable_group(:beta)
      expect(described_class.enabled?(:feature_a)).to be false
      expect(described_class.enabled?(:feature_b)).to be false
    end

    it 'returns group flags' do
      described_class.group(:beta, %i[feature_a feature_b])
      expect(described_class.group_flags(:beta)).to eq(%i[feature_a feature_b])
    end

    it 'returns empty array for unknown groups' do
      expect(described_class.group_flags(:unknown)).to eq([])
    end

    it 'does not affect flags outside the group' do
      described_class.configuration.backend.set(:other, true)
      described_class.group(:beta, %i[feature_a])
      described_class.disable_group(:beta)
      expect(described_class.enabled?(:other)).to be true
    end

    it 'overwrites group on redefinition' do
      described_class.group(:beta, %i[feature_a])
      described_class.group(:beta, %i[feature_b])
      expect(described_class.group_flags(:beta)).to eq(%i[feature_b])
    end
  end
end
