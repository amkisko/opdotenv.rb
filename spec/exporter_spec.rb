require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  let(:client) { instance_double(Opdotenv::OpClient) }

  it "exports to Secure Note using chosen field_type" do
    expect(client).to receive(:item_create_note) do |vault:, title:, notes:|
      expect(vault).to eq("V")
      expect(title).to eq(".env.development")
      expect(notes).to include("FOO=bar")
    end
    described_class.export(path: "op://V/.env.development", data: {"FOO" => "bar"}, field_type: :dotenv, client: client)
  end

  it "exports to Secure Note with json field_type" do
    expect(client).to receive(:item_create_note) do |vault:, title:, notes:|
      expect(vault).to eq("V")
      expect(title).to eq("config.json")
      expect(notes).to include('"FOO"')
    end
    described_class.export(path: "op://V/config.json", data: {"FOO" => "bar"}, field_type: :json, client: client)
  end

  it "exports to item fields" do
    expect(client).to receive(:item_create_or_update_fields).with(vault: "V", item: "I", fields: {"FOO" => "bar"})
    described_class.export(path: "op://V/I", data: {"FOO" => "bar"}, client: client)
  end

  it "serializes dotenv with quoting and calls client" do
    expect(client).to receive(:item_create_note).with(
      vault: "V",
      title: ".env.test",
      notes: %(A=1\nB="hello world"\nC=plain\n)
    )
    described_class.export(path: "op://V/.env.test", data: {"A" => 1, "B" => "hello world", "C" => "plain"}, field_type: :dotenv, client: client)
  end

  it "stringifies values and calls client for item fields" do
    expect(client).to receive(:item_create_or_update_fields).with(
      vault: "V", item: "I", fields: {A: "1", B: "true"}
    )
    described_class.export(path: "op://V/I", data: {A: 1, B: true}, client: client)
  end

  describe ".export edge cases" do
    it "handles empty data hash" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "\n"
      )
      described_class.export(path: "op://V/.env.test", data: {}, client: client)
    end

    it "handles data with symbol keys" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "FOO=bar\n"
      )
      described_class.export(path: "op://V/.env.test", data: {FOO: "bar"}, client: client)
    end

    it "handles data with non-string values" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "PORT=8080\n"
      )
      described_class.export(path: "op://V/.env.test", data: {"PORT" => 8080}, client: client)
    end
  end

  describe ".serialize_by_format" do
    it "serializes to dotenv with proper quoting" do
      data = {
        "PLAIN" => "abc",
        "WITH SPACE" => "a b",
        "WITH_QUOTE" => "a\"b"
      }
      text = described_class.serialize_by_format(data, :dotenv)
      expect(text).to include("PLAIN=abc\n")
      expect(text).to include("WITH SPACE=\"a b\"\n")
      expect(text).to include("WITH_QUOTE=\"a\\\"b\"\n")
    end

    it "serializes to JSON" do
      data = {"FOO" => "bar"}
      json = described_class.serialize_by_format(data, :json)
      expect(JSON.parse(json)).to eq({"FOO" => "bar"})
    end

    it "serializes to YAML" do
      data = {"FOO" => "bar"}
      yml = described_class.serialize_by_format(data, :yaml)
      expect(YAML.safe_load(yml)).to eq({"FOO" => "bar"})
    end

    it "handles empty hash for dotenv" do
      result = described_class.serialize_by_format({}, :dotenv)
      expect(result).to eq("\n")
    end

    it "handles hash with symbol keys" do
      result = described_class.serialize_by_format({FOO: "bar"}, :dotenv)
      expect(result).to include("FOO=bar")
    end
  end

  describe ".escape_env" do
    it "quotes when spaces or quotes present" do
      expect(described_class.escape_env("a b")).to eq("\"a b\"")
      expect(described_class.escape_env("a\"b")).to eq("\"a\\\"b\"")
    end

    it "keeps plain strings unquoted" do
      expect(described_class.escape_env("abc")).to eq("abc")
    end

    it "handles empty string" do
      expect(described_class.escape_env("")).to eq("\"\"")
    end
  end

  describe ".infer_format_from_item" do
    it "infers dotenv from .env pattern" do
      expect(described_class.infer_format_from_item(".env.development")).to eq(:dotenv)
    end

    it "infers json from any item ending with .json" do
      expect(described_class.infer_format_from_item("config.json")).to eq(:json)
    end

    it "infers yaml from any item ending with .yaml or .yml" do
      expect(described_class.infer_format_from_item("config.yaml")).to eq(:yaml)
      expect(described_class.infer_format_from_item("config.yml")).to eq(:yaml)
    end

    it "defaults to dotenv for other items" do
      expect(described_class.infer_format_from_item("App")).to eq(:dotenv)
    end
  end

  describe ".export format inference" do
    it "infers format from .env path" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "FOO=bar\n"
      )
      described_class.export(path: "op://V/.env.test", data: {"FOO" => "bar"}, client: client)
    end

    it "infers format from config.json path" do
      expect(client).to receive(:item_create_note) do |vault:, title:, notes:|
        expect(vault).to eq("V")
        expect(title).to eq("config.json")
        expect(notes).to include('"FOO"')
      end
      described_class.export(path: "op://V/config.json", data: {"FOO" => "bar"}, client: client)
    end

    it "infers format from config.yaml path" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: "config.yaml",
        notes: /FOO: bar/
      )
      described_class.export(path: "op://V/config.yaml", data: {"FOO" => "bar"}, client: client)
    end

    it "allows format override for Secure Note pattern" do
      expect(client).to receive(:item_create_note) do |vault:, title:, notes:|
        expect(vault).to eq("V")
        expect(title).to eq(".env.test")
        expect(notes).to include('"FOO"')
      end
      described_class.export(path: "op://V/.env.test", data: {"FOO" => "bar"}, field_type: :json, client: client)
    end
  end

  describe "errors" do
    it "raises on unsupported format" do
      expect { described_class.serialize_by_format({"A" => "1"}, :ini) }.to raise_error(ArgumentError)
    end
  end

  describe "with ConnectApiClient" do
    let(:connect_client) do
      instance_double(Opdotenv::ConnectApiClient)
    end

    it "exports to Secure Note using ConnectApiClient" do
      expect(connect_client).to receive(:item_create_note).with(
        vault: "TestVault",
        title: ".env.test",
        notes: "FOO=bar\n"
      )
      described_class.export(path: "op://TestVault/.env.test", data: {"FOO" => "bar"}, field_type: :dotenv, client: connect_client)
    end

    it "exports to item fields using ConnectApiClient" do
      expect(connect_client).to receive(:item_create_or_update_fields).with(
        vault: "TestVault",
        item: "TestItem",
        fields: {"KEY" => "value"}
      )
      described_class.export(path: "op://TestVault/TestItem", data: {"KEY" => "value"}, client: connect_client)
    end
  end
end
