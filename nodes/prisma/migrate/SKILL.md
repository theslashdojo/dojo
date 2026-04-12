---
name: migrate
description: Generate, apply, and manage Prisma database migrations from schema changes. Use when running migrations, deploying schema changes, resetting databases, or recovering from failed migrations.
---

# Prisma Migrate

Generate versioned SQL migrations from schema changes and apply them to your database.

## When to Use

- After editing `prisma/schema.prisma` to apply changes to the database
- Deploying schema changes to production or staging
- Resetting a development database to a clean state
- Recovering from a failed or partially applied migration
- Prototyping rapidly without migration files (`db push`)
- Adopting Prisma on an existing database (`db pull`)

## Workflow

### Development
1. Edit `prisma/schema.prisma`
2. Run `npx prisma migrate dev --name descriptive-name`
3. Migration SQL is generated in `prisma/migrations/<timestamp>_<name>/migration.sql`
4. Migration is applied to dev database
5. Prisma Client is regenerated automatically

### Production
1. Commit migration files to version control
2. In CI/CD or deployment: run `npx prisma migrate deploy`
3. All pending migrations are applied sequentially

## Command Reference

```bash
# Development: create + apply migration
npx prisma migrate dev --name add-user-table

# Development: create migration without applying
npx prisma migrate dev --create-only --name add-user-table

# Production: apply pending migrations
npx prisma migrate deploy

# Check migration status
npx prisma migrate status

# Reset database (drop + reapply all + seed)
npx prisma migrate reset

# Prototype: push schema directly (no migration files)
npx prisma db push

# Introspect existing database into schema
npx prisma db pull

# Run raw SQL file
npx prisma db execute --file ./script.sql
```

## Editing Migrations Before Applying

Use `--create-only` to generate the SQL without applying:

```bash
npx prisma migrate dev --create-only --name add-user-table
# Edit prisma/migrations/<timestamp>_add_user_table/migration.sql
# Add custom SQL: data transforms, triggers, views, etc.
npx prisma migrate dev  # Now apply the edited migration
```

## Recovery

If a migration fails partway through:

```bash
# Check what's wrong
npx prisma migrate status

# After manually fixing the database, mark as applied
npx prisma migrate resolve --applied 20240101120000_name

# Or mark as rolled back to retry
npx prisma migrate resolve --rolled-back 20240101120000_name
```

## db push vs migrate dev

| Feature | `migrate dev` | `db push` |
|---------|--------------|-----------|
| Creates migration files | Yes | No |
| Uses shadow database | Yes | No |
| Production-safe | Via `migrate deploy` | No |
| Handles data loss | Warns, creates migration | `--accept-data-loss` flag |
| Best for | Reproducible deployments | Rapid prototyping |

## Edge Cases

- Shadow database requires `CREATE DATABASE` permissions — if you can't create DBs, use `db push`
- MongoDB does not support migrations — always use `db push`
- Never run `migrate dev` in production — use `migrate deploy`
- `migrate reset` drops ALL data — development only
- Migration files are pure SQL — they can be edited but should remain idempotent
- If `migration_lock.toml` provider doesn't match your datasource, you'll get P3019
- Renaming a field generates DROP + ADD by default — use `--create-only` and edit the SQL to use `ALTER TABLE RENAME COLUMN` to preserve data
- After `migrate reset`, the seed script runs automatically (unless `--skip-seed`)
