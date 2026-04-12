---
name: agent
description: >
  Start ssh-agent, load or remove identities with ssh-add, and manage key
  lifetimes or confirmation prompts. Use when SSH keys are passphrase-protected
  or when many SSH operations should reuse one unlocked identity safely.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Agent

## When to Use

- A private key is passphrase-protected and should be unlocked once
- Many SSH commands or transfers will run in one session
- You need temporary key lifetimes or confirmation prompts
- A trusted bastion requires agent-backed auth

## Workflow

1. Start the agent and export its environment into the current shell.
2. Add the required key with optional lifetime or confirmation.
3. Run the SSH commands that depend on the agent.
4. List or clear identities when the work is done.

## Examples

```bash
# Start the agent and export env vars
eval "$(./scripts/manage-agent.sh)"

# Add a key for one hour with confirmation
SSH_AGENT_ACTION=add \
SSH_KEY_PATH="$HOME/.ssh/id_ed25519" \
SSH_ADD_LIFETIME=1h \
SSH_ADD_CONFIRM=true \
./scripts/manage-agent.sh

# List loaded identities
SSH_AGENT_ACTION=list ./scripts/manage-agent.sh

# Remove all identities
SSH_AGENT_ACTION=clear ./scripts/manage-agent.sh
```

## Edge Cases

- `ssh-add` needs `SSH_AUTH_SOCK`; start or re-export the agent first.
- Keys with loose file permissions may be ignored.
- Agent forwarding is high-trust; prefer `ProxyJump` unless a remote hop must use the key.
