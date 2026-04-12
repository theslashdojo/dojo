/**
 * Create a new Linear issue.
 *
 * Environment variables:
 *   LINEAR_API_KEY   - Required. Linear personal API key.
 *   LINEAR_TEAM_KEY  - Optional. Team key (default: ENG).
 *
 * Usage:
 *   npx tsx create-issue.ts --title "Bug: login fails" [--description "..."] [--priority 2] [--team ENG]
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

function getArg(flag: string): string | undefined {
  const idx = args.indexOf(flag);
  return idx !== -1 && idx + 1 < args.length ? args[idx + 1] : undefined;
}

const title = getArg("--title");
if (!title) {
  console.error("Usage: create-issue.ts --title <title> [--description <desc>] [--priority <0-4>] [--team <KEY>]");
  process.exit(1);
}

const teamKey = getArg("--team") || process.env.LINEAR_TEAM_KEY || "ENG";
const description = getArg("--description");
const priorityStr = getArg("--priority");
const priority = priorityStr ? parseInt(priorityStr, 10) : undefined;

// Find the team by key
const teams = await client.teams({ filter: { key: { eq: teamKey } } });
const team = teams.nodes[0];
if (!team) {
  console.error(`Error: Team with key "${teamKey}" not found.`);
  console.error("Available teams:");
  const allTeams = await client.teams();
  for (const t of allTeams.nodes) {
    console.error(`  ${t.key}: ${t.name}`);
  }
  process.exit(1);
}

// Create the issue
const input: Record<string, unknown> = {
  teamId: team.id,
  title,
};
if (description) input.description = description;
if (priority !== undefined) input.priority = priority;

const result = await client.createIssue(input);

if (result.success) {
  const issue = await result.issue;
  if (issue) {
    console.log(`Created issue: ${issue.identifier}`);
    console.log(`Title: ${issue.title}`);
    console.log(`URL: ${issue.url}`);
    console.log(`Team: ${teamKey}`);
    if (priority !== undefined) {
      const labels = ["None", "Urgent", "High", "Medium", "Low"];
      console.log(`Priority: ${labels[priority]}`);
    }
  }
} else {
  console.error("Failed to create issue.");
  process.exit(1);
}
