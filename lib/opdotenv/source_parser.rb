module Opdotenv
  # Parser for simplified source strings
  # Infers field_name and field_type from the path pattern
  module SourceParser
    NOTES_PLAIN_FIELD = "notesPlain"

    module_function

    # Parse a source string or hash into normalized format
    #
    # @param source [String, Hash] Source string (e.g., "op://Vault/Item") or hash for backward compatibility
    # @return [Hash] Normalized source with :path, :field_name, and :field_type keys
    def parse(source)
      # Handle hash format for backward compatibility
      return normalize_hash(source) if source.is_a?(Hash)

      # Handle string format
      raise ArgumentError, "Source must start with 'op://'" unless source.to_s.start_with?("op://")

      path = source.to_s
      _, item = parse_op_path(path)

      # Extract item name and potential field name
      # Handle paths like "op://Vault/Item" or "op://Vault/Item Name/field"
      item_parts = item.split("/")
      item_name = item_parts.first
      field_name = (item_parts.length > 1) ? item_parts[1] : nil

      # First check if field name is provided with extension in the path
      if field_name
        field_type = FormatInferrer.infer_from_name(field_name)
        {path: path, field_name: field_name, field_type: field_type}
      # If no field name in path, infer from item name patterns
      elsif (field_type = FormatInferrer.infer_from_name(item_name))
        {path: path, field_name: NOTES_PLAIN_FIELD, field_type: field_type}
      else
        # All other items: load all fields without parsing
        {path: path, field_name: nil, field_type: nil}
      end
    end

    # Parse op:// path to extract vault and item
    #
    # @param path [String] Path like "op://Vault/Item" or "op://Vault/Item/Field"
    # @return [Array<String>] [vault, item] tuple
    def parse_op_path(path)
      m = path.match(/\Aop:\/\/([^\/]+)\/(.+)/)
      raise ArgumentError, "Invalid op path: #{path}" unless m
      [m[1], m[2]]
    end

    # Normalize hash format for backward compatibility
    #
    # @param source [Hash] Source hash with :path, :field_name, :field_type keys
    # @return [Hash] Normalized source
    def normalize_hash(source)
      {
        path: source[:path] || source["path"],
        field_name: source[:field_name] || source["field_name"],
        field_type: (source[:field_type] || source["field_type"])&.to_sym,
        overwrite: if source.key?(:overwrite)
                     source[:overwrite]
                   else
                     (source.key?("overwrite") ? source["overwrite"] : nil)
                   end
      }
    end

    module_function :normalize_hash
  end
end
