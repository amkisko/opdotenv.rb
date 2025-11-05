require "net/http"
require "uri"

module Opdotenv
  class ConnectApiClient
    class ConnectApiError < StandardError; end

    NOTES_PLAIN_FIELD = "notesPlain"
    NOTES_PURPOSE = "NOTES"
    SECURE_NOTE_CATEGORY = "SECURE_NOTE"
    LOGIN_CATEGORY = "LOGIN"

    def initialize(base_url:, access_token:, env: ENV)
      validate_url(base_url)
      validate_token(access_token)
      @base_url = base_url.chomp("/")
      @access_token = access_token
      @env = env
    end

    # Parse op:// style path or connect:// style path
    # op://Vault/Item -> {vault: "Vault", item: "Item", field: nil}
    # op://Vault/Item/notesPlain -> {vault: "Vault", item: "Item", field: "notesPlain"}
    # op://Vault/Item/Section/Field -> {vault: "Vault", item: "Item", field: "Field"}
    def read(path)
      parsed = parse_path(path)
      item = get_item(parsed[:vault], parsed[:item])

      if parsed[:field]
        # Read specific field
        field = find_field(item, parsed[:field])
        field ? field["value"] : ""
      else
        # Read notesPlain for secure notes
        notes_field = item["fields"]&.find { |f| f["purpose"] == NOTES_PURPOSE || f["label"] == NOTES_PLAIN_FIELD }
        notes_field ? notes_field["value"] : ""
      end
    end

    def item_get(item_title, vault: nil)
      # If vault not provided, search all vaults (requires listing vaults)
      if vault.nil?
        item = find_item_in_all_vaults(item_title)
        raise ConnectApiError, "Item '#{item_title}' not found" unless item
      else
        vault_id = vault_name_to_id(vault)
        item = item_by_title_in_vault(vault_id, item_title)
        raise ConnectApiError, "Item '#{item_title}' not found in vault '#{vault}'" unless item
      end

      JSON.pretty_generate(item)
    end

    def find_item_in_all_vaults(item_title)
      vaults = list_vaults
      vaults.each do |v|
        item = item_by_title_in_vault(v["id"], item_title)
        return item if item
      end
      nil
    end

    def item_create_note(vault:, title:, notes:)
      vault_id = vault_name_to_id(vault)

      payload = {
        "vault" => {"id" => vault_id},
        "title" => title,
        "category" => SECURE_NOTE_CATEGORY,
        "fields" => [
          {
            "purpose" => NOTES_PURPOSE,
            "value" => notes
          }
        ]
      }

      response = api_request(:post, "/v1/vaults/#{vault_id}/items", payload)
      JSON.pretty_generate(response)
    end

    def item_create_or_update_fields(vault:, item:, fields: {})
      vault_id = vault_name_to_id(vault)

      # Try to find existing item by title
      existing = item_by_title_in_vault(vault_id, item)

      if existing
        # Update using PATCH
        fields_array = fields.map do |k, v|
          existing_field = existing["fields"]&.find { |f| f["label"] == k.to_s }
          if existing_field
            {
              "op" => "replace",
              "path" => "/fields/#{existing_field["id"]}/value",
              "value" => v.to_s
            }
          else
            {
              "op" => "add",
              "path" => "/fields",
              "value" => {
                "type" => "CONCEALED",
                "label" => k.to_s,
                "value" => v.to_s
              }
            }
          end
        end

        api_request(:patch, "/v1/vaults/#{vault_id}/items/#{existing["id"]}", fields_array)
      else
        # Create new item
        fields_array = fields.map do |k, v|
          {
            "type" => "CONCEALED",
            "label" => k.to_s,
            "value" => v.to_s
          }
        end

        payload = {
          "vault" => {"id" => vault_id},
          "title" => item,
          "category" => LOGIN_CATEGORY,
          "fields" => fields_array
        }

        api_request(:post, "/v1/vaults/#{vault_id}/items", payload)
      end
    end

    private

    def parse_path(path)
      # op://Vault/Item or connect://Vault/Item
      match = path.match(/\A(?:op|connect):\/\/([^\/]+)\/([^\/]+)(?:\/(.+))?\z/)
      raise ConnectApiError, "Invalid path format: #{path}" unless match

      {
        vault: match[1],
        item: match[2],
        field: match[3]
      }
    end

    def vault_name_to_id(vault_name)
      @vault_cache ||= {}
      return @vault_cache[vault_name] if @vault_cache.key?(vault_name)

      vaults = list_vaults
      vault = vaults.find { |v| v["name"] == vault_name || v["id"] == vault_name }
      raise ConnectApiError, "Vault '#{vault_name}' not found" unless vault

      @vault_cache[vault_name] = vault["id"]
    end

    def list_vaults
      api_request(:get, "/v1/vaults")
    end

    def get_item(vault_name, item_title)
      vault_id = vault_name_to_id(vault_name)
      item = item_by_title_in_vault(vault_id, item_title)
      raise ConnectApiError, "Item '#{item_title}' not found in vault '#{vault_name}'" unless item

      # Fetch full item details including fields
      api_request(:get, "/v1/vaults/#{vault_id}/items/#{item["id"]}")
    end

    def item_by_title_in_vault(vault_id, item_title)
      # List items and find by title
      items = api_request(:get, "/v1/vaults/#{vault_id}/items")
      item = items.find { |i| i["title"] == item_title || i["id"] == item_title }
      # If found by listing, fetch full details to get fields
      if item && item["id"]
        api_request(:get, "/v1/vaults/#{vault_id}/items/#{item["id"]}")
      else
        item
      end
    end

    def find_field(item, field_name)
      item["fields"]&.find do |f|
        f["label"] == field_name ||
          f["id"] == field_name ||
          (field_name == NOTES_PLAIN_FIELD && f["purpose"] == NOTES_PURPOSE)
      end
    end

    def api_request(method, path, body = nil)
      uri = build_uri(path)
      http = build_http_client(uri)

      request = build_request(method, uri, body)
      response = execute_request_with_retry(http, request)

      handle_response(response, path)
    end

    def build_uri(path)
      # Validate path to prevent path traversal attacks
      # API paths legitimately start with "/", so only check for ".."
      raise ConnectApiError, "Invalid path: #{path}" if path.include?("..")

      # Use URI.join which handles path normalization safely
      # URI.join expects base URL without trailing slash for proper joining
      base_uri = @base_url.end_with?("/") ? @base_url[0..-2] : @base_url
      normalized_path = path.start_with?("/") ? path : "/#{path}"
      URI.join(base_uri, normalized_path)
    end

    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = (@env["OPDOTENV_HTTP_OPEN_TIMEOUT"] || 5).to_i
      http.read_timeout = (@env["OPDOTENV_HTTP_READ_TIMEOUT"] || 10).to_i
      http
    end

    def build_request(method, uri, body)
      request_class = case method
      when :get then Net::HTTP::Get
      when :post then Net::HTTP::Post
      when :put then Net::HTTP::Put
      when :patch then Net::HTTP::Patch
      when :delete then Net::HTTP::Delete
      else raise ConnectApiError, "Unsupported HTTP method: #{method}"
      end

      request = request_class.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body) if body
      request
    end

    def execute_request_with_retry(http, request)
      attempts = 0
      begin
        attempts += 1
        http.request(request)
      rescue Timeout::Error, Errno::ECONNRESET
        raise if attempts >= 2
        sleep 0.2
        retry
      end
    end

    def handle_response(response, path)
      code = response.code.to_i

      case code
      when 200, 204
        return {} if response.body.empty? || code == 204
        JSON.parse(response.body)
      when 401
        raise ConnectApiError, "Unauthorized: Invalid or missing access token"
      when 403
        raise ConnectApiError, "Forbidden: Access denied"
      when 404
        raise ConnectApiError, "Not found: #{path}"
      when 500..599
        raise ConnectApiError, "API error (#{code}): Server error"
      else
        # Extract safe error message without leaking response body
        safe_message = extract_safe_error_message(response)
        raise ConnectApiError, "API error (#{code}): #{safe_message}"
      end
    end

    def extract_safe_error_message(response)
      # Only extract structured error messages from JSON responses
      # Never include raw response body to avoid leaking secrets

      parsed = JSON.parse(response.body)
      # Only return known safe fields that are typically error messages
      parsed["message"] || parsed["error"] || "Request failed"
    rescue JSON::ParserError
      # For non-JSON responses, return generic message to avoid leaking body
      "Request failed"
    end

    def validate_url(url)
      uri = URI.parse(url)
      unless ["http", "https"].include?(uri.scheme)
        raise ArgumentError, "Invalid URL scheme: #{uri.scheme}. Must be http or https"
      end
    rescue URI::InvalidURIError => e
      raise ArgumentError, "Invalid URL: #{url} - #{e.message}"
    end

    def validate_token(token)
      raise ArgumentError, "Access token cannot be empty" if token.nil? || token.empty?
    end
  end
end
