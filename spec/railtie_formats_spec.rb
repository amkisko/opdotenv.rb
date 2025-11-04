require "spec_helper"
require "active_support/ordered_options"

# Only test Railtie when railties is available (via appraisals)
if defined?(Rails::Railtie)
  require "opdotenv/railtie"

  RSpec.describe Opdotenv::Railtie do
    it "loads from sources array with different field types (simplified format)" do
      options = ActiveSupport::OrderedOptions.new
      options.sources = [
        "op://Vault/.env.development",  # inferred as dotenv
        "op://Vault/config.json",       # inferred as json
        "op://Vault/config.yaml"        # inferred as yaml
      ]
      options.overwrite = true
      options.auto_load = true

      app = double("app", config: double(opdotenv: options))

      expect(Opdotenv::Loader).to receive(:load).with("op://Vault/.env.development", hash_including(field_name: "notesPlain", field_type: :dotenv, env: ENV, overwrite: true))
      expect(Opdotenv::Loader).to receive(:load).with("op://Vault/config.json", hash_including(field_name: "notesPlain", field_type: :json, env: ENV, overwrite: true))
      expect(Opdotenv::Loader).to receive(:load).with("op://Vault/config.yaml", hash_including(field_name: "notesPlain", field_type: :yaml, env: ENV, overwrite: true))

      initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
      initializer.run(app)
    end

    it "respects per-source overwrite option (backward compatibility with hash format)" do
      options = ActiveSupport::OrderedOptions.new
      options.sources = [
        {path: "op://Vault/Item1", field_name: "notesPlain", field_type: :dotenv, overwrite: false},
        {path: "op://Vault/Item2", field_name: "notesPlain", field_type: :dotenv, overwrite: true}
      ]
      options.overwrite = true # default
      options.auto_load = true

      app = double("app", config: double(opdotenv: options))

      expect(Opdotenv::Loader).to receive(:load).with("op://Vault/Item1", hash_including(overwrite: false))
      expect(Opdotenv::Loader).to receive(:load).with("op://Vault/Item2", hash_including(overwrite: true))

      initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
      initializer.run(app)
    end
  end
end
