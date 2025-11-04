require "spec_helper"

RSpec.describe Opdotenv::Loader do
  describe ".merge_into_env" do
    it "overwrites existing keys by default" do
      env = {"A" => "1", "B" => "2"}
      described_class.merge_into_env(env, {A: 9, B: 5})
      expect(env).to eq({"A" => "9", "B" => "5"})
    end

    it "does not overwrite existing keys when overwrite=false" do
      env = {"A" => "1", "B" => "2"}
      described_class.merge_into_env(env, {A: 9, C: 3}, overwrite: false)
      expect(env).to eq({"A" => "1", "B" => "2", "C" => "3"})
    end

    it "overwrites existing keys when overwrite=true" do
      env = {"A" => "1", "B" => "2"}
      described_class.merge_into_env(env, {A: 9, B: 5}, overwrite: true)
      expect(env).to eq({"A" => "9", "B" => "5"})
    end

    it "stringifies all values" do
      env = {}
      described_class.merge_into_env(env, {A: 1, B: true, C: :sym})
      expect(env).to eq({"A" => "1", "B" => "true", "C" => "sym"})
    end
  end
end
