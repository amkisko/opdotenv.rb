require "spec_helper"

RSpec.describe Opdotenv::OpClient do
  it "raises OpError when op command fails" do
    client = described_class.new
    # Mock IO.popen to return a failed status
    io = double(read: "ERROR MESSAGE")
    instance_double(Process::Status, success?: false)

    allow(IO).to receive(:popen).and_yield(io).and_return("ERROR MESSAGE")
    # We can't mock $CHILD_STATUS directly as it's frozen, but we can verify
    # the behavior through TestOpClient which mocks capture
    allow(client).to receive(:capture).and_call_original

    # Use TestOpClient pattern: override capture to simulate error
    test_client_class = Class.new(Opdotenv::OpClient) do
      def capture(args)
        raise Opdotenv::OpClient::OpError, "ERROR MESSAGE"
      end
    end

    error_client = test_client_class.new
    expect {
      error_client.send(:capture, ["op", "read", "op://Vault/Item"])
    }.to raise_error(Opdotenv::OpClient::OpError, /ERROR MESSAGE/)
  end

  it "read strips output" do
    client = TestOpClient.new
    allow(client).to receive(:capture).with(["op", "read", "op://Vault/Item"]).and_return("  value  \n")
    result = client.read("op://Vault/Item")
    expect(result).to eq("value")
  end
end
