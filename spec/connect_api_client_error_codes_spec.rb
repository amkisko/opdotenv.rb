require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:base_url) { "http://localhost:8080" }
  let(:access_token) { "test-token" }
  let(:client) { described_class.new(base_url: base_url, access_token: access_token) }

  describe "#api_request error codes" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "handles 400 Bad Request with JSON error" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "400", body: '{"error":"Bad Request"}')
      allow(http).to receive(:request).and_return(response)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error \(400\)/)
    end

    it "handles 400 Bad Request with plain text error" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "400", body: "Invalid request")
      allow(http).to receive(:request).and_return(response)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error \(400\): Invalid request/)
    end

    it "handles 204 No Content" do
      request = instance_double(Net::HTTP::Patch)
      allow(Net::HTTP::Patch).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
      uri = URI.parse("http://localhost:8080/v1/vaults/123/items/456")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/123/items/456").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "204", body: "")
      allow(http).to receive(:request).and_return(response)

      result = client.send(:api_request, :patch, "/v1/vaults/123/items/456", [])
      expect(result).to eq({})
    end

    it "handles 200 with empty body" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "200", body: "")
      allow(http).to receive(:request).and_return(response)

      result = client.send(:api_request, :get, "/v1/vaults")
      expect(result).to eq({})
    end
  end
end
