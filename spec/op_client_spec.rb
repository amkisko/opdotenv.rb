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

  it "read strips output" do
    client = TestOpClient.new
    allow(client).to receive(:capture).with(["op", "read", "op://Vault/Item"]).and_return("  value  \n")
    result = client.read("op://Vault/Item")
    expect(result).to eq("value")
  end

  describe "cli_path configuration" do
    it "defaults to 'op' when not specified" do
      client = described_class.new
      expect(client.instance_variable_get(:@cli_path)).to eq("op")
    end

    it "uses cli_path parameter when provided" do
      client = described_class.new(cli_path: "/custom/path/op")
      expect(client.instance_variable_get(:@cli_path)).to eq("/custom/path/op")
    end

    it "reads OP_CLI_PATH from environment" do
      env = {"OP_CLI_PATH" => "/env/path/op"}
      client = described_class.new(env: env)
      expect(client.instance_variable_get(:@cli_path)).to eq("/env/path/op")
    end

    it "reads OPDOTENV_CLI_PATH from environment" do
      env = {"OPDOTENV_CLI_PATH" => "/env/path/op"}
      client = described_class.new(env: env)
      expect(client.instance_variable_get(:@cli_path)).to eq("/env/path/op")
    end

    it "prefers cli_path parameter over environment variables" do
      env = {"OP_CLI_PATH" => "/env/path/op", "OPDOTENV_CLI_PATH" => "/env/path/op"}
      client = described_class.new(env: env, cli_path: "/param/path/op")
      expect(client.instance_variable_get(:@cli_path)).to eq("/param/path/op")
    end

    it "uses custom cli_path in read command" do
      client = TestOpClient.new
      client.instance_variable_set(:@cli_path, "/custom/path/op")
      client.read("op://Vault/Item")
      expect(client.calls.last).to eq(["/custom/path/op", "read", "op://Vault/Item"])
    end

    it "uses custom cli_path in item_get command" do
      client = TestOpClient.new
      client.instance_variable_set(:@cli_path, "/custom/path/op")
      client.item_get("Item", vault: "V")
      expect(client.calls.last).to eq(["/custom/path/op", "item", "get", "Item", "--format", "json", "--vault", "V"])
    end
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

    it "uses custom cli_path when provided" do
      client = described_class.new(cli_path: "/custom/path/op")
      allow(client).to receive(:system).with("/custom/path/op", "item", "get", "Item", out: File::NULL, err: File::NULL).and_return(true)

      result = client.send(:item_exists?, "Item")
      expect(result).to be true
    end
  end

  describe "#capture" do
    let(:client) { described_class.new }

    it "raises OpError when command fails with non-JSON output" do
      # Test non-JSON command failure using real command
      # Error message should not leak command output for security
      expect {
        client.send(:capture, ["sh", "-c", 'echo "Command failed"; exit 1'])
      }.to raise_error(Opdotenv::OpClient::OpError, /Command failed: sh \(exit code: 1\)/)
    end

    it "returns output when command succeeds" do
      # Test successful command using real command
      result = client.send(:capture, ["sh", "-c", 'echo "success output"'])
      expect(result.strip).to eq("success output")
    end

    # Note: Lines 83-84 (JSON.parse when exit code non-zero) are an edge case
    # that's difficult to test without complex mocking of $CHILD_STATUS.
    # The code is defensive and handles the rare scenario where op command
    # fails but outputs valid JSON. This is acceptable as untested edge case.
  end
end
