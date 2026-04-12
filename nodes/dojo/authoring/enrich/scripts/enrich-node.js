#!/usr/bin/env node
/**
 * Analyze a Dojo node for knowledge gaps and report what needs enrichment.
 *
 * Usage:
 *   node enrich-node.js analyze <path-to-node.json>
 *   node enrich-node.js enrich <path-to-node.json>
 *
 * In analyze mode, reports which knowledge fields are missing or thin.
 * In enrich mode, generates suggestions for missing fields (output only — does not modify the file).
 */

const fs = require("fs");
const path = require("path");

const [, , mode, nodePath] = process.argv;

if (!mode || !nodePath) {
  console.error("Usage: enrich-node.js <analyze|enrich> <path-to-node.json>");
  process.exit(1);
}

if (!["analyze", "enrich"].includes(mode)) {
  console.error('Mode must be "analyze" or "enrich"');
  process.exit(1);
}

if (!fs.existsSync(nodePath)) {
  console.error(`File not found: ${nodePath}`);
  process.exit(1);
}

let node;
try {
  node = JSON.parse(fs.readFileSync(nodePath, "utf8"));
} catch (err) {
  console.error(`Invalid JSON in ${nodePath}: ${err.message}`);
  process.exit(1);
}

const gaps = [];

// Check aliases (minimum 3)
const aliases = node.aliases || [];
if (aliases.length === 0) {
  gaps.push({
    field: "aliases",
    severity: "error",
    message: "No aliases defined — node is undiscoverable by alternative names",
    suggestion: `Add at least 3 aliases: abbreviations, acronyms, and phrase variants for "${node.name}"`,
  });
} else if (aliases.length < 3) {
  gaps.push({
    field: "aliases",
    severity: "warning",
    message: `Only ${aliases.length} alias(es) — recommend at least 3`,
    suggestion: "Add abbreviations, common misspellings, and phrase variants",
  });
}

// Check triggers (minimum 3 for skill/sub, 1 for others)
const triggers = node.triggers || [];
const isExecutable = ["skill", "sub"].includes(node.type);
const minTriggers = isExecutable ? 3 : 1;
if (triggers.length === 0) {
  gaps.push({
    field: "triggers",
    severity: isExecutable ? "error" : "warning",
    message: "No triggers defined — node won't match natural-language task routing",
    suggestion: "Add verb-object phrases like: 'create a ...', 'deploy to ...', 'configure ...'",
  });
} else if (triggers.length < minTriggers) {
  gaps.push({
    field: "triggers",
    severity: "warning",
    message: `Only ${triggers.length} trigger(s) — recommend at least ${minTriggers}`,
    suggestion: "Add more task phrase variants covering different wordings",
  });
}

// Check body (minimum 100 words)
const body = node.body || "";
const wordCount = body.split(/\s+/).filter(Boolean).length;
if (wordCount === 0) {
  gaps.push({
    field: "body",
    severity: "error",
    message: "Body is empty — node cannot teach",
    suggestion: "Write markdown: mental model first, then workflows, code examples, and [[wiki-links]]",
  });
} else if (wordCount < 100) {
  gaps.push({
    field: "body",
    severity: "warning",
    message: `Body is thin (${wordCount} words) — recommend 200+`,
    suggestion: "Add code examples, tables, and explanations",
  });
}

// Check wiki-links in body
const wikiLinkCount = (body.match(/\[\[[^\]]+\]\]/g) || []).length;
if (wordCount > 0 && wikiLinkCount === 0) {
  gaps.push({
    field: "body",
    severity: "warning",
    message: "No [[wiki-links]] in body — node is isolated from the graph",
    suggestion: "Add links to related nodes: [[parent/sibling]], [[auth]], [[troubleshooting]]",
  });
}

