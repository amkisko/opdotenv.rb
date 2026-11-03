module Opdotenv
  # Shared module for format inference from item/field names
  module FormatInferrer
    module_function

    JSON_EXTENSIONS = [".json"].freeze
    YAML_EXTENSIONS = [".yaml", ".yml"].freeze

    def infer_from_name(name)
      base = File.basename(name.to_s)
      return :dotenv if dotenv_basename?(base)
      return :json if JSON_EXTENSIONS.any? { |ext| base.end_with?(ext) }
      return :yaml if YAML_EXTENSIONS.any? { |ext| base.end_with?(ext) }

      nil
    end

    def dotenv_basename?(base)
      base == ".env" ||
        base.start_with?(".env.") ||
        base.include?(" .env.") ||
        base.end_with?(" .env")
    end

    def matches_format_pattern?(name)
      !infer_from_name(name).nil?
    end
  end
end
