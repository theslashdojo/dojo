#!/usr/bin/env bash
set -euo pipefail

path="${1:?path to manifest is required}"
uri="${2:?uri is required}"
ecosystem="${3:?ecosystem is required}"
registry="${4:-${DOJO_REGISTRY_URL:-https://slashdojo.com}}"
query="${uri##*/}"

if [[ ! -f "$path" ]]; then
  echo "manifest not found: $path" >&2
  exit 1
fi

check_endpoint() {
  local name="$1"
  local url="$2"
  local status
  status="$(curl -sS -o /dev/null -w '%{http_code}' "$url" || true)"
  printf '{"name":"%s","url":"%s","status":%s}' "$name" "$url" "${status:-0}"
}

search_check="$(check_endpoint "search" "$registry/v1/search?q=$query")"
tree_check="$(check_endpoint "tree" "$registry/v1/tree/$ecosystem")"
skill_check="$(check_endpoint "skill" "$registry/v1/skills/$uri")"
learn_check="$(check_endpoint "learn" "$registry/v1/learn/$uri")"
bundle_check="$(check_endpoint "bundle" "$registry/v1/bundle/$uri")"

all_ok=true
for code in \
  "$(node -e "console.log(JSON.parse(process.argv[1]).status)" "$search_check")" \
  "$(node -e "console.log(JSON.parse(process.argv[1]).status)" "$tree_check")" \
  "$(node -e "console.log(JSON.parse(process.argv[1]).status)" "$skill_check")" \
  "$(node -e "console.log(JSON.parse(process.argv[1]).status)" "$learn_check")" \
  "$(node -e "console.log(JSON.parse(process.argv[1]).status)" "$bundle_check")"; do
  if [[ "$code" != "200" ]]; then
    all_ok=false
  fi
done

printf '{"passed":%s,"checks":[%s,%s,%s,%s,%s]}\n' \
  "$all_ok" \
  "$search_check" \
  "$tree_check" \
  "$skill_check" \
  "$learn_check" \
  "$bundle_check"
