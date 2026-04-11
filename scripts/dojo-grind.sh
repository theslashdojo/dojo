#!/usr/bin/env bash
# dojo-grind.sh — Autonomous node generation loop using claude -p
#
# Uses claude -p --dangerously-skip-permissions to invoke the dojo-node-builder
# skill repeatedly, creating missing Dojo nodes from grind-targets.json.
#
# Usage:
#   ./scripts/dojo-grind.sh                    # Run all targets
#   ./scripts/dojo-grind.sh --priority 1       # Only priority 1 targets
#   ./scripts/dojo-grind.sh --ecosystem git    # Only the git ecosystem
#   ./scripts/dojo-grind.sh --dry-run          # Show what would run
#   ./scripts/dojo-grind.sh --continue         # Skip already-built ecosystems
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

usage() {
  cat <<'USAGE'
dojo-grind.sh — Autonomous Dojo node generation

Options:
  --priority N        Only run targets with priority <= N (default: all)
  --ecosystem NAME    Only run the named ecosystem
  --dry-run           Print prompts but don't run claude
  --continue          Skip ecosystems that already have nodes/ dirs
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
if ! command -v claude &>/dev/null; then
  echo "ERROR: claude CLI not found. Install Claude Code first."
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

# Initialize status file if it doesn't exist
if [[ ! -f "$STATUS_FILE" ]]; then
  echo '{}' > "$STATUS_FILE"
fi

# Update status for an ecosystem
update_status() {
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

# Show status and exit
if [[ "$SHOW_STATUS" == true ]]; then
  echo "=== Dojo Grind Status ==="
  echo ""
  printf "%-20s %-10s %-8s %-10s %s\n" "ECOSYSTEM" "PRIORITY" "STATUS" "NODES" "UPDATED"
  printf "%-20s %-10s %-8s %-10s %s\n" "─────────" "────────" "──────" "─────" "───────"

  ecosystems=$(jq -r '.targets[] | .ecosystem' "$TARGETS_FILE")
  for eco in $ecosystems; do
    priority=$(jq -r --arg e "$eco" '.targets[] | select(.ecosystem == $e) | .priority' "$TARGETS_FILE")

    # Check if nodes directory exists
    if [[ -d "$NODES_DIR/$eco" ]]; then
      node_count=$(find "$NODES_DIR/$eco" -name node.json 2>/dev/null | wc -l | tr -d ' ')
      # Check status file for details
      status_info=$(jq -r --arg e "$eco" '.[$e].updated // "—"' "$STATUS_FILE" 2>/dev/null || echo "—")
      printf "%-20s %-10s %-8s %-10s %s\n" "$eco" "$priority" "BUILT" "$node_count" "$status_info"
    else
      # Check if it failed
      fail_status=$(jq -r --arg e "$eco" '.[$e].status // "pending"' "$STATUS_FILE" 2>/dev/null || echo "pending")
      printf "%-20s %-10s %-8s %-10s %s\n" "$eco" "$priority" "$fail_status" "0" "—"
    fi
  done

  echo ""
  total_built=$(find "$NODES_DIR" -name node.json 2>/dev/null | wc -l | tr -d ' ')
  total_ecosystems=$(ls -d "$NODES_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
  total_targets=$(jq '.targets | length' "$TARGETS_FILE")
  echo "Total nodes: $total_built across $total_ecosystems ecosystems ($total_targets targets defined)"
  exit 0
fi

# Build the prompt for a single ecosystem
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

1. Read the SPEC at $DOJO_ROOT/SPEC.md (sections 1-4 at minimum) and the schema at $DOJO_ROOT/schema/node.schema.json for the exact node.json format.
2. Look at $DOJO_ROOT/nodes/github/repos/node.json and $DOJO_ROOT/nodes/github/issues/node.json as references for well-formed skill nodes.
3. Research the official documentation for "$ecosystem" — use WebFetch to pull docs, API references, CLI help, and examples from official sources.
4. For each node in the target tree above, create a node.json file in the appropriate directory under $DOJO_ROOT/nodes/.
5. Make every node rich and complete:
   - context: one line, under 200 chars, tells an agent when to use this node
   - info: dense paragraph with scope, execution surface, and why it matters
   - body: long-form markdown with [[uri]] wiki-links, code examples, environment variables, real commands
   - sections: addressable chunks with ids, titles, bodies — these become direct-linkable knowledge
   - aliases: the real phrases agents and users actually say, including acronyms and common misspellings
   - triggers: natural language phrases that should surface this node in search
   - tags: concrete keywords for filtering
   - links: directed next steps to related nodes with context
   - related: semantic relationships (prerequisite, see-also, implements, extends)
6. For skill and sub nodes, include:
   - scripts with real executable commands/code (not placeholders), lang, runtime, entry, env vars, packages
   - schema with input/output JSON contracts
   - depends for required dependencies on other nodes
7. Create parent directories as needed (mkdir -p).
8. Do NOT ask questions. Do NOT ask for confirmation. Just build all the nodes.
9. After creating all nodes, validate that each node.json is valid JSON.

## Agent Skills Format

For any skill node, also create a SKILL.md following the Agent Skills spec (https://github.com/agentskills/agentskills):
- YAML frontmatter with name, description
- name must be lowercase-hyphenated and match the directory name
- description says what the skill does AND when to use it
- Markdown body with instructions, workflow, examples, edge cases
- Add scripts/ directory for deterministic execution when useful
- Add references/ directory for bulky reference material
- Keep SKILL.md under 500 lines; move detail to references/

## Quality Bar

Every node must teach well enough that another agent can learn and act from it without reading upstream docs. Skeleton nodes are failures. Placeholder scripts are failures.

Think about what an autonomous agent actually needs:
- Can it find this node when it needs it? (aliases, triggers, tags)
- Can it learn enough to act? (body, sections, code examples)
- Can it execute? (scripts, schema, env vars)
- Does it know where to go next? (links, related, depends)
PROMPT
}

# Extract targets from JSON
ecosystems=$(jq -r '.targets[] | .ecosystem' "$TARGETS_FILE")

echo "=== dojo-grind.sh ==="
echo "Dojo root:  $DOJO_ROOT"
echo "Targets:    $TARGETS_FILE"
echo "Log dir:    $LOG_DIR"
echo "Dry run:    $DRY_RUN"
echo "Continue:   $CONTINUE_MODE"
echo "Loop:       $LOOP_MODE"
echo "Parallel:   $MAX_PARALLEL"
echo "Retries:    $MAX_RETRIES"
echo ""

grind_ecosystem() {
  local ecosystem="$1"

  # Get target data
  local priority
  priority=$(jq -r --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .priority' "$TARGETS_FILE")
  local reason
  reason=$(jq -r --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .reason' "$TARGETS_FILE")
  local tree_json
  tree_json=$(jq --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .tree' "$TARGETS_FILE")
  local expected_nodes
  expected_nodes=$(jq --arg e "$ecosystem" '.targets[] | select(.ecosystem == $e) | .tree | length' "$TARGETS_FILE")

  # Filter by priority
  if [[ -n "$PRIORITY_FILTER" ]] && (( priority > PRIORITY_FILTER )); then
    return 0
  fi

  # Filter by ecosystem name
  if [[ -n "$ECOSYSTEM_FILTER" ]] && [[ "$ecosystem" != "$ECOSYSTEM_FILTER" ]]; then
    return 0
  fi

  # Continue mode: skip if nodes already exist and meet minimum count
  if [[ "$CONTINUE_MODE" == true ]] && [[ -d "$NODES_DIR/$ecosystem" ]]; then
    local existing_count
    existing_count=$(find "$NODES_DIR/$ecosystem" -name node.json 2>/dev/null | wc -l | tr -d ' ')
    if (( existing_count >= expected_nodes )); then
      echo "SKIP $ecosystem (already has $existing_count/$expected_nodes nodes, --continue mode)"
      return 0
    else
      echo "REBUILD $ecosystem (only $existing_count/$expected_nodes nodes, rebuilding)"
    fi
  fi

  local prompt
  prompt=$(build_prompt "$ecosystem" "$reason" "$tree_json")
  local log_file="$LOG_DIR/grind-${ecosystem}-$(date +%Y%m%d-%H%M%S).log"

  echo "───────────────────────────────────────"
  echo "GRIND: $ecosystem (priority $priority, expecting $expected_nodes nodes)"
  echo "  Reason: $reason"
  echo "  Log:    $log_file"

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY RUN] Would run claude -p --dangerously-skip-permissions"
    echo "$prompt" > "$log_file.prompt"
    echo "  Prompt saved to $log_file.prompt"
    return 0
  fi

  update_status "$ecosystem" "running" 0 0

  local attempt=0
  local success=false

  while (( attempt <= MAX_RETRIES )) && [[ "$success" == false ]]; do
    if (( attempt > 0 )); then
      echo "  Retry $attempt/$MAX_RETRIES..."
    fi

    echo "  Running claude... (attempt $((attempt + 1)))"
    local start_time
    start_time=$(date +%s)

    local attempt_log="$log_file"
    if (( attempt > 0 )); then
      attempt_log="${log_file%.log}.retry${attempt}.log"
    fi

    if claude -p --dangerously-skip-permissions "$prompt" > "$attempt_log" 2>&1; then
      local end_time
      end_time=$(date +%s)
      local duration=$(( end_time - start_time ))
      echo "  DONE in ${duration}s"

      # Count created nodes
      local node_count=0
      if [[ -d "$NODES_DIR/$ecosystem" ]]; then
        node_count=$(find "$NODES_DIR/$ecosystem" -name node.json 2>/dev/null | wc -l | tr -d ' ')
      fi
      echo "  Nodes created: $node_count/$expected_nodes"

      # Validate JSON
      local invalid=0
      if [[ -d "$NODES_DIR/$ecosystem" ]]; then
        while IFS= read -r f; do
          if ! jq empty "$f" 2>/dev/null; then
            echo "  WARN: Invalid JSON in $f"
            invalid=$((invalid + 1))
          fi
        done < <(find "$NODES_DIR/$ecosystem" -name node.json)
      fi

      if (( invalid > 0 )); then
        echo "  $invalid invalid JSON files detected"
      fi

      if (( node_count > 0 )); then
        success=true
        update_status "$ecosystem" "built" "$node_count" "$duration"

        # Auto-commit if enabled
        if [[ "$COMMIT_EACH" == true ]]; then
          echo "  Committing..."
          cd "$DOJO_ROOT"
          git add "nodes/$ecosystem/"
          # Also add any SKILL.md files created alongside nodes
          git add "nodes/$ecosystem/" 2>/dev/null || true
          git commit -m "$(cat <<EOF
chore: add $ecosystem ecosystem nodes (dojo-grind)

Auto-generated $node_count node(s) for the $ecosystem ecosystem.
Reason: $reason

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
          )" || echo "  (nothing to commit)"
        fi
      else
        echo "  No nodes created, will retry..."
      fi
    else
      local end_time
      end_time=$(date +%s)
      local duration=$(( end_time - start_time ))
      echo "  FAILED after ${duration}s — see $attempt_log"
    fi

    attempt=$(( attempt + 1 ))
  done

  if [[ "$success" == false ]]; then
    echo "  GIVE UP on $ecosystem after $((MAX_RETRIES + 1)) attempts"
    update_status "$ecosystem" "failed" 0 0
  fi
}

# Run the grind
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

  # Wait for any remaining background jobs
  wait 2>/dev/null || true
}

# Loop mode or single run
if [[ "$LOOP_MODE" == true ]]; then
  pass=1
  while true; do
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║  GRIND LOOP — Pass $pass             "
    echo "╚══════════════════════════════════════╝"
    echo ""

    run_grind

    # Check if all targets are built
    all_built=true
    for eco in $ecosystems; do
      # Apply priority filter
      if [[ -n "$PRIORITY_FILTER" ]]; then
        local_priority=$(jq -r --arg e "$eco" '.targets[] | select(.ecosystem == $e) | .priority' "$TARGETS_FILE")
        if (( local_priority > PRIORITY_FILTER )); then
          continue
        fi
      fi
      # Apply ecosystem filter
      if [[ -n "$ECOSYSTEM_FILTER" ]] && [[ "$eco" != "$ECOSYSTEM_FILTER" ]]; then
        continue
      fi
      if [[ ! -d "$NODES_DIR/$eco" ]]; then
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

# Summary
total_nodes=$(find "$NODES_DIR" -name node.json 2>/dev/null | wc -l | tr -d ' ')
total_ecosystems=$(ls -d "$NODES_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "Total nodes in Dojo: $total_nodes across $total_ecosystems ecosystems"
