#!/usr/bin/env bash
set -euo pipefail

# Manage Turborepo workspaces
# Usage: ./manage-workspaces.sh <action> [options]
#   create --name <name> --dir <apps|packages> [--scope @repo]
#   list
#   validate
#   prune --target <workspace>

ACTION="${1:?Usage: manage-workspaces.sh <create|list|validate|prune> [options]}"
shift

# Detect package manager
detect_pm() {
  if [[ -f "pnpm-workspace.yaml" ]] || [[ -f "pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "yarn.lock" ]]; then
    echo "yarn"
  elif [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
    echo "bun"
  else
    echo "npm"
  fi
}

# Navigate to repo root (find turbo.json)
find_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/turbo.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  echo "Error: Could not find turbo.json in any parent directory" >&2
  return 1
}

ROOT=$(find_root)
cd "$ROOT"
PM=$(detect_pm)

case "$ACTION" in
  create)
    NAME=""
    DIR="packages"
    SCOPE="@repo"

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --scope) SCOPE="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done

    if [[ -z "$NAME" ]]; then
      echo "Error: --name is required" >&2
      exit 1
    fi

    WORKSPACE_DIR="$DIR/$NAME"
    FULL_NAME="$SCOPE/$NAME"

    if [[ -d "$WORKSPACE_DIR" ]]; then
      echo "Error: Directory $WORKSPACE_DIR already exists" >&2
      exit 1
    fi

    echo "Creating workspace: $FULL_NAME in $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR/src"

    # Create package.json
    cat > "$WORKSPACE_DIR/package.json" <<PKGJSON
{
  "name": "$FULL_NAME",
  "version": "0.0.0",
  "private": true,
  "exports": {
    ".": "./src/index.ts"
  },
  "scripts": {
    "build": "tsup src/index.ts --format esm,cjs --dts",
    "dev": "tsup src/index.ts --format esm,cjs --dts --watch",
    "lint": "eslint src/",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
PKGJSON

    # Create index.ts
    cat > "$WORKSPACE_DIR/src/index.ts" <<'INDEXTS'
// Entry point for this workspace
export {};
INDEXTS

    # Create tsconfig.json
    cat > "$WORKSPACE_DIR/tsconfig.json" <<'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
TSCONFIG

    echo "Created workspace at $WORKSPACE_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. cd $ROOT && $PM install"
    echo "  2. Edit $WORKSPACE_DIR/src/index.ts"
    echo "  3. turbo build --filter=$FULL_NAME"
    ;;

  list)
    echo "Workspaces in $ROOT:"
    echo ""

    # List apps
    if [[ -d "apps" ]]; then
      echo "apps/"
      for dir in apps/*/; do
        if [[ -f "${dir}package.json" ]]; then
          local_name=$(jq -r '.name // "unnamed"' "${dir}package.json")
          echo "  ${dir%/} → $local_name"
        fi
      done
    fi

    echo ""

    # List packages
    if [[ -d "packages" ]]; then
      echo "packages/"
      for dir in packages/*/; do
        if [[ -f "${dir}package.json" ]]; then
          local_name=$(jq -r '.name // "unnamed"' "${dir}package.json")
          echo "  ${dir%/} → $local_name"
        fi
      done
    fi
    ;;

  validate)
    echo "Validating workspaces in $ROOT..."
    ERRORS=0

    for pattern in apps packages; do
      if [[ ! -d "$pattern" ]]; then
        continue
      fi
      for dir in "$pattern"/*/; do
        if [[ ! -f "${dir}package.json" ]]; then
          echo "WARNING: ${dir} has no package.json"
          ERRORS=$((ERRORS + 1))
          continue
        fi

        pkg_name=$(jq -r '.name // ""' "${dir}package.json")
        if [[ -z "$pkg_name" ]]; then
          echo "ERROR: ${dir}package.json missing 'name' field"
          ERRORS=$((ERRORS + 1))
        fi

        has_scripts=$(jq 'has("scripts")' "${dir}package.json")
        if [[ "$has_scripts" != "true" ]]; then
          echo "WARNING: ${dir}package.json has no scripts"
        fi

        exports=$(jq 'has("exports")' "${dir}package.json")
        if [[ "$exports" != "true" ]]; then
          echo "INFO: ${dir}package.json has no exports field (consider adding one)"
        fi
      done
    done

    if [[ $ERRORS -eq 0 ]]; then
      echo "All workspaces valid."
    else
      echo ""
      echo "$ERRORS error(s) found."
      exit 1
    fi
    ;;

  prune)
    TARGET=""
    DOCKER=false

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --docker) DOCKER=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done

    if [[ -z "$TARGET" ]]; then
      echo "Error: --target is required" >&2
      exit 1
    fi

    echo "Pruning monorepo for workspace: $TARGET"

    PRUNE_CMD="turbo prune $TARGET"
    if [[ "$DOCKER" == "true" ]]; then
      PRUNE_CMD+=" --docker"
    fi

    eval "$PRUNE_CMD"
    echo "Pruned output in ./out/"
    ;;

  *)
    echo "Unknown action: $ACTION" >&2
    echo "Usage: manage-workspaces.sh <create|list|validate|prune>" >&2
    exit 1
    ;;
esac
