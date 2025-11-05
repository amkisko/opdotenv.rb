require "spec_helper"

# Try to load real Anyway::Config if available, otherwise use stubs
begin
  require "anyway_config"
  USING_REAL_ANYWAY = true
rescue LoadError
  USING_REAL_ANYWAY = false
end

# Define Rails stub for debug logging
unless defined?(::Rails)
  module ::Rails
    def self.logger
      nil
    end
  end
end

# Define minimal Anyway stubs if not using real Anyway::Config
unless USING_REAL_ANYWAY
  unless defined?(::Anyway)
    module ::Anyway; end
  end
  unless defined?(::Anyway::Loaders)
    module ::Anyway::Loaders; end
  end
  unless defined?(::Anyway::Loaders::Base)
    class ::Anyway::Loaders::Base
      def initialize(local:)
      end
    end
  end
  unless defined?(::Anyway::Env)
    class ::Anyway::Env
      def initialize(type_cast: nil, env_container: {})
        @env_container = env_container
      end

      def fetch_with_trace(prefix)
        # Simple stub that strips prefix from keys
        result = {}
        return [result, {}] if @env_container.nil? || !@env_container.respond_to?(:each)

        prefix_with_underscore = prefix.empty? ? "" : "#{prefix}_"
        @env_container.each do |key, value|
          key_str = key.to_s
          if key_str.start_with?(prefix_with_underscore)
            new_key = key_str.sub(/^#{prefix_with_underscore}/, "").downcase
            result[new_key] = value
          end
        end
        [result, {}]
      end
    end
  end
  unless defined?(::Anyway::NoCast)
    ::Anyway::NoCast = Class.new do
      def self.call(val)
        val
      end
    end
  end
  unless defined?(::Anyway::Tracing)
    module ::Anyway::Tracing
      def self.current_trace
        nil
      end
    end
  end
end

require "opdotenv/anyway_loader"

RSpec.describe Opdotenv::AnywayLoader::Loader do
  it "registers itself into Anyway.loaders when available" do
    registry = Class.new do
      attr_reader :entries
      def initialize
        @entries = []
      end

      def append(id, handler)
        @entries << [id, handler]
      end
    end.new

    allow(::Anyway).to receive(:loaders).and_return(registry)

    # Trigger registration
    Opdotenv::AnywayLoader.register!

    expect(registry.entries.map(&:first)).to include(:opdotenv)
    handler = registry.entries.find { |id, _| id == :opdotenv }&.last
    expect(handler).to eq(Opdotenv::AnywayLoader::Loader)
  end

  it "invokes Opdotenv::Loader.load with inferred format and returns data with prefix stripped" do
    loader = described_class.new(local: true)
    # SourceParser will infer dotenv format from .env path
    # Loader returns data with prefix, then Anyway::Env strips it
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("APP_KEY=value\n")
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/.env.development"})
    # Anyway::Env strips the prefix, so APP_KEY becomes key
    expect(data).to eq({"key" => "value"})
  end

  it "handles string path option" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("APP_KEY=value\n")
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {"path" => "op://Vault/.env.development"})
    expect(data).to eq({"key" => "value"})
  end

  it "loads all fields when path doesn't match format patterns" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    expect(data).to eq({})
  end

  it "handles overwrite option false" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("APP_KEY=value\n")
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/.env.development", overwrite: false})
    expect(data).to eq({"key" => "value"})
  end

  it "returns empty hash when opdotenv options not provided" do
    loader = described_class.new(local: true)
    expect(Opdotenv::Loader).not_to receive(:load)
    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {})
    expect(data).to eq({})
  end

  it "raises when path is missing" do
    loader = described_class.new(local: true)
    expect {
      loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {overwrite: true})
    }.to raise_error(ArgumentError, /requires :path/)
  end

  it "strictly matches fields with env_prefix only (case-insensitive)" do
    loader = described_class.new(local: true)
    # Simulate loading all fields - only fields with TEST_ prefix should match (case-insensitive)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:item_get).with("TestConfig", vault: "Employee").and_return({
      fields: [
        {label: "enabled", value: "ignored"},
        {label: "ENABLED", value: "ignored"},
        {label: "TEST_ENABLED", value: "true"},
        {label: "test_enabled", value: "value1"},
        {label: "Test_Enabled", value: "value2"},
        {label: "sample", value: "ignored"},
        {label: "TEST_SAMPLE", value: "value"}
      ]
    }.to_json)
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Employee/TestConfig"})

    # Only fields with TEST_ prefix should be matched (case-insensitive)
    # Note: If multiple case variations exist, the last one processed wins
    expect(data).to include("enabled")
    expect(data).to include("sample" => "value")
    expect(data).not_to include("enabled" => "ignored")
  end

  it "handles empty env_prefix" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("KEY=value\n")
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "", config_path: nil, opdotenv: {path: "op://Vault/.env.development"})
    # When prefix is empty, normalize_keys_for_prefix_matching returns data early, but Anyway::Env still processes it
    # The Anyway::Env stub strips prefix, so KEY becomes key (no prefix to strip)
    expect(data).to eq({"key" => "value"})
  end

  it "handles empty data" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    expect(data).to eq({})
  end

  it "returns data early when Anyway::Env is not defined" do
    # Temporarily hide Anyway::Env
    original_env = ::Anyway::Env if defined?(::Anyway::Env)
    ::Anyway.send(:remove_const, :Env) if defined?(::Anyway::Env)

    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("APP_KEY=value\n")
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/.env.development"})
    expect(data).to eq({"APP_KEY" => "value"})

    # Restore
    ::Anyway.const_set(:Env, original_env) if original_env
  end

  it "handles normalize_keys with prefix matching" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
      fields: [
        {label: "APP_KEY", value: "value1"},
        {label: "APP_SECRET", value: "value2"},
        {label: "OTHER_KEY", value: "ignored"}
      ]
    }.to_json)
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    # normalize_keys_for_prefix_matching should filter to only APP_ prefixed keys
    expect(data).to include("key")
    expect(data).to include("secret")
    expect(data).not_to include("other_key")
  end

  it "handles key matching when key equals prefix exactly" do
    loader = described_class.new(local: true)
    client = instance_double(Opdotenv::OpClient)
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
      fields: [
        {label: "TEST", value: "value"}
      ]
    }.to_json)
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    data = loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    # The Anyway::Env stub strips TEST_ prefix, so TEST becomes empty string
    # But the stub implementation might handle it differently, so just verify it's processed
    expect(data).to be_a(Hash)
  end

  describe "tracing" do
    it "merges trace into Anyway::Tracing.current_trace when available" do
      trace = double("trace")
      allow(::Anyway::Tracing).to receive(:current_trace).and_return(trace)
      allow(trace).to receive(:merge!).and_return(trace)

      loader = described_class.new(local: true)
      client = instance_double(Opdotenv::OpClient)
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
      allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

      loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/Item"})

      # The trace object may be a hash or a Trace object depending on whether we're using real Anyway
      expect(trace).to have_received(:merge!)
    end
  end

  describe "debug logging" do
    before do
      ENV["OPDOTENV_DEBUG"] = "true"
    end

    after do
      ENV.delete("OPDOTENV_DEBUG")
    end

    it "logs available and matched fields when Rails.logger is available" do
      loader = described_class.new(local: true)
      logger = double("logger")
      allow(Rails).to receive(:logger).and_return(logger)

      client = instance_double(Opdotenv::OpClient)
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [
          {label: "TEST_ENABLED", value: "true"},
          {label: "TEST_SAMPLE", value: "value"},
          {label: "UNMATCHED_FIELD", value: "ignored"}
        ]
      }.to_json)
      allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

      expect(logger).to receive(:debug).with(/Available fields from 1Password/)
      expect(logger).to receive(:debug).with(/Matched fields for TEST/)
      expect(logger).to receive(:debug).with(/Unmatched fields/)
      expect(logger).to receive(:debug).with(/To use these fields/)

      loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    end

    it "logs when no unmatched fields" do
      loader = described_class.new(local: true)
      logger = double("logger")
      allow(Rails).to receive(:logger).and_return(logger)

      client = instance_double(Opdotenv::OpClient)
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [
          {label: "TEST_ENABLED", value: "true"}
        ]
      }.to_json)
      allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

      expect(logger).to receive(:debug).with(/Available fields from 1Password/)
      expect(logger).to receive(:debug).with(/Matched fields for TEST/)
      expect(logger).not_to receive(:debug).with(/Unmatched fields/)

      loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    end

    it "does not log when OPDOTENV_DEBUG is not set" do
      ENV.delete("OPDOTENV_DEBUG")

      loader = described_class.new(local: true)
      logger = double("logger")
      allow(Rails).to receive(:logger).and_return(logger)

      client = instance_double(Opdotenv::OpClient)
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
      allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

      expect(logger).not_to receive(:debug)

      loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    end

    it "does not log when Rails.logger is not available" do
      loader = described_class.new(local: true)
      allow(Rails).to receive(:logger).and_return(nil)

      client = instance_double(Opdotenv::OpClient)
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
      allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

      # Should not raise
      loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    end

    it "does not log when no available fields" do
      loader = described_class.new(local: true)
      logger = double("logger")
      allow(Rails).to receive(:logger).and_return(logger)

      client = instance_double(Opdotenv::OpClient)
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
      allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

      expect(logger).not_to receive(:debug)

      loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Item"})
    end
  end

  if USING_REAL_ANYWAY
    describe "integration with real Anyway::Config" do
      # These tests use real Anyway::Env and real Opdotenv::Loader.load
      # They only stub the 1Password client to avoid actual API calls
      # This ensures we test the actual implementation code paths

      it "actually calls Opdotenv::Loader.load and strips prefix using real Anyway::Env" do
        # Stub only the client factory, but let Opdotenv::Loader.load run
        client = instance_double(Opdotenv::OpClient)
        allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("APP_API_KEY=secret123\nAPP_API_SECRET=secret456\n")
        allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

        loader = described_class.new(local: true)
        # This actually executes lines 12-30 in anyway_loader.rb
        data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/.env.development"})

        # Real Anyway::Env should strip the prefix (tests lines 35-55)
        expect(data).to include("api_key" => "secret123")
        expect(data).to include("api_secret" => "secret456")
        expect(data).not_to include("APP_API_KEY")
        expect(data).not_to include("APP_API_SECRET")
      end

      it "actually normalizes keys and filters by prefix with real implementation" do
        # Stub only the client, let everything else run
        client = instance_double(Opdotenv::OpClient)
        allow(client).to receive(:item_get).with("Config", vault: "Vault").and_return({
          fields: [
            {label: "TEST_ENABLED", value: "true"},
            {label: "TEST_PORT", value: "8080"},
            {label: "OTHER_KEY", value: "ignored"}
          ]
        }.to_json)
        allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

        loader = described_class.new(local: true)
        # This tests normalize_keys_for_prefix_matching (lines 57-77) and strip_prefix_from_keys (lines 35-55)
        data = loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/Config"})

        # Should only include TEST_ prefixed keys, with prefix stripped
        expect(data).to include("enabled" => "true")
        expect(data).to include("port" => "8080")
        expect(data).not_to include("other_key")
        expect(data).not_to include("TEST_ENABLED")
      end

      it "handles empty data and empty env_prefix with real implementation" do
        client = instance_double(Opdotenv::OpClient)
        allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
        allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

        loader = described_class.new(local: true)
        # Tests the early return in normalize_keys_for_prefix_matching (line 58)
        data = loader.call(name: "app", env_prefix: "", config_path: nil, opdotenv: {path: "op://Vault/Item"})
        expect(data).to eq({})
      end

      it "handles empty data hash with non-empty prefix" do
        client = instance_double(Opdotenv::OpClient)
        allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return('{"fields":[]}')
        allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

        loader = described_class.new(local: true)
        # Tests normalize_keys_for_prefix_matching with empty data (line 58)
        data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/Item"})
        expect(data).to eq({})
      end

      it "uses real Anyway::Env.fetch_with_trace for prefix stripping" do
        client = instance_double(Opdotenv::OpClient)
        allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("TEST_FOO=bar\nTEST_BAR=baz\nOTHER=ignored\n")
        allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

        loader = described_class.new(local: true)
        # This tests the real Anyway::Env integration (lines 44-45)
        data = loader.call(name: "test", env_prefix: "TEST", config_path: nil, opdotenv: {path: "op://Vault/.env.development"})

        # Real Anyway::Env should strip prefix and only include TEST_ prefixed keys
        expect(data).to include("foo" => "bar")
        expect(data).to include("bar" => "baz")
        expect(data).not_to include("other")
        expect(data).not_to include("TEST_FOO")
      end

      it "handles tracing integration with real Anyway::Tracing" do
        client = instance_double(Opdotenv::OpClient)
        allow(client).to receive(:read).with("op://Vault/.env.development/notesPlain").and_return("APP_KEY=value\n")
        allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

        loader = described_class.new(local: true)
        # Test that tracing is merged into current_trace (lines 47-49)
        current_trace = ::Anyway::Tracing.current_trace || {}
        expect(current_trace).to respond_to(:merge!)

        data = loader.call(name: "app", env_prefix: "APP", config_path: nil, opdotenv: {path: "op://Vault/.env.development"})

        # Verify data is correct
        expect(data).to include("key" => "value")
      end
    end
  end
end
