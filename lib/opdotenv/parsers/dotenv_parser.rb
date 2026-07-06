module Opdotenv
  module Parsers
    class DotenvParser
      def self.parse(text)
        text.to_s.each_line.with_object({}) do |line, env|
          entry = parse_line(line)
          next unless entry

          env[entry[:key]] = entry[:value]
        end
      end

      def self.parse_line(line)
        line = line.strip
        return nil if line.empty? || line.start_with?("#")

        line = line.sub(/^export\s+/, "")
        match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/)
        return nil unless match

        {key: match[1], value: unquote_value(match[2])}
      end

      def self.unquote_value(raw)
        if raw.start_with?("\"") && raw.end_with?("\"")
          raw[1..-2].gsub('\\"', '"')
        elsif raw.start_with?("'") && raw.end_with?("'")
          raw[1..-2]
        else
          raw
        end
      end
    end
  end
end
