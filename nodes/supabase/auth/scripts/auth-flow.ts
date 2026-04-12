import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

async function main() {
  const email = process.argv[2] || 'test@example.com';
  const password = process.argv[3] || 'testpassword123';

  // Sign up
  console.log('Signing up...');
  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
    email,
    password,
  });

  if (signUpError) {
    console.error('Sign up error:', signUpError.message);
  } else {
    console.log('User created:', signUpData.user?.id);
  }

  // Sign in
  console.log('Signing in...');
  const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (signInError) {
    console.error('Sign in error:', signInError.message);
  } else {
    console.log('Signed in as:', signInData.user?.email);
    console.log('Access token:', signInData.session?.access_token.slice(0, 20) + '...');
  }

  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (user) {
    console.log('Current user:', user.id, user.email);
  }

  // Sign out
  await supabase.auth.signOut();
  console.log('Signed out.');
}

main().catch(console.error);
