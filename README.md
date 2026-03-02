<div align="center">

# 🔐 MemVault

### Production-Ready Long-Term Memory for AI Agents

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)

**Store → Retrieve → Forget — just like humans do.**

[Quick Start](#-quick-start) · [How It Works](#-how-it-works) · [API Reference](#-api-reference) · [OpenClaw Integration](#-openclaw-integration)

</div>

---

## Why MemVault?

AI agents forget everything between sessions. MemVault gives them a real memory system:

- **🧠 Ebbinghaus Decay** — Memories fade over time, just like human memory. Old, unused memories naturally weaken while frequently accessed ones stay strong.
- **⚡ Strength-Weighted Retrieval** — Search results are ranked by `similarity × strength`. Recent, important memories surface first.
- **🏠 100% Local** — Runs entirely on your machine. Ollama for LLM, sentence-transformers for embeddings, PostgreSQL for storage. No API keys, no cloud dependencies.
- **🌍 Multi-Language Translation** — Optionally translate memory summaries to your language (Chinese, Japanese, Spanish, etc.) via local LLM.
- **📊 Built-in Analytics** — Track memory distribution, access patterns, and health at a glance.

Built on [memU](https://github.com/NevaMind-AI/memU) as the extraction engine. MemVault adds the production layer: HTTP API, memory decay, weighted retrieval, multi-agent tracking, and one-command setup.

---

## 🚀 Quick Start

### Prerequisites

- Docker (for PostgreSQL + pgvector)
- Python 3.11+
- [Ollama](https://ollama.com) (or any OpenAI-compatible LLM endpoint)

### Install

```bash
git clone https://github.com/wjy9902/memvault.git
cd memvault
bash scripts/setup.sh    # Installs everything: PostgreSQL, Ollama model, Python deps
```

### Start

```bash
bash scripts/start.sh
```

### Use

```bash
# Store a memory
memvault memorize-text myagent "User prefers dark mode and midnight snacks" "Got it!"

# Retrieve relevant memories
memvault retrieve myagent "what are the user's preferences?"

# Run memory decay (do this daily)
memvault decay myagent

# Check statistics
memvault stats myagent
```

---

## 🧬 How It Works

### Memory Lifecycle

```
Conversation → Extract (LLM) → Embed → Store (pgvector) → Retrieve (weighted) → Decay (daily)
                                                                ↑                      |
                                                                └──── access_count ─────┘
```

### Ebbinghaus Forgetting Curve

Every memory has a `strength` (0.0 → 1.0) that decays over time:

```
strength = exp(-rate × days / (1 + damping × ln(1 + access_count)))
```

- **New memories** start at strength 1.0
- **Unused memories** fade toward 0 over weeks
- **Frequently accessed memories** decay much slower (the `access_count` damping)
- **Fading memories** (strength < 0.1) are excluded from retrieval
- Run `/decay` daily via cron to keep memories fresh

### Strength-Weighted Retrieval

Standard vector search: `rank = cosine_similarity(query, memory)`

MemVault search: **`rank = cosine_similarity(query, memory) × strength`**

This means a highly relevant but ancient memory scores lower than a moderately relevant but recent one — matching how human recall actually works.

### Real Production Stats

From a live deployment running for 3+ weeks with 12,000+ memories:

```json
{
  "total": 12599,
  "distribution": { "strong": 2142, "medium": 7273, "weak": 3150, "fading": 34 },
  "avg_strength": 0.51,
  "avg_access_count": 1.3,
  "max_access_count": 305
}
```

---

## 📡 API Reference

### POST `/memorize`

Store a conversation in long-term memory.

```bash
curl -X POST http://localhost:8002/memorize \
  -H "Content-Type: application/json" \
  -d '{
    "conversation": [
      {"role": "user", "content": "I just finished reading"s""Project Hail Mary"},
      {"role": "assistant", "content": "Great book! What did you think of Rocky?"}
    ],
    "user_id": "alice"
  }'
```

### POST `/retrieve`

Retrieve relevant memories with strength-weighted search.

```bash
curl -X POST http://localhost:8002/retrieve \
  -H "Content-Type: application/json" \
  -d '{"query": "what books has the user read?", "user_id": "alice", "limit": 5}'
```

### POST `/decay`

Run Ebbinghaus forgetting curve on all memories.

```bash
curl -X POST "http://localhost:8002/decay?user_id=alice&decay_rate=0.1&damping=0.5"
```

### GET `/stats`

Memory statistics and health metrics.

```bash
curl http://localhost:8002/stats?user_id=alice
```

### GET `/health`

Service health check.

---

## 🔧 Configuration

All settings via environment variables (or `.env` file):

| Variable | Default | Description |
|----------|---------|-------------|
| `MEMVAULT_DB_DSN` | `postgresql://postgres:postgres@127.0.0.1:5432/memvault` | PostgreSQL connection |
| `MEMVAULT_EMBEDDING_URL` | `http://127.0.0.1:8001` | Embedding server URL |
| `MEMVAULT_EMBEDDING_MODEL` | `all-MiniLM-L6-v2` | Embedding model name |
| `MEMVAULT_LLM_BASE_URL` | `http://127.0.0.1:11434/v1` | LLM endpoint (OpenAI-compatible) |
| `MEMVAULT_LLM_MODEL` | `qwen2.5:3b` | LLM model for extraction |
| `MEMVAULT_PORT` | `8002` | Server port |
| `MEMVAULT_TRANSLATION` | `false` | Enable summary translation |
| `MEMVAULT_TRANSLATION_LANG` | `Chinese` | Target translation language |
| `MEMVAULT_MEMORY_TYPES` | `event,knowledge` | Memory types to extract |

### Using a Different LLM

MemVault works with any OpenAI-compatible endpoint:

```bash
# OpenAI
MEMVAULT_LLM_BASE_URL=https://api.openai.com/v1
MEMVAULT_LLM_API_KEY=sk-...
MEMVAULT_LLM_MODEL=gpt-4o-mini

# Anthropic (via proxy)
MEMVAULT_LLM_BASE_URL=https://your-proxy.com/v1
MEMVAULT_LLM_MODEL=claude-sonnet-4-20250514

# Local (Ollama, LM Studio, vLLM, etc.)
MEMVAULT_LLM_BASE_URL=http://127.0.0.1:11434/v1
MEMVAULT_LLM_MODEL=qwen2.5:3b
```

---

## 🐾 OpenClaw Integration

MemVault was originally built for [OpenClaw](https://openclaw.ai) multi-agent systems.

### Add to your agent's TOOLS.md

```markdown
## MemVault Long-term Memory 🧠

\`\`\`bash
memvault memorize-text "<user_id>" "<content>" "<context>"
memvault retrieve "<user_id>" "<query>"
\`\`\`

- MemVault API: 127.0.0.1:8002
- Embedding: 127.0.0.1:8001
- PostgreSQL: 127.0.0.1:5432 (Docker)
```

### Set up daily decay cron

Add to your OpenClaw cron jobs:

```
0 3 * * *  curl -s -X POST 'http://127.0.0.1:8002/decay?user_id=YOUR_USER_ID'
```

### Multi-Agent Memory

Each agent can tag its memories with `source_agent`:

```json
{
  "conversation": [
    {"role": "metadata", "content": "{\"source_agent\": \"research-bot\"}"},
    {"role": "user", "content": "Found 3 new papers on transformer architectures"},
    {"role": "assistant", "content": "Noted, adding to research tracking."}
  ],
  "user_id": "team"
}
```

Then filter by source in `/stats` to see which agent contributes what.

---

## 📁 Project Structure

```
memvault/
├── memvault_server.py     # Main server (FastAPI)
├── embedding_server.py    # Local embedding server
├── memvault               # CLI tool
├── scripts/
│   ├── setup.sh           # One-command installation
│   └── start.sh           # Start all services
├── .env.example           # Configuration template
├── README.md
└── LICENSE
```

---

## 🤝 Contributing

PRs welcome! Some ideas:

- [ ] SQLite backend (for simpler deployments)
- [ ] Memory export/import (JSON/Markdown)
- [ ] Web dashboard for memory visualization
- [ ] Configurable decay strategies (beyond Ebbinghaus)
- [ ] Memory consolidation (merge similar memories)

---

## 📄 License

Apache 2.0 — See [LICENSE](LICENSE).

Built on [memU](https://github.com/NevaMind-AI/memU) by NevaMind AI.

---

<div align="center">

**If MemVault helps your agents remember, give it a ⭐!**

</div>
