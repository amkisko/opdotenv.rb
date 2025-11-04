require "spec_helper"

RSpec.describe Opdotenv::Parsers::YamlParser do
  it "flattens YAML into string values like JSON parser" do
    text = <<~YAML
      a:
        b: 2
      arr:
        - false
        -
        - 4
    YAML
    env = described_class.parse(text)
    expect(env).to eq(
      "a_b" => "2",
      "arr_0" => "false",
      "arr_1" => "",
      "arr_2" => "4"
    )
  end
end
