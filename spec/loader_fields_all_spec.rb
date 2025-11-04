require "spec_helper"

RSpec.describe Opdotenv::Loader do
  it "loads all fields when field_name is nil" do
    client = double("client")
    item_json = {
      "fields" => [
        {"label" => "A", "value" => "1"},
        {"label" => "B", "value" => "2"},
        {"purpose" => "NOTES", "value" => "ignored"}
      ]
    }.to_json
    expect(client).to receive(:item_get).with("Item", vault: "Vault").and_return(item_json)

    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({"A" => "1", "B" => "2"})
    expect(env).to include("A" => "1", "B" => "2")
  end
end
