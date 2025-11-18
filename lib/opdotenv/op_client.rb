require "json"
require "open3"

module Opdotenv
  class OpClient
    class OpError < StandardError; end

    NOTES_PLAIN_FIELD = "notesPlain"
    SECURE_NOTE_CATEGORY = "secure-note"
    LOGIN_CATEGORY = "LOGIN"

    def initialize(env: ENV, cli_path: nil)
      @env = env
      @cli_path = cli_path || env["OP_CLI_PATH"] || env["OPDOTENV_CLI_PATH"] || "op"
    end

    def read(path)
      validate_path(path)
      out = capture([@cli_path, "read", path])
      out.strip
    end

    def item_get(item, vault: nil)
      args = [@cli_path, "item", "get", item, "--format", "json"]
      args += ["--vault", vault] if vault
      capture(args)
    end

    def item_create_note(vault:, title:, notes:)
      # Create a Secure Note with given title and notesPlain
      # Use shell escaping to prevent injection
      args = [
        @cli_path, "item", "create",
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
          capture([@cli_path, "item", "edit", item, "--vault", vault, "--set", field_arg])
        end
      else
        args = [@cli_path, "item", "create", "--title", item, "--vault", vault]
        fields.each do |k, v|
          args += ["--set", "#{k}=#{v}"]
        end
        capture(args)
      end
    end

    private

    def item_exists?(item, vault: nil)
      args = [@cli_path, "item", "get", item]
      args += ["--vault", vault] if vault
      system(*args, out: File::NULL, err: File::NULL)
    end

    def validate_path(path)
      return if path.is_a?(String) && path.start_with?("op://")

      raise ArgumentError, "Invalid path format: #{path.inspect}. Must start with 'op://'"
    end

    def capture(args)
      # Use exec-style array to prevent shell injection
      # Open3.capture2e captures both stdout and stderr, and properly returns exit status
      out, status = Open3.capture2e(*args)

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

      unless status.success?
        # Never leak command output in error messages for security
        # Extract safe error information without exposing secrets
        exit_code = status.exitstatus
        command_name = args.first || "op"
        raise OpError, "Command failed: #{command_name} (exit code: #{exit_code})"
      end
      out
    end
  end
end
