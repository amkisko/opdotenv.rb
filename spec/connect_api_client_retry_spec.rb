require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:base_url) { "http://localhost:8080" }
  let(:access_token) { "test-token" }
  let(:client) { described_class.new(base_url: base_url, access_token: access_token) }

  describe "#api_request retries" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "retries once on timeout then succeeds" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "200", body: '{"ok":true}')
      call_sequence = [-> { raise Timeout::Error }, -> { response }]
      allow(http).to receive(:request) { call_sequence.shift.call }

      result = client.send(:api_request, :get, "/v1/vaults")
      expect(result).to eq({"ok" => true})
    end

    it "raises after second timeout" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      allow(http).to receive(:request).and_raise(Timeout::Error)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Timeout::Error)
    end
  end
end
