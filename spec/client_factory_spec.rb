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

  it "passes cli_path to OpClient when provided" do
    env = {}
    client = described_class.create(env: env, cli_path: "/usr/local/bin/op")
    expect(client).to be_a(Opdotenv::OpClient)
    expect(client.instance_variable_get(:@cli_path)).to eq("/usr/local/bin/op")
  end

  it "uses OP_CLI_PATH from environment when set" do
    env = {"OP_CLI_PATH" => "/custom/path/op"}
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::OpClient)
    expect(client.instance_variable_get(:@cli_path)).to eq("/custom/path/op")
  end

  it "uses OPDOTENV_CLI_PATH from environment when set" do
    env = {"OPDOTENV_CLI_PATH" => "/custom/path/op"}
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::OpClient)
    expect(client.instance_variable_get(:@cli_path)).to eq("/custom/path/op")
  end

  it "prefers OP_CLI_PATH over OPDOTENV_CLI_PATH" do
    env = {
      "OP_CLI_PATH" => "/primary/path/op",
      "OPDOTENV_CLI_PATH" => "/fallback/path/op"
    }
    client = described_class.create(env: env)
    expect(client).to be_a(Opdotenv::OpClient)
    expect(client.instance_variable_get(:@cli_path)).to eq("/primary/path/op")
  end

  it "prefers explicit cli_path parameter over environment variables" do
    env = {
      "OP_CLI_PATH" => "/env/path/op",
      "OPDOTENV_CLI_PATH" => "/env/path/op"
    }
    client = described_class.create(env: env, cli_path: "/explicit/path/op")
    expect(client).to be_a(Opdotenv::OpClient)
    expect(client.instance_variable_get(:@cli_path)).to eq("/explicit/path/op")
  end
end
