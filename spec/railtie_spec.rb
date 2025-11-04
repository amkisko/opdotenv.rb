require "spec_helper"
require "active_support/ordered_options"

# Only test Railtie when railties is available (via appraisals)
if defined?(Rails::Railtie)
  require "opdotenv/railtie"

  RSpec.describe Opdotenv::Railtie do
  it "initializes and loads from sources array with simplified string format" do
    # Build fake Rails app config
    options = ActiveSupport::OrderedOptions.new
    options.sources = [
      "op://Vault/.env.development",  # inferred as dotenv
      "op://Vault/Item"  # all fields
    ]
    options.overwrite = true
    options.auto_load = true

    app = double("app", config: double(opdotenv: options))

    # Expect Loader.load to be called for each source
    expect(Opdotenv::Loader).to receive(:load).with("op://Vault/.env.development", hash_including(field_name: "notesPlain", field_type: :dotenv, env: ENV, overwrite: true))
    expect(Opdotenv::Loader).to receive(:load).with("op://Vault/Item", hash_including(field_name: nil, field_type: nil, env: ENV, overwrite: true))

    initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
    expect(initializer).to be
    initializer.run(app)
  end

  it "supports backward compatibility with hash format" do
    options = ActiveSupport::OrderedOptions.new
    options.sources = [
      {path: "op://Vault/Dev", field_name: "notesPlain", field_type: :dotenv},
      {path: "op://Vault/Item"}
    ]
    options.overwrite = true
    options.auto_load = true

    app = double("app", config: double(opdotenv: options))

    expect(Opdotenv::Loader).to receive(:load).with("op://Vault/Dev", hash_including(field_name: "notesPlain", field_type: :dotenv, env: ENV, overwrite: true))
    expect(Opdotenv::Loader).to receive(:load).with("op://Vault/Item", hash_including(field_name: nil, env: ENV, overwrite: true))

    initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
    initializer.run(app)
  end

  it "skips when auto_load is false" do
    options = ActiveSupport::OrderedOptions.new
    options.sources = ["op://Vault/.env.development"]
    options.overwrite = true
    options.auto_load = false

    app = double("app", config: double(opdotenv: options))
    expect(Opdotenv::Loader).not_to receive(:load)
    initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
    initializer.run(app)
  end

  it "logs an error when Loader.load raises" do
    options = ActiveSupport::OrderedOptions.new
    options.sources = [{path: "op://Vault/Dev", field_name: "notesPlain", field_type: :dotenv}]
    options.overwrite = true
    options.auto_load = true

    app = double("app", config: double(opdotenv: options))
    allow(Opdotenv::Loader).to receive(:load).and_raise(StandardError.new("boom"))
    logger = double("logger").as_null_object
    allow(Rails).to receive(:logger).and_return(logger)
    expect(logger).to receive(:error).with(/Failed to load/).at_least(:once)
    initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
    initializer.run(app)
  end

  it "handles missing path in source" do
    options = ActiveSupport::OrderedOptions.new
    options.sources = [{field_name: "notesPlain", field_type: :dotenv}] # no path
    options.auto_load = true

    app = double("app", config: double(opdotenv: options))
    expect(Opdotenv::Loader).not_to receive(:load)
    initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
    initializer.run(app)
  end

  it "sets OP_CONNECT_URL and OP_CONNECT_TOKEN from config" do
    options = ActiveSupport::OrderedOptions.new
    options.sources = []
    options.connect_url = "http://localhost:8080"
    options.connect_token = "test-token"
    options.auto_load = true

    app = double("app", config: double(opdotenv: options))

    initializer = described_class.initializers.find { |i| i.name == "opdotenv.load" }
    initializer.run(app)

    expect(ENV["OP_CONNECT_URL"]).to eq("http://localhost:8080")
    expect(ENV["OP_CONNECT_TOKEN"]).to eq("test-token")
  ensure
    ENV.delete("OP_CONNECT_URL")
    ENV.delete("OP_CONNECT_TOKEN")
  end
  end
end
