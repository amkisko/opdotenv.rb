require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:base_url) { "http://localhost:8080" }
  let(:access_token) { "test-token" }
  let(:client) { described_class.new(base_url: base_url, access_token: access_token) }

  describe "#api_request 5xx errors" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "handles 500 with JSON error message" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "500", body: '{"message":"Internal Server Error"}')
      allow(http).to receive(:request).and_return(response)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error \(500\): Internal Server Error/)
    end

    it "handles 500 with error field in JSON" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "502", body: '{"error":"Bad Gateway"}')
      allow(http).to receive(:request).and_return(response)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error \(502\): Bad Gateway/)
    end

    it "handles 500 with invalid JSON body" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "503", body: "Service Unavailable")
      allow(http).to receive(:request).and_return(response)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error \(503\): Service Unavailable/)
    end
  end
end
