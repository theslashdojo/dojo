#!/usr/bin/env bash
# dojo-grind.sh — Fully Autonomous node generation
# No targets file. No hand-holding. Just vibes and agentic necessity.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOJO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODES_DIR="$DOJO_ROOT/nodes"
LOG_DIR="$DOJO_ROOT/scripts/grind-logs"

# Config
MAX_PASSES=5
COMMIT_EACH=true

mkdir -p "$LOG_DIR"

# 1. Get a snapshot of what we already have
get_current_state() {
  find "$NODES_DIR" -maxdepth 2 -not -path '*/.*' | sed "s|$DOJO_ROOT/||"
}

# 2. Build the "Think for yourself" prompt
build_autonomous_prompt() {
  local current_state
  current_state=$(get_current_state)

  cat <<PROMPT
You are the Architect of the Dojo Knowledge Graph.
Location: $DOJO_ROOT

## Current State
The following nodes/ecosystems already exist:
$current_state

## Your Mission
Identify ONE high-value ecosystem or toolset that is currently missing but CRITICAL for an autonomous agent to perform real-world engineering, automation, or research tasks.

## Instructions
**Choose a Target:** Pick something missing (e.g., Terraform, Kubernetes, Redis, Linear, Vercel, etc.).
**Design the Tree:** Plan a node structure for this ecosystem.

1. Read the SPEC at $DOJO_ROOT/SPEC.md (sections 1-4 at minimum) and the schema at $DOJO_ROOT/schema/node.schema.json for the exact node.json format.
2. Look at $DOJO_ROOT/nodes/node/npm/install as references for well-formed skill nodes.
3. Research the official documentation — use WebFetch to pull docs, API references, CLI help, and examples from official sources.
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
- Try make a single SKILL.md that teaches the whole ecosystem, with sections for each sub-node rather than separate SKILL.md files for each node. This is more user-friendly and easier to maintain. Use sub-skills when there are distinct sub-ecosystems or toolsets within the larger ecosystem (e.g., AWS EC2 vs AWS S3).
   - YAML frontmatter with name, description
- name must be lowercase-hyphenated and match the directory name
- description says what the skill does AND when to use it
- Markdown body with instructions, workflow, examples, edge cases
- Any CLI commands, API calls, or code snippets needed to use the tool in the body with real examples — this is what agents will learn from and execute on. Be detailed, specific with parameters, flags, and code. Avoid placeholders.
- Add scripts/ directory for deterministic execution when useful
- Talk about scripts in SKILL.md, but put actual scripts in scripts/ with real code — these can be called by agents and users directly
- Add references/ directory for bulky reference material
- Keep SKILL.md under 500 lines; move detail to references/
- https://github.com/agentskills/agentskills
- Talk about the skill/SKILL.md in node.json
- Do NOT use absolute paths in code examples or scripts. Use relative paths or environment variables. The skill should be portable and runnable on any machine without modification.
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

echo "=== Dojo Autonomous Grind ==="
echo "Dojo root: $DOJO_ROOT"
echo "Mode: Fully Autonomous (AI-led discovery)"
echo ""

for ((i=1; i<=MAX_PASSES; i++)); do
  echo "--- Pass $i of $MAX_PASSES ---"

  PROMPT=$(build_autonomous_prompt)
  LOG_FILE="$LOG_DIR/grind-auto-$(date +%Y%m%d-%H%M%S).log"

  echo "Claude is deciding what to build next..."

  ##if claude -p --dangerously-skip-permissions "$PROMPT" > "$LOG_FILE" 2>&1; then
  if codex exec --sandbox danger-full-access "$PROMPT" > "$LOG_FILE" 2>&1; then
    echo "Success! Check $LOG_FILE for details."

    if [[ "$COMMIT_EACH" == true ]]; then
      cd "$DOJO_ROOT"
      # Try to figure out what was created for the commit message
      NEW_ECO=$(git status --porcelain nodes/ | grep '??' | head -n 1 | awk '{print $2}' | cut -d/ -f2 || echo "new-ecosystem")

      git add nodes/
      git commit -m "feat(auto): autonomous build of $NEW_ECO ecosystem" || echo "Nothing new to commit."
    fi
  else
    echo "Failed. See $LOG_FILE"
    exit 1
  fi

  echo "Waiting 5s for the dust to settle..."
  sleep 5
done

echo "Grind complete. The Dojo is stronger now."