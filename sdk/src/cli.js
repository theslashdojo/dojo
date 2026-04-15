#!/usr/bin/env node
/**
 * dojo — CLI for the Dojo skill registry.
 *
 * Implements SPEC.md §20 CLI Reference: discovery, knowledge, installation,
 * execution, authoring, publishing, configuration, registry, and utilities.
 */

import { Dojo } from './index.js';
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync, statSync, chmodSync } from 'fs';
import { join, resolve, basename, dirname, extname } from 'path';
import { homedir } from 'os';
import { execSync, spawn } from 'child_process';
import { createHash } from 'crypto';
import { fileURLToPath } from 'url';

// ─── ANSI helpers ────────────────────────────────────────
const C = process.env.NO_COLOR
  ? { r: '', g: '', y: '', b: '', m: '', c: '', dim: '', bold: '', reset: '' }
  : {
      r: '\x1b[31m', g: '\x1b[32m', y: '\x1b[33m', b: '\x1b[34m',
      m: '\x1b[35m', c: '\x1b[36m', dim: '\x1b[2m', bold: '\x1b[1m',
      reset: '\x1b[0m'
    };

// ─── Paths ──────────────────────────────────────────────
const DOJO_HOME = process.env.DOJO_HOME || join(homedir(), '.dojo');
const SKILLS_DIR = join(DOJO_HOME, 'skills');
const LOCK_FILE = join(DOJO_HOME, 'skill-lock.json');
const CONFIG_FILE = join(DOJO_HOME, 'config.json');
const SECRETS_FILE = join(DOJO_HOME, 'secrets.json');

function ensureHome() {
  mkdirSync(SKILLS_DIR, { recursive: true });
}

// ─── Config helpers ─────────────────────────────────────
function loadConfig() {
  if (!existsSync(CONFIG_FILE)) return { registries: [] };
  return JSON.parse(readFileSync(CONFIG_FILE, 'utf-8'));
}

function saveConfig(cfg) {
  ensureHome();
  writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2) + '\n');
}

function loadLock() {
  if (!existsSync(LOCK_FILE)) return { resolved: {}, resolved_at: null, registry: null };
  return JSON.parse(readFileSync(LOCK_FILE, 'utf-8'));
}

function saveLock(lock) {
  ensureHome();
  writeFileSync(LOCK_FILE, JSON.stringify(lock, null, 2) + '\n');
}

function loadSecrets() {
  if (!existsSync(SECRETS_FILE)) return {};
  return JSON.parse(readFileSync(SECRETS_FILE, 'utf-8'));
}

function saveSecrets(s) {
  ensureHome();
  writeFileSync(SECRETS_FILE, JSON.stringify(s, null, 2) + '\n');
}

// ─── Client factory ─────────────────────────────────────
function makeClient() {
  const cfg = loadConfig();
  const registries = cfg.registries?.map(r => r.url) || [];
  return new Dojo({
    registries,
    registry: cfg.default_registry || registries[0],
    token: cfg.token || process.env.DOJO_TOKEN
  });
}

// ─── Arg parsing ────────────────────────────────────────
function parseArgs(argv) {
  const args = [];
  const flags = {};
  const setFlag = (key, value) => {
    if (flags[key] === undefined) {
      flags[key] = value;
    } else if (Array.isArray(flags[key])) {
      flags[key].push(value);
    } else {
      flags[key] = [flags[key], value];
    }
  };
  let i = 0;
  while (i < argv.length) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const eq = key.indexOf('=');
      if (eq >= 0) {
        setFlag(key.slice(0, eq), key.slice(eq + 1));
      } else if (i + 1 < argv.length && !argv[i + 1].startsWith('-')) {
        setFlag(key, argv[++i]);
      } else {
        setFlag(key, true);
      }
    } else if (a.startsWith('-') && a.length === 2) {
      const key = a.slice(1);
      if (i + 1 < argv.length && !argv[i + 1].startsWith('-')) {
        setFlag(key, argv[++i]);
      } else {
        setFlag(key, true);
      }
    } else {
      args.push(a);
    }
    i++;
  }
  return { args, flags };
}

// ─── Output helpers ─────────────────────────────────────
function json(data) {
  console.log(JSON.stringify(data, null, 2));
}

function die(msg) {
  console.error(`${C.r}error${C.reset}: ${msg}`);
  process.exit(1);
}

function heading(text) {
  console.log(`\n${C.bold}${text}${C.reset}`);
}

function row(label, value) {
  console.log(`  ${C.dim}${label}${C.reset}  ${value}`);
}

function skillLine(s, score) {
  const tag = s.type ? `${C.dim}[${s.type}]${C.reset} ` : '';
  const sc = score != null ? ` ${C.dim}(${(score * 100).toFixed(0)}%)${C.reset}` : '';
  console.log(`  ${C.c}${s.uri}${C.reset} ${tag}${s.context || ''}${sc}`);
}

// ─── Bundle helpers ─────────────────────────────────────

const BUNDLE_INCLUDE_DIRS = new Set(['agents', 'references', 'scripts', 'tests']);
const BUNDLE_INCLUDE_FILES = new Set(['node.json', 'skill.json', 'SKILL.md', 'README.md']);
const BUNDLE_TEXT_EXTENSIONS = new Set(['.json', '.md', '.js', '.cjs', '.mjs', '.yaml', '.yml', '.sh', '.txt']);
const MAX_BUNDLE_FILE_BYTES = 128 * 1024;

function dedupe(values = []) {
  return Array.from(new Set(values.filter(Boolean)));
}

function expandHomePath(value) {
  const raw = String(value || '.');
  if (raw === '~') return homedir();
  if (raw.startsWith('~/')) return join(homedir(), raw.slice(2));
  return resolve(raw);
}

function uriParts(uri) {
  const parts = String(uri || '').split('/').filter(Boolean);
  if (!parts.length || parts.some(part => part === '.' || part === '..' || part.includes('\\'))) {
    die(`invalid uri: ${uri}`);
  }
  return parts;
}

function bundleDirectoryName(uri, flags = {}) {
  const name = flags.name || uriParts(uri).join('-');
  return name.replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'skill';
}

