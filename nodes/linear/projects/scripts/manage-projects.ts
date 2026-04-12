/**
 * List, create, and update Linear projects.
 *
 * Environment variables:
 *   LINEAR_API_KEY - Required. Linear personal API key.
 *
 * Usage:
 *   npx tsx manage-projects.ts list [--state started]
 *   npx tsx manage-projects.ts create --name "Project Name" [--team ENG] [--target 2026-09-30]
 *   npx tsx manage-projects.ts get <project-id>
 */

import { LinearClient } from "@linear/sdk";

const apiKey = process.env.LINEAR_API_KEY;
if (!apiKey) {
  console.error("Error: LINEAR_API_KEY environment variable is required.");
  process.exit(1);
}

const client = new LinearClient({ apiKey });
const args = process.argv.slice(2);
const action = args[0] || "list";

function getArg(flag: string): string | undefined {
  const idx = args.indexOf(flag);
  return idx !== -1 && idx + 1 < args.length ? args[idx + 1] : undefined;
}

async function listProjects() {
  const stateFilter = getArg("--state");
  const filter: Record<string, unknown> = {};
  if (stateFilter) {
    filter.state = { in: [stateFilter] };
  }

  const projects = await client.projects({ filter, first: 25 });

  console.log(`Projects (${projects.nodes.length}):\n`);
  for (const project of projects.nodes) {
    const lead = project.lead ? (await project.lead).name : "no lead";
    const progress = Math.round(project.progress * 100);
    console.log(
      `  ${project.name.padEnd(40)} ${project.state.padEnd(12)} ${String(progress + "%").padEnd(6)} ${lead.padEnd(20)} ${project.targetDate || "no target"}`
    );
  }
}

async function createProject() {
  const name = getArg("--name");
  if (!name) {
    console.error("Usage: manage-projects.ts create --name <name> [--team <KEY>] [--target <YYYY-MM-DD>]");
    process.exit(1);
  }

  const teamKey = getArg("--team");
  const targetDate = getArg("--target");
  const description = getArg("--description");

  const input: Record<string, unknown> = { name, state: "planned" };
  if (description) input.description = description;
  if (targetDate) input.targetDate = targetDate;

  if (teamKey) {
    const teams = await client.teams({ filter: { key: { eq: teamKey } } });
    if (teams.nodes.length > 0) {
      input.teamIds = [teams.nodes[0].id];
    } else {
      console.error(`Warning: Team "${teamKey}" not found. Creating project without team.`);
    }
  }

  const result = await client.createProject(input);
  if (result.success) {
    const project = await result.project;
    if (project) {
      console.log(`Created project: ${project.name}`);
      console.log(`URL: ${project.url}`);
      console.log(`State: ${project.state}`);
      if (targetDate) console.log(`Target: ${targetDate}`);
    }
  } else {
    console.error("Failed to create project.");
    process.exit(1);
  }
}

async function getProject() {
  const projectId = args[1];
  if (!projectId) {
    console.error("Usage: manage-projects.ts get <project-id>");
    process.exit(1);
  }

  const project = await client.project(projectId);
  const lead = project.lead ? (await project.lead).name : "no lead";
  const teams = await project.teams();
  const issues = await project.issues({ first: 10 });
  const progress = Math.round(project.progress * 100);

  console.log(`Project: ${project.name}`);
  console.log(`State: ${project.state}`);
  console.log(`Progress: ${progress}%`);
  console.log(`Lead: ${lead}`);
  console.log(`Teams: ${teams.nodes.map(t => t.key).join(", ") || "none"}`);
  console.log(`Target: ${project.targetDate || "none"}`);
  console.log(`URL: ${project.url}`);

  if (project.description) {
    console.log(`\nDescription:\n${project.description}`);
  }

  if (issues.nodes.length > 0) {
    console.log(`\nIssues (${issues.nodes.length}):`);
    for (const issue of issues.nodes) {
      const state = await issue.state;
      console.log(`  ${issue.identifier.padEnd(10)} ${(state?.name || "?").padEnd(14)} ${issue.title}`);
    }
  }
}

switch (action) {
  case "list":
    await listProjects();
    break;
  case "create":
    await createProject();
    break;
  case "get":
    await getProject();
    break;
  default:
    console.error(`Unknown action: ${action}`);
    console.error("Usage: manage-projects.ts <list|create|get> [options]");
    process.exit(1);
}
