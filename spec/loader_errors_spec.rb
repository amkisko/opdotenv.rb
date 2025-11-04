require "spec_helper"

RSpec.describe Opdotenv::Loader do
  it "raises on unsupported format" do
    expect { described_class.parse_by_format("", :unknown) }.to raise_error(ArgumentError, /Unsupported format/)
  end

  it "raises on unsupported field_type" do
    # Mock the client to avoid actual 1Password calls
    # When field_type is specified, it uses load_field which calls client.read
    client = double("client")
    allow(client).to receive(:read).and_return("")
    allow(Opdotenv::ClientFactory).to receive(:create).and_return(client)

    # Use field_name to trigger the parse_by_format path
    expect { described_class.load("op://Vault/Item/notesPlain", field_name: "notesPlain", field_type: :unknown) }.to raise_error(ArgumentError, /Unsupported format/)
  end

  it "handles yaml format" do
    result = described_class.parse_by_format("key: value", :yaml)
    expect(result).to eq({"key" => "value"})
  end

  it "handles yml format" do
    result = described_class.parse_by_format("key: value", :yml)
    expect(result).to eq({"key" => "value"})
  end
end
