require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:base_url) { "http://localhost:8080" }
  let(:access_token) { "test-token" }
  let(:client) { described_class.new(base_url: base_url, access_token: access_token) }

  describe "#item_create_note" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "creates a secure note with notesPlain field" do
      allow(client).to receive(:vault_name_to_id).with("Vault").and_return("vault-id")

      request = instance_double(Net::HTTP::Post)
      allow(Net::HTTP::Post).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
      uri = URI.parse("http://localhost:8080/v1/vaults/vault-id/items")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/vault-id/items").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "200", body: '{"id":"item-id","title":"Note"}')
      allow(http).to receive(:request).and_return(response)

      result = client.item_create_note(vault: "Vault", title: "Note", notes: "content")
      expect(result).to include("item-id")
      expect(result).to include("Note")
    end
  end
end
