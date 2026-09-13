#!/bin/sh
# borgmatic → Prometheus textfile-collector hook.
#
# Invoked from borgmatic's `after_actions` (success) and `on_error`
# (failure) hooks. Writes node_exporter
# textfile-collector metrics describing the most recent borgmatic run,
# labelled by the config file the run was for.
#
# Usage: prometheus-textfile.sh <status> [config_filename]
#   <status>: "success" or "failure"
#   <config_filename>: path to the borgmatic config file (passed via the
#                      `{configuration_filename}` interpolation placeholder).
#                      Falls back to "all" if absent.
#
# One .prom file per config. Each invocation:
#   - emits {config="<name>"} for the three metrics below,
#   - preserves the previous `borgmatic_last_success_timestamp_seconds` value
#     on failure runs (so a single failed run after a successful one doesn't
#     wipe the historical "last success" reading),
#   - writes atomically (tmp file + rename) so node-exporter never reads a
#     half-written file.
#
# Metrics emitted:
#   borgmatic_last_run_timestamp_seconds{config="<name>"}
#   borgmatic_last_run_status{config="<name>"}             (1 = success, 0 = failure)
#   borgmatic_last_success_timestamp_seconds{config="<name>"}

set -eu

STATUS="${1:-failure}"
CONFIG_FILE="${2:-}"
OUT_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
NOW="$(date +%s)"

STATUS_VAL=0
[ "$STATUS" = "success" ] && STATUS_VAL=1

CONFIG="all"
if [ -n "$CONFIG_FILE" ]; then
  CONFIG="$(basename "$CONFIG_FILE" .yaml)"
fi

mkdir -p "$OUT_DIR"

FILE="${OUT_DIR}/borgmatic_${CONFIG}.prom"
TMP="${FILE}.$$"

if [ "$STATUS" = "success" ]; then
  LAST_SUCCESS="$NOW"
elif [ -f "$FILE" ]; then
  LAST_SUCCESS="$(grep -E '^borgmatic_last_success_timestamp_seconds\{' "$FILE" 2>/dev/null | awk '{print $NF}' | tail -n1)"
else
  LAST_SUCCESS=""
fi

{
  echo "# HELP borgmatic_last_run_timestamp_seconds Unix timestamp of the last borgmatic run (success or failure)."
  echo "# TYPE borgmatic_last_run_timestamp_seconds gauge"
  echo "borgmatic_last_run_timestamp_seconds{config=\"${CONFIG}\"} ${NOW}"
  echo "# HELP borgmatic_last_run_status 1 if last borgmatic run for this config succeeded, 0 otherwise."
  echo "# TYPE borgmatic_last_run_status gauge"
  echo "borgmatic_last_run_status{config=\"${CONFIG}\"} ${STATUS_VAL}"
  if [ -n "$LAST_SUCCESS" ]; then
    echo "# HELP borgmatic_last_success_timestamp_seconds Unix timestamp of the last successful borgmatic run for this config."
    echo "# TYPE borgmatic_last_success_timestamp_seconds gauge"
    echo "borgmatic_last_success_timestamp_seconds{config=\"${CONFIG}\"} ${LAST_SUCCESS}"
  fi
} > "$TMP"
chmod 0644 "$TMP"
mv "$TMP" "$FILE"
