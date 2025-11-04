require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  describe ".serialize_by_format edge cases" do
    it "handles empty hash for dotenv" do
      result = described_class.serialize_by_format({}, :dotenv)
      expect(result).to eq("\n")
    end

    it "handles empty hash for json" do
      result = described_class.serialize_by_format({}, :json)
      expect(result).to eq("{}")
    end

    it "handles empty hash for yaml" do
      result = described_class.serialize_by_format({}, :yaml)
      # YAML.dump outputs "--- {}\n" for empty hash
      expect(result).to match(/^---/)
    end

    it "handles hash with symbol keys" do
      result = described_class.serialize_by_format({FOO: "bar"}, :dotenv)
      expect(result).to include("FOO=bar")
    end

    it "handles hash with numeric keys" do
      result = described_class.serialize_by_format({"123" => "value"}, :dotenv)
      expect(result).to include("123=value")
    end
  end
end
