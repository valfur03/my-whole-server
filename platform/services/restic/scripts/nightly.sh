#!/bin/sh

EXIT_CODE=0

sh /common-scripts/healthchecks-run.sh restic-backup sh /scripts/run-all.sh backup || EXIT_CODE=1

if [ "$(date +%u)" = "7" ]
then
	READ_FLAG="--read-data-subset=10%"
	DAY=$(date +%d)
	MONTH=$(date +%m)
	if [ "$DAY" -le 7 ]
	then
		case "$MONTH" in
			01|04|07|10) READ_FLAG="--read-data" ;;
		esac
	fi

	sh /common-scripts/healthchecks-run.sh restic-check sh /scripts/run-all.sh check "$READ_FLAG" || EXIT_CODE=1
fi

exit $EXIT_CODE
