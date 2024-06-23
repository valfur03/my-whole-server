#!/bin/sh

if [ $# -ne 1 ]
then
	printf 'arguments number must be 1\n'
	exit 1
fi

cd $(dirname "$0")

SOURCE_DIRECTORY=$1

for i in \
	AUTHELIA_JWT_SECRET,authelia/secrets/JWT_SECRET \
	AUTHELIA_SESSION_SECRET,authelia/secrets/SESSION_SECRET \
	AUTHELIA_STORAGE_ENCRYPTION_KEY,authelia/secrets/STORAGE_ENCRYPTION_KEY \
	AUTHELIA_STORAGE_PASSWORD,authelia/secrets/STORAGE_PASSWORD \
	BORGMATIC_ENCRYPTION_PASSPHRASE,borgmatic/secrets/ENCRYPTION_PASSPHRASE \
	LDAP_ADMIN_PASSWORD,ldap/secrets/ADMIN_PASSWORD \
	NEXTCLOUD_STORAGE_PASSWORD,nextcloud/secrets/STORAGE_PASSWORD \
	SYNAPSE_STORAGE_PASSWORD,synapse/secrets/STORAGE_PASSWORD
do
	IFS=","
	set -- $i

	if [ -f  ../$SOURCE_DIRECTORY/$1 ]
	then
		cp ../$SOURCE_DIRECTORY/$1 ../$2
	fi
done
