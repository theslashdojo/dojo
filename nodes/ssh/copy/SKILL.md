---
name: copy
description: >
  Transfer files and directories over SSH using scp or sftp, including recursive
  copies, batch jobs, bastions, and preserved metadata. Use when pushing build
  artifacts, pulling logs or backups, or scripting repeatable secure transfers.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Copy

## When to Use

- Upload deploy artifacts to a server
- Download logs, dumps, or backups
- Copy directories recursively over SSH
- Run repeatable transfer jobs with `sftp -b`
- Move files through a bastion using `-J`

## Workflow

1. Pick `scp` for quick one-shot copies or `sftp` for batch-oriented workflows.
2. Set the remote host, optional user, and source/destination paths.
3. Add `SSH_RECURSIVE=true` for directories and `SSH_PRESERVE_TIMES=true` when metadata matters.
4. Use `SSH_PROXY_JUMP` or config-based `ProxyJump` for private hosts.
5. Prefer key-based auth and batch-safe SSH settings for unattended runs.

## Examples

```bash
# Upload a single file with scp
SSH_HOST=host.example.com \
SSH_USER=ops \
SSH_LOCAL_PATH=build.tar.gz \
SSH_REMOTE_PATH=/srv/releases/build.tar.gz \
./scripts/transfer-files.sh

# Download a log file
SSH_COPY_MODE=scp \
SSH_DIRECTION=download \
SSH_HOST=host.example.com \
SSH_USER=ops \
SSH_LOCAL_PATH=./api.log \
SSH_REMOTE_PATH=/var/log/api.log \
./scripts/transfer-files.sh

# Upload recursively with a bastion
SSH_COPY_MODE=scp \
SSH_HOST=app.internal.example.com \
SSH_USER=deploy \
SSH_PROXY_JUMP=bastion.example.com \
SSH_LOCAL_PATH=public \
SSH_REMOTE_PATH=/srv/www \
SSH_RECURSIVE=true \
./scripts/transfer-files.sh

# sftp batch file
SSH_COPY_MODE=sftp \
SSH_HOST=host.example.com \
SSH_USER=ops \
SSH_BATCH_FILE=deploy.sftp \
./scripts/transfer-files.sh
```

## Edge Cases

- Server lacks SFTP support: set `SSH_LEGACY_SCP=true` for `scp -O` only if compatibility requires it.
- Large transfers through a slow link: set `SSH_BANDWIDTH_LIMIT`.
- Paths with spaces: prefer a prepared `sftp` batch file rather than ad hoc shell quoting.
- Repeated transfers to the same host: enable multiplexing in `[[ssh/config]]`.
