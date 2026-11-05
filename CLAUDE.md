# Crônica — guia para quem programa

Projeto de hobby do autor (Godot 4.7, GDScript). Responder e comentar em **português**.

## Regras do projeto

1. **O banco de fatos é a verdade.** Toda mudança no mundo vira fato em `BancoDeFatos` (o quê, quem, onde, quando, origem, causas). A IA (quando existir) só dá voz e texto; nunca decide nem guarda verdade.
2. **Todo fato registra sua causa.** Fatos de origem `simulacao` precisam de causa; `autor` e `capitulo` podem ser raízes. Causas inexistentes são recusadas.
3. **Nada de campos fixos.** Tipos, temas, campos de ficha, sociedades etc. são texto livre. Listas de sugestão são só atalhos (`core/sugestoes.gd`).
4. **Nada se perde.** Remover entidade = marcar como retirada; apagar capítulo manda o texto para as notas; apagar universo manda para a lixeira; salvar mantém `.bak`.
5. **Simulação só existe se aparecer em algo que o autor lê** (texto, notícia, página).
6. **Cada parte termina com testes** (`tests/`, `./testar.sh`) e, se precisar, uma tela de depuração. Polimento só no fim.

## Estrutura

- `core/` — dados e regras, sem interface: `universo.gd`, `fact_db.gd` (BancoDeFatos), `auditor.gd`, `ligador.gd` (nomes → links), `pesquisa.gd`, `biblioteca.gd` (salvar/carregar), `text_util.gd`, `data_mundo.gd`, `cronica.gd` (autoload).
- `core/mente/` — personalidade, decisões, reações, combate, objetivos (Parte 3).
- `core/mundo/` — mapa (lugares dentro de lugares, terreno, acidentes com nome, rios), viagens, natureza, povoador, línguas, eras/leis gerais (Parte 4).
- `core/regras/` — leis escritas em português (`regras.gd`), peças de efeito (`pecas.gd`), poderes, corpo e vida, "ainda sem efeito" (`pendencias.gd`) (Parte 5).
- `ui/` — telas montadas em código: `tema.gd` (visual de livro), `menu/`, `library/`, `book/` (livro com abas `aba_*.gd`, `paginas.gd` monta BBCode).
- `tests/` — `run_tests.gd` roda todos os `test_*.gd`.
- `assets/` — fontes (OFL) e a arte do menu (feita pelo autor).

## Rodar

- Testes: `GODOT=/caminho/godot ./testar.sh`
- Abrir: `./jogar.sh`

## Plano (13 partes)

1 Fundação · 2 Texto vira fatos · 3 Mentes e tempo · 4 Universo e natureza · 5 Sistemas por escrita e poder · 6 Sociedades · 7 Guerras e intervenção · 8 Pactos e forças cósmicas · 9 Mundo em transformação · 10 Viver o mundo por dentro · 11 Histórias e cultura · 12 Laboratório e integridade · 13 Modo Viver.
