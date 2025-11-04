require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  describe ".serialize_by_format" do
    it "serializes to dotenv with proper quoting" do
      data = {
        "PLAIN" => "abc",
        "WITH SPACE" => "a b",
        "WITH_QUOTE" => "a\"b"
      }
      text = described_class.serialize_by_format(data, :dotenv)
      expect(text).to include("PLAIN=abc\n")
      expect(text).to include("WITH SPACE=\"a b\"\n")
      expect(text).to include("WITH_QUOTE=\"a\\\"b\"\n")
    end

    it "serializes to JSON" do
      data = {"FOO" => "bar"}
      json = described_class.serialize_by_format(data, :json)
      expect(JSON.parse(json)).to eq({"FOO" => "bar"})
    end

    it "serializes to YAML" do
      data = {"FOO" => "bar"}
      yml = described_class.serialize_by_format(data, :yaml)
      expect(YAML.safe_load(yml)).to eq({"FOO" => "bar"})
    end
  end
end
