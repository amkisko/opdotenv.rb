require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  describe ".infer_format_from_item" do
    it "infers dotenv from .env pattern" do
      expect(described_class.infer_format_from_item(".env")).to eq(:dotenv)
      expect(described_class.infer_format_from_item(".env.development")).to eq(:dotenv)
      expect(described_class.infer_format_from_item("Project .env.production")).to eq(:dotenv)
    end

    it "infers json from any item ending with .json" do
      expect(described_class.infer_format_from_item("config.json")).to eq(:json)
      expect(described_class.infer_format_from_item("production.json")).to eq(:json)
      expect(described_class.infer_format_from_item("staging.json")).to eq(:json)
    end

    it "infers yaml from any item ending with .yaml or .yml" do
      expect(described_class.infer_format_from_item("config.yaml")).to eq(:yaml)
      expect(described_class.infer_format_from_item("config.yml")).to eq(:yaml)
      expect(described_class.infer_format_from_item("production.yaml")).to eq(:yaml)
      expect(described_class.infer_format_from_item("my-config.yml")).to eq(:yaml)
    end

    it "defaults to dotenv for other items" do
      expect(described_class.infer_format_from_item("App")).to eq(:dotenv)
      expect(described_class.infer_format_from_item("Item")).to eq(:dotenv)
    end
  end

  describe ".export format inference" do
    let(:client) { instance_double(Opdotenv::OpClient) }

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

    it "infers format from any item ending with .json" do
      expect(client).to receive(:item_create_note) do |vault:, title:, notes:|
        expect(vault).to eq("V")
        expect(title).to eq("production.json")
        expect(notes).to include('"FOO"')
      end
      described_class.export(path: "op://V/production.json", data: {"FOO" => "bar"}, client: client)
    end

    it "infers format from config.yaml path" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: "config.yaml",
        notes: /FOO: bar/
      )
      described_class.export(path: "op://V/config.yaml", data: {"FOO" => "bar"}, client: client)
    end

    it "infers format from any item ending with .yaml or .yml" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: "staging.yaml",
        notes: /FOO: bar/
      )
      described_class.export(path: "op://V/staging.yaml", data: {"FOO" => "bar"}, client: client)

      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: "my-config.yml",
        notes: /FOO: bar/
      )
      described_class.export(path: "op://V/my-config.yml", data: {"FOO" => "bar"}, client: client)
    end

    it "allows format override for Secure Note pattern" do
      expect(client).to receive(:item_create_note) do |vault:, title:, notes:|
        expect(vault).to eq("V")
        expect(title).to eq(".env.test")
        expect(notes).to include('"FOO"')
      end
      described_class.export(path: "op://V/.env.test", data: {"FOO" => "bar"}, field_type: :json, client: client)
    end

    it "field_type override does not change item fields behavior" do
      expect(client).to receive(:item_create_or_update_fields).with(
        vault: "V",
        item: "App",
        fields: {"FOO" => "bar"}
      )
      described_class.export(path: "op://V/App", data: {"FOO" => "bar"}, field_type: :json, client: client)
    end
  end
end
