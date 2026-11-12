#!/usr/bin/env bash
# Gera o executável do Crônica para Linux em dist/Cronica/ (precisa dos modelos de exportação do Godot 4.7).
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
mkdir -p dist/Cronica
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release "Linux" dist/Cronica/Cronica.x86_64
cp assets/ui/icone.svg dist/Cronica/cronica.svg
cat > dist/Cronica/LEIA-ME.txt <<'T'
CRÔNICA — você escreve, o mundo ganha vida

Como abrir (Linux Mint):
  1. Extraia esta pasta onde quiser.
  2. Dê dois cliques em "Cronica.x86_64".
     Se não abrir: botão direito no arquivo → Propriedades → Permissões →
     marque "Permitir executar como programa". Ou, no terminal:  chmod +x Cronica.x86_64 && ./Cronica.x86_64
  3. Para ter o ícone no menu do sistema, rode uma vez:  ./instalar-atalho.sh

Não precisa de internet nem de instalar nada.

IA local (opcional): faz o Livro entender linhas mais soltas. Precisa de internet só uma vez, para instalar:
  1. No terminal:  curl -fsSL https://ollama.com/install.sh | sh
  2. Baixe um modelo pequeno:  ollama pull gemma3:4b      (com 8 GB de memória, se ficar lento:  ollama pull llama3.2:3b)
  3. No Crônica: Opções → IA local → confira o caminho e o modelo → Testar.
Depois disso funciona desligado da rede. Sem a IA o programa funciona igual; as linhas mais soltas ficam só anotadas.
Seus universos ficam em  ~/.local/share/godot/app_userdata/Crônica/  (salvos sozinhos, com cópia de segurança).
T
cat > dist/Cronica/instalar-atalho.sh <<'T'
#!/usr/bin/env bash
# Cria o atalho do Crônica no menu do sistema (com o ícone).
AQUI="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/cronica.desktop" <<D
[Desktop Entry]
Type=Application
Name=Crônica
Comment=Você escreve, o mundo ganha vida
Exec="$AQUI/Cronica.x86_64"
Icon=$AQUI/cronica.svg
Terminal=false
Categories=Office;
D
chmod +x "$AQUI/Cronica.x86_64"
echo "Atalho criado: procure por Crônica no menu."
T
chmod +x dist/Cronica/Cronica.x86_64 dist/Cronica/instalar-atalho.sh
echo "Pronto: dist/Cronica/"
