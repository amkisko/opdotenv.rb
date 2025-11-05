require "spec_helper"

RSpec.describe Opdotenv::ConnectApiClient do
  let(:base_url) { "http://localhost:8080" }
  let(:access_token) { "test-token" }
  let(:client) { described_class.new(base_url: base_url, access_token: access_token) }

  describe "#read" do
    it "reads notesPlain from secure note" do
      item_response = {
        "id" => "item-uuid",
        "title" => "TestItem",
        "fields" => [{"purpose" => "NOTES", "value" => "FOO=bar\nBAZ=qux\n"}]
      }

      allow(client).to receive(:get_item).with("TestVault", "TestItem").and_return(item_response)

      result = client.read("op://TestVault/TestItem")
      expect(result).to eq("FOO=bar\nBAZ=qux\n")
    end

    it "reads specific field by label" do
      item_response = {
        "id" => "item-uuid",
        "title" => "TestItem",
        "fields" => [
          {"label" => "API_KEY", "value" => "secret123"},
          {"label" => "API_SECRET", "value" => "secret456"}
        ]
      }

      allow(client).to receive(:get_item).with("TestVault", "TestItem").and_return(item_response)

      result = client.read("op://TestVault/TestItem/API_KEY")
      expect(result).to eq("secret123")
    end

    it "raises on invalid path format" do
      expect { client.read("invalid-path") }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Invalid path format/)
    end
  end

  describe "#item_create_note" do
    it "creates secure note with notesPlain" do
      create_response = {"id" => "new-item-uuid", "title" => "NewNote"}

      allow(client).to receive(:vault_name_to_id).with("TestVault").and_return("vault-uuid")
      allow(client).to receive(:api_request).with(:post, "/v1/vaults/vault-uuid/items", hash_including(
        "category" => "SECURE_NOTE",
        "title" => "NewNote",
        "fields" => [{"purpose" => "NOTES", "value" => "content"}]
      )).and_return(create_response)

      result = client.item_create_note(vault: "TestVault", title: "NewNote", notes: "content")
      expect(result).to include("NewNote")
    end
  end

  describe "#item_create_or_update_fields" do
    it "creates new item when it does not exist" do
      create_response = {"id" => "new-item-uuid"}

      allow(client).to receive(:vault_name_to_id).with("TestVault").and_return("vault-uuid")
      allow(client).to receive(:item_by_title_in_vault).with("vault-uuid", "NewItem").and_return(nil)
      allow(client).to receive(:api_request).with(:post, "/v1/vaults/vault-uuid/items", hash_including(
        "title" => "NewItem",
        "category" => "LOGIN"
      )).and_return(create_response)

      client.item_create_or_update_fields(vault: "TestVault", item: "NewItem", fields: {"KEY" => "value"})
      expect(client).to have_received(:api_request).with(:post, anything, anything)
    end

    it "updates existing item with PATCH" do
      existing_item = {
        "id" => "item-uuid",
        "title" => "ExistingItem",
        "fields" => [{"id" => "field-uuid", "label" => "KEY", "value" => "old"}]
      }

      allow(client).to receive(:vault_name_to_id).with("TestVault").and_return("vault-uuid")
      allow(client).to receive(:item_by_title_in_vault).with("vault-uuid", "ExistingItem").and_return(existing_item)
      allow(client).to receive(:api_request).with(:patch, "/v1/vaults/vault-uuid/items/item-uuid", anything).and_return({})

      client.item_create_or_update_fields(vault: "TestVault", item: "ExistingItem", fields: {"KEY" => "new"})
      expect(client).to have_received(:api_request).with(:patch, anything, array_including(hash_including("op" => "replace")))
    end

    it "adds new field when updating existing item with PATCH" do
      existing_item = {
        "id" => "item-uuid",
        "title" => "ExistingItem",
        "fields" => [{"id" => "field-uuid", "label" => "EXISTING", "value" => "old"}]
      }

      allow(client).to receive(:vault_name_to_id).with("TestVault").and_return("vault-uuid")
      allow(client).to receive(:item_by_title_in_vault).with("vault-uuid", "ExistingItem").and_return(existing_item)
      allow(client).to receive(:api_request).with(:patch, "/v1/vaults/vault-uuid/items/item-uuid", anything).and_return({})

      client.item_create_or_update_fields(vault: "TestVault", item: "ExistingItem", fields: {"NEW_FIELD" => "value"})
      expect(client).to have_received(:api_request).with(:patch, anything, array_including(hash_including("op" => "add")))
    end
  end

  describe "#api_request" do
    let(:http) { instance_double(Net::HTTP) }
    let(:response) { instance_double(Net::HTTPResponse, code: "200", body: '{"test":"data"}', is_a?: true) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(response)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    it "makes GET request with authorization header" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      result = client.send(:api_request, :get, "/v1/vaults")

      expect(request).to have_received(:[]=).with("Authorization", "Bearer #{access_token}")
      expect(http).to have_received(:request).with(request)
      expect(result).to eq({"test" => "data"})
    end

    it "handles 401 unauthorized" do
      unauthorized = instance_double(Net::HTTPResponse, code: "401", body: "")
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)
      allow(http).to receive(:request).and_return(unauthorized)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Unauthorized/)
    end

    it "handles 404 not found" do
      not_found = instance_double(Net::HTTPResponse, code: "404", body: "")
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)
      allow(http).to receive(:request).and_return(not_found)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Not found/)
    end

    it "handles 403 forbidden" do
      forbidden = instance_double(Net::HTTPResponse, code: "403", body: "")
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)
      allow(http).to receive(:request).and_return(forbidden)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Forbidden/)
    end

    it "handles 5xx error with generic message" do
      server_error = instance_double(Net::HTTPResponse, code: "500", body: "")
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)
      allow(http).to receive(:request).and_return(server_error)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error/)
    end

    it "handles POST with JSON body" do
      request = instance_double(Net::HTTP::Post)
      allow(Net::HTTP::Post).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
      uri = URI.parse("http://localhost:8080/v1/vaults/test/items")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/test/items").and_return(uri)

      client.send(:api_request, :post, "/v1/vaults/test/items", {"key" => "value"})

      expect(request).to have_received(:body=).with('{"key":"value"}')
    end

    it "handles PUT method" do
      request = instance_double(Net::HTTP::Put)
      allow(Net::HTTP::Put).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
      uri = URI.parse("http://localhost:8080/v1/vaults/test/items/item-id")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/test/items/item-id").and_return(uri)

      client.send(:api_request, :put, "/v1/vaults/test/items/item-id", {"key" => "value"})

      expect(request).to have_received(:body=).with('{"key":"value"}')
    end

    it "handles PATCH method" do
      request = instance_double(Net::HTTP::Patch)
      allow(Net::HTTP::Patch).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
      uri = URI.parse("http://localhost:8080/v1/vaults/test/items/item-id")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/test/items/item-id").and_return(uri)

      client.send(:api_request, :patch, "/v1/vaults/test/items/item-id", [{"op" => "replace", "path" => "/fields/0/value", "value" => "new"}])

      expect(request).to have_received(:body=).with('[{"op":"replace","path":"/fields/0/value","value":"new"}]')
    end

    it "handles 204 no content response" do
      no_content = instance_double(Net::HTTPResponse, code: "204", body: "")
      request = instance_double(Net::HTTP::Delete)
      allow(Net::HTTP::Delete).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults/test/items/item")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/test/items/item").and_return(uri)
      allow(http).to receive(:request).and_return(no_content)

      result = client.send(:api_request, :delete, "/v1/vaults/test/items/item")
      expect(result).to eq({})
    end

    it "handles error responses with JSON error messages" do
      error_response = instance_double(Net::HTTPResponse, code: "400", body: '{"message":"Bad request"}')
      request = instance_double(Net::HTTP::Post)
      allow(Net::HTTP::Post).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
      uri = URI.parse("http://localhost:8080/v1/vaults/test/items")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults/test/items").and_return(uri)
      allow(http).to receive(:request).and_return(error_response)

      expect {
        client.send(:api_request, :post, "/v1/vaults/test/items", {})
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Bad request/)
    end

    it "handles 400 with plain text error" do
      error_response = instance_double(Net::HTTPResponse, code: "400", body: "Invalid request")
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)
      allow(http).to receive(:request).and_return(error_response)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /API error \(400\): Invalid request/)
    end

    it "handles 200 with empty body" do
      empty_response = instance_double(Net::HTTPResponse, code: "200", body: "")
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)
      allow(http).to receive(:request).and_return(empty_response)

      result = client.send(:api_request, :get, "/v1/vaults")
      expect(result).to eq({})
    end
  end

  describe "#parse_path" do
    it "parses op:// style paths" do
      result = client.send(:parse_path, "op://Vault/Item")
      expect(result).to eq({vault: "Vault", item: "Item", field: nil})
    end

    it "parses paths with fields" do
      result = client.send(:parse_path, "op://Vault/Item/FieldName")
      expect(result).to eq({vault: "Vault", item: "Item", field: "FieldName"})
    end

    it "parses connect:// style paths" do
      result = client.send(:parse_path, "connect://Vault/Item")
      expect(result).to eq({vault: "Vault", item: "Item", field: nil})
    end
  end

  describe "#vault_name_to_id" do
    it "resolves vault name to UUID" do
      vaults = [{"id" => "vault-123", "name" => "MyVault"}]
      allow(client).to receive(:list_vaults).and_return(vaults)

      result = client.send(:vault_name_to_id, "MyVault")
      expect(result).to eq("vault-123")
    end

    it "accepts UUID directly" do
      vaults = [{"id" => "vault-123", "name" => "MyVault"}]
      allow(client).to receive(:list_vaults).and_return(vaults)

      result = client.send(:vault_name_to_id, "vault-123")
      expect(result).to eq("vault-123")
    end

    it "raises when vault not found" do
      vaults = [{"id" => "vault-123", "name" => "MyVault"}]
      allow(client).to receive(:list_vaults).and_return(vaults)

      expect {
        client.send(:vault_name_to_id, "NotFound")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Vault 'NotFound' not found/)
    end
  end

  describe "#initialize" do
    it "raises on invalid URL scheme" do
      expect {
        described_class.new(base_url: "ftp://example.com", access_token: "token")
      }.to raise_error(ArgumentError, /Invalid URL scheme/)
    end

    it "raises on invalid URI format" do
      expect {
        described_class.new(base_url: "not a valid url", access_token: "token")
      }.to raise_error(ArgumentError, /Invalid URL/)
    end

    it "raises on empty access token" do
      expect {
        described_class.new(base_url: "http://localhost:8080", access_token: "")
      }.to raise_error(ArgumentError, /Access token cannot be empty/)
    end

    it "raises on nil access token" do
      expect {
        described_class.new(base_url: "http://localhost:8080", access_token: nil)
      }.to raise_error(ArgumentError, /Access token cannot be empty/)
    end
  end

  describe "#find_item_in_all_vaults" do
    it "returns nil when item not found in any vault" do
      allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
        {"id" => "v1", "name" => "One"}, {"id" => "v2", "name" => "Two"}
      ])
      allow(client).to receive(:item_by_title_in_vault).with("v1", "NotFound").and_return(nil)
      allow(client).to receive(:item_by_title_in_vault).with("v2", "NotFound").and_return(nil)

      result = client.send(:find_item_in_all_vaults, "NotFound")
      expect(result).to be_nil
    end
  end

  describe "#get_item" do
    it "raises when item not found in vault" do
      allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
        {"id" => "v1", "name" => "TestVault"}
      ])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([])

      expect {
        client.send(:get_item, "TestVault", "NotFound")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Item 'NotFound' not found in vault 'TestVault'/)
    end

    it "fetches full item details when item is found" do
      item_summary = {"id" => "i1", "title" => "Item"}
      item_full = {"id" => "i1", "title" => "Item", "fields" => [{"label" => "KEY", "value" => "value"}]}
      allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
        {"id" => "v1", "name" => "TestVault"}
      ])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([item_summary])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items/i1").and_return(item_full)

      result = client.send(:get_item, "TestVault", "Item")
      expect(result).to eq(item_full)
      # Verify the full item fetch was called (line 168)
      expect(client).to have_received(:api_request).with(:get, "/v1/vaults/v1/items/i1").at_least(:once)
    end
  end

  describe "#item_by_title_in_vault" do
    it "returns item when found but has no id field" do
      item_without_id = {"title" => "Item"}
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([item_without_id])

      result = client.send(:item_by_title_in_vault, "v1", "Item")
      expect(result).to eq(item_without_id)
    end

    it "fetches full item details when item has id" do
      item_summary = {"id" => "i1", "title" => "Item"}
      item_full = {"id" => "i1", "title" => "Item", "fields" => []}
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([item_summary])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items/i1").and_return(item_full)

      result = client.send(:item_by_title_in_vault, "v1", "Item")
      expect(result).to eq(item_full)
    end
  end

  describe "#find_field" do
    it "finds field by label and id and notesPlain" do
      item = {
        "fields" => [
          {"id" => "id-1", "label" => "API_KEY", "value" => "v1"},
          {"id" => "id-2", "label" => "notesPlain", "purpose" => "NOTES", "value" => "A=1\n"}
        ]
      }

      f1 = client.send(:find_field, item, "API_KEY")
      expect(f1["value"]).to eq("v1")

      f2 = client.send(:find_field, item, "id-1")
      expect(f2["value"]).to eq("v1")

      f3 = client.send(:find_field, item, "notesPlain")
      expect(f3["value"]).to eq("A=1\n")
    end
  end

  describe "#read edge cases" do
    it "returns empty string when field not found" do
      item = {"id" => "i1", "title" => "Item", "fields" => [{"label" => "FOO", "value" => "x"}]}
      allow(client).to receive(:get_item).with("Vault", "Item").and_return(item)
      val = client.read("op://Vault/Item/BAR")
      expect(val).to eq("")
    end

    it "returns empty when no notesPlain present" do
      item = {"id" => "i1", "title" => "Item", "fields" => []}
      allow(client).to receive(:get_item).with("Vault", "Item").and_return(item)
      val = client.read("op://Vault/Item")
      expect(val).to eq("")
    end
  end

  describe "#item_get" do
    it "searches all vaults when vault is nil" do
      allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
        {"id" => "v1", "name" => "One"}, {"id" => "v2", "name" => "Two"}
      ])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([
        {"id" => "i1", "title" => "Item"}
      ])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items/i1").and_return({"id" => "i1", "title" => "Item", "fields" => []})

      json = client.item_get("Item", vault: nil)
      parsed = JSON.parse(json)
      expect(parsed["title"]).to eq("Item")
    end

    it "fetches specific vault when provided" do
      allow(client).to receive(:api_request).with(:get, "/v1/vaults").and_return([
        {"id" => "v1", "name" => "Target"}
      ])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items").and_return([
        {"id" => "i2", "title" => "Cfg"}
      ])
      allow(client).to receive(:api_request).with(:get, "/v1/vaults/v1/items/i2").and_return({"id" => "i2", "title" => "Cfg", "fields" => []})

      json = client.item_get("Cfg", vault: "Target")
      expect(json).to include("Cfg")
    end
  end

  describe "#api_request with query parameters" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "handles path with query string" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).with("/v1/vaults?filter=active").and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults?filter=active")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults?filter=active").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "200", body: "[]")
      allow(http).to receive(:request).and_return(response)

      result = client.send(:api_request, :get, "/v1/vaults?filter=active")
      expect(result).to eq([])
    end
  end

  describe "#api_request unsupported methods" do
    it "raises on unsupported HTTP method" do
      expect {
        client.send(:api_request, :head, "/v1/vaults")
      }.to raise_error(Opdotenv::ConnectApiClient::ConnectApiError, /Unsupported HTTP method/)
    end
  end

  describe "#api_request retries" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
    end

    it "retries once on timeout then succeeds" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "200", body: '{"ok":true}', is_a?: true)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      call_sequence = [-> { raise Timeout::Error }, -> { response }]
      allow(http).to receive(:request) { call_sequence.shift.call }

      result = client.send(:api_request, :get, "/v1/vaults")
      expect(result).to eq({"ok" => true})
    end

    it "raises after second timeout" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      allow(http).to receive(:request).and_raise(Timeout::Error)

      expect {
        client.send(:api_request, :get, "/v1/vaults")
      }.to raise_error(Timeout::Error)
    end

    it "retries once on ECONNRESET then succeeds" do
      request = instance_double(Net::HTTP::Get)
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      uri = URI.parse("http://localhost:8080/v1/vaults")
      allow(URI).to receive(:join).with(base_url, "/v1/vaults").and_return(uri)

      response = instance_double(Net::HTTPResponse, code: "200", body: '{"ok":true}', is_a?: true)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      call_sequence = [-> { raise Errno::ECONNRESET }, -> { response }]
      allow(http).to receive(:request) { call_sequence.shift.call }

      result = client.send(:api_request, :get, "/v1/vaults")
      expect(result).to eq({"ok" => true})
    end
  end
end
