require "spec_helper"

RSpec.describe Opdotenv::Exporter do
  it "raises on unsupported format" do
    expect { described_class.serialize_by_format({"A" => "1"}, :ini) }.to raise_error(ArgumentError)
  end
end
