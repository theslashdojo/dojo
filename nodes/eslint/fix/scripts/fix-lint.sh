#!/usr/bin/env bash
set -euo pipefail

# Run ESLint --fix with reporting on what was fixed and what remains
#
# Usage: ./fix-lint.sh [target] [options]
# Arguments:
#   target     - File, directory, or glob to fix (default: ".")
# Environment:
#   DRY_RUN    - Set to "true" for --fix-dry-run (default: false)
#   FIX_TYPE   - Comma-separated fix types: problem,suggestion,layout,directive
#   USE_CACHE  - Set to "true" to enable --cache (default: true)

TARGET="${1:-.}"
DRY_RUN="${DRY_RUN:-false}"
FIX_TYPE="${FIX_TYPE:-}"
USE_CACHE="${USE_CACHE:-true}"

# Build command
CMD="npx eslint"

if [ "$DRY_RUN" = "true" ]; then
  CMD="$CMD --fix-dry-run"
  echo "==> Previewing ESLint fixes (dry run) on: $TARGET"
else
  CMD="$CMD --fix"
  echo "==> Running ESLint --fix on: $TARGET"
fi

if [ "$USE_CACHE" = "true" ]; then
  CMD="$CMD --cache"
fi

# Add fix-type filters
if [ -n "$FIX_TYPE" ]; then
  IFS=',' read -ra TYPES <<< "$FIX_TYPE"
  for t in "${TYPES[@]}"; do
    CMD="$CMD --fix-type $t"
  done
  echo "    Fix types: $FIX_TYPE"
fi

# Capture pre-fix state
echo "==> Pre-fix violation count:"
PRE_JSON=$(npx eslint --format json "$TARGET" 2>/dev/null || true)
PRE_ERRORS=$(echo "$PRE_JSON" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  const e = d.reduce((s,f) => s + f.errorCount, 0);
  const w = d.reduce((s,f) => s + f.warningCount, 0);
  const fe = d.reduce((s,f) => s + f.fixableErrorCount, 0);
  const fw = d.reduce((s,f) => s + f.fixableWarningCount, 0);
  console.log(JSON.stringify({errors:e, warnings:w, fixableErrors:fe, fixableWarnings:fw}));
" 2>/dev/null || echo '{"errors":0,"warnings":0,"fixableErrors":0,"fixableWarnings":0}')

echo "    $(echo "$PRE_ERRORS" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  console.log(\`Errors: \${d.errors} (\${d.fixableErrors} fixable), Warnings: \${d.warnings} (\${d.fixableWarnings} fixable)\`);
")"

# Run fix
echo ""
echo "==> Executing: $CMD $TARGET"
$CMD "$TARGET" 2>&1 || true

# Capture post-fix state
if [ "$DRY_RUN" != "true" ]; then
  echo ""
  echo "==> Post-fix violation count:"
  POST_JSON=$(npx eslint --format json "$TARGET" 2>/dev/null || true)
  POST_ERRORS=$(echo "$POST_JSON" | node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    const e = d.reduce((s,f) => s + f.errorCount, 0);
    const w = d.reduce((s,f) => s + f.warningCount, 0);
    console.log(JSON.stringify({errors:e, warnings:w}));
  " 2>/dev/null || echo '{"errors":0,"warnings":0}')

  echo "    $(echo "$POST_ERRORS" | node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    console.log(\`Remaining: \${d.errors} errors, \${d.warnings} warnings\`);
  ")"

  # Summary
  echo ""
  echo "==> Summary:"
  node -e "
    const pre = $PRE_ERRORS;
    const post = $POST_ERRORS;
    const fixedErrors = pre.errors - post.errors;
    const fixedWarnings = pre.warnings - post.warnings;
    console.log(\`  Fixed: \${fixedErrors} errors, \${fixedWarnings} warnings\`);
    console.log(\`  Remaining: \${post.errors} errors, \${post.warnings} warnings\`);
    if (post.errors > 0) {
      console.log('  Note: Remaining errors require manual fixes.');
      console.log('  Run: npx eslint . to see details.');
    } else {
      console.log('  All errors resolved!');
    }
  " 2>/dev/null || true
fi
