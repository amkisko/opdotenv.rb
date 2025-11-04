require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  describe ".export edge cases" do
    let(:client) { instance_double(Opdotenv::OpClient) }

    it "handles empty data hash" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "\n"
      )
      described_class.export(path: "op://V/.env.test", data: {}, client: client)
    end

    it "handles data with symbol keys" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "FOO=bar\n"
      )
      described_class.export(path: "op://V/.env.test", data: {FOO: "bar"}, client: client)
    end

    it "handles data with non-string values" do
      expect(client).to receive(:item_create_note).with(
        vault: "V",
        title: ".env.test",
        notes: "PORT=8080\n"
      )
      described_class.export(path: "op://V/.env.test", data: {"PORT" => 8080}, client: client)
    end

    it "handles item fields with empty hash" do
      expect(client).to receive(:item_create_or_update_fields).with(
        vault: "V",
        item: "App",
        fields: {}
      )
      described_class.export(path: "op://V/App", data: {}, client: client)
    end
  end
end
