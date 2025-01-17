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
   ./scripts/distribute_secrets.sh .tmp_secrets
   ```

## Troubleshooting

### An error occurs with `before_*` script

Sometimes, the script fails, but we don't need to execute anyway.
To disable, run the command with this flag:

```shell
docker compose exec borgmatic borgmatic ... --override 'before_extract=[]’
```