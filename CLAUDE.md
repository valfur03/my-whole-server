# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

A single Docker Compose project (`compose.yaml`, project name `my-whole-server`) that runs the author's home server. There is no application code here — every "service" is either an upstream image referenced by digest, or a thin Dockerfile wrapper around one that bakes config in. Edits are almost always YAML/config tweaks plus a Renovate-managed image bump.

## Common commands

```sh
# Bring the stack up / apply changes locally (rebuilds images that have a `build:` block)
docker compose up -d --build

# Rebuild + restart one service
docker compose up -d --build <service>

# Tail logs
docker compose logs -f <service>

# Manual borg backup of every repository
docker compose exec borgmatic borgmatic --stats --list --verbosity 1
```

Restore procedure (database first, then volumes, then secrets) is documented in `docs/backups.md`. There is no test suite, linter, or build step beyond `docker compose build`.

## Deployment

`git push` to `master` is the deploy. [doco-cd](https://github.com/kimdre/doco-cd) runs as the `doco-cd` service inside this same compose stack, listens for GitHub webhooks at `https://cd.${BASE_DOMAIN}/v1/webhook` (HMAC-secured by `DOCO_CD_WEBHOOK_SECRET`), and runs `docker compose up -d --build` from a fresh clone of this repo inside the `doco-cd-data` named volume. Bootstrap and operational guide: `docs/deployment.md`. There is no GitHub Actions workflow.

Renovate (`renovate.json`, `config:best-practices`) opens PRs to bump pinned image digests. The recent commit history is dominated by these bumps.

## Architecture

### Edge: Traefik + Authelia

`reverse-proxy` (Traefik, built from `traefik/`) terminates TLS for everything (Let's Encrypt via OVH DNS-01) and discovers backends through `socket-proxy` rather than the raw Docker socket. Almost every public service exposes itself through Traefik labels declared **on the service itself** in `compose.yaml`, including the `authelia@docker` forward-auth middleware on anything that should require login.

Authelia (built from `authelia/`) is the SSO gate. Its image wraps the upstream Authelia with `gettext` so `my-entrypoint.sh` can `envsubst` `configuration.acl.template.yml` → `configuration.acl.yml` at container start — i.e. the ACL is expanded from environment variables on each boot. Authelia is backed by its own Postgres + Redis and authenticates against the shared `ldap` (OpenLDAP) service. To add a new protected route: add `traefik.http.routers.<name>.middlewares: authelia@docker` to that service's labels.

### Network segmentation

Networks in `compose.yaml` are the de-facto access-control layer; services only join the networks they need:

- `proxy` — anything Traefik must reach (subnet pinned to `172.47.0.0/16`).
- `<service>-backend` — db/redis/app trio per app (e.g. `authelia-backend`, `nextcloud-backend`, `synapse-backend`).
- `ldap-backend` — only Authelia and phpLDAPadmin reach the LDAP server.
- `metrics`, `seedbox-metrics` — Prometheus scrape paths.
- `seedbox-indexer`, `seedbox-torrenting` — separate the *arr indexers from the torrent client.
- `AAA-vpn` (subnet `10.8.1.0/24`) — the name is intentional: alphabetical ordering forces this to be `eth0` inside `wg-easy`. Don't rename it.

The seedbox stack (`vpn`, `transmission`, `joal`, `flaresolverr`, `jackett`) all share `network_mode: "service:vpn"`, so they egress only through the OpenVPN client. `transmission-exporter` reaches transmission via `http://vpn:9091`.

### Secrets

Three mechanisms, used together:

1. **Host-managed Docker secrets** — defined under `secrets:` at the bottom of `compose.yaml`. Each `file:` is `${SECRETS_DIR:-./}<service>/secrets/<NAME>`. In prod doco-cd sets `SECRETS_DIR=/etc/my-whole-server/` (via `.env.sops`) so files are read from the host dir, not the freshly-cloned repo. Locally, the default `./` keeps the existing repo-relative layout. Mounted at `/run/secrets/<NAME>`; services read via `*_FILE` env vars (and Traefik via `OVH_*_FILE`).
2. **SOPS-encrypted `.env.sops`** — committed to the repo, encrypted with `age`. doco-cd auto-decrypts at deploy time (referenced from `.doco-cd.yaml`'s `env_files`). Contains low-blast-radius interpolation vars (`BASE_DOMAIN`, `HOST_IP`, SMTP host/user, `SECRETS_DIR`, …). `OVH_*` keys and DNS-related secrets are deliberately *not* here — they're host-managed Docker secrets in (1).
3. **SOPS-encrypted `borgmatic/envs/*.env`** — same mechanism, scoped to borgmatic's env_file references. Holds `BORGBASE_*_REPO_ID` and database creds borgmatic uses. Borgmatic doesn't support `_FILE` env vars, so this is the right layer.

`scripts/distribute_secrets.sh <source_dir> [<dest_root>]` copies a flat directory of secret files into the per-service layout. With no `dest_root`, writes into the repo (legacy local-dev). In prod, pass `/etc/my-whole-server` so files land in the host dir referenced by `${SECRETS_DIR}`.

`.gitignore` excludes plaintext `.env`, the unencrypted `borgmatic/envs/{borgbase,databases}` files, the age private key (`sops_age_key*`, `*.age`), and all `secrets/` directories. Encrypted forms (`.env.sops`, `borgmatic/envs/*.env`) are committed.

The age key itself is a Docker secret (`DOCO_CD_SOPS_AGE_KEY`) read by doco-cd via `SOPS_AGE_KEY_FILE`. It's the single most critical artefact to back up out-of-band — losing it means losing every encrypted secret.

### Backups (borgmatic)

`compose.yaml` mounts the live data volumes **read-only-ish** into the `borgmatic` container, plus the Docker socket so the `before_backup` hooks can `docker exec` into other containers (see `borgmatic/scripts/`). `CRON: "0 2 * * *"` runs daily.

Borgmatic config under `borgmatic/config/` is composed via the `!include` directive: each per-service file (e.g. `nextcloud.yaml`, `vaultwarden.yaml`) merges in `includes/common.yaml`, which itself pulls in shared `constants/`, `encryption/`, `hooks/`, `name-formats/`, `retention/`, and `repositories/` fragments. To add a new service backup, follow that same pattern rather than duplicating the common bits inline.

Repositories: a `local` mount at `/backup/local` and remote borgbase repos parameterised via `${BORGBASE_*_REPO_ID}` env vars in `borgmatic/envs/borgbase` (gitignored).

### Observability

Prometheus (built from `prometheus/`) + Grafana + node-exporter + transmission-exporter on the `metrics` / `seedbox-metrics` networks. Tracing pipeline: `otel-collector` (config at `otel/collector/config.yml`) ships to a Jaeger built from `otel/jaeger.Dockerfile` using Badger storage at `/badger`.

### Custom-built images

Every directory with a `Dockerfile` wraps an upstream image to bake in config so the running container needs no bind-mounted config file. Pattern: `FROM upstream@sha256:...` then `COPY` the local config in. When you change config in `authelia/`, `traefik/`, `nextcloud/`, `prometheus/`, `web/`, `seedbox/joal/`, `otel/`, or `transmission-exporter/`, you must rebuild that service (`docker compose up -d --build <name>`); a plain restart won't pick the change up.

## Conventions

- All public hostnames are `<sub>.${BASE_DOMAIN}`. New routes follow this scheme via the `${BASE_DOMAIN}` variable in Traefik labels.
- Image references everywhere are pinned to `tag@sha256:...`. Don't add an unpinned image — Renovate expects the digest form.
- Timezone is `Europe/Paris` across services that take a `TZ`.
