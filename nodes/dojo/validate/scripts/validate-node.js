#!/usr/bin/env node

const {
  collectKnowledgeWarnings,
  inferRootDir,
  loadTree,
  readJson,
  validateCore
} = require('./lib.js');
const {
  createJsonWriter,
  normalizeCliOptions: baseNormalizeCliOptions,
  parseCliArgs
} = require('./cli.js');

function validate({ path, rootDir, strict = false, requireKnowledge = false } = {}) {
  if (!path) throw new Error('path is required');

  const node = readJson(path);
  const index = loadTree(inferRootDir(path, rootDir));
  const structural = validateCore(node, index);
  const warnings = [...structural.warnings];

  if (strict || requireKnowledge) {
    const knowledge = collectKnowledgeWarnings(node, index, {
      requireAliases: true,
      minSections: strict ? 2 : 1,
      minBodyLength: strict ? 240 : 180,
      requireExecutableLink: strict
    });
    warnings.push(...knowledge.warnings);
  }

  return {
    valid: structural.errors.length === 0,
    errors: structural.errors,
    warnings: Array.from(new Set(warnings)),
    summary: {
      uri: node.uri,
      type: node.type,
      root_dir: index.rootDir,
      known_nodes: index.byUri.size
    }
  };
}

function buildHelpText() {
  return [
    'Usage:',
    '  node scripts/validate-node.js <path> [--flag value]',
    '  node scripts/validate-node.js --json \'{"path":"./nodes/dojo/skill/node.json","strict":true}\'',
    '',
    'Options:',
    '  --root-dir <path>           Root directory containing nodes/ or examples/',
    '  --strict <true|false>       Enable stronger knowledge quality warnings',
    '  --require-knowledge <bool>  Require knowledge-focused warnings',
    '  --input-file <path>         Read a JSON object from a file',
    '  --json <json>               Read options from a JSON object',
    '',
    'Notes:',
    '  - The first positional argument is treated as path when path is omitted.',
    '  - Output is machine-readable JSON for agent callers.'
  ].join('\n');
}

function normalizeCliOptions(parsed) {
  return baseNormalizeCliOptions(parsed, {
    booleanFields: ['strict', 'requireKnowledge'],
    aliasMap: {
      rootDir: ['root_dir'],
      requireKnowledge: ['require_knowledge']
    }
  });
}

function runCli(argv = process.argv.slice(2), stdout = process.stdout, stderr = process.stderr) {
  const parsed = parseCliArgs(argv);
  if (parsed.flags.help) {
    stdout.write(`${buildHelpText()}\n`);
    return Promise.resolve(0);
  }

  let options;
  try {
    options = normalizeCliOptions(parsed);
  } catch (error) {
    stderr.write(`${error.message}\n`);
    return Promise.resolve(1);
  }

  try {
    createJsonWriter(stdout)(validate(options));
    return Promise.resolve(0);
  } catch (error) {
    stderr.write(`${error.message}\n`);
    return Promise.resolve(1);
  }
}

if (require.main === module) {
  runCli().then((code) => {
    process.exitCode = code;
  });
}

module.exports = {
  buildHelpText,
  normalizeCliOptions,
  parseCliArgs,
  runCli,
  validate
};
