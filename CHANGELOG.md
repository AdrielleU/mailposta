# Changelog

All notable changes to MailPostA. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Microsoft sign-in from the web UI: a **Sign in with Microsoft** button per Outlook account shows the
  device code and link, and updates when you're done. The mail container does the sign-in and keeps the
  token; the web UI only writes a request file (`data/control/requests/`) and reads the state. The overview
  shows which Outlook accounts are signed in or need it. Run `bin/setup` once to create `data/control/`.
- Connection test: `bin/mail --tool check [account ...]` and a **Test connection** button on each account
  card. It logs in to the server and lists the folders (downloads nothing), then shows Connected or the
  reason it failed (wrong app password, not signed in, invalid settings).

### Changed
- An account with missing or wrong settings in `.env` no longer stops the mail container. It's marked
  `INVALID` with the reason (web UI overview, run reports, sync log) and skipped; the other accounts keep
  syncing. Only an empty `ACCOUNTS` still stops it.

## [0.1.0] - 2026-10-27

### Added
- One-way (pull-only) sync of any number of Gmail (app password) and Outlook / Microsoft 365 (OAuth device
  sign-in) accounts into local Maildir copies, every 15 minutes, keeping the last 60 days.
- `bin/mail`: a host wrapper around himalaya for Claude Code and the terminal. It refuses anything that
  looks like sending and writes an audit log.
- Drafts-only: no SMTP on any account. Drafts are saved to each account's server Drafts folder.
- `delete-both`: delete by Message-ID on the server (moved to Trash) and locally, dry run first.
- Run reports per sync (`data/logs/sync-*.log`, `runs-*.jsonl`) and logs that rotate after 30 days.
- Local tags with notmuch: personal/business per account, rules in `data/rules/tags.yaml`, and
  `suggest-rules` to propose rules from repeated senders.
- `CLAUDE.md` rules and `PROMPT.md` task playbooks for Claude Code: status report, needs reply,
  summarize, draft reply, cleanup, sync health, suggest rules, organize, activity, find.
- Read-only web UI (overview, mail, message with copy buttons, run reports, logs, rules) behind a Caddy
  bcrypt login, with no secrets and read-only mounts.
- `bin/setup` for first-time folders and starter files.
- `SYNC_HOURS` to sync only between set local hours (e.g. `7-22`, or `22-6` overnight).
- Published image `ghcr.io/adrielleu/mailposta` (amd64 and arm64); `MAILPOSTA_IMAGE` in `.env` uses it
  instead of building locally.
- CI on every push and pull request: shellcheck, Python syntax, compose validation, and an image smoke test.
- Logo (`assets/`), also the web UI's favicon; system requirements in the README.
