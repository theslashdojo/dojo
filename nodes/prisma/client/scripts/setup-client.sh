#!/usr/bin/env bash
set -euo pipefail

# Setup Prisma Client
# Creates a singleton client module and generates the Prisma Client
# Requires: DATABASE_URL (env)
# Packages: prisma, @prisma/client

if [ -z "${DATABASE_URL:-}" ]; then
  echo "Error: DATABASE_URL environment variable is required"
  exit 1
fi

# Check if schema exists
if [ ! -f "prisma/schema.prisma" ]; then
  echo "Error: prisma/schema.prisma not found"
  echo "Run 'npx prisma init' first or create the schema"
  exit 1
fi

# Install packages if needed
if ! npm list @prisma/client &>/dev/null 2>&1; then
  echo "Installing @prisma/client..."
  npm install @prisma/client
fi

if ! npm list prisma --dev &>/dev/null 2>&1; then
  echo "Installing prisma (dev)..."
  npm install prisma --save-dev
fi

# Generate the Prisma Client
echo "Generating Prisma Client..."
npx prisma generate

# Create singleton module if it doesn't exist
SINGLETON_DIR="lib"
SINGLETON_FILE="${SINGLETON_DIR}/prisma.ts"

if [ ! -f "$SINGLETON_FILE" ]; then
  mkdir -p "$SINGLETON_DIR"
  cat > "$SINGLETON_FILE" << 'TYPESCRIPT'
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
TYPESCRIPT
  echo "Created singleton client at ${SINGLETON_FILE}"
else
  echo "Singleton client already exists at ${SINGLETON_FILE}"
fi

echo ""
echo "Prisma Client setup complete!"
echo "  Import: import { prisma } from './lib/prisma';"
echo "  Usage:  const users = await prisma.user.findMany();"
