# Migration: SSH deploys → doco-cd

One-time switchover guide for an existing prod stack that today deploys via `.github/workflows/deploy.yml` (SSH + `git reset --hard` + `docker compose up`). After this, deploys are `git push` to `master`.

This is the migration runbook. The fresh-install / disaster-recovery procedure lives in [`deployment.md`](./deployment.md); the day-2 ops table is also there.

## What's changing

| | Before | After |
|---|---|---|
| Trigger | Manual `workflow_dispatch` of `deploy.yml` | GitHub webhook → `cd.${BASE_DOMAIN}/v1/webhook` |
| Where compose runs | SSH session in `~/server` | `doco-cd` container, fresh clone in `doco-cd-data` named volume |
| Plaintext `.env` | `~/server/.env` (gitignored) | SOPS-encrypted `.env.sops` in repo + age key on host |
| Docker secret files | `~/server/<service>/secrets/<NAME>` | `/etc/my-whole-server/<service>/secrets/<NAME>` |
| OVH DNS keys | Plain values in `.env` | Host-managed Docker secrets, read via `OVH_*_FILE` |
| Borgbase repo IDs / DB creds | Plain `borgmatic/envs/{borgbase,databases}` (gitignored) | SOPS-encrypted `borgmatic/envs/*.env` (committed) |

The doco-cd PR has already landed on `master` by the time you run this guide; the prod host is still running the old layout. Goal of the cutover is to move the secrets, do one final manual `compose up`, and then stop SSHing.

## 0. Before you start

