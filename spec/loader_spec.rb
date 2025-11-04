require "spec_helper"

RSpec.describe Opdotenv::Loader do
  let(:client) { instance_double(Opdotenv::OpClient) }

  it "loads from field in dotenv format and merges ENV" do
    allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\nBAR=baz\n")
    env = {}
    data = described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client)
    expect(data).to eq({"FOO" => "bar", "BAR" => "baz"})
    expect(env).to include("FOO" => "bar", "BAR" => "baz")
  end

  it "loads all fields when field_name is nil and merges ENV" do
    allow(client).to receive(:item_get).with("Item", vault: "Vault").and_return({
      fields: [
        {label: "FOO", value: "x"},
        {label: "BAR", value: "y"},
        {purpose: "NOTES", value: "ignored"}
      ]
    }.to_json)
    env = {}
    data = described_class.load("op://Vault/Item", env: env, client: client)
    expect(data).to eq({"FOO" => "x", "BAR" => "y"})
    expect(env).to include("FOO" => "x", "BAR" => "y")
  end

  it "overwrites by default when overwrite not specified" do
    allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\n")
    env = {"FOO" => "existing"}
    described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client)
    expect(env["FOO"]).to eq("bar")
  end

  it "overwrites when overwrite=true" do
    allow(client).to receive(:read).with("op://Vault/Item/notesPlain").and_return("FOO=bar\n")
    env = {"FOO" => "existing"}
    described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: client, overwrite: true)
    expect(env["FOO"]).to eq("bar")
  end

  it "loads a specific named field" do
    allow(client).to receive(:read).with("op://Vault/Item/config").and_return("FOO=bar\nBAR=baz\n")
    env = {}
    data = described_class.load("op://Vault/Item", field_name: "config", field_type: :dotenv, env: env, client: client)
    expect(data).to eq({"FOO" => "bar", "BAR" => "baz"})
    expect(env).to include("FOO" => "bar", "BAR" => "baz")
  end
end
