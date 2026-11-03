# Engineering and release audit

## Participants

Andrei Makarov (@amkisko)

## Decisions

Prepare 1.0.6 as a patch release on main. Keep the initial uncommitted documentation and release changes. Do not commit, tag, push or publish.

Review core behavior, executable tests, GitHub Actions, packaging, resource budgets, trace/privacy, security, contracts and release checks. Inspect external-service boundaries with synthetic fixtures. There is no application UI, independently operated worker, learned system, cloud deployment, physical plant, IPC or message broker in this library, so those surface-specific modes do not apply. CLI diagnostics are assessed through executable tests where present; no visual screen was changed.

## Effects

All listed fixes have high confidence and observed evidence from failing-then-passing executable tests or built-package inspection. Core findings are medium severity except package size and redundant reads, which are low. The smallest repair is described with each finding; no structural rewrite was needed.

- OpClient export placed secret values in process arguments. Send item JSON through stdin for create and edit; preserve existing item fields when editing. The subprocess boundary test rejects secrets in argv.
- ConnectApiClient copied arbitrary JSON error values into exceptions. Return a generic error message with the HTTP status instead. A synthetic secret in an error response no longer reaches the exception.
- ConnectApiClient treated 201 as failure, repeated POST after timeout, and fetched item details twice per read. Accept successful 2xx responses, retry only GET, and reuse the fetched item. Regression checks observed failure, two write attempts, and two detail fetches before the fixes.
- The export CLI called its format-inference method before its definition and raised NameError. Reuse FormatInferrer; exercise the executable with a JSON source and no format override.
- Release confirmation converted EOF to an empty affirmative answer. Add ReleaseVersionCheck.confirm_release? and reject EOF while preserving an entered empty line and y. Four examples cover EOF, entered default, y and n. The release script uses the checked helper; no publish command was executed.

Confirmed privacy findings: medium severity, high confidence. A local process observer can read exported secret values from argv; the export call is the entry and Open3 is the sink. A Connect error response can carry a secret into the exception message; downstream exception logging is conditional. The regressions use synthetic values, not credentials. Fingerprints: secret-argv:OpClient.export:process-arguments; error-disclosure:ConnectApiClient.handle_response:exception. Independent review checked both fixes against the source trace and the vendor's documented stdin interface.

Enable the test workflow on pull requests and set contents: read; previously the tests started only after a main push or manual dispatch. Third-party actions are pinned by commit. Workflow YAML, triggers, permissions and matrix paths were inspected locally; hosted GitHub Actions were not run.

Checks with Ruby 4.0.2 on arm64 macOS:

- POLYRUN_COVERAGE=1 make test: exit 0, including RuboCop, RBS validation and five test workers.
- bundle exec rspec --format progress: 202 examples, zero failures, zero pending.
- Coverage merge: 99.55% (447/449) tracked lines. Coverage is evidence for those assertions, not proof of all behavior.
- gem build opdotenv.gemspec --output tmp/opdotenv-release.gem, followed by Gem::Package#verify: pass. 20480 compressed bytes, 18 packaged files. Version, changelog heading and path-package lock entries agree.
- git diff --check: pass. Branch remains main.

Resource fixtures are local and use synthetic values. Cold `bundle exec ruby -Ilib -ropdotenv -e 'puts "loaded"'`, measured with `env time -l`: 0.22 CPU seconds and 31801344 bytes maximum RSS. This includes Bundler startup. Audit ceilings are one CPU second and 100 MiB RSS per cold load; both pass. No claim is made about other machines or co-located production services.

The 10,000-operation fixture in usr/reports/resource_smoke.rb measured 0.227637 wall seconds, 0.226682 CPU seconds, 1030126 allocated objects and 776 retained heap bytes after GC. The fixture budget is one CPU second and 1 MiB retained heap growth; both pass. CPU seconds are the energy proxy; no energy meter was available. These loops perform no file writes or network calls. Network-facing unit tests stub service responses; no live provider traffic or credentials were used. Persistent diagnostic and credential paths were inspected separately from these zero-IO loops.

Re-audit: checked the corrected failure paths, consumers, release metadata, package contents, negative tests and final diff. No remaining confirmed actionable finding was identified in the reviewed paths. This is a bounded local audit; live provider behavior, Ruby 3.4 and hosted matrix execution remain outside the measured run.

The external CLI's JSON template interface does not preserve passkeys. Existing-item exports are explicitly limited to dedicated configuration items without passkeys in README.md and CHANGELOG.md. See ../dependencies/20261028093000_cli-template-passkey-limitation.md. No documented discriminator was available for a reliable runtime guard; passkey-containing items remain unsupported.

## Next

Review and commit the prepared changes before the existing release command is used. The command requires a clean worktree and interactive confirmation. No release has been published.

## Source

- AGENTS.md and .agents/skills/engineering-audit/.
- .agents/skills/changelog-update/.
- CHANGELOG.md, spec/, .github/workflows/test.yml and usr/reports/resource_smoke.rb.
- https://www.1password.dev/cli/reference/management-commands/item (documented create and edit stdin interfaces).
