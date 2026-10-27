#!/bin/sh
# Renders configs for every account in ACCOUNTS (see scripts/configure), then
# runs the sync loop (default) or whatever command was given. Secrets never land
# in the rendered files: mbsync and himalaya fetch them at runtime
# (printenv / oauth-token).
set -eu

: "${RETENTION_DAYS:=60}" "${SYNC_INTERVAL:=900}" "${LOG_RETENTION_DAYS:=30}"
export RETENTION_DAYS SYNC_INTERVAL LOG_RETENTION_DAYS

# SYNC_HOURS=START-END (local hours, 0-24, end not included; 22-6 wraps past midnight). Empty: around the clock.
num() { echo "$1" | sed 's/^0*//; s/^$/0/'; }
if [ -n "${SYNC_HOURS:-}" ]; then
  echo "$SYNC_HOURS" | grep -Eq '^[0-9]{1,2}-[0-9]{1,2}$' || { echo "SYNC_HOURS must look like 7-22, got '$SYNC_HOURS'" >&2; exit 1; }
  hours_start=$(num "${SYNC_HOURS%-*}"); hours_end=$(num "${SYNC_HOURS#*-}")
  if [ "$hours_start" -gt 24 ] || [ "$hours_end" -gt 24 ] || [ $((hours_start % 24)) -eq $((hours_end % 24)) ]; then
    echo "SYNC_HOURS: hours are 0-24 and start can't equal end (leave it empty to sync around the clock)" >&2; exit 1
  fi
  hours_start=$((hours_start % 24)); hours_end=$((hours_end % 24))
fi
in_sync_hours() {
  [ -z "${SYNC_HOURS:-}" ] && return 0
  h=$(num "$(date +%H)")
  if [ "$hours_start" -lt "$hours_end" ]; then
    [ "$h" -ge "$hours_start" ] && [ "$h" -lt "$hours_end" ]
  else
    [ "$h" -ge "$hours_start" ] || [ "$h" -lt "$hours_end" ]
  fi
}
# Seconds from now until the next HH:00 that starts the window.
until_sync_hours() {
  h=$(num "$(date +%H)"); m=$(num "$(date +%M)"); s=$(num "$(date +%S)")
  echo $(( ((hours_start - h + 24) % 24) * 3600 - m * 60 - s ))
}

mkdir -p /mail /state /logs /control/requests /control/status
# The web container has no capabilities, so under rootful Docker it can only write here if anyone may.
# It holds nothing but empty request files ("sign in", "test connection"; see scripts/control-watch).
chmod 777 /control/requests
# Validates ACCOUNTS, renders ~/.mbsyncrc + himalaya config, prints the names.
# The first account listed is himalaya's default.
accounts=$(configure)

# Everything goes to stdout (container logs) and to /logs/sync-YYYY-MM-DD.log.
logpipe() { tee -a "/logs/sync-$(date +%F).log"; }
# For long-running background output: picks the day's log file per line.
logpipe_daily() { while IFS= read -r line; do echo "$line"; echo "$line" >> "/logs/sync-$(date +%F).log"; done; }
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
      # Prefer oauth-token's own message (it says how to sign in) over mbsync's generic last line.
      err=$(grep -m1 -E "^(no token for|token refresh failed)" "$run/$a.mbsync" || redact < "$run/$a.mbsync" | grep -v '^\[SASL' | grep . | tail -1)
      echo "error=$(printf '%s' "$err" | tr -d '\r' | cut -c1-300)"
    fi
  } > "$run/$a.env"
}

case "${1:-sync-loop}" in
  sync-loop)
    # Runs what the web UI asks for: Microsoft sign-ins and connection tests.
    control-watch 2>&1 | logpipe_daily &
    while true; do
      if ! in_sync_hours; then
        wait=$(until_sync_hours)
        log "[$(date -Is)] outside SYNC_HOURS=$SYNC_HOURS, sleeping ${wait}s until ${hours_start}:00"
        sleep "$wait"
        continue
      fi
      started=$(date +%s)
      rm -rf /tmp/run && mkdir -p /tmp/run
      for a in $accounts; do sync_account "$a"; done
      # Index the local copies and apply data/rules (local tags only).
      tag-mail --report /tmp/run/tags.json 2>&1 | logpipe
      run-report "$started" $accounts | logpipe
      # Rotate: daily files (sync log, run reports, host-side audit log) older than LOG_RETENTION_DAYS.
      find /logs -maxdepth 1 -type f \( -name '*.log' -o -name '*.jsonl' \) -mtime "+$LOG_RETENTION_DAYS" -delete
      log "[$(date -Is)] sleeping ${SYNC_INTERVAL}s"
      # Wake early when /control/sync-now appears (a Microsoft sign-in just finished).
      slept=0
      while [ "$slept" -lt "$SYNC_INTERVAL" ] && [ ! -e /control/sync-now ]; do sleep 5; slept=$((slept + 5)); done
      if [ -e /control/sync-now ]; then rm -f /control/sync-now; log "[$(date -Is)] syncing now (requested)"; fi
    done
    ;;
  *) exec "$@" ;;
esac
