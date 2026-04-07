import express from 'express';
import cors from 'cors';
import Fuse from 'fuse.js';
import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

// Serve static files from the React app
app.use(express.static(join(__dirname, '../../web/dist')));

const PORT = process.env.PORT || 3000;
const SKILLS_DIR = process.env.SKILLS_DIR || resolve('./examples');

// ─── Skill Store ──────────────────────────────────────

class SkillStore {
  constructor(dir) {
    this.skills = new Map();
    this.fuse = null;
    this.loadFromDisk(dir);
    this.buildIndex();
  }

  loadFromDisk(dir) {
    if (!existsSync(dir)) return;
    this.walkDir(dir);
  }

  walkDir(dir) {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        this.walkDir(fullPath);
      } else if (entry.name === 'skill.json') {
        try {
          const content = readFileSync(fullPath, 'utf-8');
          const skill = JSON.parse(content);
          if (skill.uri) {
            this.skills.set(skill.uri, skill);
          }
        } catch (e) {
          console.warn(`Failed to load ${fullPath}: ${e.message}`);
        }
      }
    }
  }

  buildIndex() {
    const skills = Array.from(this.skills.entries())
      .filter(([uri, skill]) => typeof uri === 'string' && skill && typeof skill === 'object')
      .map(([, skill]) => skill);
    // Index long-form knowledge fields so search and agent learning can use them.
    this.fuse = new Fuse(skills, {
      keys: [
        { name: 'context', weight: 0.23 },
        { name: 'info', weight: 0.14 },
        { name: 'tags', weight: 0.16 },
        { name: 'triggers', weight: 0.1 },
        { name: 'aliases', weight: 0.14 },
        { name: 'body', weight: 0.1 },
        { name: 'sections.title', weight: 0.05 },
        { name: 'sections.body', weight: 0.04 },
        { name: 'sections.tags', weight: 0.02 },
        { name: 'links.context', weight: 0.01 },
        { name: 'uri', weight: 0.01 }
      ],
      threshold: 0.38,
      includeScore: true,
      ignoreLocation: true,
      minMatchCharLength: 2
    });
  }

  get(uri) {
    return this.skills.get(uri) || null;
  }

  search(query, opts = {}) {
    let results = this.fuse.search(query);

    if (opts.eco) {
      const ecoPrefix = `${opts.eco}/`;
      results = results.filter(r => r.item.uri === opts.eco || r.item.uri.startsWith(ecoPrefix));
    }
    if (opts.type) {
      results = results.filter(r => r.item.type === opts.type);
    }
    if (opts.tags) {
      const tags = opts.tags.split(',').map(t => t.trim()).filter(Boolean);
      results = results.filter(r =>
        tags.some(t => r.item.tags?.includes(t))
      );
    }

    const offset = parseInt(opts.offset) || 0;
    const limit = parseInt(opts.limit) || 20;

    return {
      results: results.slice(offset, offset + limit).map(r => ({
        ...r.item,
        score: Math.round((1 - r.score) * 100) / 100
      })),
      total: results.length
    };
  }

  getAncestors(uri) {
    const ancestors = [];
    const parts = uri.split('/');
    for (let i = 1; i < parts.length; i++) {
      const parentUri = parts.slice(0, i).join('/');
      const parent = this.skills.get(parentUri);
      if (parent) {
        ancestors.push({ uri: parentUri, context: parent.context, type: parent.type });
      }
    }
    return ancestors;
  }

  getChildren(uri) {
    const children = [];
    for (const [key, skill] of this.skills) {
      if (typeof key !== 'string' || !skill) continue;
      if (skill.parent === uri) {
        children.push({ uri: key, context: skill.context, type: skill.type });
      }
    }
    return children;
  }

  getTree(ecosystem, maxDepth = 4) {
    const root = this.skills.get(ecosystem);
    if (!root) return null;
    return this.buildTree(root, 0, maxDepth);
  }

  buildTree(node, depth, maxDepth) {
    if (depth >= maxDepth) return { ...node, skills: [] };
    const children = this.getChildren(node.uri);
    return {
      ...node,
      skills: children.map(c => {
        const full = this.skills.get(c.uri);
        return full ? this.buildTree(full, depth + 1, maxDepth) : c;
      })
    };
  }

  publish(skill) {
    if (!skill || typeof skill !== 'object' || typeof skill.uri !== 'string' || !skill.uri) {
      return { error: 'Invalid skill manifest', code: 400 };
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
      if (typeof uri !== 'string' || !skill) continue;
      if (skill.type === 'ecosystem') {
        const children = this.getChildren(uri);
        ecosystems.push({
          uri,
          context: skill.context,
          standards: children.filter(c => c.type === 'standard').map(c => c.uri.split('/').pop()),
          skill_count: this.countDescendants(uri),
          status: skill.status || 'draft'
        });
      }
    }
    return ecosystems;
  }

  countDescendants(uri) {
    if (typeof uri !== 'string' || !uri) return 0;
    let count = 0;
    for (const key of this.skills.keys()) {
      if (typeof key === 'string' && key.startsWith(uri + '/')) count++;
    }
    return count;
  }

  // ─── Knowledge Layer ────────────────────────────────

  getBacklinks(uri) {
    const backlinks = [];
    for (const [key, skill] of this.skills) {
      // Check links array
      if (skill.links?.some(l => l.uri === uri || l.uri.startsWith(uri + '#'))) {
        backlinks.push({ from: key, type: 'link', context: skill.context });
      }
      // Check depends
      if (skill.depends?.some(d => d.uri === uri)) {
        backlinks.push({ from: key, type: 'depends', context: skill.context });
      }
      // Check related
      if (skill.related?.some(r => r.uri === uri)) {
        backlinks.push({ from: key, type: 'related', context: skill.context });
      }
      // Check body for [[uri]] wiki-links
      if (skill.body?.includes(`[[${uri}]]`)) {
        backlinks.push({ from: key, type: 'wiki-link', context: skill.context });
      }
      // Check sections for wiki-links
      if (skill.sections?.some(s => s.body?.includes(`[[${uri}]]`))) {
        backlinks.push({ from: key, type: 'wiki-link', context: skill.context });
      }
    }
    return backlinks;
  }

  getLocalGraph(uri, depth = 2) {
    const nodes = new Map();
    const edges = [];
    const visited = new Set();

    const walk = (currentUri, d) => {
      if (d > depth || visited.has(currentUri)) return;
      visited.add(currentUri);

      const skill = this.skills.get(currentUri);
      if (skill) {
        nodes.set(currentUri, { uri: currentUri, type: skill.type, context: skill.context });

        // Outgoing links
        for (const link of (skill.links || [])) {
          edges.push({ from: currentUri, to: link.uri, type: 'link' });
          walk(link.uri.split('#')[0], d + 1);
        }
        // Dependencies
        for (const dep of (skill.depends || [])) {
          edges.push({ from: currentUri, to: dep.uri, type: 'depends' });
          walk(dep.uri, d + 1);
        }
        // Related
        for (const rel of (skill.related || [])) {
          edges.push({ from: currentUri, to: rel.uri, type: rel.relation });
          walk(rel.uri, d + 1);
        }
        // Children
        for (const child of this.getChildren(currentUri)) {
          edges.push({ from: currentUri, to: child.uri, type: 'parent' });
          nodes.set(child.uri, child);
        }
      }

      // Backlinks (only at depth 0 to avoid explosion)
      if (d === 0) {
        for (const bl of this.getBacklinks(currentUri)) {
          edges.push({ from: bl.from, to: currentUri, type: 'backlink' });
          const blSkill = this.skills.get(bl.from);
          if (blSkill) nodes.set(bl.from, { uri: bl.from, type: blSkill.type, context: blSkill.context });
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
    const q = query.toLowerCase();
    for (const [uri, skill] of this.skills) {
      if (skill.aliases?.some(a => a.toLowerCase() === q)) {
        return skill;
      }
    }
    return null;
  }
}

const store = new SkillStore(SKILLS_DIR);
console.log(`Loaded ${store.skills.size} skills from ${SKILLS_DIR}`);

// ─── Routes ───────────────────────────────────────────

// Resolve — primary agent endpoint
app.get('/v1/resolve', (req, res) => {
  const { need, tags, type, limit } = req.query;
  if (!need) return res.status(400).json({ error: 'need parameter required' });

  const start = Date.now();
  const results = store.search(need, { tags, type, limit: limit || 5 });

  res.json({
    results: results.results.map(r => ({
      uri: r.uri,
      score: r.score,
      context: r.context,
      skill: r
    })),
    total: results.total,
    resolved_in_ms: Date.now() - start
  });
});

// Get skill by URI
app.get('/v1/skills/*', (req, res) => {
  if (req.method === 'GET' && req.params[0]) {
    const uri = req.params[0];
    const skill = store.get(uri);
    if (!skill) return res.status(404).json({ error: 'Skill not found' });

    res.json({
      skill,
      ancestors: store.getAncestors(uri),
      children: store.getChildren(uri)
    });
  }
});

// Search
app.get('/v1/search', (req, res) => {
  const { q, eco, type, tags, limit, offset } = req.query;
  if (!q) return res.status(400).json({ error: 'q parameter required' });

  const results = store.search(q, { eco, type, tags, limit, offset });
  res.json(results);
});

// Ecosystems
app.get('/v1/ecosystems', (req, res) => {
  const ecosystems = store.list().sort((a, b) => {
    if (a.uri === 'dojo') return -1;
    if (b.uri === 'dojo') return 1;
    return a.uri.localeCompare(b.uri);
  });
  res.json({ ecosystems });
});

// Tree
app.get('/v1/tree/:ecosystem', (req, res) => {
  const { ecosystem } = req.params;
  const depth = parseInt(req.query.depth) || 4;
  const tree = store.getTree(ecosystem, depth);
  if (!tree) return res.status(404).json({ error: 'Ecosystem not found' });
  res.json(tree);
});

// Agent ask — simplified endpoint
app.post('/v1/agent/ask', (req, res) => {
  const { message, agent_context } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });

  const results = store.search(message, { limit: 5 });
  if (!results.results.length) {
    return res.json({
      recommendation: null,
      explanation: 'No matching skills found.',
      alternatives: []
    });
  }

  const top = results.results[0];
  const skill = store.get(top.uri);

  // Check env compatibility
  const allEnv = skill?.scripts?.flatMap(s =>
    Object.entries(s.env || {})
      .filter(([, v]) => v.required)
      .map(([k]) => k)
  ) || [];
  const hasEnv = agent_context?.has_env || [];
  const missingEnv = allEnv.filter(e => !hasEnv.includes(e));

  res.json({
    recommendation: top.uri,
    explanation: top.context,
    install: `dojo install ${top.uri}`,
    skill,
    missing_env: missingEnv,
    alternatives: results.results.slice(1, 4).map(r => ({
      uri: r.uri,
      reason: r.context
    }))
  });
});

