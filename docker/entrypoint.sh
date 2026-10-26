#!/bin/sh
# Renders configs for every account in ACCOUNTS (see scripts/configure), then
# runs the sync loop (default) or whatever command was given. Secrets never land
# in the rendered files: mbsync and himalaya fetch them at runtime
# (printenv / oauth-token).
set -eu

: "${RETENTION_DAYS:=60}" "${SYNC_INTERVAL:=900}" "${LOG_RETENTION_DAYS:=30}"
export RETENTION_DAYS SYNC_INTERVAL LOG_RETENTION_DAYS

mkdir -p /mail /state /logs
# Validates ACCOUNTS, renders ~/.mbsyncrc + himalaya config, prints the names.
# The first account listed is himalaya's default.
accounts=$(configure)

# Everything goes to stdout (container logs) and to /logs/sync-YYYY-MM-DD.log.
logpipe() { tee -a "/logs/sync-$(date +%F).log"; }
log() { echo "$*" | logpipe; }
# mbsync echoes a failed AUTHENTICATE line, which carries the token: redact it.
redact() { sed 's/\(AUTHENTICATE [A-Z0-9-]*\) [^ ]*/\1 <redacted>/'; }
# Message files by their unique name (the part before ":" changes with flags).
snapshot() {
  find "/mail/$1" -type f \( -path '*/cur/*' -o -path '*/new/*' \) -printf '%f\n' | sed 's/:.*//' | sort -u
}

sync_account() {
  a="$1"; run=/tmp/run
  log "[$(date -Is)] sync $a"
  snapshot "$a" > "$run/$a.before"
  status=0
  mbsync "$a" > "$run/$a.mbsync" 2>&1 || status=$?
  redact < "$run/$a.mbsync" | logpipe
  snapshot "$a" > "$run/$a.after"
  new=$(comm -13 "$run/$a.before" "$run/$a.after" | wc -l)
  removed=$(comm -23 "$run/$a.before" "$run/$a.after" | wc -l)
  out=$(prune "$a"); log "$out"
  pruned=$(echo "$out" | sed -n 's/.* removed \([0-9]*\) .*/\1/p')
  {
    if [ "$status" -eq 0 ]; then echo status=ok; else echo status=failed; fi
    echo "new=$new"; echo "removed_on_server=$removed"; echo "pruned=${pruned:-0}"
    echo "local_total=$(snapshot "$a" | wc -l)"
    if [ "$status" -ne 0 ]; then
      echo "error=$(redact < "$run/$a.mbsync" | grep -v '^\[SASL' | grep . | tail -1 | tr -d '\r' | cut -c1-300)"
    fi
  } > "$run/$a.env"
}

case "${1:-sync-loop}" in
  sync-loop)
    while true; do
      started=$(date +%s)
      rm -rf /tmp/run && mkdir -p /tmp/run
      for a in $accounts; do sync_account "$a"; done
      # Index the local copies and apply data/rules (local tags only).
      tag-mail --report /tmp/run/tags.json 2>&1 | logpipe
      run-report "$started" $accounts | logpipe
      # Rotate: daily files (sync log, run reports, host-side audit log) older than LOG_RETENTION_DAYS.
      find /logs -maxdepth 1 -type f \( -name '*.log' -o -name '*.jsonl' \) -mtime "+$LOG_RETENTION_DAYS" -delete
      log "[$(date -Is)] sleeping ${SYNC_INTERVAL}s"
      sleep "$SYNC_INTERVAL"
    done
    ;;
  *) exec "$@" ;;
esac
