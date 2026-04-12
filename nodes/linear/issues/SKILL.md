---
name: linear-issues
description: Create, search, update, and manage Linear issues via GraphQL API and SDK. Use when working with Linear issue tracking, bug reports, task management, or issue triage automation.
---

# Linear Issues

Manage the full issue lifecycle in Linear: create, search, filter, update, and triage issues.

## Prerequisites

- `LINEAR_API_KEY` environment variable set (from Settings → Security → API)
- `@linear/sdk` package installed (`npm install @linear/sdk`)

## Workflow

### 1. Initialize the client

```typescript
import { LinearClient } from "@linear/sdk";
const client = new LinearClient({ apiKey: process.env.LINEAR_API_KEY });
```

### 2. Identify the target team

Before creating issues, find the team ID:

```typescript
const teams = await client.teams();
const team = teams.nodes.find(t => t.key === "ENG");
```

### 3. Create an issue

```typescript
const result = await client.createIssue({
  teamId: team.id,
  title: "Bug: login fails on Safari",
  description: "## Steps\n1. Open Safari\n2. Go to /login\n3. Enter credentials\n\n## Expected\nRedirect to dashboard\n\n## Actual\n500 error",
  priority: 2,
});
const issue = await result.issue;
console.log(`Created ${issue.identifier}: ${issue.url}`);
```

### 4. Search and filter issues

```typescript
// Text search
const results = await client.searchIssues("login bug");

// Filtered listing
const issues = await client.issues({
  filter: {
    team: { key: { eq: "ENG" } },
    state: { type: { in: ["started", "unstarted"] } },
    priority: { lte: 2 },
  },
  first: 50,
});
```

### 5. Update an issue

```typescript
await client.updateIssue(issue.id, {
  stateId: "DONE_STATE_UUID",
  priority: 3,
});
```

### 6. Paginate results

```typescript
let cursor: string | undefined;
let hasMore = true;

while (hasMore) {
  const page = await client.issues({ first: 50, after: cursor });
  for (const issue of page.nodes) {
    console.log(issue.identifier, issue.title);
  }
  hasMore = page.pageInfo.hasNextPage;
  cursor = page.pageInfo.endCursor;
}
```

## Priority Values

| Value | Label   |
|-------|---------|
| 0     | None    |
| 1     | Urgent  |
| 2     | High    |
| 3     | Medium  |
| 4     | Low     |

## Common Patterns

- **Triage**: List unassigned issues, assign priority and team member
- **Sprint planning**: Move issues into a cycle with `cycleId`
- **Bug filing from CI**: Create issues from test failures with labels
- **Status sync**: Query issue states and sync to external systems

## Edge Cases

- Issue identifiers (`ENG-42`) and UUIDs both work in `issue(id)` queries
- Archived issues are excluded by default — pass `includeArchived: true`
- Creating an issue without `stateId` places it in the team's default state
- Changes within 3 minutes of creation don't appear in activity logs
- Priority is an integer (0-4), not a string
