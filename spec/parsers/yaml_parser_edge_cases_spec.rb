require "spec_helper"

RSpec.describe Opdotenv::Parsers::YamlParser do
  describe ".parse edge cases" do
    it "handles empty YAML" do
      # Empty YAML parses to nil, which flattens to {"" => ""}
      result = described_class.parse("")
      expect(result).to eq({"" => ""})
    end

    it "handles YAML with null values" do
      yaml = "foo: null\nbar: baz"
      result = described_class.parse(yaml)
      expect(result).to have_key("foo")
    end

    it "handles YAML with numeric values" do
      yaml = "port: 8080\nhost: localhost"
      result = described_class.parse(yaml)
      expect(result["port"]).to eq("8080")
      expect(result["host"]).to eq("localhost")
    end

    it "handles YAML with boolean values" do
      yaml = "enabled: true\ndebug: false"
      result = described_class.parse(yaml)
      expect(result["enabled"]).to eq("true")
      expect(result["debug"]).to eq("false")
    end
  end
end
