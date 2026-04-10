const { existsSync, readFileSync, readdirSync, statSync } = require('fs');
const { basename, dirname, join, resolve } = require('path');

const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;
const URI_RE = /^[a-z0-9-]+(\/[a-z0-9-]+)*$/;
const SEMVER_RE = /^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/;
const TAG_RE = /^[a-z0-9-]+$/;
const WIKI_LINK_RE = /\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/g;
const CONTENT_TYPES = new Set([
  'reference',
  'guide',
  'explainer',
  'comparison',
  'changelog',
  'faq',
  'glossary'
]);

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function stripSection(uri) {
  return String(uri || '').split('#')[0];
}

function splitReference(reference) {
  const [base, section] = String(reference || '').split('#');
  return { base, section: section || null };
}

function extractWikiTargets(text) {
  const targets = [];
  if (!text) return targets;
  let match;
  WIKI_LINK_RE.lastIndex = 0;
  while ((match = WIKI_LINK_RE.exec(text))) {
    targets.push(match[1]);
  }
  return targets;
}

function findManifestRoot(path) {
  let current = resolve(dirname(path));
  while (true) {
    if (basename(current) === 'examples' || basename(current) === 'nodes') return current;
    const parent = dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function inferRootDir(path, explicitRootDir) {
  if (explicitRootDir) return resolve(explicitRootDir);
  return findManifestRoot(path) || dirname(resolve(path));
}

function walkManifestFiles(dir, files = []) {
  if (!existsSync(dir)) return files;
  const names = readdirSync(dir);
  if (names.includes('node.json')) {
    files.push(join(dir, 'node.json'));
  } else if (names.includes('skill.json')) {
    files.push(join(dir, 'skill.json'));
  }
  for (const name of names) {
    const fullPath = join(dir, name);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      walkManifestFiles(fullPath, files);
    }
  }
  return files;
}

function loadTree(rootDir) {
  const manifests = walkManifestFiles(resolve(rootDir)).map((path) => ({
    path,
    node: readJson(path)
  }));
  const byUri = new Map();
  for (const item of manifests) {
    if (item.node && item.node.uri) byUri.set(item.node.uri, item);
  }
  return { rootDir: resolve(rootDir), manifests, byUri };
}

function validateReference(reference, index, label, warnings) {
  if (!reference) return;
  const { base, section } = splitReference(reference);
  if (base && !index.byUri.has(base)) {
    warnings.push(`${label} references unknown uri: ${reference}`);
    return;
  }
  if (section) {
    const target = index.byUri.get(base);
    const sections = new Set((target?.node?.sections || []).map((item) => item.id));
    if (!sections.has(section)) {
      warnings.push(`${label} references unknown section: ${reference}`);
    }
  }
}

function validateCore(node, index) {
  const errors = [];
  const warnings = [];

  if (!node || typeof node !== 'object' || Array.isArray(node)) {
    return { errors: ['manifest must be a JSON object'], warnings };
  }

  for (const field of ['name', 'version', 'uri', 'type', 'context', 'info', 'tags']) {
    if (node[field] === undefined || node[field] === null || node[field] === '') {
      errors.push(`${field} required`);
    }
  }

  if (node.name && !NAME_RE.test(node.name)) {
    errors.push('name must be lowercase with optional hyphens');
  }
  if (node.version && !SEMVER_RE.test(node.version)) {
    errors.push('version must be valid semver');
  }
  if (node.uri && !URI_RE.test(node.uri)) {
    errors.push('uri must match the lowercase slash-separated pattern');
  }
  if (node.uri && node.name && stripSection(node.uri).split('/').pop() !== node.name) {
    errors.push('name must match the last uri segment');
  }

  if (!Array.isArray(node.tags) || node.tags.length === 0) {
    errors.push('at least one tag is required');
  } else if (node.tags.some((tag) => !TAG_RE.test(tag))) {
    errors.push('tags must be lowercase tokens with optional hyphens');
  }

  if (node.type === 'ecosystem') {
    if (node.parent !== null) errors.push('ecosystem nodes must have parent: null');
  } else if (!node.parent) {
    errors.push('non-ecosystem nodes must declare a parent');
  }

  const parent = node.parent ? index.byUri.get(node.parent) : null;
  if (node.parent && !parent) {
    warnings.push(`parent not found in tree: ${node.parent}`);
  }
  if (node.parent && node.uri && !node.uri.startsWith(`${node.parent}/`)) {
    errors.push('uri must nest under parent uri');
  }
  if (parent) {
    if (node.type === 'sub' && parent.node.type !== 'skill') {
      errors.push('sub nodes must have a skill parent');
    }
    if ((node.type === 'standard' || node.type === 'skill') && parent.node.type === 'sub') {
      errors.push(`${node.type} nodes cannot have a sub parent`);
    }
  }

  const hasScripts = Array.isArray(node.scripts) && node.scripts.length > 0;
  if (hasScripts && !['skill', 'sub'].includes(node.type)) {
    errors.push('only skill and sub nodes may define scripts');
  }
  if (!hasScripts && ['skill', 'sub'].includes(node.type)) {
    warnings.push('skill/sub nodes should usually provide at least one script');
  }
  for (const script of node.scripts || []) {
    if (!script.id || !script.name || !script.lang) {
      errors.push('each script needs id, name, and lang');
    }
    if (!script.entry && !script.inline) {
      errors.push(`script ${script.id || '<unknown>'} must define entry or inline`);
    }
    if (script.entry && script.inline) {
      warnings.push(`script ${script.id} defines both entry and inline; prefer one execution mode`);
    }
    if (script.env) {
      for (const [envKey, envValue] of Object.entries(script.env)) {
        if (!envValue || !envValue.description) {
          warnings.push(`env ${envKey} should include a description`);
        }
      }
    }
  }

  if (['skill', 'sub'].includes(node.type) && !node.schema) {
    warnings.push('skill/sub nodes should usually include schema.input and schema.output');
  }
  if (!['skill', 'sub'].includes(node.type) && node.schema) {
    warnings.push('schema is usually reserved for skill and sub nodes');
  }

  if (Array.isArray(node.sub) && node.sub.length > 0 && ['context', 'sub'].includes(node.type)) {
    errors.push(`${node.type} nodes should not expose sub references`);
  }
  for (const uri of node.sub || []) {
    validateReference(uri, index, 'sub', warnings);
    const target = index.byUri.get(stripSection(uri));
    if (target && target.node.parent !== node.uri) {
      warnings.push(`sub reference ${uri} is not parented by ${node.uri}`);
    }
    if (target && target.node.type !== 'sub') {
      warnings.push(`sub reference ${uri} should point to a sub node`);
    }
  }

  for (const link of node.links || []) {
    validateReference(link.uri, index, 'link', warnings);
  }
  for (const dep of node.depends || []) {
    validateReference(dep.uri, index, 'depends', warnings);
  }
  for (const rel of node.related || []) {
    validateReference(rel.uri, index, 'related', warnings);
  }
  for (const reference of extractWikiTargets(node.info)) {
    validateReference(reference, index, 'wiki-link in info', warnings);
  }
  for (const reference of extractWikiTargets(node.body)) {
    validateReference(reference, index, 'wiki-link in body', warnings);
  }
  for (const section of node.sections || []) {
    for (const reference of extractWikiTargets(section.body)) {
      validateReference(reference, index, `wiki-link in section ${section.id}`, warnings);
    }
  }

  if (node.type === 'context' && !node.content_type) {
    warnings.push('context nodes should usually declare content_type');
  }
  if (node.type !== 'context' && node.content_type) {
    warnings.push('content_type is usually reserved for context nodes');
  }
  if (!node.repository) {
    warnings.push('repository improves provenance and package traceability');
  }
  if (!node.created || !node.updated) {
    warnings.push('created and updated timestamps improve lifecycle metadata');
  }

  return { errors, warnings };
}

function collectKnowledgeWarnings(node, index, options = {}) {
  const warnings = [];
  const minSections = options.minSections ?? 1;
  const minBodyLength = options.minBodyLength ?? 180;
  const requireAliases = options.requireAliases !== false;
  const requireExecutableLink = options.requireExecutableLink !== false;

  const body = typeof node.body === 'string' ? node.body.trim() : '';
  const sections = Array.isArray(node.sections) ? node.sections : [];
  const links = Array.isArray(node.links) ? node.links : [];
  const related = Array.isArray(node.related) ? node.related : [];
  const aliases = Array.isArray(node.aliases) ? node.aliases : [];
  const triggers = Array.isArray(node.triggers) ? node.triggers : [];

  if (requireAliases && aliases.length < 2) {
    warnings.push('add at least two aliases for realistic natural-language discovery');
  }
  if (triggers.length < 2) {
    warnings.push('add at least two triggers so the node activates on user phrasing');
  }
  if (body.length < minBodyLength) {
    warnings.push(`body should usually be at least ${minBodyLength} characters`);
  }
  if (sections.length < minSections) {
    warnings.push(`add at least ${minSections} section(s) for section-level learning`);
  }
  if (sections.some((section) => !section.body || section.body.trim().length < 60)) {
    warnings.push('sections should contain enough detail to be worth loading directly');
  }
  if (links.length === 0) {
    warnings.push('add outgoing links so the node is not a graph dead end');
  }
  if (links.length > 0 && !links.some((link) => String(link.uri || '').includes('#'))) {
    warnings.push('add at least one section-target link to demonstrate precise graph navigation');
  }
  if (related.length === 0) {
    warnings.push('add related edges for softer semantic navigation');
  }
  if (!body.includes('[[') && !sections.some((section) => String(section.body || '').includes('[['))) {
    warnings.push('use wiki-links in body or sections so backlinks can be derived from prose');
  }
  if (requireExecutableLink) {
    const hasExecutableLink = links.some((link) => {
      const target = index.byUri.get(stripSection(link.uri));
      return target && ['skill', 'sub'].includes(target.node.type);
    });
    if (!hasExecutableLink) {
      warnings.push('link to at least one skill or sub node so the reader has a clear next action');
    }
  }

  return {
    warnings,
    stats: {
      aliases: aliases.length,
      triggers: triggers.length,
      sections: sections.length,
      links: links.length,
      related: related.length
    }
  };
}

module.exports = {
  collectKnowledgeWarnings,
  inferRootDir,
  loadTree,
  readJson,
  validateCore
};
