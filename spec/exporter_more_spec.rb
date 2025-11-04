require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  it "serializes dotenv with quoting and calls client" do
    client = double("client")
    expect(client).to receive(:item_create_note).with(
      vault: "V",
      title: ".env.test",
      notes: %(A=1\nB="hello world"\nC=plain\n)
    )

    described_class.export(path: "op://V/.env.test", data: {"A" => 1, "B" => "hello world", "C" => "plain"}, field_type: :dotenv, client: client)
  end

  it "stringifies values and calls client for item fields" do
    client = double("client")
    expect(client).to receive(:item_create_or_update_fields).with(
      vault: "V", item: "I", fields: {A: "1", B: "true"}
    )

    described_class.export(path: "op://V/I", data: {A: 1, B: true}, client: client)
  end
end
