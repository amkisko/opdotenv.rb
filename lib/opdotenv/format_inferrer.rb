module Opdotenv
  # Shared module for format inference from item/field names
  module FormatInferrer
    module_function

    DOTENV_PATTERN = /\.env\.?/
    JSON_EXTENSIONS = [".json"].freeze
    YAML_EXTENSIONS = [".yaml", ".yml"].freeze

    def infer_from_name(name)
      return :dotenv if name.match?(DOTENV_PATTERN)
      return :json if JSON_EXTENSIONS.any? { |ext| name.end_with?(ext) }
      return :yaml if YAML_EXTENSIONS.any? { |ext| name.end_with?(ext) }

      nil
    end

    def matches_format_pattern?(name)
      !infer_from_name(name).nil?
    end
  end
end
