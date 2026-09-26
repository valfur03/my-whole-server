#!/bin/sh
set -eu

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

volume_exists() {
    docker volume inspect "$1" >/dev/null 2>&1
}

mountpoint_of() {
    docker volume inspect -f '{{.Mountpoint}}' "$1"
}

if [ "$DRY_RUN" -eq 0 ]; then
    [ "$(id -u)" -eq 0 ] || fail "must run as root: the volume directories are root-owned"
    [ -z "$(docker ps -q)" ] || fail "refusing to run while containers are running"
fi

PAIRS="my-whole-server_adguard-conf wireguard_adguard-conf
my-whole-server_adguard-work wireguard_adguard-work
my-whole-server_wireguard wireguard_wireguard
my-whole-server_authelia-database authelia_database
my-whole-server_ldap-config authelia_ldap-config
my-whole-server_ldap-database authelia_ldap-database
my-whole-server_autobrr-config seedbox_autobrr-config
my-whole-server_cross-seed-config seedbox_cross-seed-config
my-whole-server_prowlarr-config seedbox_prowlarr-config
my-whole-server_qbittorrent-config seedbox_qbittorrent-config
my-whole-server_sonarr-config seedbox_sonarr-config
my-whole-server_radarr-config seedbox_radarr-config
my-whole-server_plex-config seedbox_plex-config
my-whole-server_seerr-config seedbox_seerr-config
my-whole-server_seerr-database seedbox_seerr-database
my-whole-server_borg-cache borgmatic_borg-cache
my-whole-server_borg-config borgmatic_borg-config
my-whole-server_da-many-database da-many_database
my-whole-server_grafana-data observability_grafana-data
my-whole-server_prometheus-data observability_prometheus-data
my-whole-server_loki-data observability_loki-data
my-whole-server_alloy-logs-data observability_alloy-logs-data
my-whole-server_otel-collector-data observability_otel-collector-data
my-whole-server_tempo-data observability_tempo-data
my-whole-server_node-textfile-collector observability_node-textfile-collector
my-whole-server_nextcloud-data nextcloud_data
my-whole-server_nextcloud-database nextcloud_database
my-whole-server_traefik-acme http_acme
my-whole-server_vaultwarden-data vaultwarden_data
my-whole-server_weekly-money-database weekly-money_database"

while IFS=' ' read -r old new; do
    [ -z "$old" ] && continue

    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'would move %s -> %s\n' "$old" "$new"
        continue
    fi

    volume_exists "$old" || fail "source volume $old does not exist"

    if volume_exists "$new" && [ -n "$(ls -A "$(mountpoint_of "$new")")" ]; then
        printf 'skipping %s -> %s: target already exists and is not empty\n' "$old" "$new"
        continue
    fi

    project=${new%%_*}
    key=${new#*_}

    if ! volume_exists "$new"; then
        docker volume create \
            --label com.docker.compose.project="$project" \
            --label com.docker.compose.volume="$key" \
            "$new" >/dev/null
    fi

    old_mp=$(mountpoint_of "$old")
    new_mp=$(mountpoint_of "$new")

    [ -d "$old_mp" ] || fail "$old_mp is not a directory"
    [ -d "$new_mp" ] || fail "$new_mp is not a directory"

    if [ "$(stat -c %d "$old_mp")" != "$(stat -c %d "$new_mp")" ]; then
        fail "$old_mp and $new_mp are on different filesystems: a move would copy"
    fi

    rmdir "$new_mp" || fail "$new_mp is not empty"
    mv "$old_mp" "$new_mp"

    printf 'moved %s -> %s\n' "$old" "$new"
done <<EOF
$PAIRS
EOF

printf '\n# to undo, while the containers are still down:\n'
while IFS=' ' read -r old new; do
    [ -z "$old" ] && continue
    printf 'mv /var/lib/docker/volumes/%s/_data /var/lib/docker/volumes/%s/_data\n' "$new" "$old"
done <<EOF
$PAIRS
EOF

printf '\n# once the new stack is verified, the empty source volumes:\n'
while IFS=' ' read -r old new; do
    [ -z "$old" ] && continue
    printf 'docker volume rm %s\n' "$old"
done <<EOF
$PAIRS
EOF
printf 'docker volume rm my-whole-server_vidlvery-public-directory doco-cd_data\n'
