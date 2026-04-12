#!/usr/bin/env bash
set -euo pipefail

# Initialize a new Supabase project and start local services
# Requires: Docker running, supabase CLI installed

if ! command -v supabase &>/dev/null; then
  echo "Installing Supabase CLI..."
  npm install -g supabase
fi

if ! docker info &>/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Start Docker and try again."
  exit 1
fi

# Initialize if not already initialized
if [ ! -f "supabase/config.toml" ]; then
  echo "Initializing Supabase project..."
  supabase init
else
  echo "Supabase project already initialized."
fi

# Start local services
echo "Starting local Supabase stack..."
supabase start

echo ""
echo "Local Supabase is running. Use 'supabase status' to see URLs and keys."
echo "Studio: http://localhost:54323"
