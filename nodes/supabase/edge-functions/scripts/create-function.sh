#!/usr/bin/env bash
set -euo pipefail

# Create a new Supabase edge function with CORS and auth boilerplate
# Usage: ./create-function.sh <function-name>

FUNC_NAME="${1:?Usage: create-function.sh <function-name>}"

# Create the function
supabase functions new "$FUNC_NAME"

FUNC_DIR="supabase/functions/${FUNC_NAME}"

# Write boilerplate with CORS and auth
cat > "${FUNC_DIR}/index.ts" << 'EOTS'
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Create client with caller's JWT (respects RLS)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    // Verify the caller is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse request body
    const body = await req.json();

    // Your logic here
    const result = { message: 'Hello from edge function!', userId: user.id };

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
EOTS

echo "Created edge function: ${FUNC_DIR}/index.ts"
echo "Next steps:"
echo "  supabase functions serve          # Local development"
echo "  supabase functions deploy ${FUNC_NAME}  # Deploy"
