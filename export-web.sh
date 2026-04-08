#!/usr/bin/env bash
# export-web.sh — Export ZPS World Godot game to HTML5 and serve via NestJS backend
# Usage: ./export-web.sh [--headless]
#
# Prerequisites:
#   1. Godot 4.6 installed and in PATH (or set GODOT env var)
#   2. Web export templates installed in Godot editor (Editor → Manage Export Templates)
#   3. NestJS backend dependencies installed (cd backend && npm install)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${GODOT:-godot}"
OUTPUT_DIR="$SCRIPT_DIR/backend/public"
EXPORT_PATH="$OUTPUT_DIR/index.html"

echo "=== ZPS World Web Export ==="
echo "Project: $SCRIPT_DIR"
echo "Output:  $OUTPUT_DIR"
echo ""

# ── Step 1: Create output directory ──────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Step 2: Export Godot project ─────────────────────────────────────────────
echo "[1/3] Exporting Godot project to HTML5..."
"$GODOT" --headless --path "$SCRIPT_DIR" --export-release "Web" "$EXPORT_PATH"
echo "      ✓ Export complete → $OUTPUT_DIR"

# ── Step 3: Build NestJS backend ─────────────────────────────────────────────
echo "[2/3] Building NestJS backend..."
cd "$SCRIPT_DIR/backend"
npm run build
echo "      ✓ Backend compiled → dist/"

# ── Step 4: Start servers ─────────────────────────────────────────────────────
echo "[3/3] Starting servers..."
echo ""
echo "  Backend (REST + game):  http://localhost:3000"
echo "  WebSocket server:        ws://localhost:3001"
echo ""
echo "  Open http://localhost:3000 in your browser to play."
echo ""

# Start WebSocket server in background
node "$SCRIPT_DIR/server/server.js" &
WS_PID=$!
echo "  [WS]  Started (PID $WS_PID)"

# Start NestJS (foreground)
node "$SCRIPT_DIR/backend/dist/main.js"

# Cleanup on exit
kill "$WS_PID" 2>/dev/null || true
