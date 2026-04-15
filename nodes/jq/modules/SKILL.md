---
name: modules
description: >
  Organize reusable jq program files, import module libraries, and run jq tests.
  Use when inline jq filters are too large, need version control, or should be validated with repeatable fixtures.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# jq Modules

Use this skill when jq logic should be stored, shared, reviewed, and tested like normal source code.

## Workflow

1. Move the jq filter into a `.jq` file and run it with `-f`.
2. Split shared helpers into module files and import them through `-L` plus `import` or `include`.
3. Add `module { ... };` metadata when the library should describe itself.
4. Create `.tests` fixtures and run them with `jq --run-tests` before relying on the program in automation.

## Examples

~~~bash
jq -L ./jq-lib -f main.jq input.json
jq -L ./jq-lib --run-tests slug.tests

JQ_PROGRAM_FILE="main.jq" \
JQ_INPUT_FILE="input.json" \
JQ_LIBRARY_PATH="./jq-lib" \
./scripts/run-program.sh

JQ_TEST_FILE="slug.tests" \
JQ_LIBRARY_PATH="./jq-lib" \
./scripts/run-tests.sh
~~~

## References

- `references/sample-module.jq` shows a reusable helper module.
- `references/sample-module.tests` shows the `--run-tests` file format.

## Edge Cases

- Prefer `import` when you want namespacing and `include` when you want direct definitions.
- Keep `-L` paths explicit in CI so module resolution does not depend on a user home directory.
- Tests run jq programs from the test file, so keep fixtures near the library or pass `JQ_LIBRARY_PATH`.
- Once jq code reaches this stage, review it like application code rather than like a shell one-liner.
