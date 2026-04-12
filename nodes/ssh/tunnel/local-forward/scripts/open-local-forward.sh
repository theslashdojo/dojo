#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export SSH_TUNNEL_MODE=local

exec "$script_dir/../../scripts/open-tunnel.sh"
