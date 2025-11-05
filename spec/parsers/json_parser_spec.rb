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

  it "handles empty JSON object" do
    expect(described_class.parse("{}")).to eq({})
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
