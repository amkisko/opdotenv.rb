require "spec_helper"
require "tempfile"

RSpec.describe Opdotenv do
  it "infers the source format when no override is given" do
    Tempfile.create(["opdotenv", ".json"]) do |file|
      file.write('{"KEY":"value"}')
      file.flush
      stub_const("ARGV", ["export", "--path", "op://Vault/config.json", "--file", file.path])
      allow(Opdotenv::Exporter).to receive(:export)
      load File.expand_path("../bin/opdotenv", __dir__)
      expect(Opdotenv::Exporter).to have_received(:export).with(path: "op://Vault/config.json", data: {"KEY" => "value"}, field_type: :json)
    end
  end
end
