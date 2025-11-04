require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:client) { described_class.new(base_url: "http://localhost:8080", access_token: "t") }

  it "item_get searches all vaults when vault is nil (returns current implementation)" do
    # list_vaults returns two vaults, item found in first
    allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
      {"id" => "v1", "name" => "One"}, {"id" => "v2", "name" => "Two"}
    ])
    # Items list for v1 returns target; then fetch full item
    allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([
      {"id" => "i1", "title" => "Item"}
    ])
    allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items/i1").and_return({"id" => "i1", "title" => "Item", "fields" => []})

    json = client.item_get("Item", vault: nil)
    parsed = JSON.parse(json)
    expect(parsed["title"]).to eq("Item")
  end

  it "item_get fetches specific vault when provided" do
    allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
      {"id" => "v1", "name" => "Target"}
    ])
    allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([
      {"id" => "i2", "title" => "Cfg"}
    ])
    allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items/i2").and_return({"id" => "i2", "title" => "Cfg", "fields" => []})

    json = client.item_get("Cfg", vault: "Target")
    expect(json).to include("Cfg")
  end
end
