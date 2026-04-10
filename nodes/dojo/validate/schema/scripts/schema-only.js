#!/usr/bin/env node

const { inferRootDir, loadTree, readJson, validateCore } = require('../../scripts/lib.js');
const {
  createJsonWriter,
  normalizeCliOptions: baseNormalizeCliOptions,
  parseCliArgs
} = require('../../scripts/cli.js');

function validateSchema({ path, rootDir } = {}) {
  if (!path) throw new Error('path is required');

  const node = readJson(path);
  const index = loadTree(inferRootDir(path, rootDir));
  const structural = validateCore(node, index);

  return {
    valid: structural.errors.length === 0,
    errors: structural.errors,
    warnings: Array.from(new Set(structural.warnings))
  };
}

function buildHelpText() {
  return [
    'Usage:',
    '  node scripts/schema-only.js <path> [--root-dir <path>]',
    '  node scripts/schema-only.js --json \'{"path":"./nodes/dojo/skill/node.json"}\'',
    '',
    'Options:',
    '  --root-dir <path>   Root directory containing nodes/ or examples/',
    '  --input-file <path> Read a JSON object from a file',
    '  --json <json>       Read options from a JSON object'
  ].join('\n');
}

function normalizeCliOptions(parsed) {
  return baseNormalizeCliOptions(parsed, {
    aliasMap: {
      rootDir: ['root_dir']
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
    createJsonWriter(stdout)(validateSchema(options));
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
  validateSchema
};
