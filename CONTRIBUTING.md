# Contributing to MailPostA

Thanks for helping! Bug reports, ideas and pull requests are all welcome.

## Reporting bugs and ideas

Search the existing issues first, including closed ones. When reporting a bug, include:
- your OS (Linux distro, or Windows + WSL2 version) and Docker or Podman version,
- the account type involved (Gmail or Outlook), never the address or password,
- what you ran, what happened, and the relevant lines from `data/logs/sync-*.log` or `docker compose logs`.

**Redact everything personal** before posting: addresses, names, subjects, tokens, message content.
Security problems go through [SECURITY.md](SECURITY.md), not issues.

## Contributing code

1. Open an issue first for anything bigger than a small fix, so we can agree on the approach.
2. Fork, branch, and keep each pull request to one change.
3. Test it in a running stack (`docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --build`) with a test account or made-up mail.
   **Never commit `.env`, anything from `data/`, or real email.**
4. Describe what changed and how you tested it in the pull request.

### Ground rules

These are the project's promises. A change that weakens one won't be merged without a very good reason:
- **Never send mail.** No SMTP, no send commands, drafts only.
- **Leave the servers alone** unless the user explicitly confirms an action (delete, move).
- **Secrets stay out of** files, logs, images and the web UI.
- **The web UI stays read-only.**
- **Pin versions** of what the image downloads (himalaya, base images).

### Style

- Shell scripts are POSIX `sh` (`#!/bin/sh`, `set -eu`), so they work in Debian's `dash`.
- Python uses the standard library plus PyYAML only. No other dependencies.
- Write comments that explain *why*, and keep them short.
- Line endings are LF and files are UTF-8 (see `.editorconfig` and `.gitattributes`).

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
