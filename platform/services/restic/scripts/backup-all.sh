#!/bin/sh

EXIT_CODE=0

PROFILES=$(resticprofile profiles | awk '$2 == "(backup)" { sub(/:$/, "", $1); print $1 }')

if [ -z "$PROFILES" ]
then
	echo "No backup profile found"
	exit 1
fi

for PROFILE in $PROFILES
do
	resticprofile --name "$PROFILE" backup || EXIT_CODE=1
done

exit $EXIT_CODE
