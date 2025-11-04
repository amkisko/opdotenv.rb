module Opdotenv
  module Parsers
    class JsonParser
      def self.parse(text)
        data = JSON.parse(text.to_s)
        flatten_to_string_map(data)
      end

      def self.flatten_to_string_map(obj, prefix = nil, out = {})
        case obj
        when Hash
          obj.each do |k, v|
            key = prefix ? "#{prefix}_#{k}" : k.to_s
            flatten_to_string_map(v, key, out)
          end
        when Array
          obj.each_with_index do |v, i|
            key = prefix ? "#{prefix}_#{i}" : i.to_s
            flatten_to_string_map(v, key, out)
          end
        else
          out[prefix.to_s] = obj.to_s
        end
        out
      end
    end
  end
end
