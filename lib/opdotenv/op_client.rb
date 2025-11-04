require "json"

module Opdotenv
  class OpClient
    class OpError < StandardError; end

    NOTES_PLAIN_FIELD = "notesPlain"
    SECURE_NOTE_CATEGORY = "secure-note"
    LOGIN_CATEGORY = "LOGIN"

    def initialize(env: ENV)
      @env = env
    end

    def read(path)
      validate_path(path)
      out = capture(["op", "read", path])
      out.strip
    end

    def item_get(item, vault: nil)
      args = ["op", "item", "get", item, "--format", "json"]
      args += ["--vault", vault] if vault
      capture(args)
    end

    def item_create_note(vault:, title:, notes:)
      # Create a Secure Note with given title and notesPlain
      # Use shell escaping to prevent injection
      args = [
        "op", "item", "create",
        "--category", SECURE_NOTE_CATEGORY,
        "--title", title,
        "--vault", vault,
        "#{NOTES_PLAIN_FIELD}=#{notes}"
      ]
      capture(args)
    end

    def item_create_or_update_fields(vault:, item:, fields: {})
      exists = item_exists?(item, vault: vault)
      if exists
        fields.each do |k, v|
          # Use shell escaping to prevent injection
          field_arg = "#{k}=#{v}"
          capture(["op", "item", "edit", item, "--vault", vault, "--set", field_arg])
        end
      else
        args = ["op", "item", "create", "--title", item, "--vault", vault]
        fields.each do |k, v|
          args += ["--set", "#{k}=#{v}"]
        end
        capture(args)
      end
    end

    private

    def item_exists?(item, vault: nil)
      args = ["op", "item", "get", item]
      args += ["--vault", vault] if vault
      system(*args, out: File::NULL, err: File::NULL)
    end

    def validate_path(path)
      return if path.is_a?(String) && path.start_with?("op://")

      raise ArgumentError, "Invalid path format: #{path.inspect}. Must start with 'op://'"
    end

    def capture(args)
      # Use exec-style array to prevent shell injection
      # IO.popen with array arguments avoids shell interpretation
      out = IO.popen(args, err: [:child, :out]) do |io|
        io.read
      end
      status = $CHILD_STATUS

      # For JSON output, try to parse even if exit code is non-zero
      # Some op commands may return non-zero but still output valid JSON
      if args.include?("--format") && args.include?("json")
        begin
          JSON.parse(out)
          return out # Valid JSON, return it even if exit code is non-zero
        rescue JSON::ParserError
          # Not valid JSON, fall through to error handling
        end
      end

      raise OpError, out if status.nil? || !status.success?
      out
    end
  end
end
