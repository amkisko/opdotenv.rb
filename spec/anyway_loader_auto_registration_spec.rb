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
  let(:loader_file) { File.expand_path("../../lib/opdotenv/anyway_loader.rb", __FILE__) }

  around do |example|
    loaded_features = $LOADED_FEATURES.grep(/opdotenv\/anyway_loader/)
    original_loader = Opdotenv::AnywayLoader if Opdotenv.const_defined?(:AnywayLoader, false)
    $LOADED_FEATURES.delete_if { |feature| feature.include?("opdotenv/anyway_loader") }
    Opdotenv.send(:remove_const, :AnywayLoader) if original_loader

    example.run
  ensure
    Opdotenv.send(:remove_const, :AnywayLoader) if Opdotenv.const_defined?(:AnywayLoader, false)
    Opdotenv.const_set(:AnywayLoader, original_loader) if original_loader
    $LOADED_FEATURES.concat(loaded_features - $LOADED_FEATURES)
  end

  it "silently skips registration when Anyway.loaders is not available" do
    allow(::Anyway).to receive(:respond_to?).with(:loaders).and_return(false)

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
      registry = Class.new do
        def append(id, handler)
          raise StandardError.new("Registration failed")
        end
      end.new

      allow(::Anyway).to receive(:loaders).and_return(registry)

      expect {
        load loader_file
      }.to output(/Failed to register Anyway loader/).to_stderr
    end
  end
end
