#!/usr/bin/env bash
# MemVault One-Command Setup
# Installs: PostgreSQL+pgvector (Docker), Ollama, memU, Python deps
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[MemVault]${NC} $1"; }
warn() { echo -e "${YELLOW}[MemVault]${NC} $1"; }
err()  { echo -e "${RED}[MemVault]${NC} $1"; }

MEMVAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB_NAME="${MEMVAULT_DB_NAME:-memvault}"
DB_USER="${MEMVAULT_DB_USER:-postgres}"
DB_PASS="${MEMVAULT_DB_PASS:-postgres}"
DB_PORT="${MEMVAULT_DB_PORT:-5432}"

info "=== MemVault Setup ==="
info "Directory: $MEMVAULT_DIR"

# 1. Check Docker
if ! command -v docker &>/dev/null; then
    err "Docker not found. Install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi
info "✅ Docker found"

# 2. PostgreSQL + pgvector
if docker ps -a --format '{{.Names}}' | grep -q '^memvault-postgres$'; then
    if docker ps --format '{{.Names}}' | grep -q '^memvault-postgres$'; then
        info "✅ PostgreSQL already running"
    else
        info "Starting existing PostgreSQL container..."
        docker start memvault-postgres
    fi
else
    info "Creating PostgreSQL + pgvector container..."
    docker run -d \
        --name memvault-postgres \
        -e POSTGRES_USER="$DB_USER" \
        -e POSTGRES_PASSWORD="$DB_PASS" \
        -e POSTGRES_DB="$DB_NAME" \
        -p "$DB_PORT":5432 \
        --restart unless-stopped \
        pgvector/pgvector:pg16
    info "Waiting for PostgreSQL to be ready..."
    sleep 5
fi
info "✅ PostgreSQL ready on port $DB_PORT"

# 3. Check Python
if ! command -v python3 &>/dev/null; then
    err "Python 3 not found. Install Python 3.11+."
    exit 1
fi
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
info "✅ Python $PYVER"

# 4. Create venv & install deps
if [[ ! -d "$MEMVAULT_DIR/.venv" ]]; then
    info "Creating virtual environment..."
    python3 -m venv "$MEMVAULT_DIR/.venv"
fi
source "$MEMVAULT_DIR/.venv/bin/activate"

info "Installing Python dependencies..."
pip install -q --upgrade pip
pip install -q memu-py[postgres] fastapi uvicorn sentence-transformers requests psycopg2-binary httpx

# 5. Check/Install Ollama
if ! command -v ollama &>/dev/null; then
    warn "Ollama not found. Installing..."
    if [[ "$(uname)" == "Darwin" ]]; then
        brew install ollama 2>/dev/null || {
            warn "brew install failed. Install manually: https://ollama.com/download"
            warn "MemVault will still work with any OpenAI-compatible LLM endpoint."
        }
    elif [[ "$(uname)" == "Linux" ]]; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
fi

if command -v ollama &>/dev/null; then
    info "✅ Ollama found"
    # Pull default model if not present
    if ! ollama list 2>/dev/null | grep -q "qwen2.5:3b"; then
        info "Pulling qwen2.5:3b model (this may take a few minutes)..."
        ollama pull qwen2.5:3b
    fi
    info "✅ LLM model ready"
else
    warn "⚠️  Ollama not installed. Set MEMVAULT_LLM_BASE_URL to your LLM endpoint."
fi

# 6. Create .env if not exists
if [[ ! -f "$MEMVAULT_DIR/.env" ]]; then
    info "Creating .env from template..."
    cp "$MEMVAULT_DIR/.env.example" "$MEMVAULT_DIR/.env" 2>/dev/null || \
    cat > "$MEMVAULT_DIR/.env" << ENVEOF
MEMVAULT_DB_DSN=postgresql://${DB_USER}:${DB_PASS}@127.0.0.1:${DB_PORT}/${DB_NAME}
MEMVAULT_EMBEDDING_URL=http://127.0.0.1:8001
MEMVAULT_EMBEDDING_MODEL=all-MiniLM-L6-v2
MEMVAULT_LLM_BASE_URL=http://127.0.0.1:11434/v1
MEMVAULT_LLM_API_KEY=ollama
MEMVAULT_LLM_MODEL=qwen2.5:3b
MEMVAULT_TRANSLATION=false
MEMVAULT_PORT=8002
ENVEOF
fi

# 7. Install CLI
info "Installing memvault CLI..."
chmod +x "$MEMVAULT_DIR/memvault"
if [[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin"; then
    ln -sf "$MEMVAULT_DIR/memvault" "$HOME/.local/bin/memvault"
    info "✅ CLI installed to ~/.local/bin/memvault"
fi

echo ""
info "=== Setup Complete! ==="
echo ""
echo "  Start MemVault:   cd $MEMVAULT_DIR && ./scripts/start.sh"
echo "  Quick test:       memvault health"
echo "  Store memory:     memvault memorize-text myuser 'I like dark mode' 'Got it!'"
echo "  Retrieve:         memvault retrieve myuser 'what theme?'"
echo ""