- [ ] You have SSH access to the prod host.
- [ ] You have your current `~/server/.env` contents at hand (you'll re-shape them).
- [ ] The doco-cd PR is merged on `master`.
- [ ] `cd.${BASE_DOMAIN}` resolves (or you can add the DNS record now — Traefik picks it up after the deploy).
- [ ] You have a password manager / offline backup target ready for the age key.

## 1. Generate keys and encrypted files (locally)

Do this on your laptop, in a fresh checkout of `master`.

### 1a. Age key

```sh
age-keygen -o sops_age_key.txt
# Save sops_age_key.txt to your password manager + an offline copy.
# Losing this key = losing every SOPS-encrypted secret in this repo, forever.
```

The public key from this file should already be in `.sops.yaml` (committed in the doco-cd PR). If not, paste it now and commit.

### 1b. Build the slimmed `.env` and encrypt to `.env.sops`

Take your existing prod `.env` and keep only the low-blast-radius interpolation vars. Drop the OVH triplet — those move to host secrets. Add `SECRETS_DIR=/etc/my-whole-server/`.

Suggested set to keep in `.env.sops`:

```
BASE_DOMAIN=…
HOST_IP=…
SECRETS_DIR=/etc/my-whole-server/
SMTP_HOST=…
SMTP_USERNAME=…
SYSTEM_EMAIL=…
OVH_ENDPOINT=ovh-eu
AUTHELIA_LDAP_USER=…
LDAP_BASE_DC=…
LDAP_USERS_DC=…
LDAP_GROUPS_DC=…
AUTHELIA_SYSTEM_EMAIL=…
AUTHELIA_SYSTEM_EMAIL_DISPLAY_NAME=…
SONARR_BASIC_AUTH_TOKEN=…
```

(The exact list depends on what your current `.env` contains — anything Traefik labels or compose-level interpolation references that *isn't* a Docker secret needs to stay.)

```sh
# At the repo root, with sops_age_key.txt next to you
SOPS_AGE_KEY_FILE=$PWD/sops_age_key.txt sops -e .env > .env.sops
```

### 1c. Encrypt the borgmatic env files

```sh
mv borgmatic/envs/databases borgmatic/envs/databases.env
mv borgmatic/envs/borgbase  borgmatic/envs/borgbase.env
SOPS_AGE_KEY_FILE=$PWD/sops_age_key.txt sops -e -i borgmatic/envs/databases.env
SOPS_AGE_KEY_FILE=$PWD/sops_age_key.txt sops -e -i borgmatic/envs/borgbase.env
```

### 1d. Commit and push

```sh
git add .env.sops borgmatic/envs/databases.env borgmatic/envs/borgbase.env
git commit -m "chore: encrypt env files with SOPS"
git push
```

> [!IMPORTANT]
> Do **not** commit `.env`, `sops_age_key.txt`, or the unencrypted `borgmatic/envs/{borgbase,databases}` files. `.gitignore` already excludes them — verify with `git status` before pushing.

### 1e. Generate the webhook secret and GitHub PAT

```sh
openssl rand -base64 40 | tr -d '\n' > /tmp/webhook_secret
```

For the PAT: GitHub → Settings → Developer settings → Fine-grained tokens → Generate new → scope this repo only, permissions `Contents: Read` and `Metadata: Read`. Save the value.

### 1f. Stage a flat secrets bundle for the host

doco-cd plus the new host-managed secrets need everything in one place. Build a flat directory locally and rsync it to the host in step 2.

```sh
mkdir -p /tmp/secrets-bundle
# Copy from your existing ~/server prod tree (or rebuild from your password manager).
# Names below match scripts/distribute_secrets.sh on the new master.
cp ~/server/authelia/secrets/JWT_SECRET             /tmp/secrets-bundle/AUTHELIA_JWT_SECRET
cp ~/server/authelia/secrets/SESSION_SECRET         /tmp/secrets-bundle/AUTHELIA_SESSION_SECRET
cp ~/server/authelia/secrets/STORAGE_ENCRYPTION_KEY /tmp/secrets-bundle/AUTHELIA_STORAGE_ENCRYPTION_KEY
cp ~/server/authelia/secrets/STORAGE_PASSWORD       /tmp/secrets-bundle/AUTHELIA_STORAGE_PASSWORD
cp ~/server/borgmatic/secrets/ENCRYPTION_PASSPHRASE /tmp/secrets-bundle/BORGMATIC_ENCRYPTION_PASSPHRASE
cp ~/server/ldap/secrets/ADMIN_PASSWORD             /tmp/secrets-bundle/LDAP_ADMIN_PASSWORD
cp ~/server/nextcloud/secrets/STORAGE_PASSWORD      /tmp/secrets-bundle/NEXTCLOUD_STORAGE_PASSWORD
cp ~/server/secrets/SMTP_PASSWORD                   /tmp/secrets-bundle/SMTP_PASSWORD
cp ~/server/synapse/secrets/STORAGE_PASSWORD        /tmp/secrets-bundle/SYNAPSE_STORAGE_PASSWORD
cp ~/server/vaultwarden/secrets/ADMIN_TOKEN         /tmp/secrets-bundle/VAULTWARDEN_ADMIN_TOKEN

# New host-managed secrets — paste each value with no trailing newline.
printf '%s' '<OVH_APPLICATION_KEY>'    > /tmp/secrets-bundle/OVH_APPLICATION_KEY
printf '%s' '<OVH_APPLICATION_SECRET>' > /tmp/secrets-bundle/OVH_APPLICATION_SECRET
printf '%s' '<OVH_CONSUMER_KEY>'       > /tmp/secrets-bundle/OVH_CONSUMER_KEY
printf '%s' '<github PAT from 1e>'     > /tmp/secrets-bundle/DOCO_CD_GIT_ACCESS_TOKEN
cp /tmp/webhook_secret                 /tmp/secrets-bundle/DOCO_CD_WEBHOOK_SECRET
cp $PWD/sops_age_key.txt               /tmp/secrets-bundle/DOCO_CD_SOPS_AGE_KEY
```

> The OVH triplet was previously plain text in `.env`. Pull the values out of your old `.env` before you delete it.

## 2. On the prod host

SSH in. From here on, everything is on the prod host. You are still running the old stack — don't `docker compose down` until step 3.

### 2a. Pull the new master into your existing tree

```sh
cd ~/server
git fetch
git checkout master
git reset --hard origin/master
```

The working tree now has the doco-cd service definition, the SOPS-encrypted env files, the new `${SECRETS_DIR}`-aware compose.yaml, and a deleted `.github/workflows/deploy.yml`.

> The currently-running containers are still using the *previous* compose.yaml from when you last ran `docker compose up -d`. Reading the new `compose.yaml` doesn't restart anything — the cutover happens in step 3.

### 2b. Stage host secrets at `/etc/my-whole-server/`

Copy the bundle from step 1f to the host (`scp -r /tmp/secrets-bundle prod:/tmp/`), then:

```sh
sudo install -d -m 0700 /etc/my-whole-server
sudo ./scripts/distribute_secrets.sh /tmp/secrets-bundle /etc/my-whole-server
sudo chmod -R go-rwx /etc/my-whole-server

# Verify
sudo ls -laR /etc/my-whole-server | head -60
```

The script lays out files at the exact paths `compose.yaml`'s `secrets:` block expects (`/etc/my-whole-server/<service>/secrets/<NAME>`).

Wipe the bundle:

```sh
shred -u /tmp/secrets-bundle/* && rmdir /tmp/secrets-bundle
```

### 2c. Sanity-check the SOPS plumbing

Before tearing the stack down, prove the age key works:

```sh
SOPS_AGE_KEY_FILE=/etc/my-whole-server/doco-cd/secrets/SOPS_AGE_KEY \
    sops -d .env.sops | head
```

You should see your plaintext env vars. If this fails, fix it now — the new stack will not start otherwise.

## 3. Cutover

This is the only window of expected downtime — typically <2 min if everything's in place.

```sh
# Still in ~/server
SECRETS_DIR=/etc/my-whole-server/ docker compose up -d --build
```

Compose recreates every container that has a changed `secrets:` reference (which is most of them — every secret file path changed). Existing named data volumes (`postgres-data`, `nextcloud-data`, etc.) are untouched.

Watch doco-cd come up:

```sh
docker compose ps doco-cd
docker compose logs -f doco-cd     # expect "ready"
```

Verify the public webhook route reaches doco-cd through Traefik:

```sh
curl -sI -X POST https://cd.${BASE_DOMAIN}/v1/webhook | head -1
# Expect: HTTP/2 401   (request reached doco-cd; missing HMAC = correct rejection)
```

Spot-check a couple of services that use Traefik / OVH / SOPS-decrypted vars:

```sh
docker compose logs reverse-proxy | grep -i 'ovh\|certificate' | tail
docker compose logs borgmatic     | tail
```

## 4. Wire up the GitHub webhook

Repo → Settings → Webhooks → **Add webhook**:

- Payload URL: `https://cd.${BASE_DOMAIN}/v1/webhook`
- Content type: `application/json`
- Secret: contents of `/etc/my-whole-server/doco-cd/secrets/WEBHOOK_SECRET`
- Events: just **push**
- Active: ✓

GitHub immediately sends a `ping` event; Recent Deliveries should show 200.

## 5. Validate end-to-end

Push a no-op commit (e.g. tweak a comment) to `master`.

- [ ] GitHub → Webhooks → Recent Deliveries shows 200 for the `push` event.
- [ ] `docker compose logs -f doco-cd` shows: webhook received, repo cloned, `.env.sops` decrypted, `compose up` invoked, deploy success.
- [ ] `docker compose ps` — uptimes are preserved on services whose definition didn't change (no spurious recreations).
- [ ] Optional second push: bump a leaf service's image digest, confirm only that service recreates.

## 6. Cleanup

After the validation deploy succeeds:

### 6a. Old GitHub Actions secrets

`.github/workflows/deploy.yml` is gone. Delete the now-unused secrets at repo → Settings → Secrets and variables → Actions:

- `SERVER_HOST`
- `SERVER_USERNAME`
- `SERVER_SSH_KEY`
- `PROD_SERVER_DEPLOY_DIR`

### 6b. Old plaintext secrets on the host

```sh
# Confirm everything moved
ls /etc/my-whole-server/

# Then nuke the originals
shred -u ~/server/.env
sudo find ~/server -type d -name secrets -exec shred -u -- {}/* \; -exec rmdir -- {} \;
shred -u ~/server/borgmatic/envs/borgbase ~/server/borgmatic/envs/databases 2>/dev/null || true
```

### 6c. The `~/server` checkout itself

doco-cd now manages its own clone in the `doco-cd-data` named volume. The `~/server` tree is dead weight, but **keep it for one or two deploy cycles** as a break-glass. Once you're confident, `rm -rf ~/server`.

## 7. Rollback

If step 3 or 5 goes wrong, the old layout still exists on the host (you haven't run cleanup yet).

### Quick rollback to the pre-migration state

```sh
cd ~/server
git checkout <last-good-sha-before-doco-cd-PR>
docker compose down
docker compose up -d --build      # uses ~/server/.env and ~/server/<svc>/secrets/
```

The data volumes are unchanged, so services come back up against the same data.

### If only doco-cd itself is misbehaving

You can keep the new stack up but disable auto-deploy:

```sh
# Either
docker compose stop doco-cd
# Or in GitHub: Webhooks → Edit → Active: ✗
```

Manual SSH `compose up` still works; you've just paused the GitOps loop.

### If you've already done step 6b (cleanup)

Restore from borg before rolling back compose:

```sh
docker compose exec borgmatic borgmatic extract --archive latest \
    --repo /backup/local/secrets --destination /tmp -c /etc/borgmatic.d/secrets.yaml
# Copy out, redistribute — see docs/backups.md "How to restore Docker secrets"
```

## Post-migration sanity (1 week later)

- [ ] Renovate PR has merged automatically and triggered a successful redeploy.
- [ ] `docker compose logs doco-cd | grep -i error` is empty for routine deploys.
- [ ] Borg backups completed at least once after the cutover (`docker compose logs borgmatic | tail`).
- [ ] You haven't SSHed to deploy in 7 days.

If all four hold, the migration is complete. Delete `~/server`.
