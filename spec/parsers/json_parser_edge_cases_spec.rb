require "spec_helper"

RSpec.describe Opdotenv::Parsers::JsonParser do
  describe ".parse" do
    it "handles empty JSON object" do
      expect(described_class.parse("{}")).to eq({})
    end

    it "handles empty JSON array" do
      # Empty array has no elements, so flatten_to_string_map returns empty hash
      expect(described_class.parse("[]")).to eq({})
    end

    it "handles nested structures" do
      json = '{"app":{"database":{"host":"localhost"}}}'
      result = described_class.parse(json)
      expect(result).to eq({"app_database_host" => "localhost"})
    end

    it "handles arrays in nested structures" do
      json = '{"servers":["s1","s2"]}'
      result = described_class.parse(json)
      expect(result).to eq({"servers_0" => "s1", "servers_1" => "s2"})
    end
  end

  describe ".flatten_to_string_map" do
    it "handles nil values" do
      result = described_class.flatten_to_string_map(nil)
      expect(result).to eq({"" => ""})
    end

    it "handles numeric values" do
      result = described_class.flatten_to_string_map(123)
      expect(result).to eq({"" => "123"})
    end

    it "handles boolean values" do
      result = described_class.flatten_to_string_map(true)
      expect(result).to eq({"" => "true"})
    end
  end
end
