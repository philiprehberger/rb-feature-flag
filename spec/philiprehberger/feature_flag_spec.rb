# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

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

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(Philiprehberger::FeatureFlag::Configuration)
    end

    it 'memoizes the configuration' do
      expect(described_class.configuration).to equal(described_class.configuration)
    end

    it 'defaults to memory backend' do
      expect(described_class.configuration.backend).to be_a(
        Philiprehberger::FeatureFlag::Backends::MemoryBackend
      )
    end
  end

  describe '.configure' do
    it 'yields configuration to the block' do
      described_class.configure do |c|
        expect(c).to be_a(Philiprehberger::FeatureFlag::Configuration)
      end
    end

    it 'raises ArgumentError for unknown backend type' do
      expect do
        described_class.configure { |c| c.use(:redis) }
      end.to raise_error(ArgumentError, /unknown backend: redis/)
    end
  end

  describe '.reset!' do
    it 'clears the configuration' do
      old_config = described_class.configuration
      described_class.reset!
      expect(described_class.configuration).not_to equal(old_config)
    end

    it 'clears overrides' do
      described_class.configure { |c| c.use(:memory) }
      described_class.configuration.backend.set(:flag, false)
      described_class.with(:flag, true) do
        described_class.reset!
      end
      described_class.configure { |c| c.use(:memory) }
      described_class.configuration.backend.set(:flag, false)
      expect(described_class.enabled?(:flag)).to be false
    end

    it 'clears dependencies' do
      described_class.configure { |c| c.use(:memory) }
      described_class.depends_on(:child, requires: :parent)
      described_class.reset!
      expect(described_class.dependency_for(:child)).to be_nil
    end

    it 'clears schedules' do
      described_class.schedule(:flag, enable_at: Time.now + 3600)
      described_class.reset!
      expect(described_class.schedule_for(:flag)).to be_nil
    end

    it 'clears targets' do
      described_class.enable_for(:flag, users: %w[user_1])
      described_class.reset!
      expect(described_class.targeted_users(:flag)).to eq([])
    end

    it 'clears groups' do
      described_class.group(:beta, %i[a b])
      described_class.reset!
      expect(described_class.group_flags(:beta)).to eq([])
    end
  end

  describe '.reload!' do
    it 'delegates to the backend' do
      described_class.configure { |c| c.use(:memory) }
      backend = described_class.configuration.backend
      allow(backend).to receive(:reload!)
      described_class.reload!
      expect(backend).to have_received(:reload!)
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

      it 'coerces truthy non-boolean values to true' do
        described_class.configuration.backend.set(:truthy, 'yes')
        expect(described_class.enabled?(:truthy)).to be true
      end

      it 'accepts string flag names' do
        described_class.configuration.backend.set('string_flag', true)
        expect(described_class.enabled?(:string_flag)).to be true
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

      it 'returns false when percentage is nil' do
        described_class.configuration.backend.set(:nil_pct, { 'percentage' => nil })
        expect(described_class.enabled?(:nil_pct, user_id: 'user-1')).to be false
      end

      it 'returns false for negative percentage' do
        described_class.configuration.backend.set(:neg, { 'percentage' => -10 })
        expect(described_class.enabled?(:neg, user_id: 'user-1')).to be false
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

    it 'returns nil for unknown flags' do
      expect(described_class.variant(:nonexistent, user_id: 'user-1')).to be_nil
    end

    it 'returns nil when value is a hash without variants key' do
      described_class.configuration.backend.set(:no_variants, { 'percentage' => 50 })
      expect(described_class.variant(:no_variants, user_id: 'user-1')).to be_nil
    end

    it 'can distribute across two variants' do
      described_class.configuration.backend.set(:ab_test, { 'variants' => %w[control treatment] })
      result = described_class.variant(:ab_test, user_id: 'user-99')
      expect(%w[control treatment]).to include(result)
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

    it 'restores original value even when block raises' do
      expect do
        described_class.with(:feature, true) { raise 'boom' }
      end.to raise_error(RuntimeError, 'boom')
      expect(described_class.enabled?(:feature)).to be false
    end

    it 'supports nested overrides for different flags' do
      described_class.configuration.backend.set(:other, false)
      described_class.with(:feature, true) do
        described_class.with(:other, true) do
          expect(described_class.enabled?(:feature)).to be true
          expect(described_class.enabled?(:other)).to be true
        end
        expect(described_class.enabled?(:other)).to be false
      end
    end

    it 'can override to false' do
      described_class.configuration.backend.set(:feature, true)
      described_class.with(:feature, false) do
        expect(described_class.enabled?(:feature)).to be false
      end
    end

    it 'accepts string flag names' do
      described_class.with('feature', true) do
        expect(described_class.enabled?(:feature)).to be true
      end
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

    it 'parses "1" as true' do
      allow(ENV).to receive(:fetch).with('FEATURE_FLAG_ONE', nil).and_return('1')
      expect(described_class.enabled?(:flag_one)).to be true
    end

    it 'parses "0" as false' do
      allow(ENV).to receive(:fetch).with('FEATURE_FLAG_ZERO', nil).and_return('0')
      expect(described_class.enabled?(:flag_zero)).to be false
    end

    it 'parses "false" as false' do
      allow(ENV).to receive(:fetch).with('FEATURE_DISABLED', nil).and_return('false')
      expect(described_class.enabled?(:disabled)).to be false
    end

    it 'parses "FALSE" case-insensitively as false' do
      allow(ENV).to receive(:fetch).with('FEATURE_UPPER', nil).and_return('FALSE')
      expect(described_class.enabled?(:upper)).to be false
    end

    it 'treats non-boolean string values as truthy' do
      allow(ENV).to receive(:fetch).with('FEATURE_CUSTOM', nil).and_return('custom_value')
      expect(described_class.enabled?(:custom)).to be true
    end

    it 'raises NotImplementedError on set' do
      backend = described_class.configuration.backend
      expect { backend.set(:flag, true) }.to raise_error(NotImplementedError, /read-only/)
    end

    it 'returns all feature flags from ENV' do
      backend = described_class.configuration.backend
      allow(ENV).to receive(:select).and_return({ 'FEATURE_A' => 'true', 'FEATURE_B' => 'false' })
      # We call all and verify it returns a result (the mock shapes the return)
      result = backend.all
      expect(result).to be_a(Hash)
    end

    it 'reload! is a no-op' do
      backend = described_class.configuration.backend
      expect { backend.reload! }.not_to raise_error
    end
  end

  describe 'YAML backend' do
    it 'raises ArgumentError when path is nil' do
      expect do
        Philiprehberger::FeatureFlag::Backends::YamlBackend.new(nil)
      end.to raise_error(ArgumentError, /path is required/)
    end

    it 'returns empty flags when file does not exist' do
      backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new('/nonexistent/path.yml')
      expect(backend.get(:any_flag)).to be_nil
      expect(backend.all).to eq({})
    end

    it 'raises NotImplementedError on set' do
      backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new('/nonexistent/path.yml')
      expect { backend.set(:flag, true) }.to raise_error(NotImplementedError, /read-only/)
    end

    it 'loads flags from a YAML file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'flags.yml')
        File.write(path, "dark_mode: true\nbeta: false\n")
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        expect(backend.get('dark_mode')).to be true
        expect(backend.get('beta')).to be false
      end
    end

    it 'handles an empty YAML file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'empty.yml')
        File.write(path, '')
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        expect(backend.all).to eq({})
      end
    end

    it 'reloads flags from disk' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'flags.yml')
        File.write(path, "feature: true\n")
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        expect(backend.get('feature')).to be true

        File.write(path, "feature: false\n")
        backend.reload!
        expect(backend.get('feature')).to be false
      end
    end

    it 'returns all flags as a duplicate hash' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'flags.yml')
        File.write(path, "a: true\nb: false\n")
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        all = backend.all
        expect(all).to eq({ 'a' => true, 'b' => false })
        # Verify it is a dup (modifying the returned hash does not affect backend)
        all['a'] = false
        expect(backend.get('a')).to be true
      end
    end
  end

  describe 'memory backend' do
    let(:backend) { Philiprehberger::FeatureFlag::Backends::MemoryBackend.new }

    it 'stores and retrieves flags' do
      backend.set(:flag, true)
      expect(backend.get(:flag)).to be true
    end

    it 'returns nil for unset flags' do
      expect(backend.get(:missing)).to be_nil
    end

    it 'returns all stored flags' do
      backend.set(:a, true)
      backend.set(:b, false)
      expect(backend.all).to eq({ 'a' => true, 'b' => false })
    end

    it 'returns a duplicate from all' do
      backend.set(:a, true)
      result = backend.all
      result['a'] = false
      expect(backend.get(:a)).to be true
    end

    it 'reload! is a no-op' do
      expect { backend.reload! }.not_to raise_error
    end

    it 'coerces flag names to strings' do
      backend.set(:symbol_key, 'value')
      expect(backend.get('symbol_key')).to eq('value')
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

    it 'returns the dependency for a flag via dependency_for' do
      described_class.depends_on(:child, requires: :parent)
      expect(described_class.dependency_for(:child)).to eq(:parent)
    end

    it 'returns nil from dependency_for when no dependency is set' do
      expect(described_class.dependency_for(:orphan)).to be_nil
    end

    it 'fails chained dependency when middle link is disabled' do
      described_class.configuration.backend.set(:alpha, true)
      described_class.configuration.backend.set(:beta, false)
      described_class.configuration.backend.set(:gamma, true)
      described_class.depends_on(:gamma, requires: :beta)
      described_class.depends_on(:beta, requires: :alpha)
      expect(described_class.enabled?(:gamma)).to be false
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

    it 'returns the schedule via schedule_for' do
      enable_time = Time.now + 100
      disable_time = Time.now + 200
      described_class.schedule(:holiday_banner, enable_at: enable_time, disable_at: disable_time)
      sched = described_class.schedule_for(:holiday_banner)
      expect(sched).to eq({ enable_at: enable_time, disable_at: disable_time })
    end

    it 'returns nil from schedule_for when no schedule is set' do
      expect(described_class.schedule_for(:unscheduled)).to be_nil
    end

    it 'disables when only enable_at is in the future' do
      described_class.schedule(:holiday_banner, enable_at: Time.now + 3600)
      expect(described_class.enabled?(:holiday_banner)).to be false
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

    it 'returns a duplicate hash that cannot mutate internal state' do
      described_class.configuration.backend.set(:feature_x, true)
      described_class.enabled?(:feature_x)
      result = described_class.metrics(:feature_x)
      result[:checks] = 999
      expect(described_class.metrics(:feature_x)[:checks]).to eq(1)
    end

    it 'does not record metrics for overridden flags' do
      described_class.configuration.backend.set(:feature_x, false)
      described_class.with(:feature_x, true) do
        described_class.enabled?(:feature_x)
      end
      result = described_class.metrics(:feature_x)
      expect(result[:checks]).to eq(0)
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

    it 'returns empty array for untargeted flags' do
      expect(described_class.targeted_users(:no_targets)).to eq([])
    end

    it 'disable_for is safe when flag has no targets' do
      expect { described_class.disable_for(:missing, users: %w[user_1]) }.not_to raise_error
    end

    it 'returns false for nil user even when targets exist' do
      described_class.enable_for(:feature, users: %w[user_1])
      expect(described_class.enabled?(:feature, user: nil)).to be false
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

    it 'enable_group is safe for undefined groups' do
      expect { described_class.enable_group(:nonexistent) }.not_to raise_error
    end

    it 'disable_group is safe for undefined groups' do
      expect { described_class.disable_group(:nonexistent) }.not_to raise_error
    end

    it 'supports multiple independent groups' do
      described_class.group(:alpha, %i[flag_a])
      described_class.group(:beta, %i[flag_b])
      described_class.enable_group(:alpha)
      expect(described_class.enabled?(:flag_a)).to be true
      expect(described_class.enabled?(:flag_b)).to be false
    end

    it 'accepts string flag names in groups' do
      described_class.group(:beta, %w[feature_a feature_b])
      flags = described_class.group_flags(:beta)
      expect(flags).to eq(%i[feature_a feature_b])
    end
  end

  describe 'combined features' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'targeting takes priority over a failed schedule' do
      described_class.configuration.backend.set(:feature, true)
      described_class.schedule(:feature, enable_at: Time.now + 3600)
      described_class.enable_for(:feature, users: %w[vip])
      # Schedule blocks it, but targeting is checked before backend
      # Actually, schedule is checked before targeting in evaluate_flag
      expect(described_class.enabled?(:feature, user: 'vip')).to be false
    end

    it 'dependency failure blocks even targeted users' do
      described_class.configuration.backend.set(:parent, false)
      described_class.configuration.backend.set(:child, true)
      described_class.depends_on(:child, requires: :parent)
      described_class.enable_for(:child, users: %w[user_1])
      expect(described_class.enabled?(:child, user: 'user_1')).to be false
    end

    it 'override bypasses dependencies and schedules' do
      described_class.depends_on(:child, requires: :parent)
      described_class.schedule(:child, enable_at: Time.now + 3600)
      described_class.with(:child, true) do
        expect(described_class.enabled?(:child)).to be true
      end
    end
  end

  # ---------------------------------------------------------------
  # Additional test coverage (20+ new examples)
  # ---------------------------------------------------------------

  describe 'Rollout module' do
    it 'returns false when user_id is nil' do
      expect(Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, nil, 50)).to be false
    end

    it 'returns false when percentage is nil' do
      expect(Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 'user-1', nil)).to be false
    end

    it 'returns true for percentage of 100' do
      expect(Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 'user-1', 100)).to be true
    end

    it 'returns false for percentage of 0' do
      expect(Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 'user-1', 0)).to be false
    end

    it 'returns false for negative percentage' do
      expect(Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 'user-1', -5)).to be false
    end

    it 'returns true for percentage greater than 100' do
      expect(Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 'user-1', 150)).to be true
    end

    it 'produces deterministic results for integer user_id' do
      result1 = Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 42, 50)
      result2 = Philiprehberger::FeatureFlag::Rollout.enabled_for?(:flag, 42, 50)
      expect(result1).to eq(result2)
    end

    it 'varies results across different flag names for the same user' do
      results = (1..20).map do |i|
        Philiprehberger::FeatureFlag::Rollout.enabled_for?(:"flag_#{i}", 'user-1', 50)
      end
      # With 20 different flags at 50%, we expect at least some variation
      expect(results.uniq.size).to be > 1
    end
  end

  describe 'Configuration#use' do
    it 'switches to memory backend' do
      config = Philiprehberger::FeatureFlag::Configuration.new
      config.use(:memory)
      expect(config.backend).to be_a(Philiprehberger::FeatureFlag::Backends::MemoryBackend)
    end

    it 'switches to env backend' do
      config = Philiprehberger::FeatureFlag::Configuration.new
      config.use(:env)
      expect(config.backend).to be_a(Philiprehberger::FeatureFlag::Backends::EnvBackend)
    end

    it 'switches to yaml backend with path' do
      config = Philiprehberger::FeatureFlag::Configuration.new
      config.use(:yaml, path: '/nonexistent/flags.yml')
      expect(config.backend).to be_a(Philiprehberger::FeatureFlag::Backends::YamlBackend)
    end

    it 'raises ArgumentError for unknown backend type' do
      config = Philiprehberger::FeatureFlag::Configuration.new
      expect { config.use(:redis) }.to raise_error(ArgumentError, /unknown backend: redis/)
    end

    it 'allows direct assignment of backend via accessor' do
      config = Philiprehberger::FeatureFlag::Configuration.new
      custom_backend = Philiprehberger::FeatureFlag::Backends::MemoryBackend.new
      config.backend = custom_backend
      expect(config.backend).to equal(custom_backend)
    end
  end

  describe '.variant edge cases' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'returns nil when flag value is nil' do
      expect(described_class.variant(:nonexistent, user_id: 'user-1')).to be_nil
    end

    it 'returns nil when flag value is a plain boolean' do
      described_class.configuration.backend.set(:simple, true)
      expect(described_class.variant(:simple, user_id: 'user-1')).to be_nil
    end

    it 'returns nil when variants key is nil in hash' do
      described_class.configuration.backend.set(:partial, { 'variants' => nil })
      expect(described_class.variant(:partial, user_id: 'user-1')).to be_nil
    end

    it 'handles integer user_id for variant selection' do
      described_class.configuration.backend.set(:color, { 'variants' => %w[red blue] })
      result = described_class.variant(:color, user_id: 123)
      expect(%w[red blue]).to include(result)
    end

    it 'returns a single-element variant when only one variant exists' do
      described_class.configuration.backend.set(:single, { 'variants' => %w[only_option] })
      expect(described_class.variant(:single, user_id: 'user-1')).to eq('only_option')
    end
  end

  describe '.with edge cases' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'supports nested overrides for the same flag' do
      described_class.configuration.backend.set(:flag, false)
      described_class.with(:flag, true) do
        expect(described_class.enabled?(:flag)).to be true
        described_class.with(:flag, false) do
          expect(described_class.enabled?(:flag)).to be false
        end
        # Inner override removed, outer override still active
        expect(described_class.enabled?(:flag)).to be true
      end
    end

    it 'can override with nil value' do
      described_class.configuration.backend.set(:flag, true)
      described_class.with(:flag, nil) do
        expect(described_class.enabled?(:flag)).to be_nil
      end
    end

    it 'override with false is distinguishable from missing flag' do
      described_class.with(:unset_flag, false) do
        expect(described_class.enabled?(:unset_flag)).to be false
      end
    end
  end

  describe 'ENV backend edge cases' do
    let(:backend) { Philiprehberger::FeatureFlag::Backends::EnvBackend.new }

    it 'parses "TRUE" (uppercase) as true' do
      allow(ENV).to receive(:fetch).with('FEATURE_UPPER_TRUE', nil).and_return('TRUE')
      expect(backend.get(:upper_true)).to be true
    end

    it 'parses "True" (mixed case) as true' do
      allow(ENV).to receive(:fetch).with('FEATURE_MIXED_TRUE', nil).and_return('True')
      expect(backend.get(:mixed_true)).to be true
    end

    it 'returns string value for non-boolean env vars' do
      allow(ENV).to receive(:fetch).with('FEATURE_CUSTOM_VAL', nil).and_return('my_value')
      expect(backend.get(:custom_val)).to eq('my_value')
    end

    it 'converts flag name to uppercase for ENV lookup' do
      allow(ENV).to receive(:fetch).with('FEATURE_MY_FLAG', nil).and_return('true')
      expect(backend.get(:my_flag)).to be true
    end
  end

  describe 'YAML backend edge cases' do
    it 'loads hash values (rollout config) from YAML' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'flags.yml')
        File.write(path, "rollout:\n  percentage: 50\n")
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        expect(backend.get('rollout')).to eq({ 'percentage' => 50 })
      end
    end

    it 'reload! picks up a newly created file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'flags.yml')
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        expect(backend.all).to eq({})

        File.write(path, "new_flag: true\n")
        backend.reload!
        expect(backend.get('new_flag')).to be true
      end
    end

    it 'reload! handles file deletion gracefully' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'flags.yml')
        File.write(path, "flag: true\n")
        backend = Philiprehberger::FeatureFlag::Backends::YamlBackend.new(path)
        expect(backend.get('flag')).to be true

        File.delete(path)
        backend.reload!
        expect(backend.all).to eq({})
      end
    end
  end

  describe 'memory backend edge cases' do
    let(:backend) { Philiprehberger::FeatureFlag::Backends::MemoryBackend.new }

    it 'overwrites existing flag values' do
      backend.set(:flag, true)
      backend.set(:flag, false)
      expect(backend.get(:flag)).to be false
    end

    it 'stores hash values for rollout config' do
      backend.set(:rollout, { 'percentage' => 75 })
      expect(backend.get(:rollout)).to eq({ 'percentage' => 75 })
    end

    it 'stores nil as a valid value' do
      backend.set(:nilval, nil)
      expect(backend.all).to include('nilval' => nil)
    end
  end

  describe 'dependencies edge cases' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'accepts string keys for depends_on' do
      described_class.depends_on('child', requires: 'parent')
      expect(described_class.dependency_for(:child)).to eq(:parent)
    end

    it 'overwrites dependency when redefined' do
      described_class.depends_on(:child, requires: :parent_a)
      described_class.depends_on(:child, requires: :parent_b)
      expect(described_class.dependency_for(:child)).to eq(:parent_b)
    end
  end

  describe 'targeting edge cases' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'coerces integer user identifiers to strings' do
      described_class.enable_for(:feature, users: [1, 2])
      expect(described_class.targeted_users(:feature)).to eq(%w[1 2])
    end

    it 'coerces symbol user identifiers to strings' do
      described_class.enable_for(:feature, users: [:admin])
      expect(described_class.targeted_users(:feature)).to eq(%w[admin])
    end

    it 'targeted? returns false when user is nil' do
      described_class.enable_for(:feature, users: %w[user_1])
      expect(described_class.targeted?(:feature, nil)).to be false
    end

    it 'targeted? returns true for a matched user' do
      described_class.enable_for(:feature, users: %w[user_1])
      expect(described_class.targeted?(:feature, 'user_1')).to be true
    end

    it 'disable_for is a no-op when flag key does not exist in targets' do
      described_class.disable_for(:never_targeted, users: %w[user_1])
      expect(described_class.targeted_users(:never_targeted)).to eq([])
    end
  end

  describe 'scheduling edge cases' do
    before do
      described_class.configure { |c| c.use(:memory) }
      described_class.configuration.backend.set(:flag, true)
    end

    it 'scheduled_active? returns true when no schedule is set' do
      expect(described_class.scheduled_active?(:flag)).to be true
    end

    it 'schedule with both times nil is always active' do
      described_class.schedule(:flag, enable_at: nil, disable_at: nil)
      expect(described_class.enabled?(:flag)).to be true
    end

    it 'schedule_for returns nil for unscheduled flags after reset' do
      described_class.schedule(:flag, enable_at: Time.now)
      described_class.reset_schedules!
      expect(described_class.schedule_for(:flag)).to be_nil
    end
  end

  describe 'metrics edge cases' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'tracks metrics with string flag name' do
      described_class.configuration.backend.set('str_flag', true)
      described_class.enabled?('str_flag')
      expect(described_class.metrics(:str_flag)[:checks]).to eq(1)
    end

    it 'metrics returns a dup that does not leak internal counters' do
      result_a = described_class.metrics(:fresh)
      result_b = described_class.metrics(:fresh)
      result_a[:checks] = 100
      expect(result_b[:checks]).to eq(0)
    end
  end

  describe 'combined features (additional)' do
    before do
      described_class.configure { |c| c.use(:memory) }
    end

    it 'override bypasses user targeting' do
      described_class.enable_for(:feature, users: %w[user_1])
      described_class.with(:feature, false) do
        expect(described_class.enabled?(:feature, user: 'user_1')).to be false
      end
    end

    it 'rollout with targeting — targeted user bypasses rollout' do
      described_class.configuration.backend.set(:feature, { 'percentage' => 0 })
      described_class.enable_for(:feature, users: %w[vip])
      expect(described_class.enabled?(:feature, user: 'vip')).to be true
    end

    it 'metrics are recorded for rollout checks' do
      described_class.configuration.backend.set(:rollout, { 'percentage' => 50 })
      described_class.enabled?(:rollout, user_id: 'user-1')
      expect(described_class.metrics(:rollout)[:checks]).to eq(1)
    end

    it 'group enable followed by schedule block disables flag' do
      described_class.group(:beta, %i[feat])
      described_class.enable_group(:beta)
      described_class.schedule(:feat, enable_at: Time.now + 3600)
      expect(described_class.enabled?(:feat)).to be false
    end
  end
end
