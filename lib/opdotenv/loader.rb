module Opdotenv
  class Loader
    NOTES_PURPOSE = "NOTES"

    # Unified loading API
    # If field_name is set, fetches a single field and parses it with field_type (default: :dotenv)
    # If field_name is not set, fetches all fields without parsing
    def self.load(path, field_name: nil, field_type: :dotenv, env: ENV, client: nil, overwrite: true)
      client ||= ClientFactory.create(env: env)

      data = field_name ? load_field(client, path, field_name, field_type) : load_all_fields(client, path)

      merge_into_env(env, data, overwrite: overwrite)
      data
    end

    def self.load_field(client, path, field_name, field_type)
      field_path = build_field_path(path, field_name)
      text = client.read(field_path)
      parse_by_format(text, field_type)
    end

    def self.load_all_fields(client, path)
      vault, item = parse_op_path(path)
      raw_json = client.item_get(item, vault: vault)
      item_hash = parse_json_safe(raw_json)

      item_hash["fields"]&.each_with_object({}) do |field, env_data|
        label = field["label"] || field["id"]
        next unless label
        next if field["purpose"] == NOTES_PURPOSE # skip notesPlain when fetching all
        env_data[label.to_s] = (field["value"] || "").to_s
      end || {}
    end

    def self.build_field_path(path, field_name)
      # op CLI requires vault/item/field format
      # Avoid duplication if field name already in path
      path.end_with?("/#{field_name}") ? path : "#{path}/#{field_name}"
    end

    def self.parse_json_safe(json_string)
      JSON.parse(json_string)
    rescue JSON::ParserError
      {}
    end

    def self.parse_by_format(text, format)
      case format
      when :dotenv then Parsers::DotenvParser.parse(text)
      when :json then Parsers::JsonParser.parse(text)
      when :yaml, :yml then Parsers::YamlParser.parse(text)
      else
        raise ArgumentError, "Unsupported format: #{format}. Supported: :dotenv, :json, :yaml"
      end
    end

    def self.parse_op_path(path)
      m = path.match(/\Aop:\/\/([^\/]*)\/([^\/]*)/)
      raise ArgumentError, "Invalid op path: #{path}" unless m
      [m[1], m[2]]
    end

    def self.merge_into_env(env, hash, overwrite: true)
      hash.each do |k, v|
        key = k.to_s
        next if !overwrite && env.key?(key)
        env[key] = v.to_s
      end
    end
  end
end
