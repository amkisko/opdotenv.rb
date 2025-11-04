require "json"
require "yaml"
require "shellwords"

require_relative "opdotenv/version"
require_relative "opdotenv/format_inferrer"
require_relative "opdotenv/op_client"
require_relative "opdotenv/connect_api_client"
require_relative "opdotenv/client_factory"
require_relative "opdotenv/parsers/dotenv_parser"
require_relative "opdotenv/parsers/json_parser"
require_relative "opdotenv/parsers/yaml_parser"
require_relative "opdotenv/source_parser"
require_relative "opdotenv/loader"
require_relative "opdotenv/exporter"
require_relative "opdotenv/anyway_loader" if defined?(Anyway)

# Ensure Railtie is loaded so Rails auto-discovers it
require_relative "opdotenv/railtie" if defined?(Rails)
