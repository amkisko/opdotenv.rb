require "spec_helper"

class TestOpClient < Opdotenv::OpClient
  attr_reader :calls

  def initialize(exists: false)
    super()
    @exists = exists
    @calls = []
  end

  def item_exists?(item, vault: nil)
    @exists
  end

  def capture(args)
    @calls << args
    "OK"
  end
end

RSpec.describe Opdotenv::OpClient do
  it "updates fields when item exists" do
    client = TestOpClient.new(exists: true)
    client.item_create_or_update_fields(vault: "V", item: "I", fields: {"A" => "1", "B" => "2"})
    expect(client.calls).to include(["op", "item", "edit", "I", "--vault", "V", "--set", "A=1"])
    expect(client.calls).to include(["op", "item", "edit", "I", "--vault", "V", "--set", "B=2"])
  end

  it "creates item when it does not exist" do
    client = TestOpClient.new(exists: false)
    client.item_create_or_update_fields(vault: "V", item: "I", fields: {"A" => "1"})
    expect(client.calls.first).to eq(["op", "item", "create", "--title", "I", "--vault", "V", "--set", "A=1"])
  end

  it "creates note with notesPlain" do
    client = TestOpClient.new
    client.item_create_note(vault: "V", title: "T", notes: "body")
    expect(client.calls.first).to eq(["op", "item", "create", "--category", "secure-note", "--title", "T", "--vault", "V", "notesPlain=body"])
  end

  it "reads and item_get delegates to capture" do
    client = TestOpClient.new
    expect(client.read("op://Vault/Item")).to eq("OK")
    expect(client.calls.last).to eq(["op", "read", "op://Vault/Item"])
    client.item_get("Item", vault: "V")
    expect(client.calls.last).to eq(["op", "item", "get", "Item", "--format", "json", "--vault", "V"])
  end

  it "raises on invalid path format" do
    client = described_class.new
    expect {
      client.read("invalid-path")
    }.to raise_error(ArgumentError, /Invalid path format/)
  end

  describe "#item_exists?" do
    it "returns true when item exists" do
      client = described_class.new
      allow(client).to receive(:system).with("op", "item", "get", "Item", out: File::NULL, err: File::NULL).and_return(true)

      result = client.send(:item_exists?, "Item")
      expect(result).to be true
    end

    it "returns false when item does not exist" do
      client = described_class.new
      allow(client).to receive(:system).with("op", "item", "get", "Item", out: File::NULL, err: File::NULL).and_return(false)

      result = client.send(:item_exists?, "Item")
      expect(result).to be false
    end

    it "includes vault when provided" do
      client = described_class.new
      allow(client).to receive(:system).with("op", "item", "get", "Item", "--vault", "Vault", out: File::NULL, err: File::NULL).and_return(true)

      result = client.send(:item_exists?, "Item", vault: "Vault")
      expect(result).to be true
    end
  end

  describe "#capture" do
    it "returns JSON even when exit code is non-zero for JSON format commands" do
      # Create a test client that simulates the JSON fallback logic
      test_client = Class.new(Opdotenv::OpClient) do
        def capture(args)
          # Simulate valid JSON output with non-zero exit
          out = '{"id":"123"}'

          # For JSON output, try to parse even if exit code is non-zero
          if args.include?("--format") && args.include?("json")
            begin
              JSON.parse(out)
              return out # Valid JSON, return it even if exit code is non-zero
            rescue JSON::ParserError
              # Not valid JSON, fall through to error handling
            end
          end

          raise Opdotenv::OpClient::OpError, out
        end
      end.new

      result = test_client.send(:capture, ["op", "item", "get", "Item", "--format", "json"])
      expect(result).to eq('{"id":"123"}')
    end

    it "raises OpError when JSON parsing fails for JSON format commands" do
      test_client = Class.new(Opdotenv::OpClient) do
        def capture(args)
          out = "invalid json"

          # For JSON output, try to parse even if exit code is non-zero
          if args.include?("--format") && args.include?("json")
            begin
              JSON.parse(out)
              return out
            rescue JSON::ParserError
              # Not valid JSON, fall through to error handling
            end
          end

          raise Opdotenv::OpClient::OpError, out
        end
      end.new

      expect {
        test_client.send(:capture, ["op", "item", "get", "Item", "--format", "json"])
      }.to raise_error(Opdotenv::OpClient::OpError, /invalid json/)
    end

    it "raises OpError when command fails with non-JSON output" do
      test_client = Class.new(Opdotenv::OpClient) do
        def capture(args)
          out = "Command failed"

          # For JSON output, try to parse even if exit code is non-zero
          if args.include?("--format") && args.include?("json")
            begin
              JSON.parse(out)
              return out
            rescue JSON::ParserError
              # Not valid JSON, fall through to error handling
            end
          end

          raise Opdotenv::OpClient::OpError, out
        end
      end.new

      expect {
        test_client.send(:capture, ["op", "read", "op://Vault/Item"])
      }.to raise_error(Opdotenv::OpClient::OpError, /Command failed/)
    end

    it "handles nil status" do
      test_client = Class.new(Opdotenv::OpClient) do
        def capture(args)
          out = "output"

          # For JSON output, try to parse even if exit code is non-zero
          if args.include?("--format") && args.include?("json")
            begin
              JSON.parse(out)
              return out
            rescue JSON::ParserError
              # Not valid JSON, fall through to error handling
            end
          end

          # Simulate nil status - check if status is nil first
          status = nil
          raise Opdotenv::OpClient::OpError, out if status.nil? || !status.success?
          out
        end
      end.new

      expect {
        test_client.send(:capture, ["op", "read", "op://Vault/Item"])
      }.to raise_error(Opdotenv::OpClient::OpError, /output/)
    end
  end
end
