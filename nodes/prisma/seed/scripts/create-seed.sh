#!/usr/bin/env bash
set -euo pipefail

# Create a Prisma seed script
# Generates prisma/seed.ts and configures package.json
# Requires: DATABASE_URL (env)
# Packages: prisma, @prisma/client, tsx

if [ -z "${DATABASE_URL:-}" ]; then
  echo "Error: DATABASE_URL environment variable is required"
  exit 1
fi

# Check if schema exists
if [ ! -f "prisma/schema.prisma" ]; then
  echo "Error: prisma/schema.prisma not found. Initialize Prisma first."
  exit 1
fi

# Install tsx if needed
if ! npm list tsx --dev &>/dev/null 2>&1; then
  echo "Installing tsx..."
  npm install tsx --save-dev
fi

# Create seed file if it doesn't exist
SEED_FILE="prisma/seed.ts"
if [ ! -f "$SEED_FILE" ]; then
  cat > "$SEED_FILE" << 'TYPESCRIPT'
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // TODO: Replace with your seed data
  // Use upsert for idempotent seeds (safe to run multiple times)

  console.log('Seeding database...');

  // Example: seed a user
  // const user = await prisma.user.upsert({
  //   where: { email: 'admin@example.com' },
  //   update: {},
  //   create: {
  //     email: 'admin@example.com',
  //     name: 'Admin',
  //   },
  // });

  console.log('Seed complete');
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
TYPESCRIPT
  echo "Created seed file at ${SEED_FILE}"
else
  echo "Seed file already exists at ${SEED_FILE}"
fi

# Add seed command to package.json if not present
if [ -f "package.json" ]; then
  if ! grep -q '"prisma"' package.json 2>/dev/null || ! grep -q '"seed"' package.json 2>/dev/null; then
    # Use node to safely modify package.json
    node -e "
      const pkg = require('./package.json');
      if (!pkg.prisma) pkg.prisma = {};
      if (!pkg.prisma.seed) {
        pkg.prisma.seed = 'tsx prisma/seed.ts';
        require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        console.log('Added prisma.seed to package.json');
      } else {
        console.log('prisma.seed already configured in package.json');
      }
    "
  fi
fi

echo ""
echo "Seed setup complete!"
echo "  Edit: prisma/seed.ts"
echo "  Run:  npx prisma db seed"
