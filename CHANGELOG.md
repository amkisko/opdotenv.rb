# CHANGELOG

## 1.0.2 (2025-11-05)

- Enhance error handling and security measures across the codebase
- Improved error logging to avoid leaking sensitive information (uses exception class names instead of messages)
- Enhanced API error handling with generic messages for server errors to prevent sensitive data exposure
- Updated CLI output to clarify that secrets may be displayed intentionally for command-line usage
- Update Rails appraisals: remove support for Rails 6.0, 7.0, 7.1, 8.0; maintain support for Rails 6.1, 7.2, 8.1

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
