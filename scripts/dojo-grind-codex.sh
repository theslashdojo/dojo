#!/usr/bin/env bash
# dojo-grind.sh — Autonomous Dojo node generation loop using codex exec
#
# Uses codex exec --sandbox danger-full-access to invoke the dojo-node-builder
# workflow repeatedly, creating missing Dojo nodes from grind-targets.json.
#
# Usage:
#   ./scripts/dojo-grind.sh                    # Run all targets
#   ./scripts/dojo-grind.sh --priority 1       # Only priority 1 targets
#   ./scripts/dojo-grind.sh --ecosystem git    # Only the git ecosystem
#   ./scripts/dojo-grind.sh --dry-run          # Show what would run
#   ./scripts/dojo-grind.sh --continue         # Skip already-valid ecosystems
#   ./scripts/dojo-grind.sh --status           # Show build status of all targets
#   ./scripts/dojo-grind.sh --loop             # Keep running until all targets built
#   ./scripts/dojo-grind.sh --loop --priority 2  # Loop through priority <= 2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOJO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGETS_FILE="$DOJO_ROOT/scripts/grind-targets.json"
NODES_DIR="$DOJO_ROOT/nodes"
LOG_DIR="$DOJO_ROOT/scripts/grind-logs"
SKILL_FILE="$DOJO_ROOT/skills/dojo-node-builder/SKILL.md"
STATUS_FILE="$DOJO_ROOT/scripts/grind-status.json"
STATUS_LOCK_FILE="$STATUS_FILE.lock"
CODEX_BIN="${CODEX_BIN:-codex}"

# Defaults
PRIORITY_FILTER=""
ECOSYSTEM_FILTER=""
DRY_RUN=false
CONTINUE_MODE=false
MAX_PARALLEL=1
COMMIT_EACH=true
LOOP_MODE=false
MAX_RETRIES=2
SHOW_STATUS=false

# Validation stats are set by validate_ecosystem_output.
VALIDATION_ERRORS=0
VALIDATION_EXPECTED_NODES=0
VALIDATION_EXPECTED_SKILLS=0
VALIDATION_QUIET=false

usage() {
  cat <<'USAGE'
dojo-grind.sh — Autonomous Dojo node generation

Options:
  --priority N        Only run targets with priority <= N (default: all)
  --ecosystem NAME    Only run the named ecosystem
  --dry-run           Print prompts but don't run Codex
  --continue          Skip ecosystems that already validate cleanly
  --parallel N        Run N ecosystems in parallel (default: 1)
  --no-commit         Don't auto-commit after each ecosystem
  --loop              Keep running until all targets are built
  --retries N         Max retries per ecosystem on failure (default: 2)
  --status            Show build status and exit
  -h, --help          Show this help

Examples:
  ./scripts/dojo-grind.sh --priority 1
  ./scripts/dojo-grind.sh --ecosystem git --dry-run
  ./scripts/dojo-grind.sh --continue --parallel 2
  ./scripts/dojo-grind.sh --loop --priority 2
  ./scripts/dojo-grind.sh --status
USAGE
  exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --priority)   PRIORITY_FILTER="$2"; shift 2 ;;
    --ecosystem)  ECOSYSTEM_FILTER="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --continue)   CONTINUE_MODE=true; shift ;;
    --parallel)   MAX_PARALLEL="$2"; shift 2 ;;
    --no-commit)  COMMIT_EACH=false; shift ;;
    --loop)       LOOP_MODE=true; CONTINUE_MODE=true; shift ;;
    --retries)    MAX_RETRIES="$2"; shift 2 ;;
    --status)     SHOW_STATUS=true; shift ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
  esac
done

# Verify tools
if ! command -v "$CODEX_BIN" &>/dev/null; then
  echo "ERROR: $CODEX_BIN CLI not found. Install Codex CLI first."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found. Install jq first."
  exit 1
fi

if [[ ! -f "$TARGETS_FILE" ]]; then
  echo "ERROR: $TARGETS_FILE not found."
  exit 1
fi

mkdir -p "$LOG_DIR"

# Initialize status file if it doesn't exist.
if [[ ! -f "$STATUS_FILE" ]]; then
  echo '{}' > "$STATUS_FILE"
fi

normalize_yaml_scalar() {
  printf '%s' "$1" | sed -E "s/^[[:space:]]*//; s/[[:space:]]*$//; s/^['\"]//; s/['\"]$//"
}

