#!/usr/bin/env bash
set -euo pipefail

# Add or update a task definition in turbo.json
# Usage: ./add-task.sh <task-name> [options]
# Example: ./add-task.sh build --depends-on "^build" --outputs "dist/**"

TASK_NAME="${1:?Usage: add-task.sh <task-name> [--depends-on deps...] [--outputs globs...] [--inputs globs...] [--env vars...] [--no-cache] [--persistent]}"
shift

DEPENDS_ON=()
OUTPUTS=()
INPUTS=()
ENV_VARS=()
CACHE=true
PERSISTENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --depends-on)
      shift
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
        DEPENDS_ON+=("\"$1\"")
        shift
      done
      ;;
    --outputs)
      shift
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
        OUTPUTS+=("\"$1\"")
        shift
      done
      ;;
    --inputs)
      shift
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
        INPUTS+=("\"$1\"")
        shift
      done
      ;;
    --env)
      shift
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
        ENV_VARS+=("\"$1\"")
        shift
      done
      ;;
    --no-cache) CACHE=false; shift ;;
    --persistent) PERSISTENT=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TURBO_JSON="turbo.json"
if [[ ! -f "$TURBO_JSON" ]]; then
  echo "Error: turbo.json not found in $(pwd)" >&2
  echo "Run turbo/config init-config first." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: apt-get install jq / brew install jq" >&2
  exit 1
fi

# Build the task JSON object
TASK_JSON="{"

# dependsOn
if [[ ${#DEPENDS_ON[@]} -gt 0 ]]; then
  DEPS_STR=$(IFS=,; echo "${DEPENDS_ON[*]}")
  TASK_JSON+="\"dependsOn\": [${DEPS_STR}]"
else
  TASK_JSON+="\"dependsOn\": []"
fi

# outputs
if [[ ${#OUTPUTS[@]} -gt 0 ]]; then
  OUTS_STR=$(IFS=,; echo "${OUTPUTS[*]}")
  TASK_JSON+=", \"outputs\": [${OUTS_STR}]"
fi

# inputs
if [[ ${#INPUTS[@]} -gt 0 ]]; then
  INS_STR=$(IFS=,; echo "${INPUTS[*]}")
  TASK_JSON+=", \"inputs\": [${INS_STR}]"
fi

# env
if [[ ${#ENV_VARS[@]} -gt 0 ]]; then
  ENV_STR=$(IFS=,; echo "${ENV_VARS[*]}")
  TASK_JSON+=", \"env\": [${ENV_STR}]"
fi

# cache
if [[ "$CACHE" == "false" ]]; then
  TASK_JSON+=", \"cache\": false"
fi

# persistent
if [[ "$PERSISTENT" == "true" ]]; then
  TASK_JSON+=", \"persistent\": true"
fi

TASK_JSON+="}"

# Add or update the task in turbo.json using jq
UPDATED=$(jq --arg name "$TASK_NAME" --argjson task "$TASK_JSON" \
  '.tasks[$name] = $task' "$TURBO_JSON")

echo "$UPDATED" > "$TURBO_JSON"
echo "Task '$TASK_NAME' added/updated in turbo.json"
echo ""
echo "Task configuration:"
jq --arg name "$TASK_NAME" '.tasks[$name]' "$TURBO_JSON"
