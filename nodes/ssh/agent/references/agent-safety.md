# Agent Safety Notes

## Start and export

```bash
eval "$(ssh-agent -s)"
```

## Load a key for one hour with confirmation

```bash
ssh-add -t 1h -c ~/.ssh/id_ed25519
```

## Clear all identities

```bash
ssh-add -D
```

## Forwarding caution

Forward the agent only to trusted hosts:

```bash
ssh -A bastion.example.com
```

Prefer `ProxyJump` when the jump host does not actually need to use your key.
