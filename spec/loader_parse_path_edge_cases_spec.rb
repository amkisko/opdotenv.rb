require "spec_helper"

RSpec.describe Opdotenv::Loader do
  describe ".parse_op_path" do
    it "parses path with vault and item" do
      vault, item = described_class.parse_op_path("op://Vault/Item")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item")
    end

    it "parses path with single character vault" do
      vault, item = described_class.parse_op_path("op://V/I")
      expect(vault).to eq("V")
      expect(item).to eq("I")
    end

    it "parses path with item containing spaces" do
      vault, item = described_class.parse_op_path("op://Vault/Item Name")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item Name")
    end
  end
end
