# Engineering and prose audit before 1.0.6 publish

## Participants

Andrei Makarov (@amkisko)

## Decisions

Re-audit main for the unpublished 1.0.6 cut after the 2026-10-28 release-tooling pass. Include Secure Note upsert, Connect title filter, Open3 field stdin coverage, changelog release gates, dotenv basename matching, non-JSON Connect 2xx handling, pull_request CI, and ASCII docs punctuation. Leave tag and RubyGems publish to `make release` after commit.

## Effects

Pipeline: CLI/Rails/Anyway -> ClientFactory -> OpClient / ConnectApiClient -> Loader -> ENV; export via Exporter. Boundary mode covered subprocess argv/stdin and Connect HTTP. Resource and identification modes: no new person identifiers in gem logs. Queue, worker, learned-system, and physical plant modes skipped (absent).

Ranked fixes applied:

1. Upsert Secure Note exports (high confidence, observed).
2. Connect `filter=title eq ...` with UUID fallback (high confidence, observed).
3. Open3 stdin regressions for field create/edit; changelog gate specs (high confidence, observed).
4. Dotenv basename rules; invalid JSON 2xx -> `ConnectApiError` (medium confidence, observed).
5. CHANGELOG dated 2026-11-03; README Ruby 3.4+, security tone, ASCII.
6. Remove unused `shellwords`; ClassLength Max 220.

Deferred (documented in the issue): Railtie soft-fail, parse_json_safe empty success, ENV token copy, multi-segment Loader path parse, CLI ENV mutation, cleartext remote Connect URL.

Checks observed in this session:

- bundle exec rubocop on touched Ruby files: 7 files, no offenses.
- bundle exec rbs validate: ok.
- bundle exec rspec: 214 examples, 0 failures (includes release_version_check, Open3, upsert, filter).
- gem build opdotenv.gemspec and Gem::Package#verify for 1.0.6: ok; 20480 compressed bytes.
- Cold `bundle exec ruby -Ilib -ropdotenv`: 0.23 wall s, ~31 MiB max RSS (ceilings 1 CPU s / 100 MiB).
- `ruby -Ilib usr/reports/resource_smoke.rb`: 0.202 wall / 0.202 CPU s, 776 retained heap bytes (ceilings 1 CPU s / 1 MiB).

## Next

Commit, then `make release`.

## Source

- docs/issues/20261103172536_engineering-prose-release-audit.md
- CHANGELOG.md section 1.0.6 (2026-11-03)
- Prior pass: docs/issues/20261028093000_engineering-release-audit.md
