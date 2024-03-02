#/bin/sh

# Run `envsubst` against ACL config
envsubst \
	< /config/configuration.acl.template.yml \
	> /config/configuration.acl.yml

exec "$@"
