#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export SSH_TUNNEL_MODE=remote

exec "$script_dir/../../scripts/open-tunnel.sh"
