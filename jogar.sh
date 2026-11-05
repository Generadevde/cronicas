#!/usr/bin/env bash
# Atualiza o Crônica e abre o programa.
# Uso: ./jogar.sh
# Se o Godot não estiver no PATH como "godot", defina GODOT com o caminho:
#   GODOT=~/Programas/Godot_v4.7-stable_linux.x86_64 ./jogar.sh

set -e
cd "$(dirname "$0")"

echo "Atualizando o Crônica..."
git pull --ff-only || echo "Aviso: não consegui atualizar (sem internet?). Abrindo a versão atual."

GODOT_BIN="${GODOT:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  for candidato in godot4 Godot_v4.7-stable_linux.x86_64 "$HOME/Godot_v4.7-stable_linux.x86_64"; do
    if command -v "$candidato" >/dev/null 2>&1 || [ -x "$candidato" ]; then
      GODOT_BIN="$candidato"
      break
    fi
  done
fi

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
  echo "Não encontrei o Godot 4.7. Defina a variável GODOT com o caminho do executável."
  exit 1
fi

# Na primeira vez (ou depois de arquivos novos), o Godot precisa importar o projeto:
# é isso que cria a lista de classes (Universo, Tema…) e converte as imagens.
if [ ! -f .godot/global_script_class_cache.cfg ] || [ -n "$(find core ui assets -newer .godot/global_script_class_cache.cfg -print -quit 2>/dev/null)" ]; then
  echo "Preparando o projeto (só demora na primeira vez)..."
  "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
fi

echo "Abrindo..."
"$GODOT_BIN" --path . "$@"
