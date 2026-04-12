---
name: seed
description: Create and run Prisma database seed scripts to populate development and test data. Use when setting up seed files, populating test databases, or generating fixtures.
---

# Prisma Seed

Populate your database with initial, development, or test data.

## When to Use

- Setting up a seed script for a new project
- Populating a development database with sample data
- Creating test fixtures
- Seeding lookup tables (roles, categories, statuses)
- Generating realistic test data with Faker

## Workflow

1. Create `prisma/seed.ts`
2. Configure the seed command in `package.json`
3. Write idempotent seed logic using `upsert`
4. Run `npx prisma db seed`

## Setup

### package.json
```json
{
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  }
}
```

### Install runner
```bash
npm install tsx --save-dev
```

## Seed Script Template

```typescript
// prisma/seed.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Idempotent: safe to run multiple times
  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      name: 'Admin',
      role: 'ADMIN',
    },
  });

  const tags = ['javascript', 'typescript', 'prisma', 'database'];
  for (const name of tags) {
    await prisma.tag.upsert({
      where: { name },
      update: {},
      create: { name },
    });
  }

  console.log('Seed complete:', { admin: admin.email, tags: tags.length });
}

main()
  .then(async () => { await prisma.$disconnect(); })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
```

## Running

```bash
# Run seed script
npx prisma db seed

# Seeds also run after:
npx prisma migrate reset
```

## With Faker

```bash
npm install @faker-js/faker --save-dev
```

```typescript
import { faker } from '@faker-js/faker';

for (let i = 0; i < 50; i++) {
  await prisma.user.create({
    data: {
      email: faker.internet.email(),
      name: faker.person.fullName(),
    },
  });
}
```

## Edge Cases

- Always use `upsert` with `update: {}` — `create` fails on P2002 (duplicate unique)
- `createMany` is faster for bulk inserts but doesn't support nested creates
- Disconnect the client in `finally` to avoid hanging processes
- The seed command path in `package.json` is relative to the project root
- Seeds must exit cleanly — add `process.exit(1)` in the catch handler
- For large datasets, batch with `createMany` + `skipDuplicates: true`
