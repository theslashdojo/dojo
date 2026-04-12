---
name: drizzle-schema
description: Define Drizzle ORM database tables, columns, indexes, enums, and constraints in TypeScript. Use when creating or modifying database schema with Drizzle.
---

# Drizzle Schema Definition

Define database tables as TypeScript using dialect-specific table functions. Schemas are the source of truth for migrations and type-safe queries.

## Workflow

1. Choose your dialect: `pgTable` (PostgreSQL), `mysqlTable` (MySQL), `sqliteTable` (SQLite)
2. Define tables with typed columns and constraints
3. Add indexes in the third argument callback
4. Export everything — drizzle-kit discovers exports for migration generation
5. Run `npx drizzle-kit generate` to create migration SQL

## Instructions

### Step 1: Install Dependencies

```bash
npm install drizzle-orm
npm install -D drizzle-kit
# Plus your database driver:
npm install postgres          # PostgreSQL
# npm install mysql2          # MySQL
# npm install better-sqlite3  # SQLite
```

### Step 2: Create Schema File

Create `src/db/schema.ts` (or split into `src/db/schema/*.ts`).

### Step 3: Define Tables

**PostgreSQL:**
```typescript
import { pgTable, pgEnum, serial, integer, text, varchar, boolean, timestamp, uuid, jsonb, index, uniqueIndex, primaryKey } from 'drizzle-orm/pg-core';

export const roleEnum = pgEnum('role', ['user', 'admin', 'moderator']);

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  role: roleEnum('role').default('user'),
  metadata: jsonb('metadata'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (table) => [
  index('users_email_idx').on(table.email),
]);
```

**MySQL:**
```typescript
import { mysqlTable, mysqlEnum, serial, int, varchar, text, boolean, timestamp, json, index } from 'drizzle-orm/mysql-core';

export const users = mysqlTable('users', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 256 }).notNull(),
  email: varchar('email', { length: 256 }).notNull().unique(),
  role: mysqlEnum('role', ['user', 'admin']).default('user'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});
```

**SQLite:**
```typescript
import { sqliteTable, integer, text, index } from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

export const users = sqliteTable('users', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  role: text('role').$type<'user' | 'admin'>().default('user'),
  createdAt: text('created_at').default(sql`(CURRENT_TIMESTAMP)`),
});
```

### Step 4: Add Foreign Keys and Indexes

```typescript
export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 256 }).notNull(),
  content: text('content'),
  published: boolean('published').default(false),
  authorId: integer('author_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('posts_author_idx').on(table.authorId),
]);
```

### Step 5: Generate Migration

```bash
npx drizzle-kit generate --name=init
```

## Column Constraints Quick Reference

| Constraint | Syntax |
|-----------|--------|
| Primary key | `.primaryKey()` |
| Not null | `.notNull()` |
| Unique | `.unique()` |
| Default value | `.default('value')` |
| Default now | `.defaultNow()` |
| Auto-increment | `serial()` or `.autoincrement()` |
| Foreign key | `.references(() => table.col)` |
| FK with cascade | `.references(() => table.col, { onDelete: 'cascade' })` |
| Custom TS type | `.$type<MyType>()` |
| Generated ID | `.generatedAlwaysAsIdentity()` |

## Type Inference

```typescript
type User = typeof users.$inferSelect;    // What queries return
type NewUser = typeof users.$inferInsert;  // What inserts accept
```

## Reusable Patterns

```typescript
// Timestamps mixin
const timestamps = {
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
};

// Use in any table
export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  ...timestamps,
});
```

## Edge Cases

- **Self-referencing FK**: Use `(): AnyPgColumn => table.id` to break circular reference
- **Multiple schemas (PG)**: Use `pgSchema('name').table()` instead of `pgTable()`
- **Column name mapping**: Pass DB name as first arg: `firstName: text('first_name')`
- **Auto casing**: Set `casing: 'snake_case'` on `drizzle()` to auto-map camelCase to snake_case
- **MySQL varchar**: Always specify `{ length: N }` — MySQL requires it
- **SQLite booleans**: Use `integer({ mode: 'boolean' })` — SQLite has no boolean type
- **SQLite JSON**: Use `text({ mode: 'json' })` — SQLite stores JSON as text
