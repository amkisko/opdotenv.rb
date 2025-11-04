require "spec_helper"

RSpec.describe Opdotenv::Loader do
  describe ".parse_op_path" do
    it "parses op:// paths" do
      vault, item = described_class.parse_op_path("op://Vault/Item")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item")
    end

    it "raises on invalid paths" do
      expect {
        described_class.parse_op_path("invalid")
      }.to raise_error(ArgumentError, /Invalid op path/)
    end
  end
end
