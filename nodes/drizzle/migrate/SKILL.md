---
name: drizzle-migrate
description: Generate and apply database migrations using drizzle-kit CLI. Use when evolving database schema, running migrations, or introspecting existing databases with Drizzle.
---

# Drizzle Migrations

Manage database schema evolution with drizzle-kit. Generate SQL from TypeScript schema diffs, apply migrations, push directly, or introspect existing databases.

## Workflow

1. Edit your TypeScript schema (see `drizzle/schema`)
2. Run `npx drizzle-kit generate` to create SQL migration files
3. Review the generated SQL in `drizzle/XXXX_name/migration.sql`
4. Run `npx drizzle-kit migrate` to apply to your database
5. Commit migration files to version control

## Instructions

### Prerequisites

```bash
npm install drizzle-orm
npm install -D drizzle-kit
```

Ensure `drizzle.config.ts` exists (see `drizzle/config`).

### Generate a Migration

After modifying your schema:

```bash
# Generate SQL migration files
npx drizzle-kit generate

# With a descriptive name
npx drizzle-kit generate --name=add-posts-table

# With custom config
npx drizzle-kit generate --config=drizzle.prod.config.ts
```

Output structure:
```
drizzle/
  0000_add_posts_table/
    migration.sql      # SQL statements to apply
    snapshot.json      # Schema snapshot for future diffs
  meta/
    _journal.json      # Migration history journal
```

### Apply Migrations

```bash
# Apply all pending migrations
npx drizzle-kit migrate
```

### Push (No SQL Files)

For rapid prototyping — applies schema directly to database:

```bash
npx drizzle-kit push

# With confirmation for destructive changes
npx drizzle-kit push --strict

# With verbose SQL output
npx drizzle-kit push --verbose
```

### Pull (Introspect)

Generate TypeScript schema from an existing database:

```bash
npx drizzle-kit pull

# With camelCase column names
npx drizzle-kit pull  # Set introspect.casing: 'camel' in config
```

### Programmatic Runtime Migration

Apply migrations at application startup:

```typescript
// PostgreSQL
import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';

const client = postgres(process.env.DATABASE_URL!);
const db = drizzle(client);
await migrate(db, { migrationsFolder: './drizzle' });
await client.end();
```

```typescript
// MySQL
import { drizzle } from 'drizzle-orm/mysql2';
import { migrate } from 'drizzle-orm/mysql2/migrator';
import mysql from 'mysql2/promise';

const connection = await mysql.createConnection(process.env.DATABASE_URL!);
const db = drizzle(connection);
await migrate(db, { migrationsFolder: './drizzle' });
await connection.end();
```

```typescript
// SQLite
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import Database from 'better-sqlite3';

const sqlite = new Database('sqlite.db');
const db = drizzle(sqlite);
migrate(db, { migrationsFolder: './drizzle' });
```

### Visual Studio

Browse your schema and data:

```bash
npx drizzle-kit studio
```

Opens at `https://local.drizzle.studio`.

## CLI Commands Reference

| Command | Purpose |
|---------|---------|
| `generate` | Diff schema → SQL files |
| `migrate` | Apply pending SQL files |
| `push` | Apply schema directly (no files) |
| `pull` | DB → TypeScript schema |
| `export` | Output SQL to console |
| `studio` | Visual data browser |
| `check` | Validate migration consistency |
| `up` | Upgrade migration format |

## Edge Cases

- **Rename detection**: `generate` prompts when it detects drop+add that might be a rename — always answer carefully to avoid data loss
- **Statement breakpoints**: The `--> statement-breakpoint` markers in SQL are required by some databases for DDL separation
- **Destructive changes**: Column drops, type changes, and table drops are flagged in `--strict` mode
- **Team workflows**: When multiple developers generate migrations simultaneously, drizzle-kit handles merge conflicts in the journal
- **Custom migration table**: Set `migrations.table` in config if `__drizzle_migrations` conflicts
- **Migration order**: Migrations apply in alphabetical/timestamp order — never rename migration folders
