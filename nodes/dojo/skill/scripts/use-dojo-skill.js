#!/usr/bin/env node

const { readFileSync } = require('fs');
const { resolve } = require('path');

// Keep this helper self-contained because Dojo bundle exports only include files
// from this node's directory, not sibling skills.
function appendParams(path, params) {
  const search = new URLSearchParams();

  for (const [key, value] of Object.entries(params || {})) {
    if (value === undefined || value === null || value === '') continue;
    if (Array.isArray(value)) {
      if (value.length) search.set(key, value.join(','));
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

function pickFirstValue(...values) {
  for (const value of values) {
    if (value !== undefined && value !== null && value !== '') return value;
  }
  return undefined;
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
  } catch (error) {
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
  if (value === 'true') return true;
  if (value === 'false') return false;
  return value;
}

function parseIntegerField(value, field) {
  if (value === undefined || value === null || value === '') return value;
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

  if (options.query_options !== undefined) {
    options.query_options = parseObjectField('query_options', options.query_options);
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

function buildHelpText() {
  return [
    'Usage:',
    '  node scripts/use-dojo-skill.js <operation> [--flag value]',
    '  node scripts/use-dojo-skill.js --json \'{"operation":"agent_learn","question":"find info in dojo"}\'',
    '',
    'Examples:',
    '  node scripts/use-dojo-skill.js agent_learn --question "find info in dojo" --current-context dojo',
    '  node scripts/use-dojo-skill.js discover --q "how do i publish a dojo node" --current-context dojo,dojo/publish',
    '  node scripts/use-dojo-skill.js bundle --uri dojo/skill',
    '',
    'Notes:',
    '  - Arrays like tags or current_context accept comma-separated values or JSON arrays.',
    '  - agent_context and query_options accept JSON objects.',
    '  - Defaults to http://localhost:3000 when base_url is omitted.'
  ].join('\n');
}

async function request(baseUrl, method, path, body) {
  const url = `${normalizeBaseUrl(baseUrl)}${path}`;
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

async function useDojoSkill(options = {}) {
  const {
    operation,
    base_url = 'http://localhost:3000',
    need,
    q,
    message,
    uri,
    alias,
    ecosystem,
    eco,
    type,
    tags,
    mode,
    executable,
    limit,
    offset,
    question,
    section,
    depth,
    current_context = [],
    agent_context = {},
    query_options = {}
  } = options;

  requireField(operation, 'operation', 'use-dojo-skill');

  const ecosystemFilter = eco || ecosystem;
  const promptLikeInput = pickFirstValue(question, q, need, message);
  const actionLikeInput = pickFirstValue(message, need, q, question);

  switch (operation) {
    case 'index':
      return request(base_url, 'GET', '/v1');
    case 'ecosystems':
      return request(base_url, 'GET', '/v1/ecosystems');
    case 'resolve':
      requireField(actionLikeInput, message ? 'message' : (need ? 'need' : (q ? 'q' : 'question')), operation);
      return request(base_url, 'GET', appendParams('/v1/resolve', {
        need: actionLikeInput,
        eco: ecosystemFilter,
        type,
        tags,
        mode,
        executable,
        limit,
        offset
      }));
    case 'discover':
      requireField(promptLikeInput, question ? 'question' : (q ? 'q' : (need ? 'need' : 'message')), operation);
      return request(base_url, 'GET', appendParams('/v1/discover', {
        q: promptLikeInput,
        limit,
        current_context
      }));
    case 'search':
      requireField(promptLikeInput, question ? 'question' : (q ? 'q' : (need ? 'need' : 'message')), operation);
      return request(base_url, 'GET', appendParams('/v1/search', {
        q: promptLikeInput,
        eco: ecosystemFilter,
        type,
        tags,
        mode,
        executable,
        limit,
        offset
      }));
    case 'skill':
      requireField(uri, 'uri', operation);
      return request(base_url, 'GET', `/v1/skills/${uri}`);
    case 'tree':
      requireField(uri || ecosystem, uri ? 'uri' : 'ecosystem', operation);
      return request(base_url, 'GET', appendParams(`/v1/tree/${uri || ecosystem}`, {
        depth
      }));
    case 'learn':
      requireField(uri, 'uri', operation);
      return request(base_url, 'GET', appendParams(`/v1/learn/${uri}`, {
        section,
        question: promptLikeInput
      }));
    case 'bundle':
      requireField(uri, 'uri', operation);
      return request(base_url, 'GET', `/v1/bundle/${uri}`);
    case 'backlinks':
      requireField(uri, 'uri', operation);
      return request(base_url, 'GET', `/v1/backlinks/${uri}`);
    case 'graph':
      requireField(uri, 'uri', operation);
      return request(base_url, 'GET', appendParams(`/v1/graph/${uri}`, { depth }));
    case 'alias':
      requireField(alias || uri, alias ? 'alias' : 'uri', operation);
      return request(base_url, 'GET', `/v1/alias/${encodeURIComponent(alias || uri)}`);
    case 'agent_ask':
      requireField(actionLikeInput, message ? 'message' : (need ? 'need' : (q ? 'q' : 'question')), operation);
      return request(base_url, 'POST', '/v1/agent/ask', {
        message: actionLikeInput,
        agent_context
      });
    case 'agent_learn':
      requireField(promptLikeInput, question ? 'question' : (q ? 'q' : (need ? 'need' : 'message')), operation);
      return request(base_url, 'POST', '/v1/agent/learn', {
        question: promptLikeInput,
        current_context
      });
    case 'query': {
      const delegated = query_options.operation || query_options.op;
      requireField(delegated, 'query_options.operation', operation);
      return useDojoSkill({
        ...query_options,
        base_url,
        operation: delegated
      });
    }
    default:
      throw new Error(`Unsupported operation: ${operation}`);
  }
}

async function runCli(argv = process.argv.slice(2), io = {}) {
  const stdout = io.stdout || process.stdout;
  const stderr = io.stderr || process.stderr;
  const parsed = parseCliArgs(argv);

  if (parsed.flags.help || parsed.positionals[0] === 'help') {
    stdout.write(`${buildHelpText()}\n`);
    return null;
  }

  const result = await useDojoSkill(normalizeCliOptions(parsed));
  stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  return result;
}

if (require.main === module) {
  runCli().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  useDojoSkill,
  parseCliArgs,
  normalizeCliOptions,
  runCli
};
