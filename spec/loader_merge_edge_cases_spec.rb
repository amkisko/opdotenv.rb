require "spec_helper"

RSpec.describe Opdotenv::Loader do
  describe ".merge_into_env edge cases" do
    it "handles empty hash" do
      env = {"EXISTING" => "value"}
      described_class.merge_into_env(env, {})
      expect(env).to eq({"EXISTING" => "value"})
    end

    it "handles hash with nil values" do
      env = {}
      described_class.merge_into_env(env, {"KEY" => nil})
      expect(env["KEY"]).to eq("")
    end

    it "handles hash with false values" do
      env = {}
      described_class.merge_into_env(env, {"KEY" => false})
      expect(env["KEY"]).to eq("false")
    end

    it "handles hash with zero values" do
      env = {}
      described_class.merge_into_env(env, {"KEY" => 0})
      expect(env["KEY"]).to eq("0")
    end
  end
end
