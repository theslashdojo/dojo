/**
 * Drizzle Query Examples
 *
 * Demonstrates common Drizzle ORM query patterns: CRUD, joins,
 * aggregations, transactions, and the relational query API.
 *
 * Usage:
 *   DATABASE_URL=postgres://user:pass@localhost:5432/mydb npx tsx query-examples.ts
 *
 * Prerequisites:
 *   - A running PostgreSQL database with tables created via drizzle-kit migrate
 *   - npm install drizzle-orm postgres
 */

import { drizzle } from 'drizzle-orm/postgres-js';
import {
  eq, and, or, gt, lt, gte, lte, like, ilike, inArray, isNull,
  desc, asc, sql, count, sum, avg, min, max, between, not,
} from 'drizzle-orm';
import postgres from 'postgres';
import {
  pgTable, serial, integer, text, varchar, boolean, timestamp, index,
} from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

// ─── Schema (inline for self-contained example) ─────
const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  role: text('role').default('user'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 256 }).notNull(),
  content: text('content'),
  published: boolean('published').default(false),
  authorId: integer('author_id').references(() => users.id).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('posts_author_idx').on(table.authorId),
]);

const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, { fields: [posts.authorId], references: [users.id] }),
}));

// ─── Connect ────────────────────────────────────────
const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('DATABASE_URL environment variable is required.');
  process.exit(1);
}

const client = postgres(connectionString);
const db = drizzle(client, {
  schema: { users, posts, usersRelations, postsRelations },
});

async function main() {
  console.log('=== Drizzle Query Examples ===\n');

  // ─── INSERT ─────────────────────────────────────
  console.log('--- Insert ---');

  // Single insert with returning
  const [user1] = await db.insert(users)
    .values({ name: 'Dan', email: 'dan@example.com', role: 'admin' })
    .returning();
  console.log('Inserted user:', user1);

  // Batch insert
  const newUsers = await db.insert(users)
    .values([
      { name: 'Alice', email: 'alice@example.com' },
      { name: 'Bob', email: 'bob@example.com' },
    ])
    .returning();
  console.log('Batch inserted:', newUsers.length, 'users');

  // Insert posts
  await db.insert(posts).values([
    { title: 'Hello World', content: 'First post', published: true, authorId: user1.id },
    { title: 'Draft Post', content: 'Not published yet', published: false, authorId: user1.id },
    { title: 'Alice Post', content: 'From Alice', published: true, authorId: newUsers[0].id },
  ]);

  // Upsert
  await db.insert(users)
    .values({ name: 'Dan Updated', email: 'dan@example.com' })
    .onConflictDoUpdate({ target: users.email, set: { name: 'Dan Updated' } });

  // ─── SELECT ─────────────────────────────────────
  console.log('\n--- Select ---');

  // All users
  const allUsers = await db.select().from(users);
  console.log('All users:', allUsers.length);

  // Partial select
  const names = await db.select({ id: users.id, name: users.name }).from(users);
  console.log('Names:', names);

  // Where with filter
  const admins = await db.select().from(users).where(eq(users.role, 'admin'));
  console.log('Admins:', admins.length);

  // AND / OR
  const filtered = await db.select().from(users).where(
    and(
      or(eq(users.role, 'admin'), eq(users.role, 'user')),
      gt(users.createdAt, new Date('2020-01-01'))
    )
  );
  console.log('Filtered:', filtered.length);

  // LIKE / ILIKE
  const searched = await db.select().from(users).where(ilike(users.name, '%dan%'));
  console.log('Search "dan":', searched.length);

  // IN array
  const specific = await db.select().from(users)
    .where(inArray(users.id, [user1.id, newUsers[0].id]));
  console.log('Specific users:', specific.length);

  // Order + limit + offset
  const paginated = await db.select().from(users)
    .orderBy(desc(users.createdAt))
    .limit(2)
    .offset(0);
  console.log('Page 1:', paginated.map(u => u.name));

  // ─── JOINS ──────────────────────────────────────
  console.log('\n--- Joins ---');

  const usersWithPosts = await db.select({
    userName: users.name,
    postTitle: posts.title,
  }).from(users)
    .innerJoin(posts, eq(users.id, posts.authorId))
    .where(eq(posts.published, true));
  console.log('Published posts with authors:', usersWithPosts);

  // Left join (includes users without posts)
  const allWithPosts = await db.select({
    userName: users.name,
    postTitle: posts.title,
  }).from(users)
    .leftJoin(posts, eq(users.id, posts.authorId));
  console.log('All users with posts (left join):', allWithPosts.length);

  // ─── AGGREGATIONS ───────────────────────────────
  console.log('\n--- Aggregations ---');

  const userCount = await db.$count(users);
  console.log('Total users:', userCount);

  const postsByAuthor = await db.select({
    authorId: posts.authorId,
    postCount: count(),
  }).from(posts)
    .groupBy(posts.authorId);
  console.log('Posts by author:', postsByAuthor);

  // ─── RELATIONAL QUERIES ─────────────────────────
  console.log('\n--- Relational Queries ---');

  const usersNested = await db.query.users.findMany({
    with: {
      posts: {
        where: eq(posts.published, true),
        orderBy: desc(posts.createdAt),
      },
    },
  });
  console.log('Users with published posts:');
  for (const u of usersNested) {
    console.log(`  ${u.name}: ${u.posts.length} published posts`);
  }

  const singleUser = await db.query.users.findFirst({
    where: eq(users.email, 'dan@example.com'),
    columns: { id: true, name: true, email: true },
    with: { posts: true },
  });
  console.log('Single user:', singleUser?.name, 'with', singleUser?.posts.length, 'posts');

  // ─── TRANSACTIONS ───────────────────────────────
  console.log('\n--- Transactions ---');

  await db.transaction(async (tx) => {
    const [newUser] = await tx.insert(users)
      .values({ name: 'TxUser', email: 'tx@example.com' })
      .returning();
    await tx.insert(posts)
      .values({ title: 'Transaction Post', authorId: newUser.id, published: true });
    console.log('Transaction committed: user', newUser.id);
  });

  // ─── UPDATE ─────────────────────────────────────
  console.log('\n--- Update ---');

  const [updated] = await db.update(users)
    .set({ name: 'Mr. Dan' })
    .where(eq(users.email, 'dan@example.com'))
    .returning();
  console.log('Updated:', updated.name);

  // ─── DELETE ─────────────────────────────────────
  console.log('\n--- Delete ---');

  const [deleted] = await db.delete(users)
    .where(eq(users.email, 'tx@example.com'))
    .returning();
  console.log('Deleted:', deleted.name);

  // ─── RAW SQL ────────────────────────────────────
  console.log('\n--- Raw SQL ---');

  const rawResult = await db.select({
    name: users.name,
    nameLength: sql<number>`length(${users.name})`,
  }).from(users)
    .orderBy(sql`length(${users.name}) DESC`)
    .limit(3);
  console.log('Longest names:', rawResult);

  // ─── Cleanup ────────────────────────────────────
  await db.delete(posts);
  await db.delete(users);
  console.log('\nCleanup complete.');

  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
