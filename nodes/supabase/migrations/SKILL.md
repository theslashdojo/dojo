---
name: migrations
description: Create and manage Supabase database migrations — tables, columns, indexes, RLS policies, functions, and seed data. Use when modifying the database schema or syncing schema between local and remote.
---

# Supabase Migrations

## When to Use
- Creating new tables
- Adding/modifying columns, indexes, or constraints
- Defining RLS policies as part of schema setup
- Syncing schema between local and remote environments
- Seeding test data for development

## Prerequisites
- Supabase CLI installed (see supabase/cli)
- Project initialized with `supabase init`

## Workflow

### Create a New Table
```bash
# 1. Create migration file
supabase migration new create_posts_table

# 2. Write SQL in the generated file
# supabase/migrations/YYYYMMDDHHMMSS_create_posts_table.sql

# 3. Apply locally
supabase db reset

# 4. Test, then push to remote
supabase db push

# 5. Regenerate types
supabase gen types typescript --local > src/types/supabase.ts
```

### Migration Template
```sql
-- Create table
CREATE TABLE posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  body text,
  published boolean DEFAULT false,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "select_own" ON posts FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "insert_own" ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "update_own" ON posts FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "delete_own" ON posts FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
```

## Critical Rules

1. **Never edit an applied migration** — create a new one
2. **Always include RLS** when creating tables with user data
3. **Always add indexes** on foreign keys and RLS filter columns
4. **Test with `supabase db reset`** before `supabase db push`
5. **One concern per migration** — don't mix unrelated changes

## Edge Cases

### Migration fails on push
Check the error message. Common causes: conflicting column names, missing referenced tables, duplicate policy names. Fix in a new migration.

### Schema drift
If remote schema was changed manually, run `supabase db pull` to capture those changes as a migration, then commit.

### Seed data conflicts
Use `ON CONFLICT DO NOTHING` in seed.sql to make seeds idempotent.
