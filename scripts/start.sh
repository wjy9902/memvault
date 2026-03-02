#!/usr/bin/env bash
# Start MemVault services
set -e

MEMVAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MEMVAULT_DIR"

# Load .env
if [[ -f .env ]]; then
    set -a; source .env; set +a
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

# Start embedding server
echo "[MemVault] Starting embedding server on port ${MEMVAULT_EMBEDDING_PORT:-8001}..."
python3 embedding_server.py &
EMBED_PID=$!
sleep 3

# Start MemVault server
echo "[MemVault] Starting MemVault server on port ${MEMVAULT_PORT:-8002}..."
python3 memvault_server.py &
MEMVAULT_PID=$!

echo ""
echo "[MemVault] Services started:"
echo "  PostgreSQL:  localhost:${MEMVAULT_DB_PORT:-5432}"
echo "  Embedding:   localhost:${MEMVAULT_EMBEDDING_PORT:-8001} (PID: $EMBED_PID)"
echo "  MemVault:    localhost:${MEMVAULT_PORT:-8002} (PID: $MEMVAULT_PID)"
echo ""
echo "  Stop: kill $EMBED_PID $MEMVAULT_PID"
echo ""

# Trap for clean shutdown
trap "echo 'Shutting down...'; kill $EMBED_PID $MEMVAULT_PID 2>/dev/null; exit 0" SIGINT SIGTERM

wait
