require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  it "serializes JSON format" do
    client = double("client")
    expect(client).to receive(:item_create_note) do |args|
      expect(args[:vault]).to eq("V")
      expect(args[:title]).to eq("config.json")
      expect(args[:notes]).to include("\"a\": 1")
    end
    described_class.export(path: "op://V/config.json", data: {"a" => 1}, field_type: :json, client: client)
  end

  it "serializes YAML format" do
    client = double("client")
    expect(client).to receive(:item_create_note) do |args|
      expect(args[:notes]).to match(/a:\s*1/) # loose match across YAML engines
    end
    described_class.export(path: "op://V/config.yaml", data: {"a" => 1}, field_type: :yaml, client: client)
  end
end
