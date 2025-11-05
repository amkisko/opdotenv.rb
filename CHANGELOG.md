# CHANGELOG

## 1.0.1 (2025-11-05)

- Add configurable op CLI path support
- Support for `OP_CLI_PATH` and `OPDOTENV_CLI_PATH` environment variables
- Rails configuration option `config.opdotenv.cli_path`
- Direct API support via `OpClient.new(cli_path: ...)` and `ClientFactory.create(cli_path: ...)`

## 1.0.0 (2025-11-04)

- Initial stable release
- Load environment variables from 1Password using op CLI or Connect API
- Support for dotenv, JSON, and YAML formats
- Automatic format inference from file extensions
- Rails integration with declarative configuration
- Anyway Config integration with strict prefix matching
- Export data back to 1Password
- CLI tool for read/export operations
- Support for field names in paths (e.g., op://Vault/Item/config.json)
- Security improvements (input validation, safe YAML parsing)
- Comprehensive documentation with security guidelines
