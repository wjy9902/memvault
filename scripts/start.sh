#!/usr/bin/env bash
# Start MemVault services (native mode, not Docker)
set -e

MEMVAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MEMVAULT_DIR"

# Load .env first
if [[ -f .env ]]; then
    set -a; source .env; set +a
    echo "[MemVault] Loaded .env"
fi

# Activate venv
if [[ -f .venv/bin/activate ]]; then
    source .venv/bin/activate
fi

# Ensure PostgreSQL is running
if ! docker ps --format '{{.Names}}' | grep -q 'memvault-postgres'; then
    echo "[MemVault] Starting PostgreSQL..."
    docker start memvault-postgres 2>/dev/null || {
        echo "[MemVault] ERROR: memvault-postgres container not found. Run scripts/setup.sh first."
        exit 1
    }
    sleep 2
fi

# Check Ollama is running (non-fatal)
if ! curl -sf http://127.0.0.1:11434/api/tags &>/dev/null; then
    echo "[MemVault] ⚠️  Ollama not running. Start it: ollama serve"
    echo "[MemVault]    Or set MEMVAULT_LLM_BASE_URL to another OpenAI-compatible endpoint."
fi

# Start embedding server
EMBED_PORT="${MEMVAULT_EMBEDDING_PORT:-8001}"
echo "[MemVault] Starting embedding server on port $EMBED_PORT..."
python3 embedding_server.py &
EMBED_PID=$!

# Wait for embedding to be ready
for i in {1..10}; do
    if curl -sf "http://127.0.0.1:$EMBED_PORT/health" &>/dev/null; then break; fi
    sleep 1
done

# Start MemVault server
MV_PORT="${MEMVAULT_PORT:-8002}"
echo "[MemVault] Starting MemVault server on port $MV_PORT..."
python3 memvault_server.py &
MEMVAULT_PID=$!

echo ""
echo "[MemVault] ✅ All services started:"
echo "  PostgreSQL:  localhost:${MEMVAULT_DB_PORT:-5432}"
echo "  Embedding:   localhost:$EMBED_PORT  (PID: $EMBED_PID)"
echo "  MemVault:    localhost:$MV_PORT  (PID: $MEMVAULT_PID)"
echo ""
echo "  Test:  curl http://localhost:$MV_PORT/health"
echo "  Stop:  kill $EMBED_PID $MEMVAULT_PID"
echo ""

trap "echo '[MemVault] Shutting down...'; kill $EMBED_PID $MEMVAULT_PID 2>/dev/null; exit 0" SIGINT SIGTERM
wait
