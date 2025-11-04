require "spec_helper"

RSpec.describe Opdotenv::Loader do
  it "handles JSON parse error gracefully when loading all fields" do
    client = double("client")
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return("invalid json")
    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({})
  end

  it "handles missing fields array when loading all fields" do
    client = double("client")
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({}.to_json)
    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({})
  end

  it "handles field without label or id" do
    client = double("client")
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
      fields: [{value: "x"}] # no label or id
    }.to_json)
    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({})
  end

  it "uses field id when label is missing" do
    client = double("client")
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
      fields: [{id: "field-id", value: "x"}]
    }.to_json)
    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({"field-id" => "x"})
  end
end
