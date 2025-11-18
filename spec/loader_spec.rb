require "spec_helper"

RSpec.describe Opdotenv::Loader do
  let(:client) { instance_double(Opdotenv::OpClient) }

  it "loads from field in dotenv format and merges ENV" do
    allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\nBAR=baz\n")
    env = {}
    data = described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client)
    expect(data).to eq({"FOO" => "bar", "BAR" => "baz"})
    expect(env).to include("FOO" => "bar", "BAR" => "baz")
  end

  it "loads all fields when field_name is nil and merges ENV" do
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
      fields: [
        {label: "FOO", value: "x"},
        {label: "BAR", value: "y"},
        {purpose: "NOTES", value: "ignored"}
      ]
    }.to_json)
    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({"FOO" => "x", "BAR" => "y"})
    expect(env).to include("FOO" => "x", "BAR" => "y")
  end

  it "overwrites by default when overwrite not specified" do
    allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\n")
    env = {"FOO" => "existing"}
    described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client)
    expect(env["FOO"]).to eq("bar")
  end

  it "overwrites when overwrite=true" do
    allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\n")
    env = {"FOO" => "existing"}
    described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client, overwrite: true)
    expect(env["FOO"]).to eq("bar")
  end

  it "loads a specific named field" do
    allow(client).to receive(:read).with("op://Vault/Item/config").and_return("FOO=bar\nBAR=baz\n")
    env = {}
    data = described_class.load("op://Vault/Item", field_name: "config", field_type: :dotenv, env: env, client: client)
    expect(data).to eq({"FOO" => "bar", "BAR" => "baz"})
    expect(env).to include("FOO" => "bar", "BAR" => "baz")
  end

  describe ".load with field_name" do
    it "handles non-notesPlain field_name" do
      allow(client).to receive(:read).with("op://Vault/Item/config").and_return('{"a": 1}')
      env = {}
      data = described_class.load("op://Vault/Item", field_name: "config", field_type: :json, env: env, client: client)
      expect(data).to eq({"a" => "1"})
    end

    it "does not duplicate field name when already in path" do
      allow(client).to receive(:read).with("op://Vault/Item/example.json").and_return('{"a": 1}')
      env = {}
      data = described_class.load("op://Vault/Item/example.json", field_name: "example.json", field_type: :json, env: env, client: client)
      expect(data).to eq({"a" => "1"})
    end
  end

  describe ".load all fields edge cases" do
    it "filters out field with nil value" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{label: "KEY", value: nil}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({})
    end

    it "filters out field with empty string value" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{label: "EMPTY_KEY", value: ""}, {label: "WHITESPACE_KEY", value: "   "}, {label: "VALID_KEY", value: "value"}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({"VALID_KEY" => "value"})
    end

    it "handles field with numeric value" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{label: "PORT", value: 8080}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({"PORT" => "8080"})
    end

    it "handles JSON parse error gracefully when loading all fields" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return("invalid json")
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({})
    end

    it "handles missing fields array when loading all fields" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({}.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({})
    end

    it "handles field without label or id" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{value: "x"}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({})
    end

    it "uses field id when label is missing" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [{id: "field-id", value: "x"}]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({"field-id" => "x"})
    end

    it "strips whitespace from labels and filters out empty labels" do
      allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
        fields: [
          {label: "  KEY1  ", value: "value1"},
          {label: "   ", value: "value2"},
          {label: "", value: "value3"},
          {label: "KEY2", value: "value4"}
        ]
      }.to_json)
      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: client)
      expect(data).to eq({"KEY1" => "value1", "KEY2" => "value4"})
    end
  end

  describe "format handling" do
    it "raises on unsupported format" do
      expect { described_class.parse_by_format("", :unknown) }.to raise_error(ArgumentError, /Unsupported format/)
    end

    it "handles yaml format" do
      result = described_class.parse_by_format("key: value", :yaml)
      expect(result).to eq({"key" => "value"})
    end

    it "handles yml format" do
      result = described_class.parse_by_format("key: value", :yml)
      expect(result).to eq({"key" => "value"})
    end
  end

  describe ".parse_op_path" do
    it "parses op:// paths" do
      vault, item = described_class.parse_op_path("op://Vault/Item")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item")
    end

    it "parses path with item containing spaces" do
      vault, item = described_class.parse_op_path("op://Vault/Item Name")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item Name")
    end

    it "handles path with trailing slash" do
      vault, item = described_class.parse_op_path("op://Vault/Item/")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item")
    end

    it "raises on invalid path" do
      expect {
        described_class.parse_op_path("invalid")
      }.to raise_error(ArgumentError, /Invalid op path/)
    end
  end

  describe ".merge_into_env" do
    it "overwrites existing keys by default" do
      env = {"A" => "1", "B" => "2"}
      described_class.merge_into_env(env, {A: 9, B: 5})
      expect(env).to eq({"A" => "9", "B" => "5"})
    end

    it "does not overwrite existing keys when overwrite=false" do
      env = {"A" => "1", "B" => "2"}
      described_class.merge_into_env(env, {A: 9, C: 3}, overwrite: false)
      expect(env).to eq({"A" => "1", "B" => "2", "C" => "3"})
    end

    it "stringifies all values" do
      env = {}
      described_class.merge_into_env(env, {A: 1, B: true, C: :sym})
      expect(env).to eq({"A" => "1", "B" => "true", "C" => "sym"})
    end

    it "handles empty hash" do
      env = {"EXISTING" => "value"}
      described_class.merge_into_env(env, {})
      expect(env).to eq({"EXISTING" => "value"})
    end

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

  describe "with ConnectApiClient" do
    let(:connect_client) do
      instance_double(Opdotenv::ConnectApiClient).tap do |client|
        allow(client).to receive(:read).and_return("FOO=bar\nBAZ=qux\n")
      end
    end

    it "loads from field using ConnectApiClient" do
      env = {}
      data = described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: connect_client)
      expect(data).to eq({"FOO" => "bar", "BAZ" => "qux"})
      expect(env).to include("FOO" => "bar", "BAZ" => "qux")
    end

    it "loads all fields using ConnectApiClient" do
      item_json = {
        "fields" => [
          {"label" => "KEY1", "value" => "value1"},
          {"label" => "KEY2", "value" => "value2"}
        ]
      }.to_json
      allow(connect_client).to receive(:item_get).with("Item", vault: "Vault").and_return(item_json)

      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: connect_client)
      expect(data).to eq({"KEY1" => "value1", "KEY2" => "value2"})
      expect(env).to include("KEY1" => "value1", "KEY2" => "value2")
    end
  end
end
