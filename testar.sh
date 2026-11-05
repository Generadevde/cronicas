#!/usr/bin/env bash
# Roda os testes automáticos do Crônica sem abrir janela.
# Uso: ./testar.sh   (ou GODOT=/caminho/do/godot ./testar.sh)
set -e
cd "$(dirname "$0")"
GODOT_BIN="${GODOT:-godot}"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . -s res://tests/run_tests.gd
