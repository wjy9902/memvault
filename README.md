<div align="center">

# 🔐 MemVault

### Production-Ready Long-Term Memory for AI Agents

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Python 3.13+](https://img.shields.io/badge/python-3.13+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED.svg)](https://docs.docker.com/compose/)

**Store → Retrieve → Forget — just like humans do.**

[Quick Start](#-quick-start) · [How It Works](#-how-it-works) · [API](#-api-reference) · [OpenClaw](#-openclaw-integration) · [Docker](#-docker-recommended)

</div>

---

## Why MemVault?

AI agents forget everything between sessions. MemVault gives them a real memory system:

- **🧠 Ebbinghaus Decay** — Memories fade over time. Old, unused memories weaken; frequently accessed ones stay strong.
- **⚡ Strength-Weighted Retrieval** — Results ranked by `similarity × strength`. Important memories surface first.
- **🏠 100% Local** — Ollama for LLM, sentence-transformers for embeddings, PostgreSQL for storage. No API keys needed.
- **🌍 Multi-Language** — Optionally translate memory summaries to your language via local LLM.
- **📊 Built-in Analytics** — Track memory distribution, access patterns, and health.

Built on [memU](https://github.com/NevaMind-AI/memU) as the extraction engine. MemVault adds: HTTP API, memory decay, weighted retrieval, multi-agent tracking, and one-command setup.

### Real Production Stats

Running 3+ weeks with 12,000+ memories:

```
Total: 12,599 memories
Strong (≥0.8): 2,142  |  Medium: 7,273  |  Weak: 3,150  |  Fading: 34
Avg strength: 0.51  |  Max access count: 305
```

---

## 🚀 Quick Start

### Option A: OpenClaw Skill (One Command)

If you use [OpenClaw](https://openclaw.ai):

```bash
clawhub install memvault
cd ~/.openclaw/workspace/skills/memvault
bash scripts/install.sh
```

Done. `memvault` CLI is ready. Add the snippet from `SKILL.md` to your `TOOLS.md`.

### Option B: Docker (Recommended — No Python version hassles)

```bash
git clone https://github.com/wjy9902/memvault.git
cd memvault
docker compose up -d
```

That's it. PostgreSQL, embedding server, and MemVault are all running.

> **Note:** You still need Ollama running on your host for LLM extraction:
> ```bash
> # Install: https://ollama.com
> ollama pull qwen2.5:3b
> ollama serve
> ```
> Or set `MEMVAULT_LLM_BASE_URL` to any OpenAI-compatible endpoint (OpenAI, Groq, etc.)

### Option C: Native Install

> ⚠️ **Requires Python 3.13+** (memU dependency). Check with `python3 --version`.
> If you have an older Python, use Docker (Option A) instead.

```bash
git clone https://github.com/wjy9902/memvault.git
cd memvault
bash scripts/setup.sh     # PostgreSQL + Ollama + Python deps
bash scripts/start.sh     # Start all services
```

### Test It

```bash
# Store a memory
curl -X POST http://localhost:8002/memorize \
  -H "Content-Type: application/json" \
  -d '{"conversation": [{"role": "user", "content": "I love Python and dark mode"}], "user_id": "alice"}'

# Retrieve
curl -X POST http://localhost:8002/retrieve \
  -H "Content-Type: application/json" \
  -d '{"query": "what does the user prefer?", "user_id": "alice"}'

# Or use the CLI
memvault memorize-text alice "I love Python and dark mode" "Noted!"
memvault retrieve alice "user preferences"
memvault stats alice
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

Every memory has a `strength` (0.01 → 1.0) that decays over time:

```
strength = exp(-rate × days / (1 + damping × ln(1 + access_count)))
```

- **New memories** start at strength 1.0
- **Unused memories** fade over weeks
- **Frequently accessed** memories decay much slower
- **Fading memories** (strength < 0.1) are excluded from retrieval
- Run `/decay` daily via cron

### Strength-Weighted Retrieval

```
Standard:   rank = cosine_similarity(query, memory)
MemVault:   rank = cosine_similarity(query, memory) × strength
```

A highly relevant but ancient memory scores lower than a moderately relevant recent one — matching how human recall works.

---

## 📡 API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/memorize` | Store a conversation |
| POST | `/retrieve` | Search memories (strength-weighted) |
| POST | `/decay` | Run Ebbinghaus forgetting curve |
| GET | `/stats` | Memory statistics |
| GET | `/health` | Health check |

### POST `/memorize`

```json
{
  "conversation": [
    {"role": "user", "content": "I just finished reading Project Hail Mary"},
    {"role": "assistant", "content": "Great book! What did you think?"}
  ],
  "user_id": "alice"
}
```

### POST `/retrieve`

```json
{"query": "what books has the user read?", "user_id": "alice", "limit": 5}
```

Response includes `summary`, `strength`, `score`, `access_count`, `source_agent` for each memory.

### POST `/decay`

```
POST /decay?user_id=alice&decay_rate=0.1&damping=0.5
```

### Multi-Agent Tagging

Tag memories with `source_agent` via metadata role:

```json
{
  "conversation": [
    {"role": "metadata", "content": "{\"source_agent\": \"research-bot\"}"},
    {"role": "user", "content": "Found 3 new papers on transformers"}
  ],
  "user_id": "team"
}
```

---

## 🔧 Configuration

All via environment variables or `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `MEMVAULT_DB_DSN` | `postgresql://...localhost:5432/memvault` | PostgreSQL connection |
| `MEMVAULT_EMBEDDING_URL` | `http://127.0.0.1:8001` | Embedding server |
| `MEMVAULT_LLM_BASE_URL` | `http://127.0.0.1:11434/v1` | LLM endpoint |
| `MEMVAULT_LLM_MODEL` | `qwen2.5:3b` | LLM model |
| `MEMVAULT_PORT` | `8002` | Server port |
| `MEMVAULT_TRANSLATION` | `false` | Enable translation |
| `MEMVAULT_TRANSLATION_LANG` | `Chinese` | Target language |
| `MEMVAULT_MEMORY_TYPES` | `event,knowledge` | Types to extract |

### Using Different LLMs

```bash
# OpenAI
MEMVAULT_LLM_BASE_URL=https://api.openai.com/v1
MEMVAULT_LLM_API_KEY=sk-...
MEMVAULT_LLM_MODEL=gpt-4o-mini

# Groq (fast & free)
MEMVAULT_LLM_BASE_URL=https://api.groq.com/openai/v1
MEMVAULT_LLM_API_KEY=gsk_...
MEMVAULT_LLM_MODEL=llama-3.1-8b-instant

# Local Ollama (default)
MEMVAULT_LLM_BASE_URL=http://127.0.0.1:11434/v1
MEMVAULT_LLM_MODEL=qwen2.5:3b
```

---

## 🐾 OpenClaw Integration

MemVault was built for [OpenClaw](https://openclaw.ai) multi-agent systems.

### TOOLS.md snippet

```markdown
## MemVault 🧠
memvault memorize-text "<user_id>" "<content>" "<context>"
memvault retrieve "<user_id>" "<query>"
- API: 127.0.0.1:8002 | Embedding: 127.0.0.1:8001
```

### Daily decay cron

```
0 3 * * *  curl -s -X POST 'http://127.0.0.1:8002/decay?user_id=YOUR_USER'
```

---

## 🐳 Docker (Recommended)

```bash
# Start everything
docker compose up -d

# Check health
curl http://localhost:8002/health

# View logs
docker compose logs -f memvault

# Stop
docker compose down

# Stop and remove data
docker compose down -v
```

### Custom LLM with Docker

```bash
# Use OpenAI instead of local Ollama
MEMVAULT_LLM_BASE_URL=https://api.openai.com/v1 \
MEMVAULT_LLM_API_KEY=sk-... \
MEMVAULT_LLM_MODEL=gpt-4o-mini \
docker compose up -d
```

---

## 📁 Project Structure

```
memvault/
├── memvault_server.py     # Main API server (FastAPI)
├── embedding_server.py    # Local embedding server
├── memvault               # CLI tool
├── Dockerfile             # Multi-stage build
├── docker-compose.yml     # One-command deployment
├── scripts/
│   ├── setup.sh           # Native installation
│   └── start.sh           # Start services
├── examples/
│   └── basic_usage.py     # Python examples
├── docs/
│   └── ARCHITECTURE.md    # Technical architecture
├── .env.example           # Config template
└── requirements.txt
```

---

## 🤝 Contributing

PRs welcome! Ideas:

- [ ] SQLite backend (simpler deployments)
- [ ] Memory export/import (JSON/Markdown)
- [ ] Web dashboard for visualization
- [ ] Alternative decay strategies
- [ ] Memory consolidation (merge similar)
- [ ] LangChain / AutoGen integration examples

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 📄 License

Apache 2.0 — See [LICENSE](LICENSE).

Built on [memU](https://github.com/NevaMind-AI/memU) by NevaMind AI.

---

<div align="center">

**If MemVault helps your agents remember, give it a ⭐**

</div>
