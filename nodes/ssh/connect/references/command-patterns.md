# SSH Connect Patterns

## One-shot command

```bash
ssh ops@host.example.com 'uptime'
```

## Batch-safe with first-contact policy

```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new ops@host.example.com 'uname -a'
```

## Bastion hop

```bash
ssh -J bastion.example.com ops@db.internal.example.com 'ps aux | grep postgres'
```

## TTY for sudo

```bash
ssh -tt ops@host.example.com 'sudo systemctl status api'
```
