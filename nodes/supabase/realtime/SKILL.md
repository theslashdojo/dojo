---
name: realtime
description: Subscribe to Supabase Realtime events — Postgres changes, broadcast messages, and presence tracking via WebSocket. Use when building live features like notifications, chat, collaborative editing, or online indicators.
---

# Supabase Realtime

## When to Use
- Displaying live database updates (new posts, comments, etc.)
- Building chat or messaging features
- Tracking online/offline users
- Collaborative editing (cursors, typing indicators)
- Broadcasting ephemeral events between clients

## Prerequisites
- Supabase client initialized (see supabase/client)
- For Postgres Changes: table added to realtime publication

## Three Features

### 1. Postgres Changes
Listen for INSERT/UPDATE/DELETE on tables:
```typescript
const channel = supabase
  .channel('db-changes')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'messages',
  }, (payload) => {
    console.log(payload.eventType, payload.new);
  })
  .subscribe();
```

**Required SQL** (in migration):
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

### 2. Broadcast
Send/receive ephemeral messages:
```typescript
const channel = supabase.channel('room');
channel.on('broadcast', { event: 'typing' }, (payload) => {
  console.log(payload.payload);
});
channel.subscribe();
channel.send({ type: 'broadcast', event: 'typing', payload: { user: 'Alice' } });
```

### 3. Presence
Track online users:
```typescript
const channel = supabase.channel('online');
channel.on('presence', { event: 'sync' }, () => {
  console.log(channel.presenceState());
});
channel.subscribe(async (status) => {
  if (status === 'SUBSCRIBED') {
    await channel.track({ user_id: userId, online: true });
  }
});
```

## Critical Rules

1. **Add table to publication** — Postgres Changes won't work without `ALTER PUBLICATION supabase_realtime ADD TABLE x`
2. **RLS applies to Postgres Changes** — users only receive events for rows they can SELECT
3. **Broadcast has NO RLS** — any subscriber in the channel receives all messages
4. **Unsubscribe when done** — `supabase.removeChannel(channel)` to avoid memory leaks
5. **One channel, multiple features** — combine Postgres changes + broadcast + presence on one channel

## Edge Cases

### No events received
1. Check publication: `SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';`
2. Check RLS: user must have SELECT policy on the table
3. Check subscription status — wait for 'SUBSCRIBED' before expecting events

### Reconnection
The client auto-reconnects on disconnect. Events during disconnection are missed — use database queries to catch up.
