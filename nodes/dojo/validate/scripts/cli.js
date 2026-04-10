const { readFileSync } = require('fs');
const { resolve } = require('path');

function parseCliArgs(argv) {
  const flags = {};
  const positionals = [];

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];

    if (token === '--') {
      positionals.push(...argv.slice(index + 1));
      break;
    }

    if (!token.startsWith('--')) {
      positionals.push(token);
      continue;
    }

    const key = token.slice(2).replace(/-/g, '_');
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      flags[key] = true;
      continue;
    }

    flags[key] = next;
    index += 1;
  }

  return { flags, positionals };
}

function parseJsonField(field, value) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'string') return value;

  try {
    return JSON.parse(value);
  } catch (_error) {
    throw new Error(`${field} must be valid JSON`);
  }
}

function parseObjectField(field, value) {
  const parsed = parseJsonField(field, value);
  if (parsed === undefined) return undefined;
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error(`${field} must be a JSON object`);
  }
  return parsed;
}

function parseBooleanField(field, value) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'boolean') return value;

  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  throw new Error(`${field} must be a boolean`);
}

function parseIntegerField(field, value) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'number' && Number.isInteger(value)) return value;

  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isInteger(parsed)) throw new Error(`${field} must be an integer`);
  return parsed;
}

function normalizeCliOptions(
  parsed,
  {
    positionalField = 'path',
    booleanFields = [],
    integerFields = [],
    aliasMap = {}
  } = {}
) {
  const { flags, positionals } = parsed;
  const jsonOptions = parseObjectField('json', flags.json) || {};
  const inputFileOptions = flags.input_file
    ? parseObjectField('input_file', readFileSync(resolve(flags.input_file), 'utf8'))
    : {};

  const options = {
    ...jsonOptions,
    ...inputFileOptions,
    ...flags
  };

  delete options.help;
  delete options.json;
  delete options.input_file;

  if (positionals[0] && options[positionalField] === undefined) {
    options[positionalField] = positionals[0];
  }

  for (const [target, sources] of Object.entries(aliasMap)) {
    if (options[target] !== undefined) continue;
    for (const source of sources) {
      if (options[source] !== undefined) {
        options[target] = options[source];
        break;
      }
    }
  }

  for (const field of booleanFields) {
    if (options[field] !== undefined) {
      options[field] = parseBooleanField(field, options[field]);
    }
  }

  for (const field of integerFields) {
    if (options[field] !== undefined) {
      options[field] = parseIntegerField(field, options[field]);
    }
  }

  return options;
}

function createJsonWriter(stream) {
  return (value) => stream.write(`${JSON.stringify(value, null, 2)}\n`);
}

module.exports = {
  createJsonWriter,
  normalizeCliOptions,
  parseCliArgs
};