function safeBundlePath(value) {
  const normalized = String(value || '').replace(/\\/g, '/').replace(/^\.\//, '');
  const parts = normalized.split('/').filter(Boolean);
  if (!normalized || normalized.startsWith('/') || parts.includes('..')) {
    die(`unsafe bundle path: ${value}`);
  }
  return parts.join('/');
}

function bundleRouteMap(uri) {
  return {
    skill: `/v1/skills/${uri}`,
    learn: `/v1/learn/${uri}`,
    graph: `/v1/graph/${uri}`,
    backlinks: `/v1/backlinks/${uri}`,
    bundle: `/v1/bundle/${uri}`
  };
}

function bundleExecutionSummary(skill) {
  const scripts = Array.isArray(skill?.scripts) ? skill.scripts : [];
  const requiredEnv = [];
  const optionalEnv = [];

  for (const script of scripts) {
    for (const [key, meta] of Object.entries(script.env || {})) {
      if (meta?.required) requiredEnv.push(key);
      else optionalEnv.push(key);
    }
  }

  return {
    can_execute: scripts.length > 0,
    script_count: scripts.length,
    script_ids: scripts.map(script => script.id).filter(Boolean),
    langs: dedupe(scripts.map(script => script.lang)),
    runtimes: dedupe(scripts.map(script => script.runtime)),
    packages: dedupe(scripts.flatMap(script => script.packages || [])),
    required_env: dedupe(requiredEnv),
    optional_env: dedupe(optionalEnv),
    required_input_fields: dedupe(skill?.schema?.input?.required || [])
  };
}

function bundleKnowledgeSummary(skill) {
  const sections = Array.isArray(skill?.sections) ? skill.sections : [];
  return {
    has_body: Boolean(skill?.body),
    section_count: sections.length,
    has_sections: sections.length > 0,
    has_aliases: Array.isArray(skill?.aliases) && skill.aliases.length > 0
  };
}

function classifyBundleFile(relativePath) {
  if (relativePath === 'node.json' || relativePath === 'skill.json') return 'manifest';
  if (relativePath === 'SKILL.md') return 'skill';
  if (relativePath === 'README.md') return 'doc';
  if (relativePath.startsWith('agents/')) return 'agent';
  if (relativePath.startsWith('references/')) return 'reference';
  if (relativePath.startsWith('scripts/')) return 'script';
  if (relativePath.startsWith('tests/')) return 'test';
  return 'file';
}

function shouldTraverseBundleDir(relativePath) {
  const topLevel = relativePath.split('/')[0];
  return BUNDLE_INCLUDE_DIRS.has(topLevel);
}

function shouldIncludeBundleFile(relativePath) {
  if (BUNDLE_INCLUDE_FILES.has(relativePath)) return true;
  const [topLevel] = relativePath.split('/');
  if (!BUNDLE_INCLUDE_DIRS.has(topLevel)) return false;
  return BUNDLE_TEXT_EXTENSIONS.has(extname(relativePath).toLowerCase());
}

function collectLocalBundleFiles(sourceDir, relativeDir = '') {
  const files = [];
  const entries = readdirSync(sourceDir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = join(sourceDir, entry.name);
    const nextRelative = relativeDir ? `${relativeDir}/${entry.name}` : entry.name;

    if (entry.isDirectory()) {
      if (!shouldTraverseBundleDir(nextRelative)) continue;
      files.push(...collectLocalBundleFiles(fullPath, nextRelative));
      continue;
    }

    if (!shouldIncludeBundleFile(nextRelative)) continue;

    const stats = statSync(fullPath);
    const file = {
      path: nextRelative,
      kind: classifyBundleFile(nextRelative),
      size: stats.size
    };

    if (stats.size <= MAX_BUNDLE_FILE_BYTES) {
      file.content = readFileSync(fullPath, 'utf-8');
    } else {
      file.truncated = true;
    }

    files.push(file);
  }

  return files.sort((left, right) => left.path.localeCompare(right.path));
}

function addCandidateDir(candidates, dir) {
  if (!dir) return;
  const resolved = resolve(dir);
  if (!candidates.includes(resolved)) candidates.push(resolved);
}

function candidateNodeRoots(flags = {}) {
  const candidates = [];

  const addList = (value) => {
    if (!value) return;
    for (const entry of String(value).split(',')) {
      if (entry.trim()) addCandidateDir(candidates, entry.trim());
    }
  };

  if (flags.nodes) addList(flags.nodes);
  if (flags.root) addCandidateDir(candidates, join(expandHomePath(flags.root), 'nodes'));
  if (process.env.DOJO_ROOT) addCandidateDir(candidates, join(expandHomePath(process.env.DOJO_ROOT), 'nodes'));
  addList(process.env.DOJO_NODES || process.env.NODES_DIR || process.env.SKILLS_DIR);

  let dir = process.cwd();
  while (true) {
    addCandidateDir(candidates, join(dir, 'nodes'));
    addCandidateDir(candidates, join(dir, 'dojo', 'nodes'));
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  addCandidateDir(candidates, fileURLToPath(new URL('../../nodes', import.meta.url)));
  return candidates;
}

function findLocalNodeSource(uri, flags = {}) {
  const parts = uriParts(uri);
  for (const root of candidateNodeRoots(flags)) {
    const dir = join(root, ...parts);
    if (!existsSync(dir) || !statSync(dir).isDirectory()) continue;
    const manifestFile = existsSync(join(dir, 'node.json'))
      ? 'node.json'
      : existsSync(join(dir, 'skill.json'))
        ? 'skill.json'
        : null;
    if (manifestFile) return { root, dir, manifestFile };
  }
  return null;
}

function buildLocalBundle(uri, flags = {}) {
  const source = findLocalNodeSource(uri, flags);
  if (!source) return null;

  const manifest = JSON.parse(readFileSync(join(source.dir, source.manifestFile), 'utf-8'));
  const files = collectLocalBundleFiles(source.dir);
  const envelope = {
    ...manifest,
    execution: bundleExecutionSummary(manifest),
    knowledge: bundleKnowledgeSummary(manifest),
    routes: bundleRouteMap(manifest.uri || uri)
  };

  return {
    uri: manifest.uri || uri,
    routes: bundleRouteMap(manifest.uri || uri),
    manifest: envelope,
    source: {
      source_path: uri,
      manifest_file: source.manifestFile,
      origin: 'local',
      root: source.root
    },
    entrypoints: {
      manifest: source.manifestFile,
      skill_md: files.find(file => file.path === 'SKILL.md')?.path || null,
      agents: files.filter(file => file.kind === 'agent').map(file => file.path),
      references: files.filter(file => file.kind === 'reference').map(file => file.path),
      scripts: files.filter(file => file.kind === 'script').map(file => file.path),
      tests: files.filter(file => file.kind === 'test').map(file => file.path),
      docs: files.filter(file => file.kind === 'doc').map(file => file.path)
    },
    files
  };
}

function bundleTargetDir(uri, flags) {
  const rawLoc = flags.loc || flags.location || flags.out || flags.output || flags.dir;
  if (!rawLoc) return null;

  const base = expandHomePath(rawLoc);
  const skillName = bundleDirectoryName(uri, flags);
  const destinationRoot = basename(base) === '.codex'
    ? join(base, 'skills')
    : base;

  return join(destinationRoot, skillName);
}

function writeBundleFiles(bundle, targetDir) {
  mkdirSync(targetDir, { recursive: true });
  let fileCount = 0;
  let wroteManifest = false;

  for (const file of bundle.files || []) {
    if (file.content == null) continue;
    const relativePath = safeBundlePath(file.path);
    const target = join(targetDir, relativePath);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, file.content);
    if (relativePath === 'node.json' || relativePath === 'skill.json') wroteManifest = true;
    if (relativePath.startsWith('scripts/') || file.content.startsWith('#!')) {
      try { chmodSync(target, 0o755); } catch {}
    }
    fileCount++;
  }

  if (!wroteManifest && bundle.manifest) {
    writeFileSync(join(targetDir, 'node.json'), JSON.stringify(bundle.manifest, null, 2) + '\n');
    fileCount++;
  }

  return fileCount;
}

async function fetchBundle(uri, version, flags) {
  const canUseLocal = !version && !flags.chain;
  const preferLocal = flags.local || (canUseLocal && !flags.remote && !flags.registry);

  if (preferLocal) {
    const localBundle = buildLocalBundle(uri, flags);
    if (localBundle) return localBundle;
    if (flags.local) die(`local node not found: ${uri}`);
  }

  const client = makeClient();
  if (flags.registry) {
    client.registry = flags.registry;
    client.registryCandidates = [flags.registry];
  }

  const params = new URLSearchParams();
  if (version) params.set('version', version);
  if (flags.chain) params.set('chain', flags.chain);
  const qs = params.toString();

  try {
    return await client._fetch(`/v1/bundle/${uri}${qs ? '?' + qs : ''}`);
  } catch (error) {
    if (canUseLocal && !preferLocal) {
      const localBundle = buildLocalBundle(uri, flags);
      if (localBundle) return localBundle;
    }
    throw error;
  }
}

// ─── Commands ───────────────────────────────────────────

// ── Discovery ───────────────────────────────────────────

async function cmdSearch(args, flags) {
  if (!args.length) die('usage: dojo search <query>');
  const client = makeClient();
  const results = await client.search(args.join(' '), {
    eco: flags.eco,
    type: flags.type,
    tags: flags.tags,
    limit: flags.limit,
    offset: flags.offset,
    mode: flags.mode
  });
  if (flags.json) return json(results);
  if (!results.results?.length) return console.log('No results.');
  heading(`${results.total} result${results.total === 1 ? '' : 's'}`);
  for (const r of results.results) {
    skillLine(r, r.score);
  }
}

async function cmdResolve(args, flags) {
  if (!args.length) die('usage: dojo resolve <need>');
  const client = makeClient();
  const data = await client.need(args.join(' '), {
    tags: flags.tags, type: flags.type, limit: flags.limit, mode: flags.mode
  });
  if (flags.json) return json(data);
  if (!data) return console.log('No matching skill found.');
  heading('Best match');
  skillLine(data);
  if (data.scripts?.length) {
    row('scripts', data.scripts.map(s => s.id).join(', '));
  }
}

async function cmdTree(args, flags) {
  if (!args.length) die('usage: dojo tree <ecosystem>');
  const client = makeClient();
  const tree = await client.tree(args[0], Number(flags.depth) || 4);
  if (flags.json) return json(tree);
  printTree(tree, 0, Number(flags.depth) || 4);
}

function printTree(node, depth, maxDepth) {
  if (depth > maxDepth) return;
  const indent = '  '.repeat(depth);
  const tag = node.type ? `${C.dim}[${node.type}]${C.reset} ` : '';
  console.log(`${indent}${C.c}${node.uri}${C.reset} ${tag}${node.context || ''}`);
  for (const child of node.skills || node.children || []) {
    printTree(child, depth + 1, maxDepth);
  }
}

async function cmdInfo(args, flags) {
  if (!args.length) die('usage: dojo info <uri>');
  const client = makeClient();
  const data = await client.get(args[0]);
  if (flags.json) return json(data);
  const s = data.skill;
  heading(s.uri);
  row('type', s.type || 'skill');
  row('version', s.version || 'n/a');
  if (s.context) row('context', s.context);
  if (s.tags?.length) row('tags', s.tags.join(', '));
  if (s.scripts?.length) {
    row('scripts', s.scripts.map(sc => `${sc.id} (${sc.lang})`).join(', '));
  }
  if (s.depends?.length) {
    row('depends', s.depends.map(d => `${d.uri}${d.optional ? ' (opt)' : ''}`).join(', '));
  }
  if (data.ancestors?.length) {
    row('ancestors', data.ancestors.map(a => a.uri).join(' → '));
  }
  if (data.children?.length) {
    row('children', data.children.map(c => c.uri).join(', '));
  }
}

// ── Knowledge ───────────────────────────────────────────

async function cmdLearn(args, flags) {
  if (!args.length) die('usage: dojo learn <uri> [--section <id>] [--question <q>]');
  let uri = args[0];
  let section = flags.section;
  // Support uri#section shorthand
  const hash = uri.indexOf('#');
  if (hash >= 0) {
    section = section || uri.slice(hash + 1);
    uri = uri.slice(0, hash);
  }
  const client = makeClient();
  const params = new URLSearchParams();
  if (section) params.set('section', section);
  if (flags.question) params.set('question', flags.question);
  const qs = params.toString();
  const data = await client._fetch(`/v1/learn/${uri}${qs ? '?' + qs : ''}`);
  if (flags.json) return json(data);

  const node = data.node;
  heading(node.uri);
  if (node.context) console.log(`${C.dim}${node.context}${C.reset}\n`);
  if (data.focused_section) {
    console.log(`${C.bold}§ ${data.focused_section.title}${C.reset}`);
    console.log(data.focused_section.body || '');
  } else if (node.body) {
    console.log(node.body);
  }
  if (node.sections?.length && !data.focused_section) {
    heading('Sections');
    for (const sec of node.sections) {
      console.log(`  ${C.y}#${sec.id}${C.reset}  ${sec.title}`);
    }
  }
  if (data.reading_path?.length) {
    heading('Reading path');
    for (const step of data.reading_path) {
      console.log(`  → ${C.c}${step.uri || step.route}${C.reset}  ${step.why || step.title || ''}`);
    }
  }
}

async function cmdBacklinks(args, flags) {
  if (!args.length) die('usage: dojo backlinks <uri>');
  const client = makeClient();
  const data = await client._fetch(`/v1/backlinks/${args[0]}`);
  if (flags.json) return json(data);
  if (!data.backlinks?.length) return console.log('No backlinks.');
  heading(`Backlinks for ${args[0]}`);
  for (const bl of data.backlinks) {
    console.log(`  ${C.c}${bl.from}${C.reset} ${C.dim}(${bl.type})${C.reset} ${bl.context || ''}`);
  }
}

async function cmdGraph(args, flags) {
  if (!args.length) die('usage: dojo graph <uri>');
  const client = makeClient();
  const depth = Number(flags.depth) || 2;
  const data = await client._fetch(`/v1/graph/${args[0]}?depth=${depth}`);
  if (flags.json) return json(data);
  heading(`Graph around ${data.center}`);
  if (data.nodes?.length) {
    console.log(`  ${data.nodes.length} node${data.nodes.length === 1 ? '' : 's'}`);
    for (const n of data.nodes) {
      console.log(`    ${C.c}${n.uri}${C.reset} ${C.dim}[${n.type}]${C.reset}`);
    }
  }
  if (data.edges?.length) {
    heading('Edges');
    for (const e of data.edges) {
      console.log(`    ${e.from} ${C.dim}─${e.type}→${C.reset} ${e.to}`);
    }
  }
}

async function cmdAlias(args, flags) {
  if (!args.length) die('usage: dojo alias <name>');
  const client = makeClient();
  const data = await client._fetch(`/v1/alias/${encodeURIComponent(args.join(' '))}`);
  if (flags.json) return json(data);
  console.log(`${C.c}${data.uri}${C.reset}  ${data.context || ''}`);
}

// ── Installation ────────────────────────────────────────

async function cmdInstall(args, flags) {
  if (!args.length) die('usage: dojo install <uri>[@version] [--chain <variant>] [--dry-run]');
  ensureHome();
  const client = makeClient();

  let uri = args[0];
  let version;
  const atIdx = uri.lastIndexOf('@');
  if (atIdx > 0) {
    version = uri.slice(atIdx + 1);
    uri = uri.slice(0, atIdx);
  }

  console.log(`${C.dim}Fetching ${uri}${version ? '@' + version : ''}...${C.reset}`);

  // Fetch bundle
  const params = new URLSearchParams();
  if (version) params.set('version', version);
  if (flags.chain) params.set('chain', flags.chain);
  const qs = params.toString();
  const bundle = await client._fetch(`/v1/bundle/${uri}${qs ? '?' + qs : ''}`);

  if (flags['dry-run']) {
    heading('Dry run — would install:');
    row('uri', bundle.uri);
    row('files', `${bundle.files?.length || 0} file(s)`);
    if (bundle.files) {
      for (const f of bundle.files) {
        console.log(`    ${C.dim}${f.kind}${C.reset}  ${f.path} (${f.size} bytes)`);
      }
    }
    return;
  }

  // Write files to ~/.dojo/skills/<uri>/
  const skillDir = join(SKILLS_DIR, ...uri.split('/'));
  mkdirSync(skillDir, { recursive: true });

  let fileCount = 0;
  if (bundle.files) {
    for (const f of bundle.files) {
      if (f.content != null) {
        const target = join(skillDir, f.path);
        mkdirSync(dirname(target), { recursive: true });
        writeFileSync(target, f.content);
        fileCount++;
      }
    }
  }

  // Also write manifest
  if (bundle.manifest) {
    writeFileSync(join(skillDir, 'skill.json'), JSON.stringify(bundle.manifest, null, 2) + '\n');
  }

  // Update lockfile
  const lock = loadLock();
  lock.resolved[uri] = version || bundle.manifest?.version || 'latest';
  lock.resolved_at = new Date().toISOString();
  lock.registry = client.registry;
  saveLock(lock);

  // Install npm packages if any scripts need them
  const scripts = bundle.manifest?.scripts || [];
  const allPkgs = scripts.flatMap(s => s.packages || []);
  if (allPkgs.length) {
    console.log(`${C.dim}Installing packages: ${allPkgs.join(', ')}...${C.reset}`);
    try {
      execSync(`npm install --prefix "${skillDir}" ${allPkgs.join(' ')}`, { stdio: 'inherit' });
    } catch {
      console.warn(`${C.y}warn${C.reset}: package install failed — scripts may not run`);
    }
  }

  console.log(`${C.g}✓${C.reset} Installed ${C.c}${uri}${C.reset} (${fileCount} file${fileCount === 1 ? '' : 's'})`);
}

async function cmdUninstall(args, _flags) {
  if (!args.length) die('usage: dojo uninstall <uri>');
  const uri = args[0];
  const skillDir = join(SKILLS_DIR, ...uri.split('/'));
  if (!existsSync(skillDir)) die(`${uri} is not installed`);

  rmSync(skillDir, { recursive: true, force: true });

  // Clean empty parent dirs
  let parent = dirname(skillDir);
  while (parent !== SKILLS_DIR) {
    try {
      const entries = readdirSync(parent);
      if (entries.length === 0) rmSync(parent, { recursive: true });
      else break;
    } catch { break; }
    parent = dirname(parent);
  }

  // Update lockfile
  const lock = loadLock();
  delete lock.resolved[uri];
  lock.resolved_at = new Date().toISOString();
  saveLock(lock);

  console.log(`${C.g}✓${C.reset} Uninstalled ${C.c}${uri}${C.reset}`);
}

async function cmdUpdate(args, flags) {
  const lock = loadLock();
  const uris = flags.all ? Object.keys(lock.resolved) : args;
  if (!uris.length) die('usage: dojo update <uri> or dojo update --all');
  for (const uri of uris) {
    console.log(`${C.dim}Updating ${uri}...${C.reset}`);
    await cmdInstall([uri], {});
  }
}

function cmdList(_args, flags) {
  const lock = loadLock();
  const entries = Object.entries(lock.resolved);
  if (flags.json) return json(lock);
  if (!entries.length) return console.log('No skills installed.');
  heading(`${entries.length} installed skill${entries.length === 1 ? '' : 's'}`);
  for (const [uri, ver] of entries) {
    console.log(`  ${C.c}${uri}${C.reset}  ${C.dim}${ver}${C.reset}`);
  }
}

async function cmdOutdated(_args, flags) {
  const lock = loadLock();
  const entries = Object.entries(lock.resolved);
  if (!entries.length) return console.log('No skills installed.');
  const client = makeClient();
  const outdated = [];
  for (const [uri, ver] of entries) {
    try {
      const data = await client.get(uri);
      const latest = data.skill?.version;
      if (latest && latest !== ver) {
        outdated.push({ uri, current: ver, latest });
      }
    } catch { /* skip */ }
  }
  if (flags.json) return json(outdated);
  if (!outdated.length) return console.log('All skills up to date.');
  heading('Outdated skills');
  for (const o of outdated) {
    console.log(`  ${C.c}${o.uri}${C.reset}  ${C.r}${o.current}${C.reset} → ${C.g}${o.latest}${C.reset}`);
  }
}

async function cmdBundle(args, flags) {
  if (!args.length) die('usage: dojo bundle <uri> [--loc <dir>] [--version <version>] [--dry-run]');

  let uri = args[0];
  let version = flags.version;
  const atIdx = uri.lastIndexOf('@');
  if (atIdx > 0) {
    version = version || uri.slice(atIdx + 1);
    uri = uri.slice(0, atIdx);
  }

  const bundle = await fetchBundle(uri, version, flags);
  const targetDir = bundleTargetDir(bundle.uri || uri, flags);

  if (!targetDir) {
    return json(bundle);
  }

  const summary = {
    uri: bundle.uri || uri,
    destination: targetDir,
    files: bundle.files?.length || 0,
    source: bundle.source?.origin || bundle.source?.source_path || 'registry'
  };

  if (flags['dry-run']) {
    if (flags.json) return json(summary);
    heading('Dry run - would bundle:');
    row('uri', summary.uri);
    row('destination', summary.destination);
    row('files', `${summary.files} file(s)`);
    for (const file of bundle.files || []) {
      console.log(`    ${C.dim}${file.kind}${C.reset}  ${file.path} (${file.size || 0} bytes)`);
    }
    return;
  }

  const fileCount = writeBundleFiles(bundle, targetDir);
  summary.written = fileCount;

  if (flags.json) return json(summary);

  console.log(`${C.g}✓${C.reset} Bundled ${C.c}${summary.uri}${C.reset} to ${C.c}${targetDir}${C.reset} (${fileCount} file${fileCount === 1 ? '' : 's'})`);
}

// ── Execution ───────────────────────────────────────────

async function cmdRun(args, flags) {
  if (!args.length) die('usage: dojo run <uri> [script-id] [--input JSON] [--env K=V]');
  const uri = args[0];
  const scriptId = args[1];
  const client = makeClient();

  let input = {};
  if (flags.input) {
    try { input = JSON.parse(flags.input); }
    catch { die('--input must be valid JSON'); }
  }

  // Merge --env flags
  if (flags.env) {
    const pairs = Array.isArray(flags.env) ? flags.env : [flags.env];
    for (const pair of pairs) {
      const eq = pair.indexOf('=');
      if (eq > 0) process.env[pair.slice(0, eq)] = pair.slice(eq + 1);
    }
  }

  if (flags['dry-run']) {
    const data = await client.get(uri);
    const s = data.skill;
    heading('Dry run');
    row('uri', s.uri);
    if (s.scripts?.length) {
      for (const sc of s.scripts) {
        row(`script:${sc.id}`, `${sc.lang} — ${sc.entry || 'inline'}`);
      }
    }
    return;
  }

  const result = await client.run(uri, input, scriptId);
  if (typeof result === 'string') {
    process.stdout.write(result);
  } else {
    json(result);
  }
}

// ── Authoring ───────────────────────────────────────────

function cmdInit(args, flags) {
  const name = args[0] || 'my-skill';
  const type = flags.type || 'skill';
  const parent = flags.parent || '';
  const dir = resolve(name);

  if (existsSync(dir) && readdirSync(dir).length) {
    die(`directory ${name} already exists and is not empty`);
  }

  mkdirSync(dir, { recursive: true });
  mkdirSync(join(dir, 'scripts'), { recursive: true });

  const manifest = {
    name,
    version: '0.1.0',
    uri: parent ? `${parent}/${name}` : name,
    type,
    context: `TODO: describe what ${name} does`,
    ...(parent ? { parent } : {}),
    tags: [],
    scripts: [],
    schema: {
      input: { type: 'object', properties: {} },
      output: { type: 'object', properties: {} }
    },
    author: '',
    license: 'MIT',
    created: new Date().toISOString(),
    updated: new Date().toISOString(),
    status: 'draft'
  };

  writeFileSync(join(dir, 'node.json'), JSON.stringify(manifest, null, 2) + '\n');
  writeFileSync(join(dir, 'SKILL.md'), `---
name: ${name}
description: TODO
license: MIT
---

# ${name}

TODO: describe this skill.

## Fast path

- TODO

## Workflow

1. TODO
`);

  console.log(`${C.g}✓${C.reset} Scaffolded ${C.c}${name}${C.reset} (${type})`);
  console.log(`  ${C.dim}${dir}${C.reset}`);
}

function cmdValidate(args, _flags) {
  const target = resolve(args[0] || '.');
  const targetIsFile = existsSync(target) && statSync(target).isFile();
  const dir = targetIsFile ? dirname(target) : target;
  const errors = [];
  const warnings = [];

  // Check manifest
  const manifestPath = targetIsFile
    ? target
    : existsSync(join(dir, 'node.json'))
      ? join(dir, 'node.json')
      : existsSync(join(dir, 'skill.json'))
        ? join(dir, 'skill.json')
        : null;

  if (!manifestPath) {
    die('No node.json or skill.json found');
  }

  let manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf-8'));
  } catch (e) {
    die(`Invalid JSON in ${basename(manifestPath)}: ${e.message}`);
  }

  if (!manifest.name) errors.push('missing "name"');
  if (!manifest.uri) errors.push('missing "uri"');
  if (!manifest.type) warnings.push('missing "type" — defaults to "skill"');
  if (!manifest.context) warnings.push('missing "context" — no description');
  if (!manifest.version) warnings.push('missing "version"');

  // Validate scripts reference existing files
  for (const s of manifest.scripts || []) {
    if (s.entry && !existsSync(join(dir, s.entry))) {
      errors.push(`script "${s.id}" entry not found: ${s.entry}`);
    }
  }

  // Check SKILL.md
  if (!existsSync(join(dir, 'SKILL.md'))) {
    warnings.push('no SKILL.md found');
  }

  if (errors.length) {
    heading('Errors');
    for (const e of errors) console.log(`  ${C.r}✗${C.reset} ${e}`);
  }
  if (warnings.length) {
    heading('Warnings');
    for (const w of warnings) console.log(`  ${C.y}!${C.reset} ${w}`);
  }
  if (!errors.length && !warnings.length) {
    console.log(`${C.g}✓${C.reset} ${manifestPath} is valid`);
  }
  if (errors.length) process.exit(1);
}

