require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  describe "with ConnectApiClient" do
    let(:connect_client) do
      instance_double(Opdotenv::ConnectApiClient)
    end

    it "exports to Secure Note using ConnectApiClient" do
      expect(connect_client).to receive(:item_create_note).with(
        vault: "TestVault",
        title: ".env.test",
        notes: "FOO=bar\n"
      )
      described_class.export(path: "op://TestVault/.env.test", data: {"FOO" => "bar"}, field_type: :dotenv, client: connect_client)
    end

    it "exports to item fields using ConnectApiClient" do
      expect(connect_client).to receive(:item_create_or_update_fields).with(
        vault: "TestVault",
        item: "TestItem",
        fields: {"KEY" => "value"}
      )
      described_class.export(path: "op://TestVault/TestItem", data: {"KEY" => "value"}, client: connect_client)
    end
  end
end
