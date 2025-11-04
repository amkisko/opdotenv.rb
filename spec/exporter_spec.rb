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
end
