# Crônica

> *Um universo não é feito apenas daquilo que aconteceu, mas também de tudo aquilo que ainda pode acontecer.*

Criador de universos em texto, com cara de livro antigo. Você cria o mundo e escreve a história; tudo vira fato num banco de fatos, e o mundo lembra, organiza e (nas próximas partes) reage sozinho.

Feito em **Godot 4.7** e GDScript. Projeto de hobby.

## Como abrir

```bash
git clone https://github.com/Generadevde/cronicas.git
cd cronicas
./jogar.sh            # atualiza (git pull) e abre
```

Se o Godot não estiver no PATH como `godot`, informe o caminho:

```bash
GODOT=~/Godot_v4.7-stable_linux.x86_64 ./jogar.sh
```

Também dá para abrir a pasta pelo editor do Godot 4.7 e apertar F5.

## Testes automáticos

```bash
./testar.sh           # ou: GODOT=/caminho/do/godot ./testar.sh
```

Roda sem abrir janela e mostra quantos testes passaram.

## Onde ficam os universos

Salvos sozinhos (um segundo depois de cada mudança) na pasta de dados do Godot:

- Linux: `~/.local/share/godot/app_userdata/Crônica/universos/`
- Windows: `%APPDATA%\Godot\app_userdata\Crônica\universos\`

Cada universo tem uma cópia de segurança da versão anterior (`universo.json.bak`). Universos apagados vão para a pasta `lixeira`, nunca somem de vez.

## O que já existe (Parte 1 — Fundação)

- Menu principal com a arte do autor
- Biblioteca dos Universos: criar (nome + descrição livre), abrir, apagar para a lixeira
- O livro, com fitas laterais:
  - **Escrever** — livros e capítulos; data no mundo, canon/rascunho, marcador; modo leitura com nomes como links
  - **Wiki** — página de cada entidade, com ficha, onde aparece, quem a cita e linha do tempo
  - **Criadores** — qualquer entidade, com tipo e campos livres (sugestões opcionais)
  - **Pesquisa** — sem acento e tolerante a erros de digitação
  - **Notas** — privadas, a simulação nunca lê
  - **Índice** — onde cada nome aparece e os capítulos marcados
  - **Fatos** — tela de depuração do banco de fatos e do auditor de integridade
- Banco de fatos com causas e consequências; cada criação e alteração vira fato
- Auditor: causas inexistentes, ciclos, causa depois do efeito, fatos da simulação sem origem, entidades inexistentes

## Parte 2 — Texto vira fatos

- Ao escrever, a **margem** propõe o que aconteceu: vitória, morte, ferimento, família, casamento, amor, ódio, traição, mestre e discípulo, chegada a um lugar, nascimento…
- Junta a luta e o resultado mesmo em frases diferentes ("Kai enfrentou Lucas… e Lucas perdeu" → Kai venceu Lucas)
- Entende "não matou" (negação) e "Ele/Ela" no começo da frase
- Você **aceita, ajusta ou risca**; frases com nomes que não entendeu viram **dúvida**, e você **ensina** a palavra (vale no universo todo)
- Aceitar aplica as consequências (vivo/morto, onde está, família, relações) e propõe **ecos** (humilhação, ódio, luto, vingança), sempre ligados à causa
- **Desfazer**: o fato fica guardado, mas deixa de valer, e o mundo é recalculado relendo o banco de fatos
- **Continuidade**: avisa quando alguém aparece depois de morrer, antes de nascer ou em dois lugares no mesmo dia
- **Versões** de cada capítulo para restaurar
- A wiki mostra "No mundo agora": vivo/morto, onde está, família, o que sente, o que quer, relações

## Parte 3 — Mentes e tempo

- **Relógio do mundo** (aba Mundo): avançar 1 dia, semana, mês, ano, 10 anos ou "até algo importante"; também pelo botão "Avançar o tempo" no alto
- **Mundo vivo**: o tempo corre sozinho enquanto o livro está aberto; o lugar do capítulo aberto fica em foco (parado)
- Quem **tem mente própria** (marcado em Criadores) decide sozinho, em passos semanais: treinar, buscar mestre, viajar atrás de alguém, confrontar, perdoar, se dedicar a uma ambição, conviver, se apaixonar, casar, fugir, viver o luto
- **Personalidade** (10 traços) lida do texto livre da ficha ("rancoroso, corajoso…"); desejos e ambições da ficha viram objetivos
- **Emoções** que esfriam com o tempo (o rancor dura mais, o amor quase não passa); memórias, diário, idade, força
- **Notícias** correm com atraso (3 dias no mesmo lugar, ~25 em outro) e quem fica sabendo reage
- Toda decisão vira fato com causa: dá para perguntar "Por quê?" e desfazer
- **Jornal** com manchetes e bilhetes; cada notícia pode virar capítulo
- **Linha do tempo** e **Observatório** (o que aconteceu com alguém, quem o influenciou)
- Mesma semente = mesmo mundo (a simulação é reproduzível)

## Parte 4 — Universo e natureza

- **Mapa** (aba Mapa): só de texto, no estilo dos mapas antigos. O terreno aparece em aguadas leves, as costas em tinta e os rios em fio; serras, mares, lagos, florestas, desertos e rios têm **nome escrito** (gerado na língua do lugar e guardado). Os nomes se arrumam para não ficar letra sobre letra.
- **Zoom**: Cosmos › planeta › região › cidade › casa. Clique para escolher, clique duas vezes para entrar, "↑ Subir" para voltar.
- **Escrever aqui**: clique num ponto e escreva "uma casa na montanha", "uma torre em ruínas perto do rio chamada Vigia Negra" ou "uma vila de pescadores na costa". O lugar aparece no mapa e ganha página, e o programa propõe quem mora ali. Para dar nome à natureza, escreva "montanha do sul" ou "rio da pedra azul" (se não houver rio ali, nasce um).
- **Pintar** o terreno e **Colocar** no mapa o que já existe. Tudo vira fato.
- **Viagens levam tempo**, pelas distâncias do mapa (escala na ficha: "largura: 800 km"). Quem viaja fica "a caminho", e a chegada é um fato causado pela partida. As notícias também demoram a viagem.
- **Natureza por lugar**, em números: espécies do terreno (ou criadas por você, com "habitat"), lavouras, rebanhos, população e comida, com estações e clima.
- **Intervir aqui**: texto livre ("uma seca terrível por um ano") ou atalhos (seca, praga, peste, inverno rigoroso, enchente, fartura, incêndio, feras, terremoto). A seca seca as lavouras, a fome chega, gente sofre, migra ou adoece. Tudo vira fato com a causa, e dá para desfazer.
- **Gerar planeta** (clima, luas, regiões, terreno) e **Povoar** (povoados, famílias com mente própria, uma facção, figuras históricas que viram lenda), com **Desfazer povoamento**.
- **Aba Universo**: leis (magia e tecnologia, o que é possível ou proibido), **eras**, acontecimentos antigos (lendas), **línguas** que aprendem com seus exemplos, povos e espécies, planetas.

## Ajustes de leitura

No livro, o botão **Aa** (ou Configurações, no menu) escolhe a fonte do texto, a fonte da escrita (capítulos e notas; por padrão uma letra manuscrita) e o tamanho da letra, com prévia. Fica guardado para as próximas vezes.

O programa completo e polido fica para o fim da Parte 13. Até lá, cada parte termina com testes e uma tela de depuração.

## Plano

13 partes: Fundação · Texto vira fatos · Mentes e tempo · Universo e natureza · Sistemas por escrita e poder · Sociedades · Guerras e intervenção · Pactos e forças cósmicas · Mundo em transformação · Viver o mundo por dentro · Histórias e cultura · Laboratório e integridade · Modo Viver.

## Licenças

Fontes (SIL Open Font License, em `assets/fonts/`): EB Garamond, IM FELL English, UnifrakturMaguntia, Caveat, Kalam, Dancing Script, Petit Formal Script, Noto Sans Symbols/Symbols 2/Math (símbolos de reserva). A arte do menu é do autor do projeto.
