module Opdotenv
  # Anyway Config loader to fetch configuration from 1Password via opdotenv.
  # Usage per-config:
  #   class MyConfig < Anyway::Config
  #     loader_options opdotenv: {
  #       path: "op://Vault/.env.development"  # format inferred from item name
  #     }
  #   end
  module AnywayLoader
    class Loader < ::Anyway::Loaders::Base
      def call(name:, env_prefix:, config_path:, **opts)
        options = opts[:opdotenv] || {}
        return {} if options.empty?

        path = options[:path] || options["path"]
        raise ArgumentError, "opdotenv loader requires :path" unless path

        parsed = SourceParser.parse(path)
        overwrite = options.key?(:overwrite) ? options[:overwrite] : true

        # Use a separate env hash to avoid side effects on global ENV
        data = Opdotenv::Loader.load(
          path,
          field_name: parsed[:field_name],
          field_type: parsed[:field_type],
          env: {},
          overwrite: overwrite
        )

        strip_prefix_from_keys(data, env_prefix)
      end

      private

      def strip_prefix_from_keys(data, env_prefix)
        return data unless defined?(::Anyway::Env) && defined?(::Anyway::NoCast)

        # Strict matching with case-insensitive prefix: Only fields with env_prefix will be matched
        # Normalize keys to uppercase for case-insensitive matching
        normalized_data = normalize_keys_for_prefix_matching(data, env_prefix)

        # Use Anyway::Env to handle prefix stripping, matching how Doppler loader works
        # This transforms keys like "TEST_ENABLED" -> "enabled" when env_prefix is "TEST"
        env = ::Anyway::Env.new(type_cast: ::Anyway::NoCast, env_container: normalized_data)
        conf, trace = env.fetch_with_trace(env_prefix)

        if defined?(::Anyway::Tracing) && ::Anyway::Tracing.current_trace
          ::Anyway::Tracing.current_trace.merge!(trace)
        end

        # Log available fields for debugging (only when OPDOTENV_DEBUG is enabled)
        log_available_fields(data, env_prefix, conf)

        conf
      end

      def normalize_keys_for_prefix_matching(data, env_prefix)
        return data if data.empty? || env_prefix.empty?

        prefix_upper = env_prefix.upcase
        prefix_with_underscore = "#{prefix_upper}_"

        normalized = {}
        data.each do |key, value|
          key_str = key.to_s
          key_upper = key_str.upcase

          # Case-insensitive prefix matching: only include keys that start with PREFIX_
          if key_upper.start_with?(prefix_with_underscore) || key_upper == prefix_upper
            # Normalize to uppercase for consistent matching
            normalized_key = key_upper
            normalized[normalized_key] = value
          end
        end

        normalized
      end

      def log_available_fields(original_data, env_prefix, matched_data)
        return unless ENV["OPDOTENV_DEBUG"] == "true"
        return unless defined?(Rails) && Rails.logger

        prefix_upper = env_prefix.upcase
        prefix_with_underscore = "#{prefix_upper}_"

        available_fields = original_data.keys.map(&:to_s)
        matched_fields = matched_data.keys.map(&:to_s)

        # Find fields that were available but didn't match the prefix (case-insensitive)
        unmatched = available_fields.reject do |field|
          field_upper = field.to_s.upcase
          field_upper.start_with?(prefix_with_underscore) || field_upper == prefix_upper
        end

        if available_fields.any?
          Rails.logger.debug("[opdotenv] Available fields from 1Password: #{available_fields.join(", ")}")
          Rails.logger.debug("[opdotenv] Matched fields for #{env_prefix} (prefixed with #{prefix_with_underscore}, case-insensitive): #{matched_fields.join(", ")}")
          if unmatched.any?
            Rails.logger.debug("[opdotenv] Unmatched fields (must be prefixed with #{prefix_with_underscore}, case-insensitive): #{unmatched.join(", ")}")
            Rails.logger.debug("[opdotenv] To use these fields, rename them in 1Password to include the #{prefix_with_underscore} prefix")
          end
        end
      end
    end

    def self.register!
      ::Anyway.loaders.append :opdotenv, Loader
    end
  end
end

begin
  # Auto-register if Anyway is available
  # Silently skip if Anyway Config is not available or not fully loaded
  if defined?(::Anyway) && ::Anyway.respond_to?(:loaders)
    Opdotenv::AnywayLoader.register!
  end
rescue => e
  # Only warn if debugging is enabled, as this is expected when Anyway Config isn't used
  if ENV["OPDOTENV_DEBUG"] == "true"
    warn "[opdotenv] Failed to register Anyway loader: #{e.message}"
    warn "[opdotenv] Error details: #{e.class}: #{e.message}"
    warn "[opdotenv] Backtrace: #{e.backtrace.first(3).join("\n")}" if e.backtrace
  end
end