function cmdTest(args, flags) {
  const dir = resolve(args[0] || '.');
  const testDir = join(dir, 'tests');
  const testFiles = [];

  if (existsSync(testDir)) {
    for (const f of readdirSync(testDir)) {
      if (f.endsWith('.test.js') || f.endsWith('.test.mjs')) testFiles.push(join(testDir, f));
    }
  }
  // Also check root-level test files
  if (existsSync(dir)) {
    for (const f of readdirSync(dir)) {
      if ((f.endsWith('.test.js') || f.endsWith('.test.mjs')) && !f.startsWith('.')) {
        testFiles.push(join(dir, f));
      }
    }
  }

  if (!testFiles.length) die('No test files found');

  const caseFilter = flags.case;
  const nodeArgs = ['--test'];
  if (caseFilter) nodeArgs.push('--test-name-pattern', caseFilter);
  nodeArgs.push(...testFiles);

  console.log(`${C.dim}Running ${testFiles.length} test file(s)...${C.reset}`);
  const child = spawn('node', nodeArgs, { stdio: 'inherit', cwd: dir });
  child.on('close', code => process.exit(code || 0));
}

function cmdPack(args, _flags) {
  const dir = resolve(args[0] || '.');
  const manifestPath = existsSync(join(dir, 'node.json'))
    ? join(dir, 'node.json')
    : join(dir, 'skill.json');

  if (!existsSync(manifestPath)) die('No manifest found');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf-8'));
  const name = (manifest.uri || manifest.name || 'skill').replace(/\//g, '-');
  const ver = manifest.version || '0.0.0';
  const tarball = `${name}-${ver}.tar.gz`;

  try {
    execSync(`tar czf "${tarball}" --exclude=node_modules --exclude=.git -C "${dirname(dir)}" "${basename(dir)}"`, {
      stdio: 'inherit'
    });
    const stats = statSync(tarball);
    const hash = createHash('sha256').update(readFileSync(tarball)).digest('hex');
    console.log(`${C.g}✓${C.reset} Packed ${C.c}${tarball}${C.reset} (${stats.size} bytes, sha256:${hash.slice(0, 12)}...)`);
  } catch (e) {
    die(`pack failed: ${e.message}`);
  }
}

// ── Publishing ──────────────────────────────────────────

async function cmdPublish(args, flags) {
  const dir = resolve(args[0] || '.');
  const manifestPath = existsSync(join(dir, 'node.json'))
    ? join(dir, 'node.json')
    : join(dir, 'skill.json');

  if (!existsSync(manifestPath)) die('No manifest found');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf-8'));

  const client = makeClient();
  if (flags.registry) {
    client.registry = flags.registry;
    client.registryCandidates = [flags.registry];
  }

  console.log(`${C.dim}Publishing ${manifest.uri}@${manifest.version || '?'}...${C.reset}`);
  const result = await client.publish(manifest);
  console.log(`${C.g}✓${C.reset} Published ${C.c}${result.uri}${C.reset}@${result.version}`);
}

async function cmdYank(args, _flags) {
  if (!args.length) die('usage: dojo yank <uri>@<version>');
  const input = args[0];
  const atIdx = input.lastIndexOf('@');
  if (atIdx <= 0) die('version required: dojo yank <uri>@<version>');
  const uri = input.slice(0, atIdx);
  const version = input.slice(atIdx + 1);
  const client = makeClient();
  await client._fetch(`/v1/skills/${uri}`, {
    method: 'DELETE',
    body: { version },
    auth: true
  });
  console.log(`${C.g}✓${C.reset} Yanked ${C.c}${uri}${C.reset}@${version}`);
}

async function cmdDeprecate(args, flags) {
  if (!args.length) die('usage: dojo deprecate <uri> --message "..."');
  const client = makeClient();
  await client._fetch(`/v1/skills/${args[0]}`, {
    method: 'PATCH',
    body: { status: 'deprecated', deprecation_message: flags.message || 'Deprecated' },
    auth: true
  });
  console.log(`${C.g}✓${C.reset} Deprecated ${C.c}${args[0]}${C.reset}`);
}

// ── Configuration ───────────────────────────────────────

function cmdConfig(args, flags) {
  const sub = args[0];
  if (sub === 'list') {
    const cfg = loadConfig();
    if (flags.json) return json(cfg);
    heading('Configuration');
    for (const [k, v] of Object.entries(cfg)) {
      if (k === 'registries') {
        row('registries', '');
        for (const r of v) console.log(`    ${r.url} ${C.dim}(priority: ${r.priority || '-'})${C.reset}`);
      } else if (k === 'token') {
        row(k, '***');
      } else {
        row(k, typeof v === 'object' ? JSON.stringify(v) : v);
      }
    }
    return;
  }
  if (sub === 'set') {
    const key = args[1];
    const value = args[2];
    if (!key || !value) die('usage: dojo config set <key> <value>');
    const cfg = loadConfig();
    if (key === 'registry') {
      cfg.default_registry = value;
    } else if (key === 'token') {
      cfg.token = value;
    } else {
      cfg[key] = value;
    }
    saveConfig(cfg);
    console.log(`${C.g}✓${C.reset} Set ${key}`);
    return;
  }
  die('usage: dojo config <set|list>');
}

function cmdSecrets(args, _flags) {
  const sub = args[0];
  if (sub === 'list') {
    const secrets = loadSecrets();
    const keys = Object.keys(secrets);
    if (!keys.length) return console.log('No secrets stored.');
    heading(`${keys.length} secret${keys.length === 1 ? '' : 's'}`);
    for (const k of keys) {
      console.log(`  ${C.c}${k}${C.reset}`);
    }
    return;
  }
  if (sub === 'set') {
    const key = args[1];
    if (!key) die('usage: dojo secrets set <key>');
    // Read value from stdin or prompt
    const value = args[2] || process.env[key];
    if (!value) die('Provide value as third argument or set it in the environment');
    const secrets = loadSecrets();
    secrets[key] = value;
    saveSecrets(secrets);
    console.log(`${C.g}✓${C.reset} Stored secret ${C.c}${key}${C.reset}`);
    return;
  }
  die('usage: dojo secrets <set|list>');
}

// ── Registry management ─────────────────────────────────

function cmdRegistry(args, _flags) {
  const sub = args[0];
  const cfg = loadConfig();
  if (!cfg.registries) cfg.registries = [];

  if (sub === 'list') {
    if (!cfg.registries.length) return console.log('No registries configured (using defaults).');
    heading('Registries');
    for (const r of cfg.registries) {
      console.log(`  ${C.c}${r.url}${C.reset}  priority=${r.priority || '-'}`);
    }
    return;
  }
  if (sub === 'add') {
    const url = args[1];
    if (!url) die('usage: dojo registry add <url>');
    if (cfg.registries.some(r => r.url === url)) die('Registry already configured');
    cfg.registries.push({ url, priority: cfg.registries.length + 1 });
    saveConfig(cfg);
    console.log(`${C.g}✓${C.reset} Added registry ${C.c}${url}${C.reset}`);
    return;
  }
  if (sub === 'remove') {
    const url = args[1];
    if (!url) die('usage: dojo registry remove <url>');
    cfg.registries = cfg.registries.filter(r => r.url !== url);
    saveConfig(cfg);
    console.log(`${C.g}✓${C.reset} Removed registry ${C.c}${url}${C.reset}`);
    return;
  }
  die('usage: dojo registry <list|add|remove>');
}

async function cmdMirror(args, flags) {
  if (args[0] !== 'sync' || !flags.from) die('usage: dojo mirror sync --from <url>');
  console.log(`${C.dim}Syncing from ${flags.from}...${C.reset}`);
  const remote = new Dojo({ registry: flags.from });
  const local = makeClient();
  const root = await remote._fetch('/v1');
  for (const eco of root.ecosystems || []) {
    try {
      const tree = await remote.tree(eco.uri || eco, 10);
      console.log(`  ${C.dim}${eco.uri || eco}${C.reset}`);
      // Could publish each node, but for now just report
    } catch { /* skip */ }
  }
  console.log(`${C.g}✓${C.reset} Mirror sync complete (listing only — publish not yet automated)`);
}

// ── Utilities ───────────────────────────────────────────

async function cmdLink(args, _flags) {
  if (args.length < 2) die('usage: dojo link <from-uri> <to-uri>');
  console.log(`${C.y}!${C.reset} Link creation requires editing the source manifest.`);
  console.log(`  Add to ${C.c}${args[0]}${C.reset} node.json links array:`);
  console.log(`  { "uri": "${args[1]}", "context": "..." }`);
}

async function cmdDiff(args, flags) {
  if (args.length < 2) die('usage: dojo diff <uri>@v1 <uri>@v2');
  const client = makeClient();
  const parse = (s) => {
    const at = s.lastIndexOf('@');
    return at > 0 ? { uri: s.slice(0, at), version: s.slice(at + 1) } : { uri: s, version: null };
  };
  const a = parse(args[0]);
  const b = parse(args[1]);
  const [da, db] = await Promise.all([
    client.get(a.uri, a.version),
    client.get(b.uri, b.version)
  ]);
  if (flags.json) return json({ a: da.skill, b: db.skill });
  heading(`Diff: ${args[0]} vs ${args[1]}`);
  const keys = new Set([...Object.keys(da.skill || {}), ...Object.keys(db.skill || {})]);
  for (const k of [...keys].sort()) {
    const va = JSON.stringify(da.skill?.[k]);
    const vb = JSON.stringify(db.skill?.[k]);
    if (va !== vb) {
      console.log(`  ${C.y}${k}${C.reset}`);
      if (va) console.log(`    ${C.r}- ${va.slice(0, 120)}${C.reset}`);
      if (vb) console.log(`    ${C.g}+ ${vb.slice(0, 120)}${C.reset}`);
    }
  }
}

function cmdAudit(_args, flags) {
  const lock = loadLock();
  const entries = Object.entries(lock.resolved);
  if (!entries.length) return console.log('No skills installed.');
  heading('Security audit');
  let issues = 0;
  for (const [uri, ver] of entries) {
    const skillDir = join(SKILLS_DIR, ...uri.split('/'));
    const manifestPath = join(skillDir, 'skill.json');
    if (!existsSync(manifestPath)) {
      console.log(`  ${C.y}!${C.reset} ${uri} — no local manifest (orphaned lock entry)`);
      issues++;
      continue;
    }
    try {
      const m = JSON.parse(readFileSync(manifestPath, 'utf-8'));
      const scripts = m.scripts || [];
      for (const s of scripts) {
        if (s.inline) {
          console.log(`  ${C.y}!${C.reset} ${uri}:${s.id} — contains inline code`);
          issues++;
        }
        const envKeys = Object.entries(s.env || {}).filter(([, v]) => v.secret);
        if (envKeys.length) {
          console.log(`  ${C.dim}i${C.reset} ${uri}:${s.id} — requires secrets: ${envKeys.map(([k]) => k).join(', ')}`);
        }
      }
    } catch {
      console.log(`  ${C.r}✗${C.reset} ${uri} — corrupt manifest`);
      issues++;
    }
  }
  if (!issues) console.log(`  ${C.g}✓${C.reset} No issues found`);
}

function cmdCompletions(args, _flags) {
  const shell = args[0] || 'bash';
  const commands = [
    'search', 'resolve', 'tree', 'info',
    'learn', 'backlinks', 'graph', 'alias',
    'install', 'bundle', 'uninstall', 'update', 'list', 'outdated',
    'run',
    'init', 'validate', 'test', 'pack',
    'publish', 'yank', 'deprecate',
    'config', 'secrets',
    'registry', 'mirror',
    'link', 'diff', 'audit', 'completions',
    'help', 'version'
  ];

  if (shell === 'bash') {
    console.log(`# dojo bash completions — add to ~/.bashrc:
_dojo() {
  local cur=\${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -W "${commands.join(' ')}" -- "$cur") )
}
complete -F _dojo dojo`);
  } else if (shell === 'zsh') {
    console.log(`# dojo zsh completions — add to ~/.zshrc:
_dojo() {
  _arguments '1:command:(${commands.join(' ')})'
}
compdef _dojo dojo`);
  } else if (shell === 'fish') {
    for (const cmd of commands) {
      console.log(`complete -c dojo -n '__fish_use_subcommand' -a '${cmd}'`);
    }
  } else {
    die(`Unknown shell: ${shell}. Supported: bash, zsh, fish`);
  }
}

// ── Help / Version ──────────────────────────────────────

function cmdHelp() {
  console.log(`
${C.bold}dojo${C.reset} — CLI for the Dojo skill registry

${C.bold}Discovery${C.reset}
  search <query>             Full-text search
  resolve <need>             Natural language resolution
  tree <ecosystem>           View ecosystem tree
  info <uri>                 Detailed skill info

${C.bold}Knowledge${C.reset}
  learn <uri>                Read a node's knowledge
  backlinks <uri>            Incoming references
  graph <uri>                Local knowledge graph
  alias <name>               Resolve an alias

${C.bold}Installation${C.reset}
  install <uri>[@version]    Install a skill
  bundle <uri>               Export a portable skill bundle
  uninstall <uri>            Remove an installed skill
  update <uri>|--all         Update skills
  list                       List installed skills
  outdated                   Show available updates

${C.bold}Execution${C.reset}
  run <uri> [script-id]      Run a skill's script

${C.bold}Authoring${C.reset}
  init [name]                Scaffold a new skill
  validate [path]            Validate a manifest
  test [path]                Run skill tests
  pack [path]                Create distributable tarball

${C.bold}Publishing${C.reset}
  publish [path]             Publish to registry
  yank <uri>@<version>       Soft-delete a version
  deprecate <uri>            Mark deprecated

${C.bold}Configuration${C.reset}
  config set <key> <value>   Set config value
  config list                Show all config
  secrets set <key>          Store a secret
  secrets list               List secret keys

${C.bold}Registry${C.reset}
  registry list|add|remove   Manage registries
  mirror sync --from <url>   Sync a mirror

${C.bold}Utilities${C.reset}
  link <from> <to>           Create a cross-skill reference
  diff <uri>@v1 <uri>@v2     Compare versions
  audit                      Security audit installed skills
  completions <shell>        Generate shell completions

${C.bold}Flags${C.reset}
  --json                     Machine-readable JSON output
  --dry-run                  Preview without side effects
  --help, -h                 Show this help
  --version, -v              Show version
`);
}

// ─── Router ─────────────────────────────────────────────

const COMMANDS = {
  // Discovery
  search: cmdSearch,
  resolve: cmdResolve,
  tree: cmdTree,
  info: cmdInfo,
  // Knowledge
  learn: cmdLearn,
  backlinks: cmdBacklinks,
  graph: cmdGraph,
  alias: cmdAlias,
  // Installation
  install: cmdInstall,
  bundle: cmdBundle,
  uninstall: cmdUninstall,
  update: cmdUpdate,
  list: cmdList,
  outdated: cmdOutdated,
  // Execution
  run: cmdRun,
  // Authoring
  init: cmdInit,
  validate: cmdValidate,
  test: cmdTest,
  pack: cmdPack,
  // Publishing
  publish: cmdPublish,
  yank: cmdYank,
  deprecate: cmdDeprecate,
  // Configuration
  config: cmdConfig,
  secrets: cmdSecrets,
  // Registry
  registry: cmdRegistry,
  mirror: cmdMirror,
  // Utilities
  link: cmdLink,
  diff: cmdDiff,
  audit: cmdAudit,
  completions: cmdCompletions,
  // Meta
  help: cmdHelp,
  version: () => {
    const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf-8'));
    console.log(`dojo ${pkg.version}`);
  }
};

async function main() {
  const { args, flags } = parseArgs(process.argv.slice(2));

  if (flags.version || flags.v) return COMMANDS.version();
  if (flags.help || flags.h || !args.length) return cmdHelp();

  const command = args[0];
  const handler = COMMANDS[command];
  if (!handler) {
    die(`Unknown command: ${command}\nRun "dojo help" for usage.`);
  }

  try {
    await handler(args.slice(1), flags);
  } catch (e) {
    die(e.message);
  }
}

main();
