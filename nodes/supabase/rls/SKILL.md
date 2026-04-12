---
name: rls
description: Write Row Level Security policies for Supabase Postgres tables using auth.uid() and auth.jwt(). Use when securing tables, controlling per-user data access, or debugging access issues.
---

# Row Level Security (RLS)

## When to Use
- Securing a new table so users can only access their own data
- Adding public read access while restricting writes
- Implementing team/organization-based access control
- Debugging why queries return empty results
- Setting up role-based access via JWT claims

## Prerequisites
- Table exists in Postgres (see supabase/migrations)
- Auth configured (see supabase/auth)
- Understanding of Postgres SQL

## Workflow

### 1. Enable RLS
```sql
ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;
```

### 2. Add policies
```sql
-- Users read own data
CREATE POLICY "select_own" ON my_table
  FOR SELECT USING (auth.uid() = user_id);

-- Users insert own data
CREATE POLICY "insert_own" ON my_table
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users update own data
CREATE POLICY "update_own" ON my_table
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users delete own data
CREATE POLICY "delete_own" ON my_table
  FOR DELETE USING (auth.uid() = user_id);
```

### 3. Test
```typescript
// Should return only user's own rows
const { data } = await supabase.from('my_table').select('*');
```

## Critical Rules

1. **Enable RLS on every table with user data** — otherwise it's publicly accessible
2. **RLS enabled + no policies = zero rows** — always add policies after enabling
3. **USING = read filter, WITH CHECK = write validation**
4. **UPDATE needs both USING and WITH CHECK**
5. **Multiple policies on same operation are ORed** — any matching policy grants access
6. **Index columns used in policies** for performance
7. **Service role key bypasses all RLS** — never expose to client

## Debugging

If queries return empty results:
1. Check RLS is enabled: `SELECT relrowsecurity FROM pg_class WHERE relname = 'table_name';`
2. List policies: `SELECT * FROM pg_policies WHERE tablename = 'table_name';`
3. Check the user is authenticated: `auth.uid()` returns null for anon requests
4. Test in SQL editor with: `SET request.jwt.claims = '{"sub":"user-id","role":"authenticated"}';`
