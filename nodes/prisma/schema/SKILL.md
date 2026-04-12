---
name: schema
description: Define Prisma data models, datasources, generators, enums, and relations in schema.prisma. Use when creating or modifying a Prisma schema file, adding models/fields/enums, or configuring database connections.
---

# Prisma Schema

Define your data model in `prisma/schema.prisma` — the single source of truth for your database structure.

## When to Use

- Initializing Prisma in a new project
- Adding or modifying database models
- Adding fields, indexes, or constraints to existing models
- Defining enums for constrained value sets
- Configuring the datasource or generator
- Setting up relations between models

## Workflow

1. Locate or create `prisma/schema.prisma`
2. Configure the `datasource` block with provider and connection URL
3. Configure the `generator` block (usually `prisma-client-js`)
4. Define models with fields, types, and attributes
5. Add relations between models using `@relation`
6. Add indexes with `@@index` for query performance
7. Validate with `npx prisma validate`
8. Format with `npx prisma format`
9. Apply changes with `npx prisma migrate dev --name <name>` or `npx prisma db push`

## Schema Structure

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String?
  role      Role     @default(USER)
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        Int      @id @default(autoincrement())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  Int
  createdAt DateTime @default(now())

  @@index([authorId])
}

enum Role {
  USER
  ADMIN
}
```

## Field Types

- **String** — text data
- **Int** — 32-bit integer
- **BigInt** — 64-bit integer
- **Float** — floating point
- **Decimal** — exact decimal
- **Boolean** — true/false
- **DateTime** — timestamp
- **Json** — JSON data (not available on SQLite)
- **Bytes** — binary data

Modifiers: `?` = optional/nullable, `[]` = list/array

## Key Attributes

### Field-Level
- `@id` — primary key
- `@unique` — unique constraint
- `@default(value)` — default: `autoincrement()`, `uuid()`, `cuid()`, `now()`, `dbgenerated("expr")`
- `@updatedAt` — auto-updates on every save
- `@relation(fields: [fk], references: [pk])` — define foreign key relation
- `@map("column_name")` — custom column name in DB
- `@db.VarChar(255)` — native type annotation

### Block-Level
- `@@id([field1, field2])` — composite primary key
- `@@unique([field1, field2])` — composite unique constraint
- `@@index([field1, field2])` — database index
- `@@map("table_name")` — custom table name in DB

## Relation Patterns

### One-to-Many
```prisma
model User {
  posts Post[]
}
model Post {
  author   User @relation(fields: [authorId], references: [id])
  authorId Int
}
```

### One-to-One
```prisma
model User {
  profile Profile?
}
model Profile {
  user   User @relation(fields: [userId], references: [id])
  userId Int  @unique
}
```

### Many-to-Many (implicit)
```prisma
model Post { tags Tag[] }
model Tag  { posts Post[] }
```

### Self-Relation
```prisma
model Employee {
  id           Int        @id @default(autoincrement())
  manager      Employee?  @relation("Management", fields: [managerId], references: [id])
  managerId    Int?
  subordinates Employee[] @relation("Management")
}
```

## Referential Actions

On `@relation`: `onDelete: Cascade | Restrict | NoAction | SetNull | SetDefault`

```prisma
model Post {
  author   User @relation(fields: [authorId], references: [id], onDelete: Cascade)
  authorId Int
}
```

## Edge Cases

- Only one `datasource` block is allowed per schema
- `@unique` on a relation scalar field makes the relation one-to-one
- MongoDB requires `@map("_id")` on the id field and `@db.ObjectId` for ObjectId types
- Composite primary keys (`@@id`) cannot use `autoincrement()`
- Self-relations require a named relation string to disambiguate
- Multiple relations between the same two models require distinct relation names
- `@updatedAt` only works on `DateTime` fields
- `Json` type is not available on SQLite
