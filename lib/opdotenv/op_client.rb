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
      notes_field = {"id" => NOTES_PLAIN_FIELD, "type" => "STRING", "purpose" => "NOTES", "value" => notes}
      if item_exists?(title, vault: vault)
        payload = JSON.parse(item_get(title, vault: vault))
        existing = payload["fields"]&.find { |field|
          field["id"] == NOTES_PLAIN_FIELD || field["purpose"] == "NOTES" || field["label"] == NOTES_PLAIN_FIELD
        }
        if existing
          existing["value"] = notes
        else
          payload["fields"] ||= []
          payload["fields"] << notes_field
        end
        capture([@cli_path, "item", "edit", title, "--vault", vault], stdin_data: JSON.generate(payload))
      else
        args = [
          @cli_path, "item", "create",
          "--category", SECURE_NOTE_CATEGORY,
          "--title", title,
          "--vault", vault,
          "-"
        ]
        capture(args, stdin_data: JSON.generate({"fields" => [notes_field]}))
      end
    end

    def item_create_or_update_fields(vault:, item:, fields: {})
      exists = item_exists?(item, vault: vault)
      payload = exists ? JSON.parse(item_get(item, vault: vault)) : {"category" => LOGIN_CATEGORY, "fields" => []}
      fields.each do |key, value|
        field = payload["fields"].find { |entry| entry["label"] == key.to_s || entry["id"] == key.to_s }
        if field
          field["value"] = value.to_s
        else
          payload["fields"] << {"type" => "CONCEALED", "label" => key.to_s, "value" => value.to_s}
        end
      end
      args = if exists
        [@cli_path, "item", "edit", item, "--vault", vault]
      else
        [@cli_path, "item", "create", "--title", item, "--vault", vault, "-"]
      end
      capture(args, stdin_data: JSON.generate(payload))
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

    def capture(args, **options)
      # Use exec-style array to prevent shell injection
      # Open3.capture2e captures both stdout and stderr, and properly returns exit status
      out, status = Open3.capture2e(*args, **options)

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
