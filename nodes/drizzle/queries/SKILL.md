---
name: drizzle-queries
description: Write type-safe database queries with Drizzle ORM's SQL-like builder and relational API. Use when performing CRUD operations, joins, aggregations, or nested data loading.
---

# Drizzle Queries

Drizzle provides two query APIs: a SQL-like builder that maps 1:1 to SQL, and a relational API for nested data.

## Workflow

1. Import your tables from the schema and operators from `drizzle-orm`
2. Use `db.select().from(table)` for SQL-like queries
3. Use `db.query.tableName.findMany()` for relational queries (requires relations)
4. Chain `.where()`, `.orderBy()`, `.limit()`, `.offset()` for filtering
5. Use `.returning()` on insert/update/delete for PostgreSQL/SQLite

## Instructions

### Setup

```typescript
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

const client = postgres(process.env.DATABASE_URL!);
const db = drizzle(client, { schema }); // Pass schema for relational API
```

### Select

```typescript
import { eq, and, or, gt, lt, gte, lte, like, ilike, inArray, isNull, isNotNull, between, not, desc, asc, sql, count, sum, avg } from 'drizzle-orm';
import { users, posts } from './schema';

// All rows
const allUsers = await db.select().from(users);

// Specific columns
const names = await db.select({ id: users.id, name: users.name }).from(users);

// Filter
const admins = await db.select().from(users).where(eq(users.role, 'admin'));

// AND / OR
const result = await db.select().from(users).where(
  and(eq(users.role, 'admin'), gt(users.createdAt, new Date('2024-01-01')))
);

// Pagination
const page = await db.select().from(users)
  .orderBy(desc(users.createdAt))
  .limit(10).offset(20);
```

### Insert

```typescript
// Single
await db.insert(users).values({ name: 'Dan', email: 'dan@example.com' });

// Batch
await db.insert(users).values([
  { name: 'Dan', email: 'dan@example.com' },
  { name: 'Alice', email: 'alice@example.com' },
]);

// With returning
const [newUser] = await db.insert(users)
  .values({ name: 'Dan', email: 'dan@example.com' })
  .returning();

// Upsert
await db.insert(users)
  .values({ email: 'dan@example.com', name: 'Dan' })
  .onConflictDoUpdate({ target: users.email, set: { name: 'Dan Updated' } });
```

### Update

```typescript
await db.update(users).set({ name: 'Mr. Dan' }).where(eq(users.id, 1));

// With returning
const [updated] = await db.update(users)
  .set({ name: 'Mr. Dan' })
  .where(eq(users.id, 1))
  .returning();
```

### Delete

```typescript
await db.delete(users).where(eq(users.id, 1));

// With returning
const [deleted] = await db.delete(users).where(eq(users.id, 1)).returning();
```

### Joins

```typescript
const result = await db.select({
  userName: users.name,
  postTitle: posts.title,
}).from(users)
  .innerJoin(posts, eq(users.id, posts.authorId));

// Left join
const result = await db.select().from(users)
  .leftJoin(posts, eq(users.id, posts.authorId));
```

### Aggregations

```typescript
import { count, sum, avg, min, max } from 'drizzle-orm';

const total = await db.$count(users);

const stats = await db.select({
  role: users.role,
  userCount: count(),
}).from(users).groupBy(users.role);
```

### Relational Queries

Requires relations defined (see `drizzle/relations`):

```typescript
const usersWithPosts = await db.query.users.findMany({
  with: { posts: true },
});

const user = await db.query.users.findFirst({
  where: eq(users.id, 1),
  with: {
    posts: {
      where: eq(posts.published, true),
      limit: 5,
      with: { comments: true },
    },
  },
});
```

### Transactions

```typescript
await db.transaction(async (tx) => {
  const [user] = await tx.insert(users)
    .values({ name: 'Dan', email: 'dan@example.com' })
    .returning();
  await tx.insert(posts)
    .values({ title: 'Hello', authorId: user.id });
});
```

### Prepared Statements

```typescript
import { placeholder } from 'drizzle-orm';

const prepared = db.select().from(users)
  .where(eq(users.id, placeholder('id')))
  .prepare('get_user');

const user = await prepared.execute({ id: 1 });
```

## Edge Cases

- **undefined vs null**: `undefined` values in `.set()` are ignored; pass `null` explicitly to set NULL
- **returning() availability**: Only PostgreSQL and SQLite support `.returning()`. MySQL uses `.$returningId()`
- **Empty where**: Calling `.where()` with `undefined` returns all rows — useful for conditional filters
- **Type inference**: Use `typeof table.$inferSelect` for result types, `typeof table.$inferInsert` for input types
- **Raw SQL safety**: The `sql` template tag auto-parameterizes — never interpolate user input directly
- **Relational API requirements**: `db.query.*` requires passing `{ schema }` to `drizzle()` and having relations defined
- **Transaction isolation**: The `tx` object replaces `db` inside transactions — using `db` inside a transaction bypasses it
