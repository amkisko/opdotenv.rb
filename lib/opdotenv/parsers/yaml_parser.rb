require "yaml"

module Opdotenv
  module Parsers
    class YamlParser
      # Safe YAML parsing without aliases (aliases can cause DoS attacks)
      PERMITTED_CLASSES = [Date, Time, Symbol].freeze

      def self.parse(text)
        data = YAML.safe_load(text.to_s, permitted_classes: PERMITTED_CLASSES, aliases: false)
        JsonParser.flatten_to_string_map(data)
      end
    end
  end
end
