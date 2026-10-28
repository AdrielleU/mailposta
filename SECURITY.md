# Security

MailPostA handles your email and your email credentials, so security reports are very welcome.

## Reporting a vulnerability

**Please don't open a public issue.** Report it privately through GitHub:
the repository's **Security** tab → **Report a vulnerability**.

Include what you found, how to reproduce it, and what an attacker could do with it.
You'll get an answer as soon as possible, and credit in the fix if you'd like it.

Don't include real credentials, tokens or email content in a report. Use made-up accounts or redact them.

## What counts

Especially:
- **A way to send email:** through himalaya, `bin/mail`, the web UI, or anything Claude Code can reach.
  MailPostA is drafts-only by design.
- **A way to change or delete mail on the server** without an explicit confirmation.
- **A way to read secrets:** `.env`, Gmail app passwords, Outlook OAuth tokens (`data/state/oauth/`).
  That includes leaks into logs, run reports, the web UI or the audit log.
- **Getting past the web UI login**, or the web UI writing, sending or deleting anything.
- **Email content triggering actions:** prompt injection against the Claude Code setup (`CLAUDE.md`,
  `PROMPT.md`, `.claude/settings.json`), or HTML/script injection in the web UI.
- **Path traversal or file access** outside the mail, logs and rules folders through the web UI.

Out of scope: vulnerabilities in himalaya, mbsync, notmuch, Caddy or Debian themselves. Please report
those to their projects. If MailPostA uses them in an unsafe way, that is in scope.

## Design summary

How MailPostA is meant to stay safe, so you can check it holds:
- **Sync is pull-only.** mbsync never pushes changes to the server.
- **No sending path:** no SMTP is configured, Outlook tokens have IMAP scope only, and `bin/mail` refuses
  send commands. Claude Code's permission rules also block direct container access, `smtplib` and `sendmail`.
- **Secrets stay out of files:** they live only in `.env` (mode 600) and `data/state/`, and configs fetch
  them at runtime. The web UI container gets neither.
- **`bin/mail` is a gate, not just a shortcut:** besides sending, it refuses anything that reaches files
  inside the mail container (`-c`/`--config`, `--log-file`, `--attach`, `--body-file`, `--signature-file`,
  `attachment download --dir`), so a caller limited to `bin/mail` can't read the passwords or tokens.
- **The web UI is locked down:** read-only, no Linux capabilities, a read-only filesystem, behind a Caddy
  bcrypt login, bound to localhost by default. HTML mail is shown as plain text, never rendered.
- **Everything is logged:** every `bin/mail` call goes to `data/logs/audit-*.log`.

## Supported versions

Only the latest version on the main branch gets security fixes.