// Publish
app.post('/v1/skills', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Authorization required' });

  const skill = req.body;
  const result = store.publish(skill);
  if (result.error) return res.status(result.code).json(result);

  res.status(201).json({ uri: skill.uri, version: skill.version });
});

// Registry index
app.get('/v1', (req, res) => {
  const ecosystems = store.list();
  res.json({
    registry: 'dojo',
    version: '0.1.0',
    ecosystems,
    total_skills: store.skills.size,
    updated: new Date().toISOString()
  });
});

// ─── Knowledge Layer Routes ───────────────────────────

// Learn — full knowledge payload for a node
app.get('/v1/learn/*', (req, res) => {
  const uri = req.params[0];
  const [baseUri, inlineSectionId] = uri.split('#');
  const sectionId = typeof req.query.section === 'string' && req.query.section
    ? req.query.section
    : inlineSectionId;
  const skill = store.get(baseUri);
  if (!skill) return res.status(404).json({ error: 'Node not found' });

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
      frontmatter: skill.frontmatter || null
    },
    backlinks: store.getBacklinks(baseUri),
    related: skill.related || [],
    links: skill.links || [],
    ancestors: store.getAncestors(baseUri),
    children: store.getChildren(baseUri)
  };

  // If a section was requested, extract it
  if (sectionId && skill.sections) {
    const section = skill.sections.find(s => s.id === sectionId);
    if (section) {
      result.focused_section = section;
    }
  }

  // Build a reading path from sections + outgoing links
  const readingPath = [];
  if (skill.sections?.length) {
    for (const s of skill.sections) {
      readingPath.push({ uri: `${baseUri}#${s.id}`, title: s.title, type: 'section' });
    }
  }
  if (skill.links?.length) {
    for (const link of skill.links) {
      const target = store.get(link.uri.split('#')[0]);
      if (target && (target.type === 'skill' || target.type === 'sub')) {
        readingPath.push({ uri: link.uri, title: target.context, type: 'then_do' });
      }
    }
  }
  result.reading_path = readingPath;

  res.json(result);
});

