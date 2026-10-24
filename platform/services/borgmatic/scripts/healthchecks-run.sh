#!/bin/sh

set -o pipefail

PING_URL="${BORGMATIC_HEALTHCHECKS_BASE_URL:?}/borgmatic"
LOG_FILE=$(mktemp)
trap 'rm -f "$LOG_FILE"' EXIT

ping_healthchecks()
{
	STATUS=$1
	curl -fsS -m 10 --retry 5 --retry-all-errors -o /dev/null --data-binary @- "$PING_URL/$STATUS" \
		|| printf "Unable to ping healthchecks.io with status: %s\n" "$STATUS"
}

ping_healthchecks start < /dev/null

borgmatic-start --stats -v 0 "$@" 2>&1 | tee "$LOG_FILE"
EXIT_CODE=$?

tail -c 100000 "$LOG_FILE" | ping_healthchecks "$EXIT_CODE"

exit $EXIT_CODE
