require "spec_helper"

RSpec.describe Opdotenv::Loader do
  describe "with ConnectApiClient" do
    let(:connect_client) do
      instance_double(Opdotenv::ConnectApiClient).tap do |client|
        allow(client).to receive(:read).and_return("FOO=bar\nBAZ=qux\n")
      end
    end

    it "loads from field using ConnectApiClient" do
      env = {}
      data = described_class.load("op://Vault/Item", field_name: "notesPlain", field_type: :dotenv, env: env, client: connect_client)
      expect(data).to eq({"FOO" => "bar", "BAZ" => "qux"})
      expect(env).to include("FOO" => "bar", "BAZ" => "qux")
    end

    it "loads all fields using ConnectApiClient" do
      item_json = {
        "fields" => [
          {"label" => "KEY1", "value" => "value1"},
          {"label" => "KEY2", "value" => "value2"}
        ]
      }.to_json
      allow(connect_client).to receive(:item_get).with("Item", vault: "Vault").and_return(item_json)

      env = {}
      data = described_class.load("op://Vault/Item", env: env, client: connect_client)
      expect(data).to eq({"KEY1" => "value1", "KEY2" => "value2"})
      expect(env).to include("KEY1" => "value1", "KEY2" => "value2")
    end
  end
end
