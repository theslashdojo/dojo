#!/usr/bin/env bash
set -euo pipefail

# Initialize Prisma Schema
# Requires: DATABASE_URL (env), optionally PRISMA_PROVIDER (default: postgresql)
# Packages: prisma, @prisma/client

PROVIDER="${PRISMA_PROVIDER:-postgresql}"

# Check if prisma is installed
if ! npx prisma --version &>/dev/null; then
  echo "Installing prisma and @prisma/client..."
  npm install prisma --save-dev
  npm install @prisma/client
fi

# Check if schema already exists
if [ -f "prisma/schema.prisma" ]; then
  echo "prisma/schema.prisma already exists."
  echo "Validating existing schema..."
  npx prisma validate
  echo "Schema is valid."
  exit 0
fi

# Initialize Prisma with the specified provider
echo "Initializing Prisma with provider: ${PROVIDER}"
npx prisma init --datasource-provider "$PROVIDER"

echo ""
echo "Prisma initialized successfully!"
echo "  Schema: prisma/schema.prisma"
echo "  Provider: ${PROVIDER}"
echo ""
echo "Next steps:"
echo "  1. Set DATABASE_URL in your .env file"
echo "  2. Edit prisma/schema.prisma to define your models"
echo "  3. Run: npx prisma migrate dev --name init"
