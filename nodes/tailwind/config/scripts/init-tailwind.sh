#!/usr/bin/env bash
# Initialize Tailwind CSS in the current project
# Usage: ./init-tailwind.sh
# Env: TAILWIND_VERSION (optional, default: 4) - major version: 3 or 4
#      BUILD_TOOL (optional, default: auto) - vite, postcss, or auto

set -euo pipefail

TAILWIND_VERSION="${TAILWIND_VERSION:-4}"
BUILD_TOOL="${BUILD_TOOL:-auto}"

# Auto-detect build tool
if [ "$BUILD_TOOL" = "auto" ]; then
  if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ] || [ -f "vite.config.mts" ]; then
    BUILD_TOOL="vite"
  elif [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next.config.ts" ]; then
    BUILD_TOOL="postcss"
  elif [ -f "postcss.config.js" ] || [ -f "postcss.config.mjs" ] || [ -f "postcss.config.cjs" ]; then
    BUILD_TOOL="postcss"
  else
    BUILD_TOOL="postcss"
  fi
  echo "Detected build tool: $BUILD_TOOL"
fi

# Check for package.json
if [ ! -f "package.json" ]; then
  echo "Error: No package.json found. Run 'npm init -y' first." >&2
  exit 1
fi

if [ "$TAILWIND_VERSION" = "4" ]; then
  echo "Installing Tailwind CSS v4..."

  if [ "$BUILD_TOOL" = "vite" ]; then
    npm install tailwindcss @tailwindcss/vite

    # Check if vite config already imports tailwindcss
    VITE_CONFIG=""
    for f in vite.config.ts vite.config.js vite.config.mts; do
      if [ -f "$f" ]; then
        VITE_CONFIG="$f"
        break
      fi
    done

    if [ -n "$VITE_CONFIG" ]; then
      if ! grep -q "@tailwindcss/vite" "$VITE_CONFIG"; then
        echo ""
        echo "Add to $VITE_CONFIG:"
        echo ""
        echo '  import tailwindcss from "@tailwindcss/vite";'
        echo ""
        echo "  // Add to plugins array:"
        echo "  plugins: [tailwindcss()]"
      else
        echo "Vite config already includes @tailwindcss/vite"
      fi
    fi

  else
    npm install tailwindcss @tailwindcss/postcss

    # Create or update postcss config
    if [ ! -f "postcss.config.mjs" ] && [ ! -f "postcss.config.js" ] && [ ! -f "postcss.config.cjs" ]; then
      cat > postcss.config.mjs <<'EOF'
export default {
  plugins: ["@tailwindcss/postcss"],
};
EOF
      echo "Created postcss.config.mjs"
    else
      echo "PostCSS config exists — add @tailwindcss/postcss to plugins if not present"
    fi
  fi

  # Find or create CSS entry point
  CSS_FILE=""
  for candidate in src/app.css src/index.css src/globals.css app/globals.css styles/globals.css; do
    if [ -f "$candidate" ]; then
      CSS_FILE="$candidate"
      break
    fi
  done

  if [ -z "$CSS_FILE" ]; then
    mkdir -p src
    CSS_FILE="src/app.css"
  fi

  if [ -f "$CSS_FILE" ]; then
    if ! grep -q '@import "tailwindcss"' "$CSS_FILE"; then
      # Prepend the import
      TEMP=$(mktemp)
      echo '@import "tailwindcss";' > "$TEMP"
      echo "" >> "$TEMP"
      cat "$CSS_FILE" >> "$TEMP"
      mv "$TEMP" "$CSS_FILE"
      echo "Added @import \"tailwindcss\" to $CSS_FILE"
    else
      echo "$CSS_FILE already imports tailwindcss"
    fi
  else
    echo '@import "tailwindcss";' > "$CSS_FILE"
    echo "Created $CSS_FILE with Tailwind import"
  fi

elif [ "$TAILWIND_VERSION" = "3" ]; then
  echo "Installing Tailwind CSS v3..."
  npm install -D tailwindcss postcss autoprefixer

  if [ ! -f "tailwind.config.js" ] && [ ! -f "tailwind.config.ts" ]; then
    npx tailwindcss init -p
    echo "Created tailwind.config.js and postcss.config.js"
  else
    echo "tailwind.config already exists"
  fi

  # Find or create CSS entry point
  CSS_FILE=""
  for candidate in src/app.css src/index.css src/globals.css app/globals.css styles/globals.css; do
    if [ -f "$candidate" ]; then
      CSS_FILE="$candidate"
      break
    fi
  done

  if [ -z "$CSS_FILE" ]; then
    mkdir -p src
    CSS_FILE="src/app.css"
  fi

  if [ -f "$CSS_FILE" ]; then
    if ! grep -q '@tailwind' "$CSS_FILE"; then
      TEMP=$(mktemp)
      cat > "$TEMP" <<'TWCSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

TWCSS
      cat "$CSS_FILE" >> "$TEMP"
      mv "$TEMP" "$CSS_FILE"
      echo "Added @tailwind directives to $CSS_FILE"
    else
      echo "$CSS_FILE already has @tailwind directives"
    fi
  else
    cat > "$CSS_FILE" <<'TWCSS'
@tailwind base;
@tailwind components;
@tailwind utilities;
TWCSS
    echo "Created $CSS_FILE with @tailwind directives"
  fi

else
  echo "Error: Unsupported TAILWIND_VERSION '$TAILWIND_VERSION'. Use 3 or 4." >&2
  exit 1
fi

echo ""
echo "Tailwind CSS v$TAILWIND_VERSION setup complete!"
echo "CSS entry: $CSS_FILE"
echo "Build tool: $BUILD_TOOL"
echo ""
echo "Test it by adding a class to your HTML:"
echo '  <h1 class="text-3xl font-bold text-blue-600">Hello Tailwind!</h1>'
