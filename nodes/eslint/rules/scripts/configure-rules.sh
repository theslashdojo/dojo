#!/usr/bin/env bash
set -euo pipefail

# Configure ESLint rules — list, check, and verify rule settings
# This script helps agents understand and verify rule configuration
#
# Usage: ./configure-rules.sh <action> [args]
# Actions:
#   check <file>     - Show resolved ESLint config for a file
#   list-errors      - Run ESLint and list only errors by rule
#   list-warnings    - Run ESLint and list only warnings by rule
#   fixable          - Show only fixable violations
#   unfixable        - Show only unfixable violations
#   rule-docs <rule> - Print the documentation URL for a rule

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  check)
    FILE="${1:?Usage: configure-rules.sh check <file>}"
    echo "==> Resolved ESLint config for: $FILE"
    npx eslint --print-config "$FILE"
    ;;

  list-errors)
    TARGET="${1:-.}"
    echo "==> ESLint errors grouped by rule in: $TARGET"
    npx eslint --format json "$TARGET" 2>/dev/null | \
      node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
        const counts = {};
        data.forEach(f => f.messages.forEach(m => {
          if (m.severity === 2) {
            counts[m.ruleId || 'parse-error'] = (counts[m.ruleId || 'parse-error'] || 0) + 1;
          }
        }));
        Object.entries(counts)
          .sort((a,b) => b[1] - a[1])
          .forEach(([rule, count]) => console.log(\`  \${count.toString().padStart(5)}  \${rule}\`));
        const total = Object.values(counts).reduce((a,b) => a+b, 0);
        console.log(\`\n  Total: \${total} errors across \${Object.keys(counts).length} rules\`);
      " || echo "  No errors found or ESLint not configured."
    ;;

  list-warnings)
    TARGET="${1:-.}"
    echo "==> ESLint warnings grouped by rule in: $TARGET"
    npx eslint --format json "$TARGET" 2>/dev/null | \
      node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
        const counts = {};
        data.forEach(f => f.messages.forEach(m => {
          if (m.severity === 1) {
            counts[m.ruleId || 'unknown'] = (counts[m.ruleId || 'unknown'] || 0) + 1;
          }
        }));
        Object.entries(counts)
          .sort((a,b) => b[1] - a[1])
          .forEach(([rule, count]) => console.log(\`  \${count.toString().padStart(5)}  \${rule}\`));
        const total = Object.values(counts).reduce((a,b) => a+b, 0);
        console.log(\`\n  Total: \${total} warnings across \${Object.keys(counts).length} rules\`);
      " || echo "  No warnings found or ESLint not configured."
    ;;

  fixable)
    TARGET="${1:-.}"
    echo "==> Fixable ESLint violations in: $TARGET"
    npx eslint --format json "$TARGET" 2>/dev/null | \
      node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
        let fixable = 0;
        data.forEach(f => {
          fixable += f.fixableErrorCount + f.fixableWarningCount;
          if (f.fixableErrorCount + f.fixableWarningCount > 0) {
            console.log(\`  \${f.filePath}: \${f.fixableErrorCount} errors, \${f.fixableWarningCount} warnings (fixable)\`);
          }
        });
        console.log(\`\n  Total fixable: \${fixable}\`);
        console.log('  Run: npx eslint --fix .');
      " || echo "  No fixable violations or ESLint not configured."
    ;;

  unfixable)
    TARGET="${1:-.}"
    echo "==> Unfixable ESLint violations in: $TARGET"
    npx eslint --format json "$TARGET" 2>/dev/null | \
      node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
        data.forEach(f => {
          const unfixable = f.messages.filter(m => !m.fix);
          if (unfixable.length > 0) {
            console.log(\`\n  \${f.filePath}:\`);
            unfixable.forEach(m => {
              const sev = m.severity === 2 ? 'error' : 'warn';
              console.log(\`    \${m.line}:\${m.column}  \${sev}  \${m.message}  [\${m.ruleId}]\`);
            });
          }
        });
      " || echo "  No unfixable violations or ESLint not configured."
    ;;

  rule-docs)
    RULE="${1:?Usage: configure-rules.sh rule-docs <rule-name>}"
    if [[ "$RULE" == @typescript-eslint/* ]]; then
      RULE_NAME="${RULE#@typescript-eslint/}"
      echo "https://typescript-eslint.io/rules/$RULE_NAME"
    elif [[ "$RULE" == react/* ]]; then
      RULE_NAME="${RULE#react/}"
      echo "https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/$RULE_NAME.md"
    elif [[ "$RULE" == react-hooks/* ]]; then
      echo "https://react.dev/reference/rules/rules-of-hooks"
    elif [[ "$RULE" == import/* ]]; then
      RULE_NAME="${RULE#import/}"
      echo "https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/$RULE_NAME.md"
    else
      echo "https://eslint.org/docs/latest/rules/$RULE"
    fi
    ;;

  help|*)
    echo "ESLint Rules Helper"
    echo ""
    echo "Usage: ./configure-rules.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  check <file>       Show resolved ESLint config for a file"
    echo "  list-errors [dir]  List errors grouped by rule"
    echo "  list-warnings [dir] List warnings grouped by rule"
    echo "  fixable [dir]      Show only fixable violations"
    echo "  unfixable [dir]    Show only unfixable violations"
    echo "  rule-docs <rule>   Print documentation URL for a rule"
    ;;
esac
