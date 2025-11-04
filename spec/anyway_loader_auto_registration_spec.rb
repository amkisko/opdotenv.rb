require "spec_helper"

# Set up minimal Anyway stubs for the file to load
unless defined?(::Anyway)
  module ::Anyway; end
end
unless defined?(::Anyway::Loaders)
  module ::Anyway::Loaders; end
end
unless defined?(::Anyway::Loaders::Base)
  class ::Anyway::Loaders::Base
    def initialize(local:)
    end
  end
end

RSpec.describe "Opdotenv::AnywayLoader auto-registration" do
  # This test needs to run in isolation because it modifies global state
  # and reloads the anyway_loader file

  let(:loader_file) { File.expand_path("../../lib/opdotenv/anyway_loader.rb", __FILE__) }

  before do
    # Remove the module from $LOADED_FEATURES so we can reload it
    $LOADED_FEATURES.delete_if { |f| f.include?("opdotenv/anyway_loader") }
    # Also remove from Opdotenv module if it exists
    if Opdotenv.const_defined?(:AnywayLoader)
      Opdotenv.send(:remove_const, :AnywayLoader)
    end
  end

  it "silently skips registration when Anyway.loaders is not available" do
    # Mock Anyway to not respond to loaders
    allow(::Anyway).to receive(:respond_to?).with(:loaders).and_return(false)

    # Reload the file - should not raise
    expect {
      load loader_file
    }.not_to raise_error
  end

  context "when OPDOTENV_DEBUG is enabled" do
    before do
      ENV["OPDOTENV_DEBUG"] = "true"
    end

    after do
      ENV.delete("OPDOTENV_DEBUG")
    end

    it "warns when registration fails" do
      # Create a registry that raises an error
      registry = Class.new do
        def append(id, handler)
          raise StandardError.new("Registration failed")
        end
      end.new

      allow(::Anyway).to receive(:loaders).and_return(registry)

      # Reload the file - should warn but not raise
      expect {
        load loader_file
      }.to output(/Failed to register Anyway loader/).to_stderr
    end
  end
end
