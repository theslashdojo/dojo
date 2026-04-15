/**
 * slashdojo — Agent-facing client for the Dojo registry.
 *
 * Usage:
 *   import { Dojo } from 'slashdojo';
 *   const hub = new Dojo();
 *   const skill = await hub.need('deploy a contract to Base');
 *   const result = await hub.run(skill, { contract_source: '...', chain: 'base' });
 */

const DEFAULT_REGISTRY = 'https://slashdojo.com';
const LOCAL_FALLBACK_REGISTRY = 'http://localhost:3000';

function dedupe(values = []) {
  return Array.from(new Set(values.filter(Boolean)));
}

function toKebabCase(value) {
  return String(value).replace(/_/g, '-');
}

function safeRelativePath(value) {
  const normalized = String(value || '').replace(/\\/g, '/').replace(/^\.\//, '');
  if (!normalized || normalized.startsWith('/') || normalized.split('/').includes('..')) {
    throw new Error(`Unsafe bundle path: ${value}`);
  }
  return normalized;
}

function scalarEnv(input = {}) {
  const env = {};
  for (const [key, value] of Object.entries(input)) {
    if (['args', 'argv'].includes(key)) continue;
    if (['string', 'number', 'boolean'].includes(typeof value)) {
      env[key] = String(value);
    }
  }
  return env;
}

export class Dojo {
  constructor(opts = {}) {
    const explicitRegistries = dedupe([
      opts.registry,
      ...(opts.registries || []),
      process.env.DOJO_REGISTRY
    ]);
    this.registryCandidates = explicitRegistries.length
      ? explicitRegistries
      : [DEFAULT_REGISTRY, LOCAL_FALLBACK_REGISTRY];
    this.registry = this.registryCandidates[0];
    this.token = opts.token || process.env.DOJO_TOKEN || null;
    this.cache = new Map();
    this.capabilities = opts.capabilities || [];
    this.envKeys = opts.envKeys || Object.keys(process.env);
  }

  // ─── Core: "I need X" ────────────────────────────────

  /**
   * Describe what you need in natural language. Returns the best matching skill.
   * This is the primary method agents should call.
   *
   * @param {string} description - What capability you need
   * @param {object} opts - Optional filters: { tags, type, limit }
   * @returns {Promise<Skill|null>}
   */
  async need(description, opts = {}) {
    const params = new URLSearchParams({ need: description });
    if (opts.tags) params.set('tags', Array.isArray(opts.tags) ? opts.tags.join(',') : opts.tags);
    if (opts.type) params.set('type', opts.type);
    params.set('mode', opts.mode || 'do');
    params.set('executable', String(opts.executable ?? !opts.type));
    params.set('limit', String(opts.limit || 3));

    const data = await this._fetch(`/v1/resolve?${params}`);
    if (!data.results?.length) return null;

    const best = data.results[0];
    return this._enrichSkill(best.skill || best);
  }

  /**
   * Ask the registry for a recommendation with full context.
   * Returns the recommendation, missing env vars, and alternatives.
   *
   * @param {string} message - Natural language request
   * @returns {Promise<Recommendation>}
   */
  async ask(message) {
    const data = await this._fetch('/v1/agent/ask', {
      method: 'POST',
      body: {
        message,
        agent_context: {
          capabilities: this.capabilities,
          has_env: this.envKeys
        }
      }
    });
    return data;
  }

  // ─── Retrieval ───────────────────────────────────────

  /**
   * Get a skill by its URI.
   * @param {string} uri - e.g. "openai/chat"
   * @param {string} [version] - Optional version or range
   * @returns {Promise<SkillWithContext>}
   */
  async get(uri, version) {
    const cacheKey = `${uri}@${version || 'latest'}`;
    if (this.cache.has(cacheKey)) return this.cache.get(cacheKey);

    const params = version ? `?version=${version}` : '';
    const data = await this._fetch(`/v1/skills/${uri}${params}`);

    const result = {
      skill: this._enrichSkill(data.skill),
      ancestors: data.ancestors || [],
      children: data.children || []
    };

    this.cache.set(cacheKey, result);
    return result;
  }

  /**
   * Search for skills by query string.
   * @param {string} query
   * @param {object} opts - { eco, type, tags, limit, offset }
   * @returns {Promise<SearchResults>}
   */
  async search(query, opts = {}) {
    const params = new URLSearchParams({ q: query });
    for (const [k, v] of Object.entries(opts)) {
      if (v != null) params.set(k, String(v));
    }
    return this._fetch(`/v1/search?${params}`);
  }

  /**
   * Get the full tree for an ecosystem.
   * @param {string} ecosystem - e.g. "openai"
   * @param {number} [depth=4]
   * @returns {Promise<Skill>}
   */
  async tree(ecosystem, depth = 4) {
    return this._fetch(`/v1/tree/${ecosystem}?depth=${depth}`);
  }

  // ─── Execution ───────────────────────────────────────

  /**
   * Execute a skill's script. Resolves the skill, finds the script,
   * checks env requirements, and runs it.
   *
   * @param {Skill|string} skillOrUri - Skill object or URI string
   * @param {object} input - Input matching the skill's schema
   * @param {string} [scriptId] - Specific script to run (defaults to first)
   * @returns {Promise<any>}
   */
  async run(skillOrUri, input = {}, scriptId) {
    const skill = typeof skillOrUri === 'string'
      ? (await this.get(skillOrUri)).skill
      : skillOrUri;

    if (!skill.scripts?.length) {
      throw new Error(`Skill ${skill.uri} has no executable scripts`);
    }

    const script = scriptId
      ? skill.scripts.find(s => s.id === scriptId)
      : skill.scripts[0];

    if (!script) {
      throw new Error(`Script "${scriptId}" not found in ${skill.uri}`);
    }

    // Check env requirements
    const missing = this._checkEnv(script, input);
    if (missing.length) {
      throw new Error(
        `Missing required environment variables for ${script.id}: ${missing.join(', ')}`
      );
    }

    // Execute based on language
    return this._execute(script, input, { skill });
  }

  /**
   * Check what env vars are missing for a skill.
   * @param {Skill} skill
   * @returns {{ script: string, missing: string[] }[]}
   */
  checkRequirements(skill) {
    return (skill.scripts || []).map(script => ({
      script: script.id,
      missing: this._checkEnv(script),
      packages: script.packages || []
    })).filter(r => r.missing.length > 0 || r.packages.length > 0);
  }

  // ─── Publishing ──────────────────────────────────────

  /**
   * Publish a skill to the registry.
   * @param {Skill} skill - Full node manifest
   * @returns {Promise<{ uri: string, version: string }>}
   */
  async publish(skill) {
    if (!this.token) throw new Error('Auth token required for publishing');
    return this._fetch('/v1/skills', {
      method: 'POST',
      body: skill,
      auth: true
    });
  }

  // ─── Composition ─────────────────────────────────────

  /**
   * Resolve a skill and all its dependencies into a flat list.
   * @param {string} uri
   * @returns {Promise<Skill[]>}
   */
  async resolve(uri) {
    const { skill } = await this.get(uri);
    const resolved = [skill];
    const seen = new Set([uri]);

    const deps = skill.depends?.filter(d => !d.optional) || [];
    for (const dep of deps) {
      if (seen.has(dep.uri)) continue;
      seen.add(dep.uri);
      try {
        const depSkills = await this.resolve(dep.uri);
        resolved.push(...depSkills.filter(s => !seen.has(s.uri)));
        depSkills.forEach(s => seen.add(s.uri));
      } catch {
        // Optional deps that fail to resolve are skipped
      }
    }

    return resolved;
  }

  /**
   * Build a pipeline: resolve multiple skills and order by dependencies.
   * @param {string[]} uris - Skills to compose
   * @returns {Promise<Skill[]>} - Ordered execution plan
   */
  async pipeline(...uris) {
    const all = [];
    for (const uri of uris) {
      const skills = await this.resolve(uri);
      all.push(...skills);
    }
    // Deduplicate
    const seen = new Set();
    return all.filter(s => {
      if (seen.has(s.uri)) return false;
      seen.add(s.uri);
      return true;
    });
  }

  // ─── Internal ────────────────────────────────────────

  async _fetch(path, opts = {}) {
    if (path.startsWith('http')) {
      return this._fetchOne(path, opts);
    }

    const errors = [];
    for (const registry of this.registryCandidates) {
      const url = `${registry}${path}`;
      try {
        const data = await this._fetchOne(url, opts);
        this.registry = registry;
        return data;
      } catch (error) {
        errors.push(`${registry}: ${error.message}`);
      }
    }

    throw new Error(errors.join(' | '));
  }

  async _fetchOne(url, opts = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (opts.auth && this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const res = await fetch(url, {
      method: opts.method || 'GET',
      headers,
      body: opts.body ? JSON.stringify(opts.body) : undefined
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ message: `HTTP ${res.status}` }));
      throw new Error(err.message || err.error || `Registry error: ${res.status}`);
    }

    return res.json();
  }

  _enrichSkill(skill) {
    if (!skill) return null;
    // Add computed helpers
    skill._requirements = this.checkRequirements(skill);
    skill._ready = skill._requirements.every(r => r.missing.length === 0);
    return skill;
  }

  _checkEnv(script, input = {}) {
    if (!script.env) return [];
    const hasInputValue = (key) => {
      const lower = key.toLowerCase();
      const camel = lower.replace(/_([a-z])/g, (_, char) => char.toUpperCase());
      return input[key] != null || input[lower] != null || input[camel] != null;
    };

    return Object.entries(script.env)
      .filter(([key, meta]) => meta.required && !hasInputValue(key) && process.env[key] == null)
      .map(([key]) => key);
  }

  async _execute(script, input, context = {}) {
    if (script.lang === 'bash' && script.inline) {
      const { execSync } = await import('child_process');
      const result = execSync(script.inline, {
        env: { ...process.env, ...scalarEnv(input) },
        encoding: 'utf-8',
        timeout: 30000
      });
      return result;
    }

    if (['javascript', 'typescript'].includes(script.lang) && script.inline) {
      // Use the caller workspace so inline scripts can resolve local node_modules.
      const { writeFileSync, unlinkSync } = await import('fs');
      const { join } = await import('path');
      const { pathToFileURL } = await import('url');
      const tmpFile = join(process.cwd(), `.dojo_${script.id}_${Date.now()}.cjs`);

      try {
        writeFileSync(tmpFile, script.inline);
        const mod = await import(pathToFileURL(tmpFile).href);
        const fn = mod.default || mod[Object.keys(mod)[0]];
        if (typeof fn === 'function') return await fn(input);
        if (mod.default && typeof mod.default === 'object') {
          const exported = mod.default;
          const candidate = exported.default || exported[Object.keys(exported)[0]];
          if (typeof candidate === 'function') return await candidate(input);
          return exported;
        }
        return mod.default || mod;
      } finally {
        try { unlinkSync(tmpFile); } catch {}
      }
    }

    if (script.entry) {
      return this._executeEntry(script, input, context.skill);
    }

    throw new Error(`Execution not supported for lang: ${script.lang}`);
  }

  async _executeEntry(script, input = {}, skill) {
    if (!skill?.uri) {
      throw new Error(`Entry script ${script.id} requires a skill uri`);
    }

    const bundles = await this._fetchBundleChain(skill.uri);
    const { activeDir, cleanup } = await this._materializeBundles(bundles);

    try {
      const { join } = await import('path');
      const entryPath = join(activeDir, safeRelativePath(script.entry));
      const { existsSync } = await import('fs');
      if (!existsSync(entryPath)) {
        throw new Error(`Entry file not found in bundle: ${script.entry}`);
      }

      const command = this._entryCommand(script.lang);
      const args = this._entryArgs(script, input, skill);
      const output = await this._spawn(command, [entryPath, ...args], {
        cwd: activeDir,
        input,
        env: {
          ...process.env,
          ...scalarEnv(input),
          DOJO_INPUT: JSON.stringify(input)
        }
      });

      return this._parseExecutionOutput(output);
    } finally {
      cleanup();
    }
  }

  async _fetchBundleChain(uri) {
    const parts = uri.split('/').filter(Boolean);
    const candidates = [];

    for (let index = 2; index <= parts.length; index += 1) {
      candidates.push(parts.slice(0, index).join('/'));
    }

    const bundles = [];
    for (const candidate of candidates) {
      try {
        bundles.push(await this._fetch(`/v1/bundle/${candidate}`));
      } catch (error) {
        if (candidate === uri) throw error;
      }
    }

    return bundles;
  }

  async _materializeBundles(bundles) {
    const { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } = await import('fs');
    const { dirname, join } = await import('path');
    const { tmpdir } = await import('os');

    const root = mkdtempSync(join(tmpdir(), 'dojo-skill-'));
    let activeDir = root;

    try {
      for (const bundle of bundles) {
        const sourcePath = bundle.source?.source_path && bundle.source.source_path !== '.'
          ? safeRelativePath(bundle.source.source_path)
          : '';
        const bundleRoot = sourcePath ? join(root, sourcePath) : root;
        activeDir = bundleRoot;

        for (const file of bundle.files || []) {
          if (file.content == null) continue;

          const relativePath = safeRelativePath(file.path);
          const target = join(bundleRoot, relativePath);
          mkdirSync(dirname(target), { recursive: true });
          writeFileSync(target, file.content);

          if (relativePath.startsWith('scripts/') || file.content.startsWith('#!')) {
            try { chmodSync(target, 0o755); } catch {}
          }
        }
      }
    } catch (error) {
      rmSync(root, { recursive: true, force: true });
      throw error;
    }

    return {
      root,
      activeDir,
      cleanup: () => rmSync(root, { recursive: true, force: true })
    };
  }

  _entryCommand(lang) {
    if (lang === 'bash') return 'bash';
    if (['javascript', 'typescript'].includes(lang)) return process.execPath;
    if (lang === 'python') return process.env.PYTHON || 'python3';
    throw new Error(`Execution not supported for lang: ${lang}`);
  }

  _entryArgs(script, input = {}, skill = {}) {
    if (Array.isArray(input.argv)) return input.argv.map(String);
    if (Array.isArray(input.args)) return input.args.map(String);

    if (['javascript', 'typescript', 'python'].includes(script.lang)) {
      return ['--json', JSON.stringify(input)];
    }

    const args = [];
    const required = Array.isArray(skill.schema?.input?.required)
      ? skill.schema.input.required
      : [];
    const positional = required.find(key => input[key] != null);

    if (positional) args.push(String(input[positional]));

    for (const [key, value] of Object.entries(input)) {
      if (value == null || ['args', 'argv', positional].includes(key)) continue;
      const flag = key === 'tags' ? 'tag' : toKebabCase(key);

      if (value === true) {
        args.push(`--${flag}`);
      } else if (Array.isArray(value)) {
        args.push(`--${flag}`, value.join(','));
      } else if (value !== false) {
        args.push(`--${flag}`, String(value));
      }
    }

    return args;
  }

  async _spawn(command, args, { cwd, input, env }) {
    const { spawn } = await import('child_process');

    return new Promise((resolve, reject) => {
      const child = spawn(command, args, {
        cwd,
        env,
        stdio: ['pipe', 'pipe', 'pipe']
      });
      let stdout = '';
      let stderr = '';

      child.stdout.setEncoding('utf8');
      child.stderr.setEncoding('utf8');
      child.stdout.on('data', chunk => { stdout += chunk; });
      child.stderr.on('data', chunk => { stderr += chunk; });
      child.on('error', reject);
      child.on('close', code => {
        if (code === 0) return resolve(stdout);
        reject(new Error((stderr || stdout || `${command} exited with code ${code}`).trim()));
      });
      child.stdin.on('error', error => {
        if (error.code !== 'EPIPE') reject(error);
      });

      child.stdin.end(`${JSON.stringify(input || {})}\n`);
    });
  }

  _parseExecutionOutput(output) {
    const text = String(output || '').trim();
    if (!text) return '';
    try {
      return JSON.parse(text);
    } catch {
      return output;
    }
  }
}

// ─── Convenience export ────────────────────────────────

export function createClient(opts) {
  return new Dojo(opts);
}

export default Dojo;
