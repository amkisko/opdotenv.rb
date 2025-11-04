require "spec_helper"

RSpec.describe Opdotenv::SourceParser do
  describe ".parse" do
    context "with string sources (simplified format)" do
      it "parses .env files as dotenv type" do
        result = described_class.parse("op://ProjectName/.env.development")
        expect(result).to eq({
          path: "op://ProjectName/.env.development",
          field_name: "notesPlain",
          field_type: :dotenv
        })
      end

      it "parses .env files with spaces in item name" do
        result = described_class.parse("op://ProjectName/ProjectName .env.development")
        expect(result).to eq({
          path: "op://ProjectName/ProjectName .env.development",
          field_name: "notesPlain",
          field_type: :dotenv
        })
      end

      it "parses config.json as json type" do
        result = described_class.parse("op://ProjectName/config.json")
        expect(result).to eq({
          path: "op://ProjectName/config.json",
          field_name: "notesPlain",
          field_type: :json
        })
      end

      it "parses config.yaml as yaml type" do
        result = described_class.parse("op://ProjectName/config.yaml")
        expect(result).to eq({
          path: "op://ProjectName/config.yaml",
          field_name: "notesPlain",
          field_type: :yaml
        })
      end

      it "parses config.yml as yaml type" do
        result = described_class.parse("op://ProjectName/config.yml")
        expect(result).to eq({
          path: "op://ProjectName/config.yml",
          field_name: "notesPlain",
          field_type: :yaml
        })
      end

      it "parses any item name ending with .json as json type" do
        result = described_class.parse("op://ProjectName/production.json")
        expect(result).to eq({
          path: "op://ProjectName/production.json",
          field_name: "notesPlain",
          field_type: :json
        })
      end

      it "parses any item name ending with .yaml as yaml type" do
        result = described_class.parse("op://ProjectName/staging.yaml")
        expect(result).to eq({
          path: "op://ProjectName/staging.yaml",
          field_name: "notesPlain",
          field_type: :yaml
        })
      end

      it "parses any item name ending with .yml as yaml type" do
        result = described_class.parse("op://ProjectName/my-config.yml")
        expect(result).to eq({
          path: "op://ProjectName/my-config.yml",
          field_name: "notesPlain",
          field_type: :yaml
        })
      end

      it "parses field name with extension in path (config.json)" do
        result = described_class.parse("op://Vault/Item Name/config.json")
        expect(result).to eq({
          path: "op://Vault/Item Name/config.json",
          field_name: "config.json",
          field_type: :json
        })
      end

      it "parses field name with extension in path (any .json)" do
        result = described_class.parse("op://Vault/Item Name/production.json")
        expect(result).to eq({
          path: "op://Vault/Item Name/production.json",
          field_name: "production.json",
          field_type: :json
        })
      end

      it "parses field name with extension in path (.yaml)" do
        result = described_class.parse("op://Vault/Item Name/staging.yaml")
        expect(result).to eq({
          path: "op://Vault/Item Name/staging.yaml",
          field_name: "staging.yaml",
          field_type: :yaml
        })
      end

      it "parses field name with extension in path (.yml)" do
        result = described_class.parse("op://Vault/Item Name/my-config.yml")
        expect(result).to eq({
          path: "op://Vault/Item Name/my-config.yml",
          field_name: "my-config.yml",
          field_type: :yaml
        })
      end

      it "parses field name with .env extension in path" do
        result = described_class.parse("op://Vault/Item Name/.env.development")
        expect(result).to eq({
          path: "op://Vault/Item Name/.env.development",
          field_name: ".env.development",
          field_type: :dotenv
        })
      end

      it "parses field name without extension as unknown type" do
        result = described_class.parse("op://Vault/Item Name/someField")
        expect(result).to eq({
          path: "op://Vault/Item Name/someField",
          field_name: "someField",
          field_type: nil
        })
      end

      it "parses other items as all fields (no parsing)" do
        result = described_class.parse("op://ProjectName/Sentry")
        expect(result).to eq({
          path: "op://ProjectName/Sentry",
          field_name: nil,
          field_type: nil
        })
      end

      it "parses App item as all fields" do
        result = described_class.parse("op://ProjectName/App")
        expect(result).to eq({
          path: "op://ProjectName/App",
          field_name: nil,
          field_type: nil
        })
      end

      it "raises error for invalid path format" do
        expect {
          described_class.parse("invalid-path")
        }.to raise_error(ArgumentError, /must start with 'op:\/\//)
      end
    end

    context "with hash sources (backward compatibility)" do
      it "normalizes hash format" do
        result = described_class.parse({
          path: "op://Vault/Item",
          field_name: "notesPlain",
          field_type: :dotenv,
          overwrite: true
        })
        expect(result).to eq({
          path: "op://Vault/Item",
          field_name: "notesPlain",
          field_type: :dotenv,
          overwrite: true
        })
      end

      it "handles string keys in hash" do
        result = described_class.parse({
          "path" => "op://Vault/Item",
          "field_name" => "notesPlain",
          "field_type" => "json"
        })
        expect(result).to eq({
          path: "op://Vault/Item",
          field_name: "notesPlain",
          field_type: :json,
          overwrite: nil
        })
      end
    end
  end

  describe ".parse_op_path" do
    it "extracts vault and item from path" do
      vault, item = described_class.parse_op_path("op://Vault/Item")
      expect(vault).to eq("Vault")
      expect(item).to eq("Item")
    end

    it "handles item names with spaces" do
      vault, item = described_class.parse_op_path("op://ProjectName/ProjectName .env.development")
      expect(vault).to eq("ProjectName")
      expect(item).to eq("ProjectName .env.development")
    end

    it "raises error for invalid path" do
      expect {
        described_class.parse_op_path("invalid")
      }.to raise_error(ArgumentError, /Invalid op path/)
    end
  end
end
