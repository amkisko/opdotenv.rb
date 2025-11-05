require "spec_helper"

RSpec.describe Opdotenv::Parsers::DotenvParser do
  it "parses simple KEY=VALUE lines and ignores comments" do
    text = <<~ENV
      # comment
      FOO=bar
      BAZ = qux
      export WITH_QUOTE="a b c"
    ENV
    env = described_class.parse(text)
    expect(env).to eq(
      "FOO" => "bar",
      "BAZ" => "qux",
      "WITH_QUOTE" => "a b c"
    )
  end

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
