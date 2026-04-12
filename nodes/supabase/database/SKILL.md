---
name: database
description: Query Supabase Postgres via the PostgREST query builder — select, insert, update, delete, filters, joins, and RPC. Use when reading or writing data through the Supabase client SDK.
---

# Supabase Database Queries

## When to Use
- Reading data from Supabase tables
- Creating, updating, or deleting records
- Filtering, ordering, and paginating results
- Joining related tables via foreign keys
- Calling Postgres functions via RPC

## Prerequisites
- Supabase client initialized (see supabase/client)
- Tables created via migrations (see supabase/migrations)
- RLS policies in place (see supabase/rls)

## Quick Reference

### Select
```typescript
const { data, error } = await supabase.from('posts').select('*');
const { data } = await supabase.from('posts').select('id, title').eq('published', true).order('created_at', { ascending: false }).limit(10);
const { data } = await supabase.from('posts').select('*').eq('id', id).single();
```

### Insert
```typescript
const { data, error } = await supabase.from('posts').insert({ title: 'New Post' }).select();
```

### Update
```typescript
const { data, error } = await supabase.from('posts').update({ title: 'Updated' }).eq('id', id).select();
```

### Delete
```typescript
const { error } = await supabase.from('posts').delete().eq('id', id);
```

### Joins
```typescript
const { data } = await supabase.from('posts').select('*, author:profiles(name), comments(id, body)');
```

### RPC
```typescript
const { data } = await supabase.rpc('search_posts', { query: 'hello' });
```

## Critical Rules

1. **Always check `error`** — the SDK never throws exceptions
2. **Chain `.select()` after mutations** — otherwise you get no data back
3. **Use `.single()` carefully** — it errors if 0 or 2+ rows match
4. **Filters on update/delete are mandatory** — PostgREST rejects unfiltered bulk mutations
5. **RLS applies automatically** — with anon key, users only see data their policies allow

## Common Patterns

### Pagination
```typescript
const PAGE_SIZE = 20;
const page = 0;
const { data, count } = await supabase
  .from('posts')
  .select('*', { count: 'exact' })
  .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
```

### Search
```typescript
const { data } = await supabase
  .from('posts')
  .select('*')
  .textSearch('title', query, { type: 'websearch' });
```

### OR conditions
```typescript
const { data } = await supabase
  .from('posts')
  .select('*')
  .or('status.eq.published,status.eq.featured');
```
