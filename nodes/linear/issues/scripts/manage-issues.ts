/**
 * List, search, and display Linear issues with filtering and pagination.
 *
 * Environment variables:
 *   LINEAR_API_KEY   - Required. Linear personal API key.
 *   LINEAR_TEAM_KEY  - Optional. Team key to filter (e.g., "ENG").
 *
 * Usage:
 *   npx tsx manage-issues.ts list [--team ENG] [--limit 25]
 *   npx tsx manage-issues.ts search "query string"
 *   npx tsx manage-issues.ts get ENG-42
 */

import { LinearClient } from "@linear/sdk";

const apiKey = process.env.LINEAR_API_KEY;
if (!apiKey) {
  console.error("Error: LINEAR_API_KEY environment variable is required.");
  console.error("Get one from Linear → Settings → Security → API");
  process.exit(1);
}

const client = new LinearClient({ apiKey });

const args = process.argv.slice(2);
const action = args[0] || "list";

async function listIssues() {
  const teamKey = getArg("--team") || process.env.LINEAR_TEAM_KEY;
  const limit = parseInt(getArg("--limit") || "25", 10);

  const filter: Record<string, unknown> = {};
  if (teamKey) {
    filter.team = { key: { eq: teamKey } };
  }

  const issues = await client.issues({
    first: limit,
    filter,
    orderBy: "updatedAt" as never,
  });

  console.log(`Found ${issues.nodes.length} issues:\n`);

  for (const issue of issues.nodes) {
    const assignee = issue.assignee ? (await issue.assignee).name : "unassigned";
    const state = await issue.state;
    const priorityLabels = ["None", "Urgent", "High", "Medium", "Low"];
    const priority = priorityLabels[issue.priority] || "None";
    console.log(
      `  ${issue.identifier.padEnd(10)} ${priority.padEnd(8)} ${(state?.name || "unknown").padEnd(14)} ${assignee.padEnd(20)} ${issue.title}`
    );
  }

  if (issues.pageInfo.hasNextPage) {
    console.log(`\n  ... more results available (cursor: ${issues.pageInfo.endCursor})`);
  }
}

async function searchIssues() {
  const query = args.slice(1).join(" ");
  if (!query) {
    console.error("Usage: manage-issues.ts search <query>");
    process.exit(1);
  }

  const results = await client.searchIssues(query);

  console.log(`Search results for "${query}":\n`);
  for (const issue of results.nodes) {
    const state = await issue.state;
    console.log(
      `  ${issue.identifier.padEnd(10)} ${(state?.name || "unknown").padEnd(14)} ${issue.title}`
    );
  }
}

async function getIssue() {
  const issueId = args[1];
  if (!issueId) {
    console.error("Usage: manage-issues.ts get <issue-id>");
    process.exit(1);
  }

  const issue = await client.issue(issueId);
  const assignee = issue.assignee ? (await issue.assignee).name : "unassigned";
  const state = await issue.state;
  const team = await issue.team;
  const labels = await issue.labels();
  const priorityLabels = ["None", "Urgent", "High", "Medium", "Low"];

  console.log(`Issue: ${issue.identifier}`);
  console.log(`Title: ${issue.title}`);
  console.log(`Team: ${team?.name} (${team?.key})`);
  console.log(`State: ${state?.name} (${state?.type})`);
  console.log(`Priority: ${priorityLabels[issue.priority]}`);
  console.log(`Assignee: ${assignee}`);
  console.log(`Labels: ${labels.nodes.map(l => l.name).join(", ") || "none"}`);
  console.log(`Created: ${issue.createdAt}`);
  console.log(`Updated: ${issue.updatedAt}`);
  console.log(`URL: ${issue.url}`);

  if (issue.description) {
    console.log(`\nDescription:\n${issue.description}`);
  }
}

function getArg(flag: string): string | undefined {
  const idx = args.indexOf(flag);
  return idx !== -1 && idx + 1 < args.length ? args[idx + 1] : undefined;
}

switch (action) {
  case "list":
    await listIssues();
    break;
  case "search":
    await searchIssues();
    break;
  case "get":
    await getIssue();
    break;
  default:
    console.error(`Unknown action: ${action}`);
    console.error("Usage: manage-issues.ts <list|search|get> [options]");
    process.exit(1);
}
