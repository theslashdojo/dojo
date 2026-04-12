/**
 * Update an existing Linear issue.
 *
 * Environment variables:
 *   LINEAR_API_KEY - Required. Linear personal API key.
 *
 * Usage:
 *   npx tsx update-issue.ts --id ENG-42 [--state Done] [--priority 2] [--assignee user@co.com]
 *   npx tsx update-issue.ts --id ENG-42 --close
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

function hasFlag(flag: string): boolean {
  return args.includes(flag);
}

const issueId = getArg("--id");
if (!issueId) {
  console.error("Usage: update-issue.ts --id <ENG-42> [--state <name>] [--priority <0-4>] [--assignee <email>] [--close]");
  process.exit(1);
}

// Fetch the issue
const issue = await client.issue(issueId);
const team = await issue.team;
if (!team) {
  console.error("Error: Could not determine issue team.");
  process.exit(1);
}

const updateInput: Record<string, unknown> = {};

// Handle --state
const stateName = getArg("--state");
if (stateName) {
  const states = await team.states();
  const targetState = states.nodes.find(
    s => s.name.toLowerCase() === stateName.toLowerCase()
  );
  if (!targetState) {
    console.error(`Error: State "${stateName}" not found for team ${team.key}.`);
    console.error("Available states:");
    for (const s of states.nodes) {
      console.error(`  ${s.name} (${s.type})`);
    }
    process.exit(1);
  }
  updateInput.stateId = targetState.id;
}

// Handle --close (find first "completed" type state)
if (hasFlag("--close")) {
  const states = await team.states();
  const doneState = states.nodes.find(s => s.type === "completed");
  if (!doneState) {
    console.error("Error: No completed state found for this team.");
    process.exit(1);
  }
  updateInput.stateId = doneState.id;
}

// Handle --priority
const priorityStr = getArg("--priority");
if (priorityStr) {
  updateInput.priority = parseInt(priorityStr, 10);
}

// Handle --assignee (by email)
const assigneeEmail = getArg("--assignee");
if (assigneeEmail) {
  const members = await team.members();
  const member = members.nodes.find(
    m => m.email.toLowerCase() === assigneeEmail.toLowerCase()
  );
  if (!member) {
    console.error(`Error: No team member found with email "${assigneeEmail}".`);
    process.exit(1);
  }
  updateInput.assigneeId = member.id;
}

// Handle --unassign
if (hasFlag("--unassign")) {
  updateInput.assigneeId = null;
}

// Handle --title
const newTitle = getArg("--title");
if (newTitle) {
  updateInput.title = newTitle;
}

if (Object.keys(updateInput).length === 0) {
  console.error("No updates specified. Use --state, --priority, --assignee, --close, or --title.");
  process.exit(1);
}

const result = await client.updateIssue(issue.id, updateInput);

if (result.success) {
  const updated = await result.issue;
  if (updated) {
    const state = await updated.state;
    const assignee = updated.assignee ? (await updated.assignee).name : "unassigned";
    const priorityLabels = ["None", "Urgent", "High", "Medium", "Low"];

    console.log(`Updated: ${updated.identifier}`);
    console.log(`Title: ${updated.title}`);
    console.log(`State: ${state?.name || "unknown"}`);
    console.log(`Priority: ${priorityLabels[updated.priority]}`);
    console.log(`Assignee: ${assignee}`);
    console.log(`URL: ${updated.url}`);
  }
} else {
  console.error("Failed to update issue.");
  process.exit(1);
}
