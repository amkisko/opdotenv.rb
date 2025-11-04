require "spec_helper"

RSpec.describe Opdotenv::Parsers::JsonParser do
  it "flattens nested JSON into string values" do
    text = '{"a":{"b":1},"arr":[true, null, 3]}'
    env = described_class.parse(text)
    expect(env).to eq(
      "a_b" => "1",
      "arr_0" => "true",
      "arr_1" => "",
      "arr_2" => "3"
    )
  end
end
