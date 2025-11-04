require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  describe ".escape_env" do
    it "quotes when spaces or quotes present" do
      expect(described_class.escape_env("a b")).to eq("\"a b\"")
      expect(described_class.escape_env("a\"b")).to eq("\"a\\\"b\"")
    end

    it "keeps plain strings unquoted" do
      expect(described_class.escape_env("abc")).to eq("abc")
    end

    it "handles empty string" do
      expect(described_class.escape_env("")).to eq("\"\"")
    end

    it "escapes internal double quotes" do
      expect(described_class.escape_env('a"b')).to eq('"a\\"b"')
    end
  end
end
