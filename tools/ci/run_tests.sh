#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_PATH="${PROJECT_PATH:-$(pwd)}"

echo "Running unit tests..."
"$GODOT_BIN" --headless --path "$PROJECT_PATH" --unit

echo "Running smoke tests..."
"$GODOT_BIN" --headless --path "$PROJECT_PATH" --smoke



