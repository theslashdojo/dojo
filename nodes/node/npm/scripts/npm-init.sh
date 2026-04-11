#!/usr/bin/env bash
set -euo pipefail
# Creates a new npm project with sensible defaults
# Usage: npm-init.sh [project-name] [--type module|commonjs] [--private] [--description "desc"]
#
# Examples:
#   npm-init.sh my-app
#   npm-init.sh my-lib --type module --description "A utility library"
#   npm-init.sh my-service --private --type commonjs

PROJECT_NAME="${1:-}"
MODULE_TYPE="module"
PRIVATE="false"
DESCRIPTION=""

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: npm-init.sh <project-name> [--type module|commonjs] [--private] [--description \"desc\"]"
  exit 1
fi
shift

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      MODULE_TYPE="${2:?--type requires a value (module or commonjs)}"
      if [[ "$MODULE_TYPE" != "module" && "$MODULE_TYPE" != "commonjs" ]]; then
        echo "Error: --type must be 'module' or 'commonjs'"
        exit 1
      fi
      shift 2
      ;;
    --private)
      PRIVATE="true"
      shift
      ;;
    --description)
      DESCRIPTION="${2:?--description requires a value}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: npm-init.sh <project-name> [--type module|commonjs] [--private] [--description \"desc\"]"
      exit 1
      ;;
  esac
done

# Validate project name (npm naming rules: lowercase, no spaces, hyphens ok)
if [[ ! "$PROJECT_NAME" =~ ^(@[a-z0-9-]+/)?[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "Error: Invalid package name '$PROJECT_NAME'. Use lowercase letters, numbers, hyphens, and dots."
  exit 1
fi

# Create project directory if it does not exist
if [ ! -d "$PROJECT_NAME" ]; then
  mkdir -p "$PROJECT_NAME"
  echo "Created directory: $PROJECT_NAME"
fi

cd "$PROJECT_NAME"

# Guard against overwriting an existing package.json
if [ -f "package.json" ]; then
  echo "package.json already exists in $PROJECT_NAME — skipping initialization"
  echo "Path: $(pwd)/package.json"
  exit 0
fi

# Initialize with npm to get a valid baseline
npm init -y --silent >/dev/null 2>&1

# Rewrite package.json with our configured values
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.name = '${PROJECT_NAME}';
pkg.version = '0.1.0';
pkg.description = '${DESCRIPTION}';
pkg.type = '${MODULE_TYPE}';
pkg.main = pkg.type === 'module' ? './src/index.js' : './src/index.js';
pkg.scripts = {
  start: 'node src/index.js',
  test: 'echo \"Error: no test specified\" && exit 1',
  lint: 'echo \"No linter configured\"'
};
pkg.keywords = [];
pkg.author = '';
pkg.license = 'MIT';
if (${PRIVATE} === true) pkg.private = true;
delete pkg.module;
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"

# Create src directory with entry point
mkdir -p src
if [ ! -f src/index.js ]; then
  if [ "$MODULE_TYPE" = "module" ]; then
    cat > src/index.js << 'ENTRY'
// Entry point
export function main() {
  console.log("Hello from $PROJECT_NAME");
}

main();
ENTRY
  else
    cat > src/index.js << 'ENTRY'
// Entry point
function main() {
  console.log("Hello from $PROJECT_NAME");
}

module.exports = { main };
main();
ENTRY
  fi
fi

# Create .gitignore if missing
if [ ! -f .gitignore ]; then
  cat > .gitignore << 'GITIGNORE'
node_modules/
dist/
.env
.env.*
*.tgz
coverage/
.DS_Store
GITIGNORE
fi

PACKAGE_JSON_PATH="$(pwd)/package.json"

echo "Initialized $PROJECT_NAME"
echo "  Type: $MODULE_TYPE"
echo "  Private: $PRIVATE"
echo "  Path: $PACKAGE_JSON_PATH"
echo ""
cat package.json
