import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

async function main() {
  // Select all posts
  const { data: posts, error: selectError } = await supabase
    .from('posts')
    .select('id, title, created_at')
    .order('created_at', { ascending: false })
    .limit(10);

  if (selectError) {
    console.error('Select error:', selectError.message);
  } else {
    console.log('Posts:', posts);
  }

  // Insert a post
  const { data: newPost, error: insertError } = await supabase
    .from('posts')
    .insert({ title: 'Test Post', body: 'Created by script' })
    .select()
    .single();

  if (insertError) {
    console.error('Insert error:', insertError.message);
  } else {
    console.log('Created:', newPost);

    // Update the post
    const { data: updated, error: updateError } = await supabase
      .from('posts')
      .update({ title: 'Updated Test Post' })
      .eq('id', newPost.id)
      .select()
      .single();

    if (updateError) {
      console.error('Update error:', updateError.message);
    } else {
      console.log('Updated:', updated);
    }

    // Delete the post
    const { error: deleteError } = await supabase
      .from('posts')
      .delete()
      .eq('id', newPost.id);

    if (deleteError) {
      console.error('Delete error:', deleteError.message);
    } else {
      console.log('Deleted post', newPost.id);
    }
  }

  // RPC example
  const { data: rpcResult, error: rpcError } = await supabase
    .rpc('get_post_count');

  if (!rpcError) {
    console.log('Post count:', rpcResult);
  }
}

main().catch(console.error);
