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
end
