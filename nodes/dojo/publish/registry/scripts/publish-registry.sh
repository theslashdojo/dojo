#!/usr/bin/env bash
set -euo pipefail

path="${1:?path to manifest is required}"
registry="${2:-${DOJO_REGISTRY_URL:-http://localhost:3000}}"
dry_run="${3:-${DOJO_DRY_RUN:-false}}"

if [[ ! -f "$path" ]]; then
  echo "manifest not found: $path" >&2
  exit 1
fi

if [[ "$dry_run" == "true" ]]; then
  node -e "const fs=require('fs'); const node=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(JSON.stringify({published:false, uri: node.uri, version: node.version, status:'dry-run'}));" "$path"
  exit 0
fi

: "${DOJO_TOKEN:?DOJO_TOKEN is required}"

response_file="$(mktemp)"
status_code="$(curl -sS -o "$response_file" -w '%{http_code}' -X POST "$registry/v1/skills" \
  -H "Authorization: Bearer $DOJO_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary "@$path")"
response="$(cat "$response_file")"
rm -f "$response_file"

if [[ "$status_code" -lt 200 || "$status_code" -ge 300 ]]; then
  printf '%s\n' "$response" >&2
  exit 1
fi

node -e "const data=JSON.parse(process.argv[1]); console.log(JSON.stringify({published:true,status:'published',...data}));" "$response"
