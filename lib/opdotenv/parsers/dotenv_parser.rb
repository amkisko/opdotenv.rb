module Opdotenv
  module Parsers
    class DotenvParser
      def self.parse(text)
        env = {}
        text.to_s.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?("#")
          # Support KEY=VALUE and KEY="VALUE"; ignore export prefix
          line = line.sub(/^export\s+/, "")
          if (m = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/))
            key = m[1]
            raw = m[2]
            value = if raw.start_with?("\"") && raw.end_with?("\"")
              raw[1..-2].gsub('\\"', '"')
            elsif raw.start_with?("'") && raw.end_with?("'")
              raw[1..-2]
            else
              raw
            end
            env[key] = value
          end
        end
        env
      end
    end
  end
end