// Check sections (minimum 2)
const sections = node.sections || [];
if (sections.length === 0) {
  gaps.push({
    field: "sections",
    severity: "error",
    message: "No sections — node has no addressable knowledge chunks",
    suggestion: "Add 2+ sections with id, title, body, and tags for the most likely questions",
  });
} else if (sections.length < 2) {
  gaps.push({
    field: "sections",
    severity: "warning",
    message: `Only ${sections.length} section(s) — recommend at least 2`,
    suggestion: "Add sections for: overview, primary workflow, edge cases, troubleshooting",
  });
}

// Check links (minimum 2)
const links = node.links || [];
if (links.length === 0) {
  gaps.push({
    field: "links",
    severity: "error",
    message: "No links — node is a dead end with no next steps",
    suggestion: "Add directed links to related actionable nodes",
  });
} else if (links.length < 2) {
  gaps.push({
    field: "links",
    severity: "warning",
    message: `Only ${links.length} link(s) — recommend at least 2`,
    suggestion: "Link to prerequisites, related skills, and context nodes",
  });
}

// Check related (minimum 1)
const related = node.related || [];
if (related.length === 0) {
  gaps.push({
    field: "related",
    severity: "warning",
    message: "No related edges — node has no semantic graph connections",
    suggestion: "Add prerequisite, see-also, or implements relations to connected nodes",
  });
}

// Check context vs info duplication
if (node.context && node.info) {
  const contextWords = new Set(node.context.toLowerCase().split(/\s+/));
  const infoWords = node.info.toLowerCase().split(/\s+/);
  const overlap = infoWords.filter((w) => contextWords.has(w)).length;
  const overlapRatio = overlap / infoWords.length;
  if (overlapRatio > 0.7) {
    gaps.push({
      field: "info",
      severity: "warning",
      message: "Info is too similar to context — they should complement, not repeat",
      suggestion: "Context is the hook (when to use). Info is the scope (what it covers and why).",
    });
  }
}

// Check scripts for skill/sub nodes
if (isExecutable) {
  const scripts = node.scripts || [];
  if (scripts.length === 0) {
    gaps.push({
      field: "scripts",
      severity: "error",
      message: `${node.type} node has no scripts — it should be executable`,
      suggestion: "Add at least one script with id, name, lang, and entry or inline",
    });
  } else {
    scripts.forEach((s) => {
      if (!s.entry && !s.inline) {
        gaps.push({
          field: `scripts[${s.id}]`,
          severity: "error",
          message: `Script "${s.id}" has no entry file or inline code`,
          suggestion: "Add entry (file path) or inline (embedded code)",
        });
      }
    });
  }
}

// Output results
const errors = gaps.filter((g) => g.severity === "error");
const warnings = gaps.filter((g) => g.severity === "warning");

console.log(`\n📋 Node: ${node.uri} (${node.type})`);
console.log(`   Name: ${node.name} v${node.version}`);
console.log(`   Status: ${node.status || "unknown"}\n`);

if (gaps.length === 0) {
  console.log("✅ Node passes all knowledge quality checks\n");
  process.exit(0);
}

if (errors.length > 0) {
  console.log(`❌ ${errors.length} error(s):`);
  errors.forEach((g) => {
    console.log(`   [${g.field}] ${g.message}`);
    if (mode === "enrich") console.log(`   → ${g.suggestion}`);
  });
  console.log("");
}

if (warnings.length > 0) {
  console.log(`⚠️  ${warnings.length} warning(s):`);
  warnings.forEach((g) => {
    console.log(`   [${g.field}] ${g.message}`);
    if (mode === "enrich") console.log(`   → ${g.suggestion}`);
  });
  console.log("");
}

const score = Math.max(0, 100 - errors.length * 20 - warnings.length * 5);
console.log(`Knowledge score: ${score}/100`);
console.log(
  score >= 80
    ? "Ready for publishing"
    : score >= 50
      ? "Needs enrichment before publishing"
      : "Significant gaps — enrich before use"
);

process.exit(errors.length > 0 ? 1 : 0);
