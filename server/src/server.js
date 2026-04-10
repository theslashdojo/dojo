import express from 'express';
import cors from 'cors';
import Fuse from 'fuse.js';
import { readFileSync, readdirSync, existsSync, statSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, extname, join, relative, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const DEFAULT_MANIFEST_DIRS = [
  resolve(__dirname, '../../nodes'),
  resolve(__dirname, '../../examples')
];

function getRegistryDirs(env = process.env) {
  const rawDirs = env.SKILLS_DIR || env.NODES_DIR || '';
  const explicitDirs = rawDirs
    .split(',')
    .map(dir => dir.trim())
    .filter(Boolean)
    .map(dir => resolve(dir));

  return explicitDirs.length ? explicitDirs : DEFAULT_MANIFEST_DIRS;
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function containsWikiTarget(text, uri) {
  if (!text || !uri) return false;
  const pattern = new RegExp(`\\[\\[${escapeRegExp(uri)}(?:#[^\\]|]+)?(?:\\|[^\\]]+)?\\]\\]`);
  return pattern.test(text);
}

const STOP_WORDS = new Set([
  'a', 'an', 'and', 'are', 'do', 'for', 'from', 'how', 'i', 'in',
  'is', 'it', 'like', 'my', 'of', 'on', 'or', 'the', 'to', 'use', 'with'
]);

const QUERY_SYNONYMS = {
  eth: ['ethereum', 'native'],
  ethereum: ['eth', 'evm'],
  tx: ['transaction'],
  transaction: ['tx', 'transfer', 'send'],
  transfer: ['send', 'transaction', 'pay'],
  send: ['transfer', 'broadcast', 'pay'],
  gas: ['fees', 'gwei'],
  docs: ['guide', 'knowledge', 'learn'],
  learn: ['guide', 'docs', 'knowledge']
};

const BUNDLE_INCLUDE_DIRS = new Set(['agents', 'references', 'scripts', 'tests']);
const BUNDLE_INCLUDE_FILES = new Set(['node.json', 'skill.json', 'SKILL.md', 'README.md']);
const BUNDLE_TEXT_EXTENSIONS = new Set(['.json', '.md', '.js', '.cjs', '.mjs', '.yaml', '.yml', '.sh', '.txt']);
const MAX_BUNDLE_FILE_BYTES = 128 * 1024;

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function tokenize(value) {
  return normalizeText(value)
    .split(/\s+/)
    .map(token => token.trim())
    .filter(token => token && !STOP_WORDS.has(token));
}

function buildQueryVariants(value) {
  const raw = String(value || '').trim();
  const normalized = normalizeText(raw);
  const tokens = tokenize(raw);
  const expanded = new Set(tokens);

  for (const token of tokens) {
    const singular = token.endsWith('s') && token.length > 3 ? token.slice(0, -1) : token;
    const plural = token.endsWith('s') ? token : `${token}s`;
    expanded.add(singular);
    if (plural.length <= 24) expanded.add(plural);
    for (const synonym of (QUERY_SYNONYMS[token] || [])) expanded.add(synonym);
    for (const synonym of (QUERY_SYNONYMS[singular] || [])) expanded.add(synonym);
  }

  return dedupeStrings([
    raw,
    normalized,
    Array.from(expanded).join(' ')
  ]).filter(Boolean);
}

function clipExcerpt(text, terms, maxLength = 220) {
  const source = String(text || '').replace(/\s+/g, ' ').trim();
  if (!source) return null;

  const lowered = source.toLowerCase();
  const hit = (terms || []).find(term => lowered.includes(term.toLowerCase()));
  if (!hit) {
    return source.length <= maxLength ? source : `${source.slice(0, maxLength - 3).trimEnd()}...`;
  }

  const index = lowered.indexOf(hit.toLowerCase());
  const start = Math.max(0, index - Math.floor(maxLength * 0.35));
  const end = Math.min(source.length, start + maxLength);
  const prefix = start > 0 ? '...' : '';
  const suffix = end < source.length ? '...' : '';
  return `${prefix}${source.slice(start, end).trim()}${suffix}`;
}

function roundScore(value) {
  return Math.round(Math.max(0, Math.min(1.5, value)) * 100) / 100;
}

function parseBooleanFlag(value) {
  if (value === undefined || value === null || value === '') return undefined;
  const normalized = normalizeText(value);
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return undefined;
}

function dedupeStrings(values) {
  return Array.from(new Set((values || []).filter(Boolean)));
}

function parseIntWithDefault(value, fallback) {
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseStringList(value) {
  if (Array.isArray(value)) {
    return dedupeStrings(value.flatMap(entry => parseStringList(entry)));
  }

  if (value === undefined || value === null || value === '') return [];

  return String(value)
    .split(',')
    .map(entry => entry.trim())
    .filter(Boolean);
}

function buildRouteMap(uri) {
  if (!uri) return {};

  return {
    skill: `/v1/skills/${uri}`,
    learn: `/v1/learn/${uri}`,
    graph: `/v1/graph/${uri}`,
    backlinks: `/v1/backlinks/${uri}`,
    bundle: `/v1/bundle/${uri}`
  };
}

function buildExecutionSummary(skill) {
  const scripts = Array.isArray(skill?.scripts) ? skill.scripts : [];
  const requiredEnv = [];
  const optionalEnv = [];
  const requiredInputFields = Array.isArray(skill?.schema?.input?.required)
    ? skill.schema.input.required
    : [];

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
    langs: dedupeStrings(scripts.map(script => script.lang)),
    runtimes: dedupeStrings(scripts.map(script => script.runtime)),
    packages: dedupeStrings(scripts.flatMap(script => script.packages || [])),
    required_env: dedupeStrings(requiredEnv),
    optional_env: dedupeStrings(optionalEnv),
    required_input_fields: dedupeStrings(requiredInputFields)
  };
}

function buildKnowledgeSummary(skill) {
  const sections = Array.isArray(skill?.sections) ? skill.sections : [];
  return {
    has_body: Boolean(skill?.body),
    section_count: sections.length,
    has_sections: sections.length > 0,
    has_aliases: Array.isArray(skill?.aliases) && skill.aliases.length > 0
  };
}

function buildFieldReasons(matches = []) {
  const labels = {
    context: 'matched context',
    info: 'matched info',
    tags: 'matched tag',
    triggers: 'matched trigger',
    aliases: 'matched alias',
    body: 'matched body',
    'sections.title': 'matched section title',
    'sections.body': 'matched section body',
    'sections.tags': 'matched section tag',
    'links.context': 'matched linked context',
    uri: 'matched uri'
  };

  return dedupeStrings(
    matches.map(match => labels[match.key]).filter(Boolean)
  );
}

function collectTextMatches(values, query, tokenSet) {
  const exact = [];
  const partial = [];

  for (const value of values || []) {
    const normalized = normalizeText(value);
    if (!normalized) continue;

    if (normalized === query) {
      exact.push(value);
      continue;
    }

    const hasTokenOverlap = tokenize(normalized).some(token => tokenSet.has(token));
    if (hasTokenOverlap || normalized.includes(query)) {
      partial.push(value);
    }
  }

  return { exact, partial };
}

function buildManualReasons(skill, query, tokenSet) {
  const reasons = [];

  if (normalizeText(skill.uri) === query) reasons.push('exact uri match');

  const aliasMatches = collectTextMatches(skill.aliases, query, tokenSet);
  if (aliasMatches.exact.length) reasons.push('exact alias match');
  else if (aliasMatches.partial.length) reasons.push('alias overlap');

  const triggerMatches = collectTextMatches(skill.triggers, query, tokenSet);
  if (triggerMatches.exact.length) reasons.push('exact trigger match');
  else if (triggerMatches.partial.length) reasons.push('trigger overlap');

  const tagMatches = collectTextMatches(skill.tags, query, tokenSet);
  if (tagMatches.exact.length) reasons.push('exact tag match');
  else if (tagMatches.partial.length) reasons.push('tag overlap');

  const sectionTitleMatches = collectTextMatches(
    (skill.sections || []).map(section => section.title),
    query,
    tokenSet
  );
  if (sectionTitleMatches.exact.length) reasons.push('exact section title match');

  return dedupeStrings(reasons);
}

function buildSkillEnvelope(skill, extra = {}) {
  return {
    ...skill,
    execution: buildExecutionSummary(skill),
    knowledge: buildKnowledgeSummary(skill),
    routes: buildRouteMap(skill?.uri),
    ...extra
  };
}

function classifyBundleFile(relativePath) {
  if (relativePath === 'node.json' || relativePath === 'skill.json') return 'manifest';
  if (relativePath === 'SKILL.md') return 'skill';
  if (relativePath === 'README.md') return 'doc';

  const [topLevel] = relativePath.split('/');
  if (topLevel === 'agents') return 'agent';
  if (topLevel === 'references') return 'reference';
  if (topLevel === 'scripts') return 'script';
  if (topLevel === 'tests') return 'test';
  return 'file';
}

function shouldTraverseBundleDir(relativePath) {
  if (!relativePath) return true;
  const topLevel = relativePath.split('/')[0];
  return BUNDLE_INCLUDE_DIRS.has(topLevel);
}

function shouldIncludeBundleFile(relativePath) {
  if (BUNDLE_INCLUDE_FILES.has(relativePath)) return true;
  const [topLevel] = relativePath.split('/');
  if (!BUNDLE_INCLUDE_DIRS.has(topLevel)) return false;
  return BUNDLE_TEXT_EXTENSIONS.has(extname(relativePath).toLowerCase());
}

function collectBundleFiles(sourceDir, relativeDir = '') {
  const files = [];
  const entries = readdirSync(sourceDir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = join(sourceDir, entry.name);
    const nextRelative = relativeDir ? `${relativeDir}/${entry.name}` : entry.name;

    if (entry.isDirectory()) {
      if (!shouldTraverseBundleDir(nextRelative)) continue;
      files.push(...collectBundleFiles(fullPath, nextRelative));
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

function scoreContextAffinity(skill, currentContext = []) {
  const contexts = Array.isArray(currentContext)
    ? currentContext.map(value => String(value || '').split('#')[0]).filter(Boolean)
    : [];

  if (!contexts.length || !skill?.uri) return 0;

  let affinity = 0;
  for (const uri of contexts) {
    if (skill.uri === uri) affinity = Math.max(affinity, 0.2);
    if (skill.uri.startsWith(`${uri}/`) || uri.startsWith(`${skill.uri}/`)) affinity = Math.max(affinity, 0.14);
    if (skill.parent === uri) affinity = Math.max(affinity, 0.12);
    if (skill.links?.some(link => link.uri === uri || link.uri?.startsWith(`${uri}#`))) affinity = Math.max(affinity, 0.1);
    if (skill.related?.some(related => related.uri === uri)) affinity = Math.max(affinity, 0.08);
    if (skill.uri.split('/')[0] === uri.split('/')[0]) affinity = Math.max(affinity, 0.04);
  }

  return affinity;
}

function buildSkillExcerpt(skill, query) {
  const terms = dedupeStrings(Array.isArray(query) ? query.flatMap(tokenize) : tokenize(query));

  const findRelevantText = (value) => {
    const normalized = normalizeText(value);
    return terms.some(term => normalized.includes(term));
  };

  for (const section of skill.sections || []) {
    if (findRelevantText(section.title) || findRelevantText(section.body) || (section.tags || []).some(findRelevantText)) {
      return clipExcerpt(section.body || section.title, terms);
    }
  }

  if (findRelevantText(skill.info)) return clipExcerpt(skill.info, terms);
  if (findRelevantText(skill.body)) return clipExcerpt(skill.body, terms);
  if (findRelevantText(skill.context)) return clipExcerpt(skill.context, terms);
  return clipExcerpt(skill.info || skill.context || skill.body, terms);
}

export class SkillStore {
  constructor(dir) {
    this.skills = new Map();
    this.sources = new Map();
    this.fuse = null;
    this.loadFromDisk(dir);
    this.buildIndex();
  }

  loadFromDisk(dir) {
    const dirs = Array.isArray(dir) ? dir : [dir];
    for (const entry of dirs) {
      if (!existsSync(entry)) continue;
      this.walkDir(entry, entry);
    }
  }

  walkDir(dir, rootDir = dir) {
    const entries = readdirSync(dir, { withFileTypes: true });
    const manifestEntry = entries.find(entry => entry.isFile() && entry.name === 'node.json')
      || entries.find(entry => entry.isFile() && entry.name === 'skill.json');

    if (manifestEntry) {
      const fullPath = join(dir, manifestEntry.name);
      try {
        const content = readFileSync(fullPath, 'utf-8');
        const skill = JSON.parse(content);
        if (skill.uri) {
          if (this.skills.has(skill.uri)) {
            console.warn(`Skipping duplicate uri ${skill.uri} from ${fullPath}`);
          } else {
            this.skills.set(skill.uri, skill);
            this.sources.set(skill.uri, {
              dir,
              rootDir,
              manifestFile: manifestEntry.name,
              sourcePath: relative(rootDir, dir).replace(/\\/g, '/')
            });
          }
        }
      } catch (error) {
        console.warn(`Failed to load ${fullPath}: ${error.message}`);
      }
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      this.walkDir(join(dir, entry.name), rootDir);
    }
  }

  buildIndex() {
    const skills = Array.from(this.skills.values()).filter(Boolean);

    this.fuse = new Fuse(skills, {
      keys: [
        { name: 'context', weight: 0.22 },
        { name: 'tags', weight: 0.18 },
        { name: 'triggers', weight: 0.14 },
        { name: 'aliases', weight: 0.14 },
        { name: 'info', weight: 0.1 },
        { name: 'body', weight: 0.08 },
        { name: 'sections.title', weight: 0.06 },
        { name: 'sections.body', weight: 0.04 },
        { name: 'sections.tags', weight: 0.02 },
        { name: 'links.context', weight: 0.01 },
        { name: 'uri', weight: 0.01 }
      ],
      threshold: 0.38,
      includeScore: true,
      includeMatches: true,
      ignoreLocation: true,
      minMatchCharLength: 2
    });
  }

  get(uri) {
    return this.skills.get(uri) || null;
  }

  getSource(uri) {
    return this.sources.get(uri) || null;
  }

  search(query, opts = {}) {
    const queryVariants = buildQueryVariants(query);
    const normalizedQuery = normalizeText(query);
    const tokenSet = new Set(dedupeStrings(queryVariants.flatMap(tokenize)));
    const mode = normalizeText(opts.mode) || 'all';
    const executableFilter = parseBooleanFlag(opts.executable);
    const candidates = new Map();

    const upsertCandidate = (skill, baseScore, matches = [], seedReasons = []) => {
      if (!skill?.uri) return;

      const existing = candidates.get(skill.uri);
      if (existing) {
        existing.baseScore = Math.max(existing.baseScore, baseScore);
        existing.matches.push(...matches);
        for (const reason of seedReasons) existing.seedReasons.add(reason);
        return;
      }

      candidates.set(skill.uri, {
        skill,
        baseScore,
        matches: [...matches],
        seedReasons: new Set(seedReasons)
      });
    };

    for (const variant of queryVariants) {
      for (const result of this.fuse.search(variant)) {
        const variantBoost = normalizeText(variant) === normalizedQuery ? 0 : 0.04;
        const baseScore = (1 - (result.score ?? 1)) + variantBoost;
        upsertCandidate(result.item, baseScore, result.matches || [], []);
      }
    }

    for (const skill of this.skills.values()) {
      const manualReasons = dedupeStrings(
        queryVariants.flatMap(variant => buildManualReasons(skill, normalizeText(variant), tokenSet))
      );
      if (!manualReasons.length) continue;

      let baseScore = 0.7;
      if (manualReasons.includes('exact uri match')) baseScore = 1.3;
      else if (manualReasons.includes('exact alias match')) baseScore = 1.15;
      else if (manualReasons.includes('exact trigger match')) baseScore = 1.05;
      else if (manualReasons.includes('exact tag match')) baseScore = 0.95;
      else if (manualReasons.includes('exact section title match')) baseScore = 0.9;

      upsertCandidate(skill, baseScore, [], manualReasons);
    }

    let results = Array.from(candidates.values()).map(candidate => {
      const execution = buildExecutionSummary(candidate.skill);
      const knowledge = buildKnowledgeSummary(candidate.skill);
      const excerpt = buildSkillExcerpt(candidate.skill, queryVariants);
      let score = candidate.baseScore;
      const seedReasons = Array.from(candidate.seedReasons);

      if (mode === 'do') {
        if (execution.can_execute) {
          if (candidate.skill.type === 'skill' || candidate.skill.type === 'sub') score += 0.22;
          else if (candidate.skill.type === 'standard') score += 0.06;
          else score += 0.02;
        } else {
          score -= 0.12;
        }
        if (candidate.skill.type === 'context') score -= 0.04;
        if (candidate.skill.type === 'ecosystem') score -= 0.06;
      } else if (mode === 'learn') {
        score += candidate.skill.type === 'context' ? 0.18 : 0;
        score += knowledge.has_body || knowledge.has_sections ? 0.08 : -0.04;
        if (execution.can_execute) score += 0.02;
      }

      if (seedReasons.includes('exact alias match')) score += 0.16;
      if (seedReasons.includes('exact trigger match')) score += 0.12;
      if (seedReasons.includes('exact tag match')) score += 0.08;
      if (seedReasons.includes('alias overlap')) score += 0.06;
      if (seedReasons.includes('trigger overlap')) score += 0.04;
      if (seedReasons.includes('tag overlap')) score += 0.02;
      if (seedReasons.includes('exact section title match')) score += 0.03;

      score += scoreContextAffinity(candidate.skill, opts.current_context);

      const reasons = dedupeStrings([
        ...seedReasons,
        ...buildFieldReasons(candidate.matches)
      ]).slice(0, 5);

      return buildSkillEnvelope(candidate.skill, {
        score: roundScore(score),
        reasons,
        excerpt
      });
    });

    if (opts.eco) {
      const ecoPrefix = `${opts.eco}/`;
      results = results.filter(result => result.uri === opts.eco || result.uri.startsWith(ecoPrefix));
    }

    if (opts.type) {
      results = results.filter(result => result.type === opts.type);
    }

    if (opts.tags) {
      const tags = String(opts.tags)
        .split(',')
        .map(tag => normalizeText(tag))
        .filter(Boolean);
      results = results.filter(result =>
        tags.some(tag => (result.tags || []).some(skillTag => normalizeText(skillTag) === tag))
      );
    }

    if (executableFilter !== undefined) {
      results = results.filter(result => result.execution.can_execute === executableFilter);
    }

    results.sort((left, right) => {
      if (right.score !== left.score) return right.score - left.score;
      return left.uri.localeCompare(right.uri);
    });

    const offset = parseIntWithDefault(opts.offset, 0);
    const limit = parseIntWithDefault(opts.limit, 20);

    return {
      results: results.slice(offset, offset + limit),
      total: results.length,
      query,
      query_variants: queryVariants,
      mode
    };
  }

  getAncestors(uri) {
    const ancestors = [];
    const parts = uri.split('/');

    for (let index = 1; index < parts.length; index += 1) {
      const parentUri = parts.slice(0, index).join('/');
      const parent = this.skills.get(parentUri);
      if (parent) {
        ancestors.push({
          uri: parentUri,
          context: parent.context,
          type: parent.type,
          routes: buildRouteMap(parentUri),
          execution: buildExecutionSummary(parent),
          knowledge: buildKnowledgeSummary(parent)
        });
      }
    }

    return ancestors;
  }

  getChildren(uri) {
    const children = [];

    for (const [key, skill] of this.skills) {
      if (skill?.parent === uri) {
        children.push({
          uri: key,
          context: skill.context,
          type: skill.type,
          routes: buildRouteMap(key),
          execution: buildExecutionSummary(skill),
          knowledge: buildKnowledgeSummary(skill)
        });
      }
    }

    return children.sort((left, right) => left.uri.localeCompare(right.uri));
  }

  getTree(ecosystem, maxDepth = 4) {
    const root = this.skills.get(ecosystem);
    if (!root) return null;
    return this.buildTree(root, 0, maxDepth);
  }

  buildTree(node, depth, maxDepth) {
    if (depth >= maxDepth) return buildSkillEnvelope(node, { skills: [] });
    const children = this.getChildren(node.uri);

    return buildSkillEnvelope(node, {
      skills: children.map(child => {
        const full = this.skills.get(child.uri);
        return full ? this.buildTree(full, depth + 1, maxDepth) : child;
      })
    });
  }

  publish(skill) {
    if (!skill || typeof skill !== 'object' || typeof skill.uri !== 'string' || !skill.uri) {
      return { error: 'Invalid node manifest', code: 400 };
    }

    if (this.skills.has(skill.uri)) {
      const existing = this.skills.get(skill.uri);
      if (existing.version === skill.version) {
        return { error: 'Version already exists', code: 409 };
      }
    }

    skill.updated = new Date().toISOString();
    if (!skill.created) skill.created = skill.updated;
    this.skills.set(skill.uri, skill);
    this.buildIndex();

    return { success: true };
  }

  list() {
    const ecosystems = [];

    for (const [uri, skill] of this.skills) {
      if (skill?.type !== 'ecosystem') continue;
      const children = this.getChildren(uri);
      ecosystems.push({
        uri,
        context: skill.context,
        standards: children.filter(child => child.type === 'standard').map(child => child.uri.split('/').pop()),
        node_count: this.countDescendants(uri),
        skill_count: this.countDescendants(uri),
        status: skill.status || 'draft',
        routes: buildRouteMap(uri)
      });
    }

    return ecosystems;
  }

  countDescendants(uri) {
    let count = 0;
    for (const key of this.skills.keys()) {
      if (key.startsWith(`${uri}/`)) count += 1;
    }
    return count;
  }

  getBacklinks(uri) {
    const backlinks = [];

    for (const [key, skill] of this.skills) {
      if (skill.links?.some(link => link.uri === uri || link.uri?.startsWith(`${uri}#`))) {
        backlinks.push({ from: key, type: 'link', context: skill.context });
      }

      if (skill.depends?.some(dep => dep.uri === uri)) {
        backlinks.push({ from: key, type: 'depends', context: skill.context });
      }

      if (skill.related?.some(related => related.uri === uri)) {
        backlinks.push({ from: key, type: 'related', context: skill.context });
      }

      if (containsWikiTarget(skill.body, uri)) {
        backlinks.push({ from: key, type: 'wiki-link', context: skill.context });
      }

      if (skill.sections?.some(section => containsWikiTarget(section.body, uri))) {
        backlinks.push({ from: key, type: 'wiki-link', context: skill.context });
      }
    }

    return backlinks;
  }

  getLocalGraph(uri, depth = 2) {
    const nodes = new Map();
    const edges = [];
    const visited = new Set();

    const walk = (currentUri, currentDepth) => {
      if (currentDepth > depth || visited.has(currentUri)) return;
      visited.add(currentUri);

      const skill = this.skills.get(currentUri);
      if (skill) {
        nodes.set(currentUri, { uri: currentUri, type: skill.type, context: skill.context });

        for (const link of skill.links || []) {
          edges.push({ from: currentUri, to: link.uri, type: 'link' });
          walk(link.uri.split('#')[0], currentDepth + 1);
        }

        for (const dep of skill.depends || []) {
          edges.push({ from: currentUri, to: dep.uri, type: 'depends' });
          walk(dep.uri, currentDepth + 1);
        }

        for (const related of skill.related || []) {
          edges.push({ from: currentUri, to: related.uri, type: related.relation });
          walk(related.uri, currentDepth + 1);
        }

        for (const child of this.getChildren(currentUri)) {
          edges.push({ from: currentUri, to: child.uri, type: 'parent' });
          nodes.set(child.uri, child);
        }
      }

      if (currentDepth === 0) {
        for (const backlink of this.getBacklinks(currentUri)) {
          edges.push({ from: backlink.from, to: currentUri, type: 'backlink' });
          const source = this.skills.get(backlink.from);
          if (source) {
            nodes.set(backlink.from, {
              uri: backlink.from,
              type: source.type,
              context: source.context
            });
          }
        }
      }
    };

    walk(uri, 0);

    return {
      center: uri,
      nodes: Array.from(nodes.values()),
      edges
    };
  }

  resolveByAlias(query) {
    const normalized = normalizeText(query);

    for (const skill of this.skills.values()) {
      if (normalizeText(skill.uri) === normalized) return skill;
      if (skill.aliases?.some(alias => normalizeText(alias) === normalized)) return skill;
    }

    const fallback = this.search(query, { limit: 1, mode: 'learn' });
    return fallback.results[0] || null;
  }

  findRelevantSections(skillOrUri, query, limit = 3) {
    const skill = typeof skillOrUri === 'string' ? this.get(skillOrUri) : skillOrUri;
    if (!skill?.sections?.length) return [];

    const normalizedQuery = normalizeText(query);
    const tokenSet = new Set(dedupeStrings(buildQueryVariants(query).flatMap(tokenize)));

    return skill.sections
      .map(section => {
        let score = 0;
        const reasons = [];
        const title = normalizeText(section.title);
        const body = normalizeText(section.body);
        const tags = (section.tags || []).map(tag => normalizeText(tag));

        if (title.includes(normalizedQuery) && normalizedQuery) {
          score += 3;
          reasons.push('title overlap');
        }

        if (body.includes(normalizedQuery) && normalizedQuery) {
          score += 2;
          reasons.push('body overlap');
        }

        const titleTokens = tokenize(section.title);
        const matchedTokens = titleTokens.filter(token => tokenSet.has(token));
        if (matchedTokens.length) {
          score += matchedTokens.length;
          reasons.push('title token match');
        }

        const matchedTags = tags.filter(tag => tokenSet.has(tag) || tag === normalizedQuery);
        if (matchedTags.length) {
          score += matchedTags.length * 2;
          reasons.push('tag match');
        }

        return {
          id: section.id,
          title: section.title,
          score,
          reasons: dedupeStrings(reasons)
        };
      })
      .filter(section => section.score > 0)
      .sort((left, right) => right.score - left.score || left.title.localeCompare(right.title))
      .slice(0, limit)
      .map(section => ({
        id: section.id,
        title: section.title,
        reasons: section.reasons
      }));
  }
}

function buildReadingPath(store, skill) {
  const readingPath = [];

  for (const section of skill.sections || []) {
    readingPath.push({
      uri: `${skill.uri}#${section.id}`,
      title: section.title,
      type: 'section',
      why: `Read ${section.title} before moving on`,
      route: `/v1/learn/${skill.uri}?section=${section.id}`
    });
  }

  for (const link of skill.links || []) {
    const target = store.get(link.uri.split('#')[0]);
    if (!target) continue;

    const targetExecution = buildExecutionSummary(target);
    readingPath.push({
      uri: link.uri,
      title: target.context,
      type: targetExecution.can_execute ? 'then_do' : 'read_next',
      why: link.context || target.context,
      routes: buildRouteMap(target.uri)
    });
  }

  return readingPath;
}

function buildLearnPayload(store, skill, sectionId, question) {
  const result = {
    node: {
      uri: skill.uri,
      type: skill.type,
      context: skill.context,
      info: skill.info,
      body: skill.body || null,
      sections: skill.sections || [],
      content_type: skill.content_type || null,
      aliases: skill.aliases || [],
      frontmatter: skill.frontmatter || null,
      routes: buildRouteMap(skill.uri)
    },
    execution: buildExecutionSummary(skill),
    knowledge: buildKnowledgeSummary(skill),
    backlinks: store.getBacklinks(skill.uri),
    related: skill.related || [],
    links: skill.links || [],
    ancestors: store.getAncestors(skill.uri),
    children: store.getChildren(skill.uri),
    reading_path: buildReadingPath(store, skill)
  };

  if (sectionId && skill.sections) {
    const section = skill.sections.find(entry => entry.id === sectionId);
    if (section) result.focused_section = section;
  }

  if (question) {
    result.relevant_sections = store.findRelevantSections(skill, question, 5);
  }

  return result;
}

function buildBundlePayload(store, skill) {
  const source = store.getSource(skill.uri);
  if (!source) return null;

  const files = collectBundleFiles(source.dir);

  return {
    uri: skill.uri,
    routes: buildRouteMap(skill.uri),
    manifest: buildSkillEnvelope(skill),
    source: {
      source_path: source.sourcePath || '.',
      manifest_file: source.manifestFile
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

function buildDiscoverLearnEntry(store, result, question) {
  const full = store.get(result.uri);
  return {
    uri: result.uri,
    type: result.type,
    context: result.context,
    reasons: result.reasons,
    excerpt: result.excerpt,
    routes: result.routes,
    knowledge: result.knowledge,
    execution: result.execution,
    sections: store.findRelevantSections(full, question, 4),
    reading_path: full ? buildReadingPath(store, full).slice(0, 6) : []
  };
}

function buildDiscoverDoEntry(store, result, query) {
  const full = store.get(result.uri);
  return {
    uri: result.uri,
    type: result.type,
    context: result.context,
    reasons: result.reasons,
    excerpt: result.excerpt,
    routes: result.routes,
    execution: result.execution,
    knowledge: result.knowledge,
    required_input_fields: result.execution.required_input_fields,
    install: `dojo install ${result.uri}`,
    learn: `dojo learn ${result.uri}`,
    bundle: buildRouteMap(result.uri).bundle,
    preview_sections: store.findRelevantSections(full, query, 2)
  };
}

function buildDiscoveryPayload(store, query, options = {}) {
  const limit = parseIntWithDefault(options.limit, 5);
  const currentContext = parseStringList(options.current_context);
  const all = store.search(query, {
    limit: Math.max(limit * 2, 8),
    mode: 'all',
    current_context: currentContext
  });
  const learn = store.search(query, {
    limit,
    mode: 'learn',
    current_context: currentContext
  });
  let action = store.search(query, {
    limit,
    mode: 'do',
    executable: true,
    current_context: currentContext
  });

  if (!action.results.length) {
    action = store.search(query, {
      limit,
      mode: 'do',
      current_context: currentContext
    });
  }

  const bestMatch = all.results[0] || learn.results[0] || action.results[0] || null;

  return {
    query,
    current_context: currentContext,
    query_variants: all.query_variants,
    best_match: bestMatch ? buildSkillEnvelope(store.get(bestMatch.uri), {
      score: bestMatch.score,
      reasons: bestMatch.reasons,
      excerpt: bestMatch.excerpt
    }) : null,
    learn_first: learn.results.map(result => buildDiscoverLearnEntry(store, result, query)),
    then_do: action.results.map(result => buildDiscoverDoEntry(store, result, query)),
    alternatives: all.results.slice(0, limit).map(result => ({
      uri: result.uri,
      type: result.type,
      context: result.context,
      reasons: result.reasons,
      excerpt: result.excerpt,
      routes: result.routes
    }))
  };
}

function collectFollowUpSkills(store, answerNodes, searchResults, limit = 3) {
  const followUps = new Map();

  const pushFollowUp = (skill, reason) => {
    if (!skill) return;
    const execution = buildExecutionSummary(skill);
    if (!execution.can_execute) return;
    if (followUps.has(skill.uri)) return;

    followUps.set(skill.uri, {
      uri: skill.uri,
      type: skill.type,
      reason,
      execution
    });
  };

  for (const answerNode of answerNodes) {
    const full = store.get(answerNode.uri);
    for (const link of full?.links || []) {
      pushFollowUp(store.get(link.uri.split('#')[0]), link.context || full.context);
    }

    for (const child of store.getChildren(answerNode.uri)) {
      pushFollowUp(store.get(child.uri), `child node of ${answerNode.uri}`);
    }
  }

  for (const result of searchResults.results) {
    pushFollowUp(store.get(result.uri), result.excerpt || result.context);
    if (followUps.size >= limit) break;
  }

  return Array.from(followUps.values()).slice(0, limit);
}

export function createApp(options = {}) {
  const app = express();
  const store = options.store || new SkillStore(options.registryDirs || getRegistryDirs());
  const shouldServeStatic = options.serveStatic !== false;

  app.use(cors());
  app.use(express.json({ limit: '5mb' }));

  if (shouldServeStatic) {
    app.use(express.static(join(__dirname, '../../web/dist')));
  }

  app.get('/v1/resolve', (req, res) => {
    const { need, eco, tags, type, limit, offset, mode, executable } = req.query;
    if (!need) return res.status(400).json({ error: 'need parameter required' });

    const start = Date.now();
    const effectiveMode = mode || 'do';
    const effectiveExecutable = executable !== undefined
      ? executable
      : (effectiveMode === 'do' && !type ? 'true' : undefined);
    const results = store.search(need, {
      eco,
      tags,
      type,
      limit: limit || 5,
      offset,
      mode: effectiveMode,
      executable: effectiveExecutable
    });

    res.json({
      results: results.results.map(result => ({
        uri: result.uri,
        score: result.score,
        context: result.context,
        type: result.type,
        reasons: result.reasons,
        excerpt: result.excerpt,
        execution: result.execution,
        knowledge: result.knowledge,
        routes: result.routes,
        skill: result
      })),
      total: results.total,
      query_variants: results.query_variants,
      mode: results.mode,
      resolved_in_ms: Date.now() - start
    });
  });

  app.get('/v1/discover', (req, res) => {
    const query = req.query.q || req.query.need || req.query.question;
    if (!query) return res.status(400).json({ error: 'q, need, or question parameter required' });

    const payload = buildDiscoveryPayload(store, query, {
      limit: req.query.limit,
      current_context: req.query.current_context
    });

    res.json(payload);
  });

  app.get('/v1/skills/*', (req, res) => {
    const uri = req.params[0];
    const skill = store.get(uri);
    if (!skill) return res.status(404).json({ error: 'Node not found' });

    res.json({
      skill: buildSkillEnvelope(skill),
      ancestors: store.getAncestors(uri),
      children: store.getChildren(uri),
      execution: buildExecutionSummary(skill),
      knowledge: buildKnowledgeSummary(skill),
      routes: buildRouteMap(uri)
    });
  });

  app.get('/v1/search', (req, res) => {
    const { q, eco, type, tags, limit, offset, mode, executable } = req.query;
    if (!q) return res.status(400).json({ error: 'q parameter required' });

    const results = store.search(q, { eco, type, tags, limit, offset, mode, executable });
    res.json(results);
  });

  app.get('/v1/ecosystems', (req, res) => {
    const ecosystems = store.list().sort((left, right) => {
      if (left.uri === 'dojo') return -1;
      if (right.uri === 'dojo') return 1;
      return left.uri.localeCompare(right.uri);
    });
    res.json({ ecosystems });
  });

  app.get('/v1/tree/:ecosystem', (req, res) => {
    const { ecosystem } = req.params;
    const depth = parseIntWithDefault(req.query.depth, 4);
    const tree = store.getTree(ecosystem, depth);
    if (!tree) return res.status(404).json({ error: 'Ecosystem not found' });
    res.json(tree);
  });

  app.post('/v1/agent/ask', (req, res) => {
    const { message, agent_context } = req.body;
    if (!message) return res.status(400).json({ error: 'message required' });

    let results = store.search(message, {
      limit: 5,
      mode: 'do',
      executable: true
    });

    if (!results.results.length) {
      results = store.search(message, {
        limit: 5,
        mode: 'do'
      });
    }

    if (!results.results.length) {
      return res.json({
        recommendation: null,
        explanation: 'No matching nodes found.',
        alternatives: []
      });
    }

    const top = results.results[0];
    const skill = store.get(top.uri);
    const execution = buildExecutionSummary(skill);
    const hasEnv = agent_context?.has_env || [];
    const missingEnv = execution.required_env.filter(envKey => !hasEnv.includes(envKey));
    const inputSchema = skill?.schema?.input || null;
    const requiredInputFields = Array.isArray(inputSchema?.required) ? inputSchema.required : [];

    res.json({
      recommendation: top.uri,
      recommendation_node: {
        uri: top.uri,
        type: top.type,
        context: top.context,
        score: top.score,
        reasons: top.reasons,
        excerpt: top.excerpt,
        execution,
        routes: buildRouteMap(top.uri)
      },
      explanation: top.excerpt || `${top.context}. ${top.reasons.join(', ') || 'Strong semantic match'}.`,
      install: `dojo install ${top.uri}`,
      learn: `dojo learn ${top.uri}`,
      skill,
      missing_env: missingEnv,
      ready: missingEnv.length === 0,
      required_input_fields: requiredInputFields,
      alternatives: results.results.slice(1, 4).map(result => ({
        uri: result.uri,
        type: result.type,
        reason: result.excerpt || result.context,
        reasons: result.reasons,
        execution: result.execution,
        routes: result.routes
      }))
    });
  });

  app.post('/v1/agent/learn', (req, res) => {
    const { question, current_context = [] } = req.body;
    if (!question) return res.status(400).json({ error: 'question required' });

    const results = store.search(question, {
      limit: 10,
      mode: 'learn',
      current_context
    });

    const answerPool = results.results.filter(result =>
      result.type === 'context' || result.knowledge.has_body || result.knowledge.has_sections
    );
    const answerCandidates = (answerPool.length ? answerPool : results.results).slice(0, 3);
    const answerNodes = answerCandidates.map(result => {
      const full = store.get(result.uri);
      return {
        uri: result.uri,
        type: full?.type,
        relevance: result.score,
        context: result.context,
        reasons: result.reasons,
        excerpt: result.excerpt,
        routes: buildRouteMap(result.uri),
        sections: store.findRelevantSections(full, question),
        has_body: Boolean(full?.body)
      };
    });

    res.json({
      question,
      current_context,
      answer_nodes: answerNodes,
      then_do: collectFollowUpSkills(store, answerNodes, results),
      alternatives: results.results.slice(0, 5).map(result => ({
        uri: result.uri,
        type: result.type,
        context: result.context,
        reasons: result.reasons,
        excerpt: result.excerpt,
        routes: result.routes
      }))
    });
  });

  app.post('/v1/skills', (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ error: 'Authorization required' });

    const skill = req.body;
    const result = store.publish(skill);
    if (result.error) return res.status(result.code).json(result);

    res.status(201).json({ uri: skill.uri, version: skill.version });
  });

  app.get('/v1', (req, res) => {
    const ecosystems = store.list();
    res.json({
      registry: 'dojo',
      version: '0.1.0',
      ecosystems,
      total_nodes: store.skills.size,
      total_skills: Array.from(store.skills.values()).filter(skill =>
        buildExecutionSummary(skill).can_execute
      ).length,
      routes: {
        resolve: '/v1/resolve',
        search: '/v1/search',
        discover: '/v1/discover',
        ecosystems: '/v1/ecosystems',
        tree: '/v1/tree/:ecosystem',
        skill: '/v1/skills/*',
        learn: '/v1/learn/*',
        graph: '/v1/graph/*',
        backlinks: '/v1/backlinks/*',
        alias: '/v1/alias/:alias',
        bundle: '/v1/bundle/*',
        agent_ask: '/v1/agent/ask',
        agent_learn: '/v1/agent/learn',
        publish: '/v1/skills'
      },
      updated: new Date().toISOString()
    });
  });

  app.get('/v1/learn/*', (req, res) => {
    const uri = req.params[0];
    const [baseUri, inlineSectionId] = uri.split('#');
    const sectionId = typeof req.query.section === 'string' && req.query.section
      ? req.query.section
      : inlineSectionId;
    const question = typeof req.query.question === 'string' && req.query.question
      ? req.query.question
      : undefined;
    const skill = store.get(baseUri);
    if (!skill) return res.status(404).json({ error: 'Node not found' });

    res.json(buildLearnPayload(store, skill, sectionId, question));
  });

  app.get('/v1/backlinks/*', (req, res) => {
    const uri = req.params[0];
    if (!store.get(uri)) return res.status(404).json({ error: 'Node not found' });
    res.json({ uri, backlinks: store.getBacklinks(uri) });
  });

  app.get('/v1/graph/*', (req, res) => {
    const uri = req.params[0];
    const depth = parseIntWithDefault(req.query.depth, 2);
    if (!store.get(uri)) return res.status(404).json({ error: 'Node not found' });
    res.json(store.getLocalGraph(uri, depth));
  });

  app.get('/v1/alias/:alias', (req, res) => {
    const skill = store.resolveByAlias(req.params.alias);
    if (!skill) return res.status(404).json({ error: 'No node with that alias' });
    res.json({
      uri: skill.uri,
      context: skill.context,
      type: skill.type,
      routes: buildRouteMap(skill.uri)
    });
  });

  app.get('/v1/bundle/*', (req, res) => {
    const uri = req.params[0];
    const skill = store.get(uri);
    if (!skill) return res.status(404).json({ error: 'Node not found' });

    const bundle = buildBundlePayload(store, skill);
    if (!bundle) return res.status(404).json({ error: 'Bundle not available for node' });

    res.json(bundle);
  });

  if (shouldServeStatic) {
    app.get('*', (req, res) => {
      res.sendFile(resolve(__dirname, '../../web/dist/index.html'));
    });
  }

  return { app, store };
}

export function startServer(options = {}) {
  const port = options.port || process.env.PORT || 3000;
  const registryDirs = options.registryDirs || getRegistryDirs();
  const store = options.store || new SkillStore(registryDirs);
  const { app } = createApp({ ...options, registryDirs, store });

  console.log(`Loaded ${store.skills.size} nodes from ${registryDirs.join(', ')}`);

  const server = app.listen(port, () => {
    console.log(`Dojo registry running at http://localhost:${port}`);
    console.log(`API docs: http://localhost:${port}/v1`);
  });

  return { app, store, server };
}

if (process.argv[1] && resolve(process.argv[1]) === __filename) {
  startServer();
}
