#!/usr/bin/env node

const {
  collectKnowledgeWarnings,
  inferRootDir,
  loadTree,
  readJson
} = require('../../scripts/lib.js');
const {
  createJsonWriter,
  normalizeCliOptions: baseNormalizeCliOptions,
  parseCliArgs
} = require('../../scripts/cli.js');

function validateKnowledge({
  path,
  rootDir,
  requireAliases = true,
  minSections = 1,
  minBodyLength = 180,
  requireExecutableLink = true
} = {}) {
  if (!path) throw new Error('path is required');

  const node = readJson(path);
  const index = loadTree(inferRootDir(path, rootDir));
  const result = collectKnowledgeWarnings(node, index, {
    requireAliases,
    minSections,
    minBodyLength,
    requireExecutableLink
  });

  return {
    valid: result.warnings.length === 0,
    warnings: result.warnings,
    stats: result.stats
  };
}

function buildHelpText() {
  return [
    'Usage:',
    '  node scripts/knowledge-only.js <path> [--flag value]',
    '  node scripts/knowledge-only.js --json \'{"path":"./nodes/dojo/skill/node.json","minSections":2}\'',
    '',
    'Options:',
    '  --root-dir <path>                Root directory containing nodes/ or examples/',
    '  --require-aliases <true|false>   Require aliases for discovery',
    '  --min-sections <n>               Minimum section count',
    '  --min-body-length <n>            Minimum body character length',
    '  --require-executable-link <bool> Require a link to a skill or sub node',
    '  --input-file <path>              Read a JSON object from a file',
    '  --json <json>                    Read options from a JSON object'
  ].join('\n');
}

function normalizeCliOptions(parsed) {
  return baseNormalizeCliOptions(parsed, {
    booleanFields: ['requireAliases', 'requireExecutableLink'],
    integerFields: ['minSections', 'minBodyLength'],
    aliasMap: {
      rootDir: ['root_dir'],
      requireAliases: ['require_aliases'],
      minSections: ['min_sections'],
      minBodyLength: ['min_body_length'],
      requireExecutableLink: ['require_executable_link']
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
    createJsonWriter(stdout)(validateKnowledge(options));
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
  validateKnowledge
};
