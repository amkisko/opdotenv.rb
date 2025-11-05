require "opdotenv"

module Opdotenv
  class Railtie < ::Rails::Railtie
    # This Railtie ensures opdotenv is automatically required when Rails loads
    # and provides configuration via Rails.configuration.opdotenv

    config.opdotenv = ActiveSupport::OrderedOptions.new
    config.opdotenv.sources = []
    # Optional 1Password Connect settings (alternatively set via ENV)
    config.opdotenv.connect_url = nil
    config.opdotenv.connect_token = nil
    # Optional op CLI path (defaults to "op", can also be set via OP_CLI_PATH or OPDOTENV_CLI_PATH env vars)
    config.opdotenv.cli_path = nil
    config.opdotenv.overwrite = true
    config.opdotenv.auto_load = true

    # Hook into Rails initialization to load from 1Password
    initializer "opdotenv.load", before: :load_environment_config do |app|
      config = app.config.opdotenv

      next unless config.auto_load

      # Prefer Connect API settings from Rails configuration if provided
      if config.connect_url && config.connect_token
        ENV["OP_CONNECT_URL"] = config.connect_url
        ENV["OP_CONNECT_TOKEN"] = config.connect_token
      end

      # Set op CLI path from Rails configuration if provided
      if config.cli_path
        ENV["OPDOTENV_CLI_PATH"] = config.cli_path
      end

      # Load from configured sources
      # Sources can be strings (simplified format) or hashes (backward compatibility)
      (config.sources || []).each do |source|
        parsed = SourceParser.parse(source)
        next unless parsed[:path]

        overwrite = if source.is_a?(Hash) && (source.key?(:overwrite) || source.key?("overwrite"))
          parsed[:overwrite]
        else
          config.overwrite
        end

        begin
          Loader.load(
            parsed[:path],
            field_name: parsed[:field_name],
            field_type: parsed[:field_type],
            env: ENV,
            overwrite: overwrite
          )
        rescue => e
          # Only log errors, not warnings, to avoid noise in production
          Rails.logger&.error("Opdotenv: Failed to load #{parsed[:path]}: #{e.message}")
        end
      end
    end
  end
end
