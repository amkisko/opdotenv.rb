module Opdotenv
  class Exporter
    # Export data to 1Password
    # Paths like "op://Vault/.env.development" or "op://Vault/config.json" create Secure Notes (format inferred from item name extension)
    # Paths like "op://Vault/App" create/update item fields
    # Format is inferred from item name extension: .env.*, *.json, *.yaml, *.yml
    # @param path [String] Path like "op://Vault/.env.development", "op://Vault/production.json", or "op://Vault/App"
    # @param data [Hash] Data to export
    # @param field_type [Symbol] Format override (:dotenv, :json, :yaml). Default: inferred from path
    def self.export(path:, data:, field_type: nil, client: nil, env: ENV)
      client ||= ClientFactory.create(env: env)
      vault, item = Loader.parse_op_path(path)

      # Extract item name and potential field name
      # Handle paths like "op://Vault/Item" or "op://Vault/Item Name/field"
      item_parts = item.split("/")
      item_name = item_parts.first

      # Check if path matches format patterns (Secure Note) or regular item (fields)
      if FormatInferrer.matches_format_pattern?(item_name)
        # Create Secure Note
        field_type ||= FormatInferrer.infer_from_name(item_name) || :dotenv
        content = serialize_by_format(data, field_type)
        client.item_create_note(vault: vault, title: item_name, notes: content)
      else
        # Create/update item with fields
        flat = data.transform_values(&:to_s)
        client.item_create_or_update_fields(vault: vault, item: item_name, fields: flat)
      end
    end

    def self.infer_format_from_item(item)
      FormatInferrer.infer_from_name(item) || :dotenv
    end

    def self.serialize_by_format(data, format)
      case format
      when :dotenv
        data.map { |k, v| "#{k}=#{escape_env(v)}" }.join("\n") + "\n"
      when :json
        JSON.pretty_generate(data)
      when :yaml, :yml
        YAML.dump(data)
      else
        raise ArgumentError, "Unsupported format: #{format}. Supported: :dotenv, :json, :yaml"
      end
    end

    def self.escape_env(value)
      s = value.to_s
      return '""' if s.empty?
      if s.match?(/\s|["'#]/)
        '"' + s.gsub('"', '\\"') + '"'
      else
        s
      end
    end
  end
end
