require "spec_helper"

RSpec.describe Opdotenv::Parsers::DotenvParser do
  it "supports single quotes and export prefix" do
    text = <<~ENV
      export A='a b'
      B='c'
      C="d"
    ENV
    env = described_class.parse(text)
    expect(env).to include(
      "A" => "a b",
      "B" => "c",
      "C" => "d"
    )
  end
end
