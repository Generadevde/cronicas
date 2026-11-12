# Crônica — guia para quem programa

Projeto de hobby do autor (Godot 4.7, GDScript). Responder e comentar em **português**.

## Regras do projeto

0. **A escrita é o centro.** O que o autor escreve molda o mundo frase a frase, e o mundo anda junto. Todo sistema novo deve poder nascer de uma frase (via `Leitor`) e aparecer na margem.

1. **O banco de fatos é a verdade.** Toda mudança no mundo vira fato em `BancoDeFatos` (o quê, quem, onde, quando, origem, causas). A IA (quando existir) só dá voz e texto; nunca decide nem guarda verdade.
2. **Todo fato registra sua causa.** Fatos de origem `simulacao` precisam de causa; `autor` e `capitulo` podem ser raízes. Causas inexistentes são recusadas.
3. **Nada de campos fixos.** Tipos, temas, campos de ficha, sociedades etc. são texto livre. Listas de sugestão são só atalhos (`core/sugestoes.gd`).
4. **Nada se perde.** Remover entidade = marcar como retirada; apagar capítulo manda o texto para as notas; apagar universo manda para a lixeira; salvar mantém `.bak`.
5. **Simulação só existe se aparecer em algo que o autor lê** (texto, notícia, página).
6. **Cada parte termina com testes** (`tests/`, `./testar.sh`) e, se precisar, uma tela de depuração. Polimento só no fim.

## Estrutura

- `core/escrita/` — **o centro**: `leitor.gd` (cada frase vira mundo: lugares, gente, criaturas, necessidades, pessoas, sentimentos, leis, tempo; cada frase tem um fato-raiz para desfazer) e `escrita.gd` (lê o capítulo frase a frase, aceita as ações, faz o tempo andar, monta os cartões da margem e a sugestão do mundo).
- `core/escrita/leitor_mais.gd` — escrever "por cima": números como se escreve ("3.700", "três mil e duzentos"), lugares e pessoas pelo nome, títulos ainda sem nome (o Livro pergunta), o que está por vir ("até a chegada do imperador"), perguntas ao Livro, regras do Livro, ordens de criar e acontecimentos anotados.
- `core/escrita/interprete.gd` — a IA local como intérprete: reescreve uma linha que o Leitor só anotou em frases-modelo que ele entende; corta nome ou número que a linha não diz; o autor confere na margem ("A IA leu assim") antes de valer; apagar a linha desfaz. A IA nunca decide nem guarda verdade.
- `core/` — dados e regras, sem interface: `universo.gd`, `fact_db.gd` (BancoDeFatos), `auditor.gd`, `ligador.gd` (nomes → links), `pesquisa.gd`, `biblioteca.gd` (salvar/carregar), `text_util.gd`, `data_mundo.gd`, `cronica.gd` (autoload).
- `core/mente/` — personalidade, decisões, reações, combate, objetivos (Parte 3).
- `core/mundo/` — mapa (lugares dentro de lugares, terreno, acidentes com nome, rios), viagens, natureza, povoador, línguas, eras/leis gerais (Parte 4); criaturas que atacam (`ameacas.gd`) e recursos de sobrevivência (`recursos.gd`).
- `core/regras/` — leis escritas em português (`regras.gd`), peças de efeito (`pecas.gd`), poderes, corpo e vida, "ainda sem efeito" (`pendencias.gd`) (Parte 5); regras vivas — perigos e dons que o mundo obedece e aos quais o povo se adapta (`vivas.gd`).
- `core/sociedade/` — governos e sucessão (`sociedades.gd`), humor do povo e revoltas, economia, reputação relativa, família e gerações (Parte 6).
- `core/guerra/` — forças militares (`forcas.gd`), guerras, batalhas, intervenção e pós-guerra (`guerras.gd`), lutas em aberto (`lutas.gd`), lendas, títulos e nomes (`lendas.gd`) (Parte 7).
- `core/cosmico/` — pactos e preços (`pactos.gd`), o Autor e o arauto (`autor.gd`), poderes que mudam o motor: pausa, sono, apagar, ver o futuro, galhos (`motor.gd`) (Parte 8).
- `core/transformacao/` — técnicas e invenções (`tecnicas.gd`), escolas, religiões, cidades e ruínas, intriga (espiões, submundo, propaganda), aventura (monstros, torneios), povos (migrações, revoluções, alianças, colônias) (Parte 9).
- `core/vida/` — conversar com personagens (`conversa.gd`), acompanhar e ponto de vista (`acompanhar.gd`), IA local opcional que só dá voz (`ia_local.gd`) (Parte 10); Modo Viver: viver um personagem por dentro, ações em texto livre, diário e capítulo (`vivencia.gd`) (Parte 13).
- `core/historia/` — fios e arcos (`fios.gd`), obras (`obras.gd`), legado cultural (`legado.gd`), cronista, diretor de drama e tom (`diretor.gd`), ganchos, segredos, boatos e sementes (`enredo.gd`) (Parte 11).
- `core/integridade/` — ramos e comparação (`laboratorio.gd`), versões (`versoes.gd`), destinos do autor (`destinos.gd`), auditores, recuperação e memória (`integridade.gd`), importar/exportar (`troca.gd`) (Parte 12).
- `core/integridade/confronto.gd` — Laboratório de confronto: ensaia uma luta entre dois lados e conta em palavras, com motivo; não gera fatos.
- `ui/tela/` — **a tela única** (é a cena "livro" do programa): `tela.gd` (página no centro, margem à direita, estante fina à esquerda, painéis por cima; hospeda as abas antigas `ui/book/aba_*.gd` dentro dos painéis), `painel_opcoes.gd` (tema, letra, tamanho, som), `painel_estante.gd` (sagas → livros, exportar em texto), `painel_confronto.gd`, `realce.gd` (linhas do mundo em outra tinta), `som.gd` (máquina de escrever, gerado em código), `icone.gd`.
- `ui/` — telas montadas em código: `tema.gd` (visual de livro), `menu/`, `library/`, `book/` (livro com quatro fitas — Escrever, O mundo, Linha do tempo, Bastidores — que juntam as abas `aba_*.gd`; `paginas.gd` monta BBCode).
- `tests/` — `run_tests.gd` roda todos os `test_*.gd`.
- `assets/` — fontes (OFL) e a arte do menu (feita pelo autor).

## Como o programa se apresenta

É um programa de escrever, não um jogo. O autor escreve "por cima" (uma coisa por linha); cada linha terminada vira mundo; o mundo responde em outra tinta e o autor aceita, muda ou risca. Nada de porcentagens na tela: tudo em palavras, com motivo. Na interface, "saga" é o `livro` do motor e "livro" é o `capítulo`. As cores do `Tema` são variáveis (temas antigo, escuro e claro em `Tema.PALETAS`): nunca guardar uma cor do Tema em `const`.

## Rodar

- Testes: `GODOT=/caminho/godot ./testar.sh`
- Abrir: `./jogar.sh`
- Executável Linux: `GODOT=/caminho/godot ./exportar.sh` (precisa dos modelos de exportação do Godot 4.7) → `dist/Cronica/`

## Plano (13 partes)

1 Fundação · 2 Texto vira fatos · 3 Mentes e tempo · 4 Universo e natureza · 5 Sistemas por escrita e poder · 6 Sociedades · 7 Guerras e intervenção · 8 Pactos e forças cósmicas · 9 Mundo em transformação · 10 Viver o mundo por dentro · 11 Histórias e cultura · 12 Laboratório e integridade · 13 Modo Viver.
