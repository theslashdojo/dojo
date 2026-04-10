#!/usr/bin/env node

const { readFileSync } = require('fs');
const { resolve } = require('path');

function appendParams(path, params) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params || {})) {
    if (value === undefined || value === null || value === '') continue;
    if (Array.isArray(value)) {
      if (value.length > 0) search.set(key, value.join(','));
      continue;
    }
    search.set(key, String(value));
  }
  const query = search.toString();
  return query ? `${path}?${query}` : path;
}

function requireField(value, field, operation) {
  if (value === undefined || value === null || value === '') {
    throw new Error(`${field} is required for ${operation}`);
  }
}

function normalizeBaseUrl(baseUrl) {
  return String(baseUrl || 'http://localhost:3000').replace(/\/+$/, '');
}

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

function parseListField(field, value) {
  if (value === undefined || value === null || value === '') return undefined;
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string') return [value];
  if (value.trim().startsWith('[')) {
    const parsed = parseJsonField(field, value);
    if (!Array.isArray(parsed)) throw new Error(`${field} JSON must be an array`);
    return parsed;
  }

  return value.split(',').map((part) => part.trim()).filter(Boolean);
}

function parseBooleanField(value) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'boolean') return value;
  if (value === 'true') return true;
  if (value === 'false') return false;
  return value;
}

function parseIntegerField(value, field) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'number') return value;
  const parsed = Number.parseInt(String(value), 10);
  if (Number.isNaN(parsed)) throw new Error(`${field} must be an integer`);
  return parsed;
}

function normalizeCliOptions(parsed) {
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

  if (positionals[0] && !options.operation) {
    options.operation = positionals[0];
  }

  if (options.tags !== undefined) {
    options.tags = parseListField('tags', options.tags);
  }
  if (options.current_context !== undefined) {
    options.current_context = parseListField('current_context', options.current_context);
  }
  if (options.agent_context !== undefined) {
    options.agent_context = parseObjectField('agent_context', options.agent_context);
  }
  if (options.executable !== undefined) {
    options.executable = parseBooleanField(options.executable);
  }
  if (options.limit !== undefined) {
    options.limit = parseIntegerField(options.limit, 'limit');
  }
  if (options.offset !== undefined) {
    options.offset = parseIntegerField(options.offset, 'offset');
  }
  if (options.depth !== undefined) {
    options.depth = parseIntegerField(options.depth, 'depth');
  }

  return options;
}

function normalizeOperationName(operation) {
  if (operation === 'agent-ask') return 'agent_ask';
  if (operation === 'agent-learn') return 'agent_learn';
  return operation;
}

async function query(options = {}) {
  const {
    operation,
    base_url = 'http://localhost:3000',
    need,
    q,
    message,
    uri,
    alias,
    eco,
    type,
    tags,
    mode,
    executable,
    limit,
    offset,
    section,
    depth,
    question,
    current_context = [],
    agent_context = {}
  } = options;

  const normalizedOperation = normalizeOperationName(operation);
  requireField(normalizedOperation, 'operation', 'query');

  const baseUrl = normalizeBaseUrl(base_url);
  let method = 'GET';
  let path = '/v1';
  let body;

  switch (normalizedOperation) {
    case 'index':
      path = '/v1';
      break;
    case 'resolve':
      requireField(need, 'need', operation);
      path = appendParams('/v1/resolve', { need, eco, type, tags, mode, executable, limit, offset });
      break;
    case 'discover':
      requireField(q || need || question, q ? 'q' : (need ? 'need' : 'question'), operation);
      path = appendParams('/v1/discover', {
        q: q || need || question,
        limit,
        current_context
      });
      break;
    case 'search':
      requireField(q, 'q', operation);
      path = appendParams('/v1/search', { q, eco, type, tags, mode, executable, limit, offset });
      break;
    case 'skill':
      requireField(uri, 'uri', operation);
      path = `/v1/skills/${uri}`;
      break;
    case 'bundle':
      requireField(uri, 'uri', operation);
      path = `/v1/bundle/${uri}`;
      break;
    case 'tree':
      requireField(uri, 'uri', operation);
      path = appendParams(`/v1/tree/${uri}`, { depth });
      break;
    case 'learn':
      requireField(uri, 'uri', operation);
      path = appendParams(`/v1/learn/${uri}`, { section, question });
      break;
    case 'backlinks':
      requireField(uri, 'uri', operation);
      path = `/v1/backlinks/${uri}`;
      break;
    case 'graph':
      requireField(uri, 'uri', operation);
      path = appendParams(`/v1/graph/${uri}`, { depth });
      break;
    case 'alias':
      requireField(alias || uri, alias ? 'alias' : 'uri', operation);
      path = `/v1/alias/${encodeURIComponent(alias || uri)}`;
      break;
    case 'ecosystems':
      path = '/v1/ecosystems';
      break;
    case 'agent_ask':
      requireField(message, 'message', operation);
      method = 'POST';
      path = '/v1/agent/ask';
      body = { message, agent_context };
      break;
    case 'agent_learn':
      requireField(question, 'question', operation);
      method = 'POST';
      path = '/v1/agent/learn';
      body = { question, current_context };
      break;
    default:
      throw new Error(`Unsupported operation: ${normalizedOperation}`);
  }

  const url = `${baseUrl}${path}`;
  const response = await fetch(url, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined
  });

  let data;
  try {
    data = await response.json();
  } catch (error) {
    data = { error: `Non-JSON response for ${path}` };
  }

  return {
    status: response.status,
    method,
    url,
    data
  };
}

function buildHelpText() {
  return [
    'Usage:',
    '  node scripts/query-registry.js <operation> [--flag value]',
    '  node scripts/query-registry.js --json \'{"operation":"agent_learn","question":"find info in dojo"}\'',
    '',
    'Examples:',
    '  node scripts/query-registry.js search --q "dojo validation" --mode learn',
    '  node scripts/query-registry.js learn --uri dojo/api --question "where is the bundle route"',
    '  node scripts/query-registry.js bundle --uri dojo/skill',
    '',
    'Notes:',
    '  - Arrays like tags or current_context accept comma-separated values or JSON arrays.',
    '  - agent_context accepts a JSON object.',
    '  - `agent-ask` and `agent_ask` are both accepted.'
  ].join('\n');
}

async function runCli(argv = process.argv.slice(2), stdout = process.stdout, stderr = process.stderr) {
  const parsed = parseCliArgs(argv);
  if (parsed.flags.help) {
    stdout.write(`${buildHelpText()}\n`);
    return 0;
  }

  let options;
  try {
    options = normalizeCliOptions(parsed);
  } catch (error) {
    stderr.write(`${error.message}\n`);
    return 1;
  }

  try {
    const result = await query(options);
    stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    return 0;
  } catch (error) {
    stderr.write(`${error.message}\n`);
    return 1;
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
  query,
  runCli
};
