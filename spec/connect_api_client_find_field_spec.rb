require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:client) { described_class.new(base_url: "http://x", access_token: "t") }

  it "finds field by label and id and notesPlain" do
    item = {
      "fields" => [
        {"id" => "id-1", "label" => "API_KEY", "value" => "v1"},
        {"id" => "id-2", "label" => "notesPlain", "purpose" => "NOTES", "value" => "A=1\n"}
      ]
    }

    f1 = client.send(:find_field, item, "API_KEY")
    expect(f1["value"]).to eq("v1")

    f2 = client.send(:find_field, item, "id-1")
    expect(f2["value"]).to eq("v1")

    f3 = client.send(:find_field, item, "notesPlain")
    expect(f3["value"]).to eq("A=1\n")
  end
end
