require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:client) { described_class.new(base_url: "http://localhost:8080", access_token: "t") }

  it "read returns empty string when field not found" do
    item = {"id" => "i1", "title" => "Item", "fields" => [{"label" => "FOO", "value" => "x"}]}
    allow(client).to receive(:get_item).with("Vault", "Item").and_return(item)
    val = client.read("op://Vault/Item/BAR")
    expect(val).to eq("")
  end

  it "read returns empty when no notesPlain present" do
    item = {"id" => "i1", "title" => "Item", "fields" => []}
    allow(client).to receive(:get_item).with("Vault", "Item").and_return(item)
    val = client.read("op://Vault/Item")
    expect(val).to eq("")
  end
end
