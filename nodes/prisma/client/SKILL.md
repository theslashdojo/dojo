---
name: client
description: Generate and use the Prisma Client for type-safe database queries, mutations, and transactions. Use when setting up Prisma Client, writing queries, handling transactions, or managing connections.
---

# Prisma Client

Generate and use a type-safe database client from your Prisma schema.

## When to Use

- Setting up Prisma Client in a project
- Writing database queries (CRUD operations)
- Loading related data with `include` or `select`
- Running transactions (batch or interactive)
- Executing raw SQL
- Setting up a singleton client for production

## Workflow

1. Ensure schema is defined and migrations are applied
2. Run `npx prisma generate` (auto-runs with `migrate dev`)
3. Import and instantiate `PrismaClient`
4. Use model methods: `findUnique`, `findMany`, `create`, `update`, `delete`, etc.
5. Handle errors by catching `PrismaClientKnownRequestError`
6. Disconnect on shutdown with `$disconnect()`

## Setup

```bash
npm install @prisma/client
npm install prisma --save-dev
npx prisma generate
```

## Singleton Pattern (Critical for Production)

```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };
export const prisma = globalForPrisma.prisma || new PrismaClient();
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

Without this, hot-reloading creates new connection pools and exhausts database connections.

## Quick CRUD Reference

```typescript
import { prisma } from './lib/prisma';

// Create
const user = await prisma.user.create({
  data: { email: 'alice@example.com', name: 'Alice' },
});

// Read
const user = await prisma.user.findUnique({ where: { id: 1 } });
const users = await prisma.user.findMany({ where: { role: 'ADMIN' } });

// Update
await prisma.user.update({ where: { id: 1 }, data: { name: 'Updated' } });

// Delete
await prisma.user.delete({ where: { id: 1 } });

// Upsert
await prisma.user.upsert({
  where: { email: 'alice@example.com' },
  update: { name: 'Alice Updated' },
  create: { email: 'alice@example.com', name: 'Alice' },
});
```

## Transactions

```typescript
// Batch — array of operations
const [users, count] = await prisma.$transaction([
  prisma.user.findMany(),
  prisma.user.count(),
]);

// Interactive — with custom logic and rollback
await prisma.$transaction(async (tx) => {
  const sender = await tx.account.update({
    data: { balance: { decrement: 100 } },
    where: { email: 'alice@example.com' },
  });
  if (sender.balance < 0) throw new Error('Insufficient funds');
  await tx.account.update({
    data: { balance: { increment: 100 } },
    where: { email: 'bob@example.com' },
  });
});
```

## Raw SQL

```typescript
// Safe parameterized queries
const users = await prisma.$queryRaw`SELECT * FROM "User" WHERE email = ${email}`;
const count = await prisma.$executeRaw`DELETE FROM "Post" WHERE "authorId" = ${userId}`;
```

## Error Handling

```typescript
import { Prisma } from '@prisma/client';

try {
  await prisma.user.create({ data: { email: 'alice@example.com' } });
} catch (e) {
  if (e instanceof Prisma.PrismaClientKnownRequestError) {
    switch (e.code) {
      case 'P2002': console.error('Duplicate:', e.meta?.target); break;
      case 'P2025': console.error('Not found'); break;
      default: throw e;
    }
  }
}
```

## Edge Cases

- `select` and `include` cannot be used together at the same level
- `findUnique` returns `null` when not found; use `findUniqueOrThrow` to throw instead
- `createMany` doesn't support nested creates — use individual `create` calls for nested data
- `$queryRaw` returns an array; `$executeRaw` returns an affected-row count
- Never use `$queryRawUnsafe` with user input — SQL injection risk
- In Next.js API routes/Server Components, always use the singleton pattern
- Each `PrismaClient` instance manages its own connection pool
