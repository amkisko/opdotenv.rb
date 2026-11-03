# Engineering and prose audit before 1.0.6 publish

## Participants

Andrei Makarov (@amkisko)

## Decisions

- Keep version 1.0.6. Fold re-audit fixes into the unpublished cut and date the product changelog 2026-11-03.
- Upsert Secure Note exports on create and edit for `op` CLI and Connect.
- Filter Connect item lookups by title; keep UUID direct fetch as fallback.
- Reject non-JSON Connect 2xx bodies with a generic `ConnectApiError`.
- Match dotenv basenames (`.env`, `.env.*`, spaced titles like `App .env.development`); do not match `foo.env` / `my.envfile`.
- Cover Open3 stdin for field create/edit, changelog release gates, and note upsert.
- ASCII and factual prose pass on README; Ruby floor matches gemspec (`>= 3.4`).
- Leave Railtie soft-fail boot, `Loader.parse_json_safe` empty success, Railtie Connect token copy into `ENV`, multi-segment `Loader.parse_op_path`, CLI `read` ENV mutation, and cleartext remote Connect URL hardening as follow-up (documented below).
- Leave tag and RubyGems publish to `make release` after commit.

## Effects

Pipeline: CLI / Rails / Anyway ingress -> ClientFactory -> OpClient (`op` subprocess) or ConnectApiClient (HTTP) -> Loader/parsers -> ENV egress; export reverses via Exporter. Boundary mode covered CLI argv/stdin and Connect HTTP. Resource and identification modes: cold load and JSON parse smoke measured this session; no new person identifiers in gem logs. Queue, worker, learned-system, and physical plant modes skipped (absent).

Ranked fixes applied:

1. Secure Note upsert for OpClient and ConnectApiClient (high confidence, observed).
2. Connect title filter plus UUID fallback; Open3 field create/edit stdin specs (high confidence, observed).
3. Non-JSON 2xx Connect responses raise `ConnectApiError` (medium confidence, observed).
4. Dotenv basename matching without mid-name `.env` overmatch (medium confidence, observed).
5. Changelog heading and confirmation specs; CHANGELOG dated 2026-11-03 (medium confidence, observed).
6. README Ruby floor, security section tone, ASCII punctuation, badge (house prose).
7. Drop unused `shellwords` require; ClassLength Max 220 for Connect client growth.

Deferred:

- Railtie `rescue` soft-fail at boot (high severity for fail-closed hosts; breaking if default changes).
- `Loader.parse_json_safe` returning `{}` on corrupt JSON (high severity epistemic; breaking if raised).
- Railtie writing `OP_CONNECT_TOKEN` into process `ENV` (medium; token amplification to children).
- `Loader.parse_op_path` dropping segments after the item name vs SourceParser (medium).
- CLI `read` mutating process `ENV` (low).
- Warn/raise on non-loopback `http://` Connect base URL (low hardening).

## Next

- Commit the worktree, then run `make release` for tag and gem push.
- Follow-up: optional `raise_on_load_error`, raise on JSON parse failure, client construction without ENV token write, shared path parser, CLI fetch-without-merge, Connect HTTP scheme guard.

## Source

- docs/reviews/20261103172536_engineering-prose-release-audit.md
- CHANGELOG.md section 1.0.6 (2026-11-03)
- Prior pass: docs/issues/20261028093000_engineering-release-audit.md
