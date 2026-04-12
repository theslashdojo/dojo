---
name: linear-projects
description: Create, query, and manage Linear projects for cross-team initiatives and milestone tracking. Use when working with Linear project planning, roadmaps, or initiative management.
---

# Linear Projects

Manage cross-team initiatives, milestones, and progress tracking in Linear.

## Prerequisites

- `LINEAR_API_KEY` environment variable set
- `@linear/sdk` package installed

## Workflow

### 1. Initialize

```typescript
import { LinearClient } from "@linear/sdk";
const client = new LinearClient({ apiKey: process.env.LINEAR_API_KEY });
```

### 2. List active projects

```typescript
const projects = await client.projects({
  filter: { state: { in: ["started", "planned"] } },
});

for (const project of projects.nodes) {
  console.log(`${project.name} — ${project.state} (${Math.round(project.progress * 100)}%)`);
}
```

### 3. Create a project

```typescript
const teams = await client.teams();
const engTeam = teams.nodes.find(t => t.key === "ENG");

const result = await client.createProject({
  name: "Q3 Platform Rewrite",
  description: "Rewrite core services for scalability",
  teamIds: [engTeam.id],
  targetDate: "2026-09-30",
  state: "planned",
});

const project = await result.project;
console.log(`Created: ${project.name} — ${project.url}`);
```

### 4. Add issues to a project

```typescript
// Set projectId when creating an issue
await client.createIssue({
  teamId: engTeam.id,
  title: "Implement new auth flow",
  projectId: project.id,
});

// Or update an existing issue
await client.updateIssue(existingIssue.id, {
  projectId: project.id,
});
```

### 5. Post a project update

```graphql
mutation {
  projectUpdateCreate(input: {
    projectId: "PROJECT_UUID"
    body: "## Week 12\n\nAuth migration complete. Frontend starts next week."
    health: "onTrack"
  }) {
    success
  }
}
```

### 6. Update project status

```typescript
await client.updateProject(project.id, {
  state: "started",
});
```

## Project States

| State | Meaning |
|-------|---------|
| `backlog` | Not yet planned |
| `planned` | Scheduled, not started |
| `started` | In progress |
| `paused` | On hold |
| `completed` | Done |
| `cancelled` | Abandoned |

## Health Values

- `onTrack` — project is progressing as expected
- `atRisk` — some concerns about timeline or scope
- `offTrack` — significant issues blocking progress

## Edge Cases

- Progress is auto-calculated from completed/total issues
- Projects without issues show 0% progress
- Target dates are informational — no automated enforcement
- Projects can span multiple teams via `teamIds`
- Removing all team associations doesn't delete the project
