---
name: vectors
description: Store and search vector embeddings in Supabase Postgres using pgvector — similarity search, RAG pipelines, and semantic search. Use when building AI-powered search, recommendations, or retrieval-augmented generation.
---

# Supabase Vectors (pgvector)

## When to Use
- Storing text/image embeddings for similarity search
- Building RAG (Retrieval-Augmented Generation) pipelines
- Implementing semantic search over documents
- Creating recommendation systems
- Finding similar items (products, articles, users)

## Prerequisites
- Supabase project with Postgres (see supabase/cli)
- pgvector extension enabled (see setup below)
- An embedding model (OpenAI, Cohere, or local)

## Setup (Migration)

```sql
-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Create documents table
CREATE TABLE documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content text NOT NULL,
  metadata jsonb DEFAULT '{}',
  embedding vector(1536),
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Create HNSW index
CREATE INDEX idx_documents_embedding ON documents
  USING hnsw (embedding vector_cosine_ops);

-- Create search function
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.78,
  match_count int DEFAULT 10
)
RETURNS TABLE (id uuid, content text, metadata jsonb, similarity float) AS $$
  SELECT id, content, metadata,
    1 - (embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$ LANGUAGE sql STABLE;
```

## Workflow

### 1. Generate and store embeddings
```typescript
const embedding = await openai.embeddings.create({
  model: 'text-embedding-3-small', input: text
});

await supabase.from('documents').insert({
  content: text,
  embedding: embedding.data[0].embedding,
});
```

### 2. Search
```typescript
const queryEmb = await openai.embeddings.create({
  model: 'text-embedding-3-small', input: question
});

const { data } = await supabase.rpc('match_documents', {
  query_embedding: queryEmb.data[0].embedding,
  match_threshold: 0.78,
  match_count: 5,
});
```

### 3. RAG
```typescript
const context = data.map(d => d.content).join('\n\n');
const answer = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    { role: 'system', content: `Context:\n${context}` },
    { role: 'user', content: question },
  ],
});
```

## Critical Rules

1. **Match dimensions** — vector(1536) for ada-002/text-embedding-3-small, vector(3072) for text-embedding-3-large
2. **Always create an index** — without an index, search does a full table scan
3. **Use HNSW over IVFFlat** — better recall, no training step
4. **Cosine distance (`<=>`)** is the default — works with normalized vectors
5. **Chunk large documents** — embedding models have token limits; chunk text into 500-1000 token segments

## Common Dimensions

| Model | Dimensions | Column |
|-------|-----------|---------|
| OpenAI text-embedding-3-small | 1536 | `vector(1536)` |
| OpenAI text-embedding-3-large | 3072 | `vector(3072)` |
| OpenAI text-embedding-ada-002 | 1536 | `vector(1536)` |
| Cohere embed-english-v3 | 1024 | `vector(1024)` |
| BGE-small-en-v1.5 | 384 | `vector(384)` |