// Backlinks for a node
app.get('/v1/backlinks/*', (req, res) => {
  const uri = req.params[0];
  if (!store.get(uri)) return res.status(404).json({ error: 'Node not found' });
  res.json({ uri, backlinks: store.getBacklinks(uri) });
});

// Local knowledge graph
app.get('/v1/graph/*', (req, res) => {
  const uri = req.params[0];
  const depth = parseInt(req.query.depth) || 2;
  if (!store.get(uri)) return res.status(404).json({ error: 'Node not found' });
  res.json(store.getLocalGraph(uri, depth));
});

// Agent learn — natural language knowledge query
app.post('/v1/agent/learn', (req, res) => {
  const { question, current_context } = req.body;
  if (!question) return res.status(400).json({ error: 'question required' });

  // Search across all nodes including body/sections
  const results = store.search(question, { limit: 10 });

  // Prefer context nodes for learning
  const contextNodes = results.results.filter(r => r.type === 'context');
  const skillNodes = results.results.filter(r => r.type === 'skill' || r.type === 'sub');

  const answerNodes = (contextNodes.length ? contextNodes : results.results)
    .slice(0, 3)
    .map(r => {
      const full = store.get(r.uri);
      // Find relevant sections
      const relevantSections = (full?.sections || [])
        .filter(s => {
          const q = question.toLowerCase();
          return s.title.toLowerCase().includes(q) ||
            s.body?.toLowerCase().includes(q) ||
            s.tags?.some(t => q.includes(t));
        })
        .map(s => s.id);

      return {
        uri: r.uri,
        type: full?.type,
        relevance: r.score,
        context: r.context,
        sections: relevantSections.length ? relevantSections : undefined,
        has_body: !!full?.body
      };
    });

  // Suggest skills to execute after learning
  const thenDo = skillNodes.slice(0, 2).map(r => ({
    uri: r.uri,
    type: 'skill',
    reason: r.context
  }));

  res.json({ answer_nodes: answerNodes, then_do: thenDo });
});

// Alias lookup
app.get('/v1/alias/:alias', (req, res) => {
  const skill = store.resolveByAlias(req.params.alias);
  if (!skill) return res.status(404).json({ error: 'No node with that alias' });
  res.json({ uri: skill.uri, context: skill.context, type: skill.type });
});

// Catch-all to serve index.html for SPA routing
app.get('*', (req, res) => {
  res.sendFile(resolve(__dirname, '../../web/dist/index.html'));
});

// ─── Start ────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Dojo registry running at http://localhost:${PORT}`);
  console.log(`API docs: http://localhost:${PORT}/v1`);
});
