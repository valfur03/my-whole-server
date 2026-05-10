# Backups

Backups are fully managed by [borgmatic](https://torsion.org/borgmatic/).

## How to perform a backup

Backups are performed automatically by a cron job inside the borgmatic service.

It is also possible to perform a manual backup on all repositories.

```shell
docker compose exec borgmatic borgmatic --stats --list --verbosity 1
```

> [!NOTE]
> The flags at the end of the command line are optional.

See more at the [backup creation documentation](https://torsion.org/borgmatic/docs/how-to/set-up-backups/#backups).

## How to restore a backup

Backup restoration is not as simple as creation.
It is recommended to restore each repository individually, one after the other.

Also, the database may be restored before the data volumes.

For the database restoration:

```shell
docker compose exec borgmatic borgmatic restore --archive latest --database <service> -c /etc/borgmatic.d/<service>.yaml
```

For the data extraction:

```shell
docker compose exec borgmatic borgmatic restore --archive latest --repository <repo> -c /etc/borgmatic.d/<service>.yaml --progress
```

Here are the possible repository values:

| Type     | Value                                                |
|----------|------------------------------------------------------|
| local    | `/backup/local/<service>`                            |
| borgbase | `ssh://<repo_id>@<repo_id>.repo.borgbase.com/./repo` |

### How to restore Docker secrets

> [!WARNING]
> The `BORGMATIC_ENCRYPTION_PASSPHRASE` is still needed,
> so hopefully you have backed it up somewhere else.

> [!IMPORTANT]
> Before doco-cd: secrets lived under `<repo>/<service>/secrets/<NAME>` and `distribute_secrets.sh` (no second arg) restored them there. With doco-cd, secrets live under `/etc/my-whole-server/<service>/secrets/<NAME>` on the host and the distribution script needs the dest root passed explicitly.

We have to follow these steps:

1. Extract the secrets from our repo
   ```shell
   docker compose exec borgmatic borgmatic extract --archive latest --repo <secrets_repo> --destination /tmp -c /etc/borgmatic.d/secrets.yaml --progress
   ```
2. Copy the secrets out of the Docker container
   ```shell
   mkdir -p .tmp_secrets
   docker compose cp borgmatic:/tmp/run/secrets/. .tmp_secrets/
   ```
3. Populate our secrets in our host directory
   ```shell
   # On the prod host with doco-cd:
   ./scripts/distribute_secrets.sh .tmp_secrets /etc/my-whole-server

   # Or for a local-dev layout (legacy / no doco-cd):
   ./scripts/distribute_secrets.sh .tmp_secrets
   ```

### How to restore the SOPS age key

The age private key encrypts `.env.sops` and `borgmatic/envs/*.env`. Without it, the deployed stack cannot read its compose-interpolation env. The key is included in the secrets archive (under `DOCO_CD_SOPS_AGE_KEY`) and `distribute_secrets.sh` places it at `/etc/my-whole-server/doco-cd/secrets/SOPS_AGE_KEY`. Compose mounts that file into the doco-cd container as the `DOCO_CD_SOPS_AGE_KEY` Docker secret, where doco-cd reads it via `SOPS_AGE_KEY_FILE`.

> [!IMPORTANT]
> Treat the age key like the `BORGMATIC_ENCRYPTION_PASSPHRASE`: keep an offline copy outside this backup chain. If you lose both the live host and this archive's age key, the encrypted `.env.sops` in the public repo becomes unrecoverable.

### Disaster-recovery order

1. Restore `BORGMATIC_ENCRYPTION_PASSPHRASE` from your offline copy. Without it, no other archive opens.
2. On a fresh host: install Docker + Compose, clone this repo into `/data/my-whole-server`, set `SECRETS_DIR=/etc/my-whole-server/` and the prerequisite system secrets (at minimum, the borg passphrase + age key) so `borgmatic` can come up.
3. Bring borgmatic up alone (`docker compose up -d borgmatic`), extract the secrets archive, run `distribute_secrets.sh .tmp_secrets /etc/my-whole-server`.
4. Restore database archives, then per-service data volumes.
5. `docker compose up -d` for the rest of the stack. doco-cd takes over from there.

## Troubleshooting

### An error occurs with `before_*` script

Sometimes, the script fails, but we don't need to execute anyway.
To disable, run the command with this flag:

```shell
docker compose exec borgmatic borgmatic ... --override 'before_extract=[]’
```
