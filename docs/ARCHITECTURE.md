# MemVault Architecture

## Overview

```
┌─────────────────┐
│   Your Agent    │
└────────┬────────┘
         │ HTTP API
    ┌────▼─────────────────┐
    │  memvault_server.py  │
    │  (FastAPI)           │
    └─┬─────────────────┬──┘
      │                 │
      │ memU            │ pgvector
      │ (extraction)    │ (storage)
      │                 │
    ┌─▼──────────┐  ┌──▼──────────┐
    │ embedding  │  │ PostgreSQL   │
    │  server    │  │ + pgvector   │
    └────────────┘  └──────────────┘
         │
      ┌──▼──────────┐
      │ Ollama LLM  │
      │ (local)     │
      └─────────────┘
```

## Components

### 1. memvault_server.py

Main FastAPI server exposing:
- `/memorize` — Store conversations
- `/retrieve` — Strength-weighted vector search
- `/decay` — Ebbinghaus forgetting curve
- `/stats` — Analytics

### 2. embedding_server.py

Local embedding service using `sentence-transformers`. Provides OpenAI-compatible `/embeddings` endpoint.

### 3. PostgreSQL + pgvector

- Stores memory items with embeddings
- `pgvector` extension for vector similarity search
- Schema managed by memU

### 4. Ollama (LLM)

- Extracts facts/events/knowledge from conversations
- Optional: translates summaries to target language
- Can be replaced with any OpenAI-compatible endpoint

## Memory Schema

```sql
CREATE TABLE memory_items (
  id UUID PRIMARY KEY,
  user_id TEXT,
  summary TEXT,
  memory_type TEXT,  -- 'event', 'knowledge', 'profile', 'behavior'
  embedding vector(384),  -- pgvector
  strength FLOAT DEFAULT 1.0,
  access_count INT DEFAULT 0,
  last_accessed TIMESTAMP,
  source_agent TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  extra JSONB
);
```

## Decay Formula

```
strength(t) = exp(-α × days / (1 + β × ln(1 + access_count)))

where:
  α = decay_rate (default 0.1)
  β = damping (default 0.5)
  days = (now - created_at) / 86400
```

**Intuition:** New memories start at strength 1.0. Over time, strength decays exponentially, but frequently accessed memories (`access_count` high) decay much slower due to the damping term.

## Retrieval Ranking

```
score = cosine_similarity(query_embedding, memory_embedding) × strength
```

Fading memories (strength < 0.1) are excluded from search.

## Performance Optimizations

1. **Skip multimodal preprocess** — Text-only conversations don't need image/audio preprocessing
2. **Reduced memory types** — Extract only `event` and `knowledge` (skip `profile`/`behavior` to save LLM calls)
3. **Batch translation** — Translate all new summaries in one LLM call
4. **Parallel embedding** — Re-embed translated summaries concurrently

## Multi-Agent Support

Each memory item can be tagged with `source_agent` to track which agent contributed it. Useful for:
- Team memory sharing
- Agent-specific memory analytics
- Debugging agent behavior