validation_warn() {
  if [[ "${VALIDATION_QUIET:-false}" != true ]]; then
    echo "$@"
  fi
}

with_status_lock() {
  if command -v flock &>/dev/null; then
    local lock_fd
    exec {lock_fd}> "$STATUS_LOCK_FILE"
    flock "$lock_fd"
    "$@"
    flock -u "$lock_fd"
  else
    "$@"
  fi
}

update_status_impl() {
  local ecosystem="$1"
  local status="$2"
  local node_count="${3:-0}"
  local duration="${4:-0}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)
  jq --arg e "$ecosystem" \
     --arg s "$status" \
     --argjson n "$node_count" \
     --argjson d "$duration" \
     --arg t "$timestamp" \
     '.[$e] = { status: $s, nodes: $n, duration_s: $d, updated: $t }' \
     "$STATUS_FILE" > "$tmp"
  mv "$tmp" "$STATUS_FILE"
}

# Update status for an ecosystem.
update_status() {
  with_status_lock update_status_impl "$@"
}

validate_skill_frontmatter() {
  local skill_file="$1"
  local expected_name="$2"

  if [[ ! -f "$skill_file" ]]; then
    validation_warn "  WARN: Missing $skill_file"
    return 1
  fi

  local frontmatter=""
  if ! frontmatter=$(awk '
    NR == 1 {
      if ($0 != "---") exit 1
      next
    }
    /^---$/ {
      found = 1
      exit 0
    }
    { print }
    END {
      if (!found) exit 2
    }
  ' "$skill_file"); then
    validation_warn "  WARN: Invalid YAML frontmatter in $skill_file"
    return 1
  fi

  local raw_name
  raw_name=$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)
  if [[ -z "$raw_name" ]]; then
    validation_warn "  WARN: Missing frontmatter name in $skill_file"
    return 1
  fi

  local skill_name
  skill_name=$(normalize_yaml_scalar "$raw_name")
  if [[ "$skill_name" != "$expected_name" ]]; then
    validation_warn "  WARN: SKILL.md name '$skill_name' does not match directory '$expected_name' in $skill_file"
    return 1
  fi

  if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    validation_warn "  WARN: SKILL.md name '$skill_name' is not Agent Skills compliant in $skill_file"
    return 1
  fi

  if (( ${#skill_name} > 64 )); then
    validation_warn "  WARN: SKILL.md name '$skill_name' exceeds 64 characters in $skill_file"
    return 1
  fi

  if ! printf '%s\n' "$frontmatter" | grep -qE '^description:[[:space:]]'; then
    validation_warn "  WARN: Missing frontmatter description in $skill_file"
    return 1
  fi

  return 0
}

validate_skill_node_contract() {
  local node_file="$1"
  local node_dir="$2"

  if ! jq -e '
    (.scripts | type == "array" and length > 0) and
    (.schema | type == "object") and
    (.schema.input != null) and
    (.schema.output != null)
  ' "$node_file" >/dev/null 2>&1; then
    validation_warn "  WARN: Skill node is missing scripts or schema in $node_file"
    return 1
  fi

  local missing=0
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    local rel_path="${entry#./}"
    if [[ ! -f "$node_dir/$rel_path" ]]; then
      validation_warn "  WARN: Missing script entry '$entry' referenced by $node_file"
      missing=$((missing + 1))
    fi
  done < <(jq -r '.scripts[]?.entry // empty' "$node_file")

  (( missing == 0 ))
}

validate_ecosystem_output() {
  local ecosystem="$1"
  local quiet="${2:-false}"
  local errors=0
  local expected_nodes=0
  local expected_skills=0

  VALIDATION_QUIET="$quiet"

  while IFS=$'\t' read -r uri type; do
    [[ -n "$uri" ]] || continue
    expected_nodes=$((expected_nodes + 1))

    local node_dir="$NODES_DIR/$uri"
    local node_file="$node_dir/node.json"

    if [[ ! -f "$node_file" ]]; then
      validation_warn "  WARN: Missing $node_file"
      errors=$((errors + 1))
      continue
    fi

    if ! jq empty "$node_file" >/dev/null 2>&1; then
      validation_warn "  WARN: Invalid JSON in $node_file"
      errors=$((errors + 1))
      continue
    fi

    if ! jq -e --arg uri "$uri" --arg type "$type" '
      .uri == $uri and
      .type == $type and
      (.name | type == "string")
    ' "$node_file" >/dev/null 2>&1; then
      validation_warn "  WARN: URI/type mismatch in $node_file (expected $uri [$type])"
      errors=$((errors + 1))
    fi

    if [[ "$type" == "skill" || "$type" == "sub" ]]; then
      expected_skills=$((expected_skills + 1))

      if ! validate_skill_frontmatter "$node_dir/SKILL.md" "$(basename "$node_dir")"; then
        errors=$((errors + 1))
      fi

      if ! validate_skill_node_contract "$node_file" "$node_dir"; then
        errors=$((errors + 1))
      fi
    fi
  done < <(jq -r --arg e "$ecosystem" '
    .targets[] | select(.ecosystem == $e) | .tree[] | [.uri, .type] | @tsv
  ' "$TARGETS_FILE")

  VALIDATION_ERRORS="$errors"
  VALIDATION_EXPECTED_NODES="$expected_nodes"
  VALIDATION_EXPECTED_SKILLS="$expected_skills"
  VALIDATION_QUIET=false

  (( errors == 0 ))
}

# Show status and exit.
if [[ "$SHOW_STATUS" == true ]]; then
  echo "=== Dojo Grind Status ==="
  echo ""
  printf "%-20s %-10s %-10s %-10s %s\n" "ECOSYSTEM" "PRIORITY" "STATUS" "NODES" "UPDATED"
  printf "%-20s %-10s %-10s %-10s %s\n" "─────────" "────────" "──────" "─────" "───────"

  ecosystems=$(jq -r '.targets[] | .ecosystem' "$TARGETS_FILE")
  for eco in $ecosystems; do
    priority=$(jq -r --arg e "$eco" '.targets[] | select(.ecosystem == $e) | .priority' "$TARGETS_FILE")
    node_count=0
    updated=$(jq -r --arg e "$eco" '.[$e].updated // "—"' "$STATUS_FILE" 2>/dev/null || echo "—")
    status_label=$(jq -r --arg e "$eco" '.[$e].status // "pending"' "$STATUS_FILE" 2>/dev/null || echo "pending")

    if [[ -d "$NODES_DIR/$eco" ]]; then
      node_count=$(find "$NODES_DIR/$eco" -name node.json 2>/dev/null | wc -l | tr -d ' ')
      if validate_ecosystem_output "$eco" true; then
        status_label="BUILT"
      else
        status_label="PARTIAL"
      fi
    fi

    printf "%-20s %-10s %-10s %-10s %s\n" "$eco" "$priority" "$status_label" "$node_count" "$updated"
  done

  echo ""
  total_built=$(find "$NODES_DIR" -name node.json 2>/dev/null | wc -l | tr -d ' ')
  total_ecosystems=$(find "$NODES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  total_targets=$(jq '.targets | length' "$TARGETS_FILE")
  echo "Total nodes: $total_built across $total_ecosystems ecosystems ($total_targets targets defined)"
  exit 0
fi

# Build the prompt for a single ecosystem.
build_prompt() {
  local ecosystem="$1"
  local reason="$2"
  local tree_json="$3"

  cat <<PROMPT
You are working in the Dojo repository at $DOJO_ROOT.

Your task: build the "$ecosystem" ecosystem node tree for Dojo.

## Context
$reason

## Target Tree
$tree_json

## Instructions

1. Start by reading $SKILL_FILE and follow it as the authoring workflow.
2. Read the spec at $DOJO_ROOT/SPEC.md (sections 1-4 at minimum) and the schema at $DOJO_ROOT/schema/node.schema.json for the exact node.json format.
3. Look at $DOJO_ROOT/nodes/github/node.json, $DOJO_ROOT/nodes/github/repos/node.json, and $DOJO_ROOT/nodes/github/issues/node.json as references for well-formed ecosystem and skill nodes.
4. Research the official documentation for "$ecosystem" from official docs, API references, SDK docs, CLI help, changelogs, and official repositories. Prioritize first-party sources over blog posts.
5. For each node in the target tree above, create or revise the node.json file in the appropriate directory under $DOJO_ROOT/nodes/.
6. Make every node rich and complete:
   - context: one line, under 200 chars, tells an agent when to use this node
   - info: dense paragraph with scope, execution surface, and why it matters
   - body: long-form markdown with [[uri]] wiki-links, code examples, environment variables, and real commands
   - sections: addressable chunks with ids, titles, bodies, and useful tags
   - aliases: phrases agents and users actually say, including acronyms and common broken phrasing
   - triggers: natural-language requests that should surface this node in search
   - tags: concrete filterable keywords
   - links: directed next steps to related nodes with context
   - related: semantic relationships like prerequisite, see-also, implements, extends
7. For skill and sub nodes, include:
   - scripts with real executable commands or code, lang, runtime, entry, env vars, and packages when needed
   - schema with input and output JSON contracts
   - depends for required dependencies on other nodes
8. For every skill or sub node, create a portable Agent Skills package that follows the official spec from https://agentskills.io/specification and https://github.com/agentskills/agentskills:
   - include SKILL.md with valid YAML frontmatter
   - name must match the directory name, use lowercase letters/numbers/hyphens only, and stay under 64 chars
   - description must say what the skill does and when to use it
   - use scripts/ and references/ when they make the skill more reusable
   - keep SKILL.md concise and push bulky detail into references/
9. Only edit files under $DOJO_ROOT/nodes/$ecosystem/. Do not touch unrelated ecosystems, scripts, or user changes elsewhere in the repo.
10. Do not ask questions. Do not ask for confirmation. Build the full target tree.
11. After authoring, verify:
    - every expected node exists
    - every node.json is valid JSON
    - every skill/sub node has SKILL.md with valid frontmatter
    - any script entry paths referenced in node.json actually exist

## Quality Bar

Every node must teach well enough that another agent can learn and act from it without reading upstream docs. Skeleton nodes are failures. Placeholder scripts are failures. Build for the jobs autonomous agents actually repeat, not for a docs sidebar mirror.
PROMPT
}

# Extract targets from JSON.
ecosystems=$(jq -r '.targets[] | .ecosystem' "$TARGETS_FILE")

echo "=== dojo-grind.sh ==="
echo "Dojo root:  $DOJO_ROOT"
echo "Targets:    $TARGETS_FILE"
echo "Log dir:    $LOG_DIR"
echo "Runner:     $CODEX_BIN exec --sandbox danger-full-access"
echo "Dry run:    $DRY_RUN"
echo "Continue:   $CONTINUE_MODE"
echo "Loop:       $LOOP_MODE"
echo "Parallel:   $MAX_PARALLEL"
echo "Retries:    $MAX_RETRIES"
echo ""

grind_ecosystem() {
  local ecosystem="$1"

  local priority
  priority=$(jq -r --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .priority' "$TARGETS_FILE")
  local reason
  reason=$(jq -r --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .reason' "$TARGETS_FILE")
  local tree_json
  tree_json=$(jq --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .tree' "$TARGETS_FILE")
  local expected_nodes
  expected_nodes=$(jq --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .tree | length' "$TARGETS_FILE")

  if [[ -n "$PRIORITY_FILTER" ]] && (( priority > PRIORITY_FILTER )); then
    return 0
  fi

  if [[ -n "$ECOSYSTEM_FILTER" ]] && [[ "$ecosystem" != "$ECOSYSTEM_FILTER" ]]; then
    return 0
  fi

  if [[ "$CONTINUE_MODE" == true ]] && [[ -d "$NODES_DIR/$ecosystem" ]]; then
    if validate_ecosystem_output "$ecosystem" true; then
      local existing_count
      existing_count=$(find "$NODES_DIR/$ecosystem" -name node.json 2>/dev/null | wc -l | tr -d ' ')
      echo "SKIP $ecosystem (expected tree already present and valid, --continue mode)"
      update_status "$ecosystem" "built" "$existing_count" 0
      return 0
    fi
    echo "REBUILD $ecosystem (existing tree incomplete or invalid)"
  fi

  local prompt
  prompt=$(build_prompt "$ecosystem" "$reason" "$tree_json")
  local log_file="$LOG_DIR/grind-${ecosystem}-$(date +%Y%m%d-%H%M%S).log"
  local prompt_file="${log_file%.log}.prompt"
  printf '%s\n' "$prompt" > "$prompt_file"

  echo "───────────────────────────────────────"
  echo "GRIND: $ecosystem (priority $priority, expecting $expected_nodes nodes)"
  echo "  Reason: $reason"
  echo "  Prompt: $prompt_file"
  echo "  Log:    $log_file"

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY RUN] Would run: $CODEX_BIN exec --sandbox danger-full-access"
    return 0
  fi

  update_status "$ecosystem" "running" 0 0

  local attempt=0
  local success=false

  while (( attempt <= MAX_RETRIES )) && [[ "$success" == false ]]; do
    if (( attempt > 0 )); then
      echo "  Retry $attempt/$MAX_RETRIES..."
    fi

    echo "  Running Codex... (attempt $((attempt + 1)))"
    local start_time
    start_time=$(date +%s)

    local attempt_log="$log_file"
    if (( attempt > 0 )); then
      attempt_log="${log_file%.log}.retry${attempt}.log"
    fi
    local attempt_message="${attempt_log%.log}.last.txt"

    if printf '%s\n' "$prompt" | "$CODEX_BIN" exec \
      --sandbox danger-full-access \
      --cd "$DOJO_ROOT" \
      --color never \
      --output-last-message "$attempt_message" \
      - > "$attempt_log" 2>&1; then
      local end_time
      end_time=$(date +%s)
      local duration=$(( end_time - start_time ))
      echo "  Codex exited successfully in ${duration}s"

      local node_count=0
      if [[ -d "$NODES_DIR/$ecosystem" ]]; then
        node_count=$(find "$NODES_DIR/$ecosystem" -name node.json 2>/dev/null | wc -l | tr -d ' ')
      fi
      echo "  Nodes present: $node_count/$expected_nodes"

      if validate_ecosystem_output "$ecosystem"; then
        success=true
        echo "  Validation passed for $ecosystem"
        update_status "$ecosystem" "built" "$node_count" "$duration"

        if [[ "$COMMIT_EACH" == true ]]; then
          echo "  Committing..."
          (
            cd "$DOJO_ROOT"
            git add "nodes/$ecosystem/"
            git commit -m "$(cat <<EOF
chore: add $ecosystem ecosystem nodes (dojo-grind)

Auto-generated $node_count node(s) for the $ecosystem ecosystem.
Reason: $reason
Runner: codex exec --sandbox danger-full-access
EOF
            )" || echo "  (nothing to commit)"
          )
        fi
      else
        echo "  Validation failed for $ecosystem — see warnings above and $attempt_log"
      fi
    else
      local end_time
      end_time=$(date +%s)
      local duration=$(( end_time - start_time ))
      echo "  Codex failed after ${duration}s — see $attempt_log"
    fi

    attempt=$(( attempt + 1 ))
  done

  if [[ "$success" == false ]]; then
    echo "  GIVE UP on $ecosystem after $((MAX_RETRIES + 1)) attempts"
    update_status "$ecosystem" "failed" 0 0
  fi
}

run_grind() {
  local running=0
  for ecosystem in $ecosystems; do
    if (( MAX_PARALLEL <= 1 )); then
      grind_ecosystem "$ecosystem"
    else
      grind_ecosystem "$ecosystem" &
      running=$(( running + 1 ))
      if (( running >= MAX_PARALLEL )); then
        wait -n 2>/dev/null || true
        running=$(( running - 1 ))
      fi
    fi
  done

  wait 2>/dev/null || true
}

if [[ "$LOOP_MODE" == true ]]; then
  pass=1
  while true; do
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║  GRIND LOOP — Pass $pass             "
    echo "╚══════════════════════════════════════╝"
    echo ""

    run_grind

    all_built=true
    for eco in $ecosystems; do
      if [[ -n "$PRIORITY_FILTER" ]]; then
        local_priority=$(jq -r --arg e "$eco" '.targets[] | select(.ecosystem == $e) | .priority' "$TARGETS_FILE")
        if (( local_priority > PRIORITY_FILTER )); then
          continue
        fi
      fi

      if [[ -n "$ECOSYSTEM_FILTER" ]] && [[ "$eco" != "$ECOSYSTEM_FILTER" ]]; then
        continue
      fi

      if ! validate_ecosystem_output "$eco" true; then
        all_built=false
        break
      fi
    done

    if [[ "$all_built" == true ]]; then
      echo ""
      echo "All targeted ecosystems have been built."
      break
    fi

    pass=$(( pass + 1 ))
    echo ""
    echo "Some targets remain. Starting pass $pass in 10 seconds... (Ctrl+C to stop)"
    sleep 10
  done
else
  run_grind
fi

echo ""
echo "=== dojo-grind.sh complete ==="

total_nodes=$(find "$NODES_DIR" -name node.json 2>/dev/null | wc -l | tr -d ' ')
total_ecosystems=$(find "$NODES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo "Total nodes in Dojo: $total_nodes across $total_ecosystems ecosystems"
