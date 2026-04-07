/**
 * @dojo/sdk — Agent-facing client for the Dojo registry.
 *
 * Usage:
 *   import { Dojo } from '@dojo/sdk';
 *   const hub = new Dojo();
 *   const skill = await hub.need('deploy a contract to Base');
 *   const result = await hub.run(skill, { contract_source: '...', chain: 'base' });
 */

const DEFAULT_REGISTRY = 'https://api.dojo.dev';

export class Dojo {
  constructor(opts = {}) {
    this.registry = opts.registry || process.env.DOJO_REGISTRY || DEFAULT_REGISTRY;
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
    const missing = this._checkEnv(script);
    if (missing.length) {
      throw new Error(
        `Missing required environment variables for ${script.id}: ${missing.join(', ')}`
      );
    }

    // Execute based on language
    return this._execute(script, input);
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
   * @param {Skill} skill - Full skill manifest
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
    const url = path.startsWith('http') ? path : `${this.registry}${path}`;
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

  _checkEnv(script) {
    if (!script.env) return [];
    return Object.entries(script.env)
      .filter(([, meta]) => meta.required && !process.env[_k])
      .map(([key]) => key);
  }

  async _execute(script, input) {
    if (script.lang === 'bash' && script.inline) {
      const { execSync } = await import('child_process');
      const result = execSync(script.inline, {
        env: { ...process.env, ...input },
        encoding: 'utf-8',
        timeout: 30000
      });
      return result;
    }

    if (['javascript', 'typescript'].includes(script.lang) && script.inline) {
      // Create a temporary module and execute
      const { writeFileSync, unlinkSync } = await import('fs');
      const { join } = await import('path');
      const tmpFile = join(process.env.HOME || '/tmp', `.dojo_${script.id}_${Date.now()}.js`);
      try {
        writeFileSync(tmpFile, script.inline);
        const mod = await import(tmpFile);
        const fn = mod.default || mod[Object.keys(mod)[0]];
        if (typeof fn === 'function') return await fn(input);
        return mod;
      } finally {
        try { unlinkSync(tmpFile); } catch {}
      }
    }

    throw new Error(`Execution not supported for lang: ${script.lang}`);
  }
}

// ─── Convenience export ────────────────────────────────

export function createClient(opts) {
  return new Dojo(opts);
}

export default Dojo;
