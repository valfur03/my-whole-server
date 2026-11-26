#!/bin/sh

if [ $# -lt 1 ]
then
	echo "Usage: $0 <command> [flags]"
	exit 1
fi

COMMAND=$1
shift

EXIT_CODE=0

PROFILES=$(resticprofile profiles | awk -v command="$COMMAND" '
	/^[[:space:]]*[^[:space:]]+:[[:space:]]+\(/ {
		name = $1
		sub(/:$/, "", name)
		sections = $0
		sub(/^[^(]*\(/, "", sections)
		sub(/\).*$/, "", sections)
		count = split(sections, list, /, /)
		for (i = 1; i <= count; i++) {
			if (list[i] == command) {
				print name
				break
			}
		}
	}
')

if [ -z "$PROFILES" ]
then
	echo "No profile found for the $COMMAND command"
	exit 1
fi

for PROFILE in $PROFILES
do
	resticprofile --name "$PROFILE" "$COMMAND" "$@" || EXIT_CODE=1
done

exit $EXIT_CODE
