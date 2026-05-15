# Deployment

Deploys are pull-based via [doco-cd](https://github.com/kimdre/doco-cd) running inside this same compose stack. A `git push` to `master` fires a GitHub webhook at `https://cd.${BASE_DOMAIN}/v1/webhook`; doco-cd verifies the HMAC signature, fetches the new commit into `/data/my-whole-server`, decrypts `.env.sops` (and `borgmatic/envs/*.env`) with the age key mounted as a Docker secret, and runs `docker compose up -d --build`.

There is no GitHub Actions workflow. SSH access is preserved as a break-glass.

## Bootstrap (one time, over SSH)

This is the only manual step. After it succeeds, every subsequent deploy is `git push`.

### 1. Generate the age key locally

```sh
age-keygen -o sops_age_key.txt
# Note the public key — it goes into .sops.yaml
```

Back up `sops_age_key.txt` outside this repo (password manager + offline copy). Losing it means losing every secret encrypted with it.

### 2. Fill in `.sops.yaml`

Replace `<AGE_PUBLIC_KEY>` in `.sops.yaml` with the public key from step 1.

### 3. Encrypt `.env.sops`

Build a slimmed `.env` with only the low-blast-radius interpolation vars (no OVH keys — those move to host secrets). Include `SECRETS_DIR=/etc/my-whole-server/` so compose picks the host layout in prod.

```sh
sops -e .env > .env.sops
```

Same treatment for the borgmatic env files:

```sh
mv borgmatic/envs/databases borgmatic/envs/databases.env
mv borgmatic/envs/borgbase  borgmatic/envs/borgbase.env
sops -e -i borgmatic/envs/databases.env
sops -e -i borgmatic/envs/borgbase.env
```

Commit `.env.sops`, `borgmatic/envs/*.env`, and the updated `.sops.yaml`.

### 4. Stage host secrets

On the prod host:

```sh
sudo install -d -m 0700 /etc/my-whole-server

# Move existing per-service secret files. The layout below matches what
# scripts/distribute_secrets.sh produces with /etc/my-whole-server as dest root.
sudo cp -r ~/server/authelia/secrets    /etc/my-whole-server/authelia/secrets
sudo cp -r ~/server/borgmatic/secrets   /etc/my-whole-server/borgmatic/secrets
sudo cp -r ~/server/ldap/secrets        /etc/my-whole-server/ldap/secrets
sudo cp -r ~/server/nextcloud/secrets   /etc/my-whole-server/nextcloud/secrets
sudo cp -r ~/server/synapse/secrets     /etc/my-whole-server/synapse/secrets
sudo cp -r ~/server/vaultwarden/secrets /etc/my-whole-server/vaultwarden/secrets
sudo cp -r ~/server/secrets             /etc/my-whole-server/secrets

# New host-managed secrets (paste each value).
sudo install -d -m 0700 /etc/my-whole-server/ovh/secrets /etc/my-whole-server/doco-cd/secrets
echo -n '<OVH_APPLICATION_KEY>'    | sudo tee /etc/my-whole-server/ovh/secrets/APPLICATION_KEY    >/dev/null
echo -n '<OVH_APPLICATION_SECRET>' | sudo tee /etc/my-whole-server/ovh/secrets/APPLICATION_SECRET >/dev/null
echo -n '<OVH_CONSUMER_KEY>'       | sudo tee /etc/my-whole-server/ovh/secrets/CONSUMER_KEY       >/dev/null
echo -n '<github PAT>'             | sudo tee /etc/my-whole-server/doco-cd/secrets/GIT_ACCESS_TOKEN >/dev/null
openssl rand -base64 40            | tr -d '\n' | sudo tee /etc/my-whole-server/doco-cd/secrets/WEBHOOK_SECRET >/dev/null
sudo install -m 0600 sops_age_key.txt /etc/my-whole-server/doco-cd/secrets/SOPS_AGE_KEY

sudo chmod -R go-rwx /etc/my-whole-server
```

### 5. Final manual deploy

doco-cd's data lives in the `doco-cd-data` named volume; nothing to pre-stage on the host. Run the last manual `compose up` from your existing working tree (`~/server` or wherever you currently deploy from). After this boots, doco-cd clones a fresh copy into its volume on the first webhook and takes over.

```sh
cd ~/server          # or wherever you currently keep the working tree
git fetch && git checkout master && git reset --hard origin/master
SECRETS_DIR=/etc/my-whole-server/ docker compose up -d --build
docker compose ps doco-cd
docker compose logs -f doco-cd          # expect "ready"
```

Sanity-check the public route exists:

```sh
curl -sI -X POST https://cd.<BASE_DOMAIN>/v1/webhook | head -1
# Expect HTTP/2 401 — request reached doco-cd, missing HMAC = correct rejection.
```

### 6. Wire up the GitHub webhook

Repo → Settings → Webhooks → Add webhook:

- Payload URL: `https://cd.${BASE_DOMAIN}/v1/webhook`
- Content type: `application/json`
- Secret: contents of `/etc/my-whole-server/doco-cd/secrets/WEBHOOK_SECRET`
- Events: just `push`
- Active: ✓

### 7. Validate

Push a no-op commit. Check:

- GitHub → Webhooks → Recent Deliveries shows 200.
- `docker compose logs -f doco-cd` shows the deploy.
- `docker compose ps` shows uptimes preserved (no spurious recreations).

### 8. Clean up old GitHub Actions secrets

Since `.github/workflows/deploy.yml` is gone, delete the unused secrets from the repo settings: `SERVER_HOST`, `SERVER_USERNAME`, `SERVER_SSH_KEY`, `PROD_SERVER_DEPLOY_DIR`.

## Day-2

| Want to | Do |
|---|---|
| Deploy a change | `git push` to `master` |
| Force a redeploy without a code change | Re-trigger the webhook from GitHub → Webhooks → Recent Deliveries |
| Rotate the webhook secret | Replace `/etc/my-whole-server/doco-cd/secrets/WEBHOOK_SECRET`, `docker compose up -d doco-cd`, update GitHub webhook secret |
| Rotate the age key | Re-encrypt `.env.sops` and `borgmatic/envs/*.env` with the new public key, replace the host file, restart doco-cd. Old git history remains decryptable with the old key — assume any leaked old key is permanently compromising |
| Pause auto-deploys | Disable the GitHub webhook (Active: ✗) or `docker compose stop doco-cd` |
| Manual rollback | SSH to host, `cd "$(docker volume inspect my-whole-server_doco-cd-data --format '{{ .Mountpoint }}')/my-whole-server"`, `git checkout <good-sha>`, `SECRETS_DIR=/etc/my-whole-server/ docker compose up -d --build` |

## Self-update

When doco-cd's own image is bumped (Renovate PR), the running doco-cd container redeploys *itself* on the next webhook. Docker creates the new container before stopping the old, so the in-flight webhook completes. If a self-update ever wedges, fall back to the manual SSH path above.
