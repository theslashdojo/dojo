import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY! });

async function embedAndStore(text: string, metadata: Record<string, unknown> = {}) {
  const embeddingResponse = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  });

  const { error } = await supabase.from('documents').insert({
    content: text,
    metadata,
    embedding: embeddingResponse.data[0].embedding,
  });

  if (error) {
    console.error('Insert error:', error.message);
    return;
  }

  console.log('Stored document:', text.slice(0, 80) + '...');
}

async function search(query: string, threshold = 0.78, count = 5) {
  // Generate embedding for the query
  const embeddingResponse = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: query,
  });

  // Search for similar documents
  const { data, error } = await supabase.rpc('match_documents', {
    query_embedding: embeddingResponse.data[0].embedding,
    match_threshold: threshold,
    match_count: count,
  });

  if (error) {
    console.error('Search error:', error.message);
    return [];
  }

  return data;
}

async function main() {
  const command = process.argv[2];
  const text = process.argv[3];

  if (command === 'store' && text) {
    await embedAndStore(text);
  } else if (command === 'search' && text) {
    const results = await search(text);
    console.log(`Found ${results.length} results:`);
    for (const doc of results) {
      console.log(`  [${doc.similarity.toFixed(3)}] ${doc.content.slice(0, 100)}`);
    }
  } else {
    console.log('Usage:');
    console.log('  npx tsx vector-search.ts store "Your text here"');
    console.log('  npx tsx vector-search.ts search "Your query here"');
  }
}

main().catch(console.error);
