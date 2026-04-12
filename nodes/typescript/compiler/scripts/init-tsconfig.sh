#!/usr/bin/env bash
# Initialize a tsconfig.json with recommended modern defaults.
# Usage: ./init-tsconfig.sh [target-directory]
# Creates tsconfig.json in the specified directory (default: current directory).

set -euo pipefail

TARGET_DIR="${1:-.}"
TSCONFIG="$TARGET_DIR/tsconfig.json"

if [ -f "$TSCONFIG" ]; then
  echo "Error: $TSCONFIG already exists. Remove it first or use a different directory." >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

cat > "$TSCONFIG" << 'TSCONFIG_EOF'
{
  "compilerOptions": {
    /* Language and Environment */
    "target": "es2022",
    "lib": ["es2023"],
    "module": "nodenext",
    "moduleResolution": "nodenext",

    /* Type Checking */
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,

    /* Emit */
    "outDir": "./dist",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true,

    /* Interop */
    "esModuleInterop": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,

    /* Performance */
    "skipLibCheck": true,
    "incremental": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
TSCONFIG_EOF

echo "Created $TSCONFIG with recommended modern defaults."
echo "Run 'npx tsc --noEmit' to type-check."
