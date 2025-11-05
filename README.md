# opdotenv

[![Gem Version](https://badge.fury.io/rb/opdotenv.svg?v=1.0.0)](https://badge.fury.io/rb/opdotenv) [![Test Status](https://github.com/amkisko/opdotenv.rb/actions/workflows/ci.yml/badge.svg)](https://github.com/amkisko/opdotenv.rb/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/amkisko/opdotenv.rb/graph/badge.svg?token=U4FMVZGO8R)](https://codecov.io/gh/amkisko/opdotenv.rb)

Load environment variables from 1Password using the `op` CLI or 1Password Connect Server API. Supports dotenv, JSON, and YAML formats.

Sponsored by [Kisko Labs](https://www.kiskolabs.com).

<a href="https://www.kiskolabs.com">
  <img src="https://brand.kiskolabs.com/images/logos/Kisko_Logo_Black_Horizontal-7249a361.svg" width="200" style="display: block; background: white; border-radius: 10px;" />
</a>

## Installation

Add to your Gemfile:

```ruby
gem "opdotenv"
```

## Requirements

Choose one:
- **1Password CLI** (`op`) - must be installed and authenticated (`op signin`)
  - By default, `op` is expected to be in your `PATH`
  - You can configure a custom path via `OP_CLI_PATH` or `OPDOTENV_CLI_PATH` environment variables, or via Rails config (see below)
- **1Password Connect Server** - set `OP_CONNECT_URL` and `OP_CONNECT_TOKEN` environment variables

Ruby 2.7+ supported.

## Rails

Configure in `config/application.rb` or environment-specific files:

```ruby
Rails.application.configure do
  config.opdotenv.sources = [
    "op://Vault/.env.development",  # dotenv format (inferred)
    "op://Vault/config.json",        # json format (inferred from .json extension)
    "op://Vault/App"                 # all fields without parsing
  ]
end
```

Format is automatically inferred from item name or field name:
- `.env.*` → dotenv format
- `*.json` → JSON format
- `*.yaml` or `*.yml` → YAML format
- Other items → load all fields without parsing

You can also specify the field name with extension in the path:
- `op://Vault/Item Name/config.json` → uses field `config.json` as JSON
- `op://Vault/Item Name/production.json` → uses field `production.json` as JSON
- `op://Vault/Item Name/.env.development` → uses field `.env.development` as dotenv

### 1Password Connect

```ruby
Rails.application.configure do
  config.opdotenv.connect_url = "https://connect.example.com"
  config.opdotenv.connect_token = Rails.application.credentials.dig(:op_connect, :token)
end
```

### Configure op CLI path

If your `op` CLI command is not in your `PATH` or you want to use a custom path:

```ruby
Rails.application.configure do
  config.opdotenv.cli_path = "/usr/local/bin/op"
end
```

Alternatively, you can set the `OP_CLI_PATH` or `OPDOTENV_CLI_PATH` environment variable:

```bash
export OP_CLI_PATH=/usr/local/bin/op
```

### Disable automatic loading

```ruby
Rails.application.configure do
  config.opdotenv.auto_load = false
end

# Load manually when needed
Opdotenv::Loader.load("op://Vault/Item")
```

## Standalone usage

```ruby
require "opdotenv"

# Load from dotenv format (format inferred from item name)
Opdotenv::Loader.load("op://Vault/.env.development")

# Load from JSON format (any item name ending with .json)
Opdotenv::Loader.load("op://Vault/config.json")
Opdotenv::Loader.load("op://Vault/production.json")

# Load from field with extension in path
Opdotenv::Loader.load("op://Vault/Item Name/config.json")

# Load all fields from an item
Opdotenv::Loader.load("op://Vault/App")

# Don't overwrite existing ENV values
Opdotenv::Loader.load("op://Vault/Item", overwrite: false)
```

## Anyway Config integration

Automatically registers when `anyway_config` is available:

```ruby
class AppConfig < Anyway::Config
  attr_config :api_key, :api_secret

  # Format is inferred from item name
  loader_options opdotenv: {
    path: "op://Vault/.env.development"  # dotenv format inferred
  }
end

# Or load all fields from an item
class DatabaseConfig < Anyway::Config
  attr_config :url, :username, :password

  loader_options opdotenv: {
    path: "op://Vault/Database"  # all fields loaded
  }
end
```

### Conditional Loading (Recommended for Security)

For better security, only load from 1Password in development/test environments:

```ruby
class TestConfig < Anyway::Config
  config_name :test
  attr_config :enabled, :sample

  # Only load from 1Password in local/development environments
  if Rails.env.local?
    loader_options opdotenv: {
      path: "op://Employee/.env.test"
    }
  end
end
```

This ensures that production environments won't attempt to load secrets from 1Password, aligning with the [production recommendations](#environment-recommendation).

### Loading All Fields from an Item

When loading all fields from a 1Password item (not a parsed format), field names are automatically normalized to match the `env_prefix`:

```ruby
class TestConfig < Anyway::Config
  config_name :test
  attr_config :enabled, :sample

  loader_options opdotenv: {
    path: "op://Employee/TestConfig"  # Loads all fields from item
  }
end
```

**Field name matching (strict with case-insensitive prefix):**
- Fields in 1Password **must** be prefixed with the `env_prefix` (e.g., `TEST_` for `config_name :test`)
- Matching is **case-insensitive**: `TEST_ENABLED`, `test_enabled`, `Test_Enabled` all work
- After prefix stripping, `TEST_ENABLED` becomes `enabled` (matching `attr_config :enabled`)
- Fields without the prefix (e.g., `enabled`, `ENABLED`) are ignored and logged as unmatched

**Debugging field matching:**
- Enable debug logging by setting `OPDOTENV_DEBUG=true`
- Check Rails logs for messages like:
  ```
  [opdotenv] Available fields from 1Password: enabled, ENABLED, sample, SAMPLE
  [opdotenv] Matched fields for TEST: enabled, sample
  [opdotenv] Unmatched fields (must be prefixed with TEST_, case-insensitive): other_field
  ```

## Using with dotenv

Load order determines which values take precedence:

```ruby
require "dotenv"
require "opdotenv"

# Load local files first, then augment from 1Password (1Password values override by default)
Dotenv.load(".env", ".env.development")
Opdotenv::Loader.load("op://Vault/.env.development")

# Or load from 1Password first, then local files (local values override)
Opdotenv::Loader.load("op://Vault/.env.development", overwrite: false)
Dotenv.load(".env", ".env.development")
```

## Export to 1Password

### CLI

```bash
# Export .env file (format inferred from path)
opdotenv export --path "op://Vault/.env.development" --file .env.development

# Export to item fields
opdotenv export --path "op://Vault/App" --file .env

# Read and print (format inferred from path)
opdotenv read --path "op://Vault/.env.development"
```

### Ruby API

```ruby
# Export to Secure Note (format inferred from path)
Opdotenv::Exporter.export(
  path: "op://Vault/.env.development",
  data: {"API_KEY" => "secret"}
)

# Export to item fields
Opdotenv::Exporter.export(
  path: "op://Vault/App",
  data: {"API_KEY" => "secret", "API_SECRET" => "another"}
)
```

## Supported formats

Format is automatically inferred from item name or field name:
- `.env.*` → dotenv format (`KEY=VALUE`)
- `*.json` → JSON format (nested structures flattened with underscores)
- `*.yaml` or `*.yml` → YAML format (nested structures flattened with underscores)
- Other items → load all fields without parsing

Field names can be specified with extensions in the path:
- `op://Vault/Item Name/config.json` → loads field `config.json` as JSON
- `op://Vault/Item Name/production.json` → loads field `production.json` as JSON
- `op://Vault/Item Name/.env.development` → loads field `.env.development` as dotenv

For advanced usage, you can explicitly specify `field_name` and `field_type` in the API.

## Security

### Environment Recommendation

**⚠️ This gem is recommended for development and test environments only.**

For production environments, we recommend using dedicated secret management solutions that integrate with your infrastructure:

- **Kubernetes**: Use [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) or [External Secrets Operator](https://external-secrets.io/) with providers like AWS Secrets Manager, HashiCorp Vault, or Azure Key Vault
- **AWS**: Use [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) or [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- **Azure**: Use [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault)
- **GCP**: Use [Google Secret Manager](https://cloud.google.com/secret-manager)

Provision secrets through infrastructure-as-code tools:
- **Helm** (Kubernetes): Use `helm secrets` or external secrets operator
- **Terraform**: Use `aws_secretsmanager_secret`, `azurerm_key_vault_secret`, or `google_secret_manager_secret`
- **Bicep** (Azure): Use `Microsoft.KeyVault/vaults` resources

These solutions provide:
- Better audit trails and access controls
- Integration with IAM/RBAC systems
- Automatic secret rotation
- Compliance with security standards
- No dependency on external CLI tools or API servers

### Security Considerations

- **CLI mode**: Secrets fetched via authenticated `op` CLI session.
- **Connect API mode**: Secrets fetched via HTTPS. Ensure tokens are secure.
- The library does not persist secrets in memory or on disk.
- Always verify 1Password CLI or Connect server is up to date and authenticated.

### Code Locations for Security Review

For security-sensitive applications, developers should review where this gem reads and writes data from 1Password. The following locations handle secret data:

#### Reading Secrets (OpClient - CLI mode)

- **`lib/opdotenv/op_client.rb`**:
  - `read(path)` - Executes `op read` command to fetch a single field value
  - `item_get(item, vault:)` - Executes `op item get` command to fetch all item data as JSON
  - `capture(args)` - Executes shell commands via `IO.popen` (array arguments, no shell interpretation)

#### Reading Secrets (ConnectApiClient - API mode)

- **`lib/opdotenv/connect_api_client.rb`**:
  - `read(path)` - Makes HTTP GET request to fetch field or notesPlain content
  - `item_get(item_title, vault:)` - Searches and fetches item data via API
  - `get_item(vault_name, item_title)` - Fetches full item details including all fields
  - `item_by_title_in_vault(vault_id, item_title)` - Lists items and fetches by title
  - `list_vaults()` - Lists all accessible vaults (uses `api_request(:get, "/v1/vaults")`)
  - `vault_name_to_id(vault_name)` - Resolves vault names to IDs (cached)
  - `api_request(method, path, body)` - All HTTP requests go through this method
  - `find_field(item, field_name)` - Searches item fields by label, ID, or purpose

#### Main Entry Points

- **`lib/opdotenv/loader.rb`**:
  - `load(path, ...)` - Main entry point that orchestrates secret fetching
  - `load_field(client, path, field_name, field_type)` - Loads and parses a single field
  - `load_all_fields(client, path)` - Loads all fields from an item (skips notesPlain)
  - `merge_into_env(env, hash, overwrite:)` - Writes secrets to environment hash

#### Rails Integration

- **`lib/opdotenv/railtie.rb`**:
  - `initializer "opdotenv.load"` - Automatically loads secrets during Rails initialization
  - Reads from `config.opdotenv.sources` array
  - Sets `OP_CONNECT_URL` and `OP_CONNECT_TOKEN` from Rails config if provided

#### Anyway Config Integration

- **`lib/opdotenv/anyway_loader.rb`**:
  - `Loader#call(...)` - Loads secrets for Anyway Config classes
  - Uses `Opdotenv::Loader.load()` internally

#### Parsing and Processing

- **`lib/opdotenv/parsers/dotenv_parser.rb`** - Parses dotenv format strings
- **`lib/opdotenv/parsers/json_parser.rb`** - Parses and flattens JSON structures
- **`lib/opdotenv/parsers/yaml_parser.rb`** - Parses YAML (safe_load with aliases: false)

#### Data Flow

1. **Configuration** → Rails config or direct API calls
2. **Path Parsing** → `SourceParser.parse()` extracts vault/item/field from path
3. **Client Selection** → `ClientFactory.create()` chooses CLI or API client
4. **Secret Fetching** → Client reads from 1Password (CLI command or HTTP request)
5. **Parsing** → Format-specific parser converts to key-value pairs
6. **Environment Merge** → Secrets merged into `ENV` or provided hash

All secret data flows through these code paths. No secrets are persisted to disk or logged (except explicit error messages).

## Development

```bash
bundle install
bundle exec rspec
bundle exec rbs validate
bundle exec standardrb --fix
```

## License

MIT
