require "spec_helper"

RSpec.describe Opdotenv::Loader do
  describe ".load with field_name" do
    let(:client) { instance_double(Opdotenv::OpClient) }

    it "handles non-notesPlain field_name" do
      allow(client).to receive(:read).with("op://Vault/Item/config").and_return('{"a": 1}')
      env = {}
      data = described_class.load("op://Vault/Item", field_name: "config", field_type: :json, env: env, client: client)
      expect(data).to eq({"a" => "1"})
    end

    it "handles notesPlain field_name with custom path" do
      allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\n")
      env = {}
      data = described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client)
      expect(data).to eq({"FOO" => "bar"})
    end

    it "does not duplicate field name when already in path" do
      allow(client).to receive(:read).with("op://Vault/Item/example.json").and_return('{"a": 1}')
      env = {}
      data = described_class.load("op://Vault/Item/example.json", field_name: "example.json", field_type: :json, env: env, client: client)
      expect(data).to eq({"a" => "1"})
    end
  end

  describe ".load all fields edge cases" do
    let(:client) { instance_double(Opdotenv::OpClient) }

    it "handles field with nil value" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{label: "KEY", value: nil}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({"KEY" => ""})
    end

    it "handles field with numeric value" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{label: "PORT", value: 8080}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({"PORT" => "8080"})
    end
  end

  describe ".parse_op_path" do
    it "raises on invalid path" do
      expect {
        described_class.parse_op_path("invalid")
      }.to raise_error(ArgumentError, /Invalid op path/)
    end

    it "handles path with trailing slash" do
      vault, item = described_class.parse_op_path("op://Vault/Item/")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item")
    end
  end

  describe ".merge_into_env" do
    it "handles non-string keys" do
      env = {}
      described_class.merge_into_env(env, {:FOO => "bar", 123 => "numeric"})
      expect(env).to eq({"FOO" => "bar", "123" => "numeric"})
    end

    it "handles non-string values" do
      env = {}
      described_class.merge_into_env(env, {"FOO" => 123, "BAR" => true})
      expect(env).to eq({"FOO" => "123", "BAR" => "true"})
    end
  end
end
