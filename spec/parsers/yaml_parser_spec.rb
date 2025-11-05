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
