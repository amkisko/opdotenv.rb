require "spec_helper"

RSpec.describe Opdotenv::Parsers::DotenvParser do
  describe ".parse edge cases" do
    it "handles single quotes" do
      text = "FOO='bar baz'"
      result = described_class.parse(text)
      expect(result).to eq({"FOO" => "bar baz"})
    end

    it "handles export prefix" do
      text = "export FOO=bar"
      result = described_class.parse(text)
      expect(result).to eq({"FOO" => "bar"})
    end

    it "handles multiple export prefixes" do
      # sub(/^export\s+/, "") only removes the first export
      text = "export export FOO=bar"
      result = described_class.parse(text)
      # After removing first export, we get "export FOO=bar" which doesn't match the key pattern
      expect(result).to eq({})
    end

    it "handles lines with only whitespace" do
      text = "FOO=bar\n  \nBAR=baz"
      result = described_class.parse(text)
      expect(result).to eq({"FOO" => "bar", "BAR" => "baz"})
    end

    it "handles lines starting with hash" do
      text = "# Comment\nFOO=bar\n# Another comment"
      result = described_class.parse(text)
      expect(result).to eq({"FOO" => "bar"})
    end

    it "handles invalid key names" do
      text = "123INVALID=bar\nVALID_KEY=baz"
      result = described_class.parse(text)
      expect(result).to eq({"VALID_KEY" => "baz"})
    end

    it "handles empty value" do
      text = "FOO="
      result = described_class.parse(text)
      expect(result).to eq({"FOO" => ""})
    end
  end
end
