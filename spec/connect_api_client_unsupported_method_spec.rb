require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:base_url) { "http://localhost:8080" }
  let(:access_token) { "test-token" }
  let(:client) { described_class.new(base_url: base_url, access_token: access_token) }

  describe "#api_request unsupported methods" do
    it "raises on unsupported HTTP method" do
      expect {
        client.send(:api_request, :head, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Unsupported HTTP method/)
    end
  end
end
