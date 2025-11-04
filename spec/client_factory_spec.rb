require "spec_helper"

RSpec.describe Opdotenv::ClientFactory do
  it "creates OpClient when Connect API env vars not set" do
    env = {}
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::OpClient)
  end

  it "creates ConnectApiClient when OP_CONNECT_URL and OP_CONNECT_TOKEN are set" do
    env = {
      "OP_CONNECT_URL" => "http://localhost:8080",
      "OP_CONNECT_TOKEN" => "test-token"
    }
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::ConnectApiClient)
  end

  it "creates ConnectApiClient when OPDOTENV_CONNECT_URL and OPDOTENV_CONNECT_TOKEN are set" do
    env = {
      "OPDOTENV_CONNECT_URL" => "http://localhost:8080",
      "OPDOTENV_CONNECT_TOKEN" => "test-token"
    }
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::ConnectApiClient)
  end

  it "prefers OP_* vars over OPDOTENV_* vars" do
    env = {
      "OP_CONNECT_URL" => "http://primary:8080",
      "OP_CONNECT_TOKEN" => "primary-token",
      "OPDOTENV_CONNECT_URL" => "http://fallback:8080",
      "OPDOTENV_CONNECT_TOKEN" => "fallback-token"
    }
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::ConnectApiClient)
    expect(client.instance_variable_get(:@base_url)).to eq("http://primary:8080")
    expect(client.instance_variable_get(:@access_token)).to eq("primary-token")
  end

  it "creates OpClient when only URL is set" do
    env = {"OP_CONNECT_URL" => "http://localhost:8080"}
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::OpClient)
  end

  it "creates OpClient when only token is set" do
    env = {"OP_CONNECT_TOKEN" => "test-token"}
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::OpClient)
  end
end
