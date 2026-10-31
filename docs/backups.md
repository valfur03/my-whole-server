# Backups

## Overview

At the moment, two tools back up the services: borg and restic. The repository is slowly shifting towards restic only.

<table>
  <tr>
    <th>Tool</th>
    <td><a href="https://restic.net/">Restic</a></td>
    <td><a href="https://www.borgbackup.org/">Borg</a></td>
  </tr>
  <tr>
    <th>Configuration tool</th>
    <td><a href="https://creativeprojects.github.io/resticprofile/">Resticprofile</a></td>
    <td><a href="https://torsion.org/borgmatic/">Borgmatic</a></td>
  </tr>
  <tr>
    <th>Local destination</th>
    <td><i>none</i></td>
    <td><code>/backup/local</code></td>
  </tr>
  <tr>
    <th>Remote destination</th>
    <td><a href="https://www.backblaze.com/cloud-storage">Backblaze B2</a></td>
    <td><a href="https://www.borgbase.com/">BorgBase</a></td>
  </tr>
</table>

An additional third-party service, [healthchecks.io](https://healthchecks.io/), tracks backup jobs and sends an alert when a job was missed or failed.

## Status of the migration

<!-- TODO -->

## Restic

> [!NOTE]
> As mentioned earlier, Restic backups target a subset of services only, and are only written remotely.

### Quick commands

**Run a backup by hand:**

```shell
# Without a healthchecks.io ping
docker compose -p restic exec restic resticprofile --name <profile> backup

# With a healthchecks.io ping
docker compose -p restic exec restic sh /common-scripts/healthchecks-run.sh restic-backup sh /scripts/backup-all.sh
```

**List the snapshots:**

```shell
docker compose -p restic exec restic resticprofile --name <repository-profile> snapshots
docker compose -p restic exec restic resticprofile --name <repository-profile> snapshots --latest 1
```

**Create a repository:**

```shell
docker compose -p restic exec restic resticprofile --name <repository-profile> init
```

### Restoring a backup

#### Database

> [!NOTE]
> The restore step does not overwrite data: make sure the database is blank first.

**Postgres:**

```shell
docker compose -p restic exec -T restic resticprofile --name <repository-profile> dump --path /<file>.sql latest /<file>.sql \
  | docker compose -p <stack> exec -T <service> psql -U <user> -d <database> -v ON_ERROR_STOP=1 -q
```

#### LDAP

<!-- TODO -->

#### Files

<!-- TODO: this section needs a complete re-write. what is a volume? what's `--include`? -->

```shell
docker compose -p restic exec restic resticprofile --name <repository-profile> restore latest --target /tmp/restore
```

The files are under `/tmp/restore/volumes/<name>`. Add `--include /volumes/<name>` to restore one volume only.

The volumes are read-only in the Restic container. To copy the files into a volume, stop the service that uses it, then:

```shell
docker compose -p restic exec -T restic tar -C /tmp/restore/volumes/<name> -cf - . \
  | docker run --rm -i -v <volume>:/to alpine tar -C /to -xpf -
docker compose -p restic exec restic rm -rf /tmp/restore
```

This copy into a volume is not tested yet (Phase 2).

## Borg

| Repository | Location                                             |
| ---------- | ---------------------------------------------------- |
| local      | `/backup/local/<service>`                            |
| BorgBase   | `ssh://<repo_id>@<repo_id>.repo.borgbase.com/./repo` |

### Quick commands

**Run a backup by hand:**

```shell
docker compose -p borgmatic exec borgmatic borgmatic --stats --list --verbosity 1
```

#### Database

**Postgres:**

```shell
docker compose -p borgmatic exec borgmatic borgmatic restore --archive latest --database <database> -c /etc/borgmatic.d/<service>.yaml
```

#### Files

```shell
docker compose -p borgmatic exec borgmatic borgmatic restore --archive latest --repository <repository> -c /etc/borgmatic.d/<service>.yaml --progress
```

### Troubleshooting

If a `before_*` hook fails and you do not need it, skip it:

```shell
docker compose -p borgmatic exec borgmatic borgmatic ... --override 'before_extract=[]'
```

## B2 setup

### Creating the backup key

We use the `b2` CLI because the web UI's "Read and Write" key includes `deleteFiles`, which this key must **not** have.

```shell
b2 key create --bucket <bucket> <key-name> listBuckets,listFiles,readFiles,writeFiles
```
