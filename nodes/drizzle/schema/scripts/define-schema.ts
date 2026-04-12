/**
 * Drizzle Schema Generator
 *
 * Generates a Drizzle ORM schema file with tables, columns, indexes,
 * and enums for PostgreSQL, MySQL, or SQLite.
 *
 * Usage:
 *   DRIZZLE_DIALECT=postgresql npx tsx define-schema.ts
 *
 * Environment:
 *   DRIZZLE_DIALECT - postgresql (default), mysql, or sqlite
 *
 * Output: Prints a starter schema to stdout. Redirect to a file:
 *   npx tsx define-schema.ts > src/db/schema.ts
 */

const dialect = (process.env.DRIZZLE_DIALECT || 'postgresql') as 'postgresql' | 'mysql' | 'sqlite';

const schemas: Record<string, string> = {
  postgresql: `import {
  pgTable,
  pgEnum,
  serial,
  integer,
  text,
  varchar,
  boolean,
  timestamp,
  jsonb,
  index,
  uniqueIndex,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

// ─── Enums ──────────────────────────────────────────
export const roleEnum = pgEnum('role', ['user', 'admin', 'moderator']);

// ─── Users ──────────────────────────────────────────
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  role: roleEnum('role').default('user'),
  bio: text('bio'),
  metadata: jsonb('metadata'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (table) => [
  index('users_email_idx').on(table.email),
]);

// ─── Posts ──────────────────────────────────────────
export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 256 }).notNull(),
  content: text('content'),
  slug: varchar('slug', { length: 256 }).unique(),
  published: boolean('published').default(false),
  authorId: integer('author_id')
    .references(() => users.id, { onDelete: 'cascade' })
    .notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('posts_author_idx').on(table.authorId),
  index('posts_slug_idx').on(table.slug),
]);

// ─── Tags (many-to-many) ────────────────────────────
export const tags = pgTable('tags', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 64 }).notNull().unique(),
});

export const postsToTags = pgTable('posts_to_tags', {
  postId: integer('post_id')
    .references(() => posts.id, { onDelete: 'cascade' })
    .notNull(),
  tagId: integer('tag_id')
    .references(() => tags.id, { onDelete: 'cascade' })
    .notNull(),
}, (table) => [
  primaryKey({ columns: [table.postId, table.tagId] }),
]);

// ─── Relations ──────────────────────────────────────
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one, many }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
  postsToTags: many(postsToTags),
}));

export const tagsRelations = relations(tags, ({ many }) => ({
  postsToTags: many(postsToTags),
}));

export const postsToTagsRelations = relations(postsToTags, ({ one }) => ({
  post: one(posts, {
    fields: [postsToTags.postId],
    references: [posts.id],
  }),
  tag: one(tags, {
    fields: [postsToTags.tagId],
    references: [tags.id],
  }),
}));
`,

  mysql: `import {
  mysqlTable,
  mysqlEnum,
  serial,
  int,
  varchar,
  text,
  boolean,
  timestamp,
  json,
  index,
  primaryKey,
} from 'drizzle-orm/mysql-core';
import { relations } from 'drizzle-orm';

// ─── Users ──────────────────────────────────────────
export const users = mysqlTable('users', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 256 }).notNull(),
  email: varchar('email', { length: 256 }).notNull().unique(),
  role: mysqlEnum('role', ['user', 'admin', 'moderator']).default('user'),
  bio: text('bio'),
  metadata: json('metadata'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

// ─── Posts ──────────────────────────────────────────
export const posts = mysqlTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 256 }).notNull(),
  content: text('content'),
  slug: varchar('slug', { length: 256 }).unique(),
  published: boolean('published').default(false),
  authorId: int('author_id')
    .references(() => users.id)
    .notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('posts_author_idx').on(table.authorId),
]);

// ─── Tags (many-to-many) ────────────────────────────
export const tags = mysqlTable('tags', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 64 }).notNull().unique(),
});

export const postsToTags = mysqlTable('posts_to_tags', {
  postId: int('post_id')
    .references(() => posts.id)
    .notNull(),
  tagId: int('tag_id')
    .references(() => tags.id)
    .notNull(),
}, (table) => [
  primaryKey({ columns: [table.postId, table.tagId] }),
]);

// ─── Relations ──────────────────────────────────────
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one, many }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
  postsToTags: many(postsToTags),
}));

export const tagsRelations = relations(tags, ({ many }) => ({
  postsToTags: many(postsToTags),
}));

export const postsToTagsRelations = relations(postsToTags, ({ one }) => ({
  post: one(posts, {
    fields: [postsToTags.postId],
    references: [posts.id],
  }),
  tag: one(tags, {
    fields: [postsToTags.tagId],
    references: [tags.id],
  }),
}));
`,

  sqlite: `import {
  sqliteTable,
  integer,
  text,
  index,
  primaryKey,
} from 'drizzle-orm/sqlite-core';
import { sql, relations } from 'drizzle-orm';

// ─── Users ──────────────────────────────────────────
export const users = sqliteTable('users', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  role: text('role').$type<'user' | 'admin' | 'moderator'>().default('user'),
  bio: text('bio'),
  metadata: text('metadata', { mode: 'json' }),
  createdAt: text('created_at').default(sql\`(CURRENT_TIMESTAMP)\`).notNull(),
  updatedAt: text('updated_at').default(sql\`(CURRENT_TIMESTAMP)\`).notNull(),
});

// ─── Posts ──────────────────────────────────────────
export const posts = sqliteTable('posts', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  title: text('title').notNull(),
  content: text('content'),
  slug: text('slug').unique(),
  published: integer('published', { mode: 'boolean' }).default(false),
  authorId: integer('author_id')
    .references(() => users.id, { onDelete: 'cascade' })
    .notNull(),
  createdAt: text('created_at').default(sql\`(CURRENT_TIMESTAMP)\`).notNull(),
}, (table) => [
  index('posts_author_idx').on(table.authorId),
]);

// ─── Tags (many-to-many) ────────────────────────────
export const tags = sqliteTable('tags', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull().unique(),
});

export const postsToTags = sqliteTable('posts_to_tags', {
  postId: integer('post_id')
    .references(() => posts.id, { onDelete: 'cascade' })
    .notNull(),
  tagId: integer('tag_id')
    .references(() => tags.id, { onDelete: 'cascade' })
    .notNull(),
}, (table) => [
  primaryKey({ columns: [table.postId, table.tagId] }),
]);

// ─── Relations ──────────────────────────────────────
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one, many }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
  postsToTags: many(postsToTags),
}));

export const tagsRelations = relations(tags, ({ many }) => ({
  postsToTags: many(postsToTags),
}));

export const postsToTagsRelations = relations(postsToTags, ({ one }) => ({
  post: one(posts, {
    fields: [postsToTags.postId],
    references: [posts.id],
  }),
  tag: one(tags, {
    fields: [postsToTags.tagId],
    references: [tags.id],
  }),
}));
`,
};

const schema = schemas[dialect];
if (!schema) {
  console.error(`Unknown dialect: ${dialect}. Use postgresql, mysql, or sqlite.`);
  process.exit(1);
}

console.log(schema);
