Gem::Specification.new do |spec|
  spec.name          = "opdotenv"
  spec.version       = File.read(File.expand_path("lib/opdotenv/version.rb", __dir__)).match(/VERSION\s*=\s*\"([^\"]+)\"/)[1]
  spec.authors       = ["Andrei Makarov"]
  spec.email         = ["contact@kiskolabs.com"]

  spec.summary       = "Load and export environment variables with 1Password CLI or Connect API"
  spec.description   = "Read environment variables from 1Password fields (dotenv/json/yaml format) or all fields using the op CLI or 1Password Connect Server API. Export local .env files back to 1Password."
  spec.homepage      = "https://github.com/amkisko/opdotenv.rb"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "README.md", "LICENSE*", "CHANGELOG.md"].select { |f| File.file?(f) }
  end
  spec.bindir        = "bin"
  spec.executables   = ["opdotenv"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "source_code_uri" => "https://github.com/amkisko/opdotenv.rb",
    "changelog_uri" => "https://github.com/amkisko/opdotenv.rb/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/amkisko/opdotenv.rb/issues"
  }

  spec.add_runtime_dependency "railties", ">= 6.0", "< 9.0"

  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "rspec", "~> 3"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.6"
  spec.add_development_dependency "simplecov-cobertura", "~> 3"
  spec.add_development_dependency "standard", "~> 1"
  spec.add_development_dependency "appraisal", "~> 2"
  spec.add_development_dependency "webmock", "~> 3"
  spec.add_development_dependency "pry", "~> 0.15"
  spec.add_development_dependency "rbs", "~> 3"
  spec.add_development_dependency "anyway_config", "~> 2.0"
end

