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

## Parte 5 — Sistemas por escrita e poder

- **Leis do Universo** (aba Leis): escreva em português e o mundo passa a seguir. O programa separa **Quando** (vencer, perder, lutar, matar, morrer, casar, nascer, chegar, treinar, usar magia ou um poder; "a cada 100 anos"; ou um termo seu, como "beber da fonte de Varn"), **Quem** ("guerreiros de Kresk", "os elfos", alguém pelo nome), **O quê** e **Se** ("se estiver ferido", "30% das vezes").
  - Exemplos que funcionam: "Neste mundo, quem usa magia envelhece um ano por feitiço."; "Guerreiros de Kresk ficam 10% mais fortes a cada vitória."; "Quem bebe da fonte de Varn esquece o último ano."; "A cada 100 anos, um eclipse desperta os mortos de Aldra."; "Os elfos vivem 700 anos."
  - Efeitos: envelhecer/rejuvenescer, mais forte/mais fraco, esquecer, morrer, ferir, adoecer, curar, sentir algo, mudar o que sente por alguém, ir para um lugar, voltar à vida, seca/praga/peste…, espécies e lavouras ±%, mudar o jeito, ganhar uma **marca** ("amaldiçoado", "conhece o Autor").
  - Cada efeito vira fato com a causa (o que disparou a lei). Dá para suspender, reescrever, apagar e desfazer.
- **Nada sem efeito**: a lista "Ainda sem efeito" mostra campos de ficha que nenhum sistema lê, intervenções que o programa não entendeu, leis entendidas em parte, frases em dúvida e pedidos do mundo. Você **define o efeito escrevendo** (vira lei e vale daqui em diante) ou diz que é só descrição. Atalho: "chuva de sangue → todos em Varn sentem medo; lavouras caem 30%".
- **Poderes**: qualquer entidade do tipo magia, dom, técnica… Quem a cita na ficha tem o poder e usa nas lutas. Na ficha do poder: "força", "custo" (ex.: envelhece um ano), "limite" (ex.: uma vez por mês) e "efeitos permitidos". Poderes **narrativos** (destino, realidade…) viram pedido para você decidir. Há um sistema de poder pronto, estilo shonen (aba Universo).
- **Corpo e vida**: a idade conta o que as leis fazem envelhecer; a força cresce até a juventude e cai na velhice; morte natural pela expectativa de vida (da ficha, do povo ou de uma lei); cicatrizes de ferimentos graves.
- Magia e tecnologia têm efeito: sem magia, poderes mágicos falham; mais tecnologia faz as lavouras renderem mais e as viagens ficarem mais rápidas.
- **Fauna e flora** de cada terreno editáveis na aba Universo.
- Simulação mais rápida (um planeta povoado com uns 150 personagens leva cerca de 30 segundos para avançar 10 anos).

## Parte 6 — Sociedades

- **Qualquer coisa com governo na ficha é uma sociedade** (aba Sociedades): reino, república, tribo, teocracia, império, guilda, ordem, colmeia… Campos livres: "forma de governo", "líder", "território", "conselho", "leis", "impostos", "religião", "admiram", "desprezam".
- **Governo e sucessão**: o governante, a casa (sobrenome) e a história dos governantes. Quando o governante morre, o sucessor vem pela forma de governo (herança, eleição, escolha da fé, força). Conselheiros pouco leais podem dar **golpe**.
- **Humor do povo** em cada povoado (raiva, medo, alegria, fé): sobe com fome, pestes, impostos e com o que o povo acha do governante. Raiva alta vira inquietação e, depois de semanas, **revolta**, que pode derrubar o governo (e até mudar a forma de governo) ou ser esmagada. Alegria vira festa; medo e fé fazem surgir profetas (e, numa teocracia, hereges).
- **Economia**: caravanas levam comida de onde sobra para onde falta; preço do pão; riqueza vinda dos impostos.
- **Reputação relativa**: a mesma pessoa pode ser herói para um povo e carniceiro para outro, conforme o que cada cultura admira ou despreza e o que chegou até ela.
- **Gerações**: casais têm filhos que herdam o sobrenome, um pouco do jeito dos pais e as inimizades da família.
- Leis da sociedade valem só no território dela ("a magia é proibida" faz quem usa magia ali virar fugitivo).
- Teste do plano: uma seca vira fome, a fome vira revolta e a revolta derruba o governo, com a cadeia de causas inteira.

## Parte 7 — Guerras e intervenção

- **Forças militares** são entidades com ficha livre: "tamanho" (20 mil), "tipo de força" (infantaria, cavalaria, frota, aviões, naves, magos, monstros, máquinas, sobrenaturais), "pertence a", "comandante", "moral", "pontos fortes" ("imune a balas, invisível na areia") e "fraquezas" ("some com a luz do dia"). Cada tipo tem vantagens e fraquezas contra os outros: quem não alcança o ar não acerta aviões, magia fere o sobrenatural, frotas lutam mal em terra.
- **Guerras nascem da simulação** (fome em casa e fartura no vizinho, vingança de guerras passadas, ódio entre governantes, fé, ambição, "inimigos" na ficha) ou de você: no capítulo ("Sokovia declarou guerra a Bermudit") ou na aba **Guerras**.
- **Painel da guerra**: lados e aliados, forças (tamanho, tipo, moral, comandante, suprimentos), frente de batalha, **previsão de quem vence e por quê**, batalhas e mortos. Botões para intervir: reforços, traição, desastre, aliado inesperado, morte de um general, fazer a paz, ou **escrever** ("o rei fez um pacto com o Ser da Quinta Dimensão e recebeu um exército de fantasmas do deserto"): o ser vira entidade, os fantasmas viram força, e a guerra recalcula.
- **Batalhas em resumo** (força, terreno, dia ou noite, estação, moral, suprimentos, sorte), cada uma com nome ("A Noite dos Fantasmas do Deserto", "Os Dez Dias de Aldra"), mortos, heróis, generais que caem, ocupação de cidades e refugiados.
- **Depois da guerra**: tratado, terras que mudam de dono, rancor entre povos por gerações, veteranos, heróis com título ("o Conquistador", "Senhor da Noite"), lugares com nome de guerra ("as Areias Vermelhas"), e guerras longas lembradas como "A Guerra dos N Anos".
- **Lutas em aberto**: escreva a luta sem dizer quem venceu ("Eles lutaram por 10 dias; apenas um ficou em pé"). Ao avançar o tempo, o programa decide (força, resistência, fraquezas, poderes, terreno, amigos por perto, sorte) e o resultado chega na margem: aceitar, trocar o vencedor ou manter em mistério.
- **Lendas**: com os anos, dez dias viram trinta e o vencedor vira um deus; a verdade fica no fato. Heróis lendários dão moral ao seu povo, e cultos surgem em volta deles.
- No mapa, guerras e cidades ocupadas aparecem marcadas com ⚔.
- Teste do plano: Sokovia contra Bermudit com o exército de fantasmas.

## Parte 8 — Pactos e forças cósmicas

- **Pactos**: qualquer entidade com "o que oferece" e "o que cobra" na ficha (deus, demônio, ser antigo, o próprio Autor) procura quem tem um desejo forte e nenhuma saída — vingança contra alguém muito mais forte, doença, uma guerra perdida, um luto — e oferece um pacto. A mente da pessoa decide (desespero, ambição, prudência, e se o preço cai sobre a família).
- **O desejo se cumpre de verdade** ("Kai morreu de repente, sem que ninguém soubesse explicar"). O **preço fica secreto**: só você vê, na aba **Cosmos** e na wiki, e os personagens não ficam sabendo pelas notícias.
- **O preço chega depois**, no tempo escrito ("a alma do primeiro filho, em dez anos"; "vinte anos de vida"; "a cidade inteira dorme"). Paga a pessoa, o primeiro filho, a família ou a cidade. Só então o mundo descobre.
- Entidades ganham **seguidores**, e as sociedades reagem: perseguem o culto (teocracias, quem despreza pactos) ou tentam usar a entidade.
- **O Autor e o arauto**: você pode existir no mundo como força cósmica (com o nome que quiser), fora do mapa, sem envelhecer nem morrer. Quem "conhece o Autor" é seu arauto: você revela uma visão, uma ordem ou uma profecia, e ele reage com a própria mente — obedece, duvida, espalha ou esconde. O mundo fica sabendo pelas notícias, com atraso. Dá para fazer pactos com o Autor.
- **Poderes que mudam o motor** (no "efeito" do poder, numa lei ou num preço): **parar o tempo** (o relógio do mundo para, menos para quem usou e quem ele tocou), **sono eterno** (um lugar sai da simulação até a maldição ser quebrada), **apagar da existência**, **ver o futuro** (a simulação roda numa cópia do mundo e a visão fica guardada no fato) e **voltar ao passado** (abre um galho da linha do tempo; em "Ainda sem efeito" você decide abrir, e o galho vira um universo à parte na estante).
- No mapa: ◉ onde há pacto ainda não cobrado, ☾ onde há sono eterno.
- Teste do plano: um pacto cujo preço chega anos depois.

## Parte 9 — Mundo em transformação

- **Criações dos personagens**: gente curiosa e com um objetivo inventa técnicas de luta, feitiços e invenções (viram entidades com nome e criador). Elas são **ensinadas** a discípulos, filhos e amigos, **aperfeiçoadas**, **roubadas**, **esquecidas** quando morre o último que sabia (ficam vestígios onde ele vivia) e **redescobertas** anos ou séculos depois — de preferência por alguém curioso nos vestígios ou nas ruínas. Técnicas de luta e feitiços contam nas lutas; invenções melhoram as lavouras de onde são usadas.
- **Mestres, linhagens e escolas**: com três mestres no mesmo lugar nasce uma escola, que ensina alunos todo ano, disputa jovens com as outras e pode ser proibida (uma escola de magia onde a magia é proibida) ou fechar sem mestres.
- **Religiões que nascem e morrem**: um profeta com seguidores funda uma religião (com a crença que pregava); ela se espalha onde a fé é forte, pode se dividir numa heresia e, sem fiéis, desaparece — o templo vira ruína.
- **Construções e ruínas**: aldeias viram vilas, cidades e metrópoles (ou minguam); muralhas sobem quando a guerra ameaça e ajudam quem defende; lugares desertos viram ruínas.
- **Espiões**: rivais e inimigos plantam espiões, que roubam segredos (até pactos secretos) e dão vantagem na guerra; podem ser presos ou virar agentes duplos.
- **Submundo**: onde há raiva, preço alto e gente fria nasce uma guilda de ladrões, que rouba, contrabandeia (o governo perde impostos) e é perseguida.
- **Propaganda e línguas**: depois de uma derrota, o governo espalha a sua versão e o humor do povo acompanha; tratados entre povos de línguas diferentes podem sair mal traduzidos.
- **Ecologia de monstros e torneios**: caçar demais de um lado faz as feras fugirem para o vizinho (e nascem caçadores de monstros); torneios anuais fazem campeões, rivais e, com três títulos, "o Invicto".
- **Migrações, revoluções e família**: fome, guerra e peste levam povos inteiros a migrar (as línguas se misturam); ideias novas ("ninguém deve ter rei") se espalham e, com o povo irritado, viram revolução; casamentos entre casas governantes viram alianças; ciúmes e brigas dividem famílias.
- **Contato entre mundos e colonização**: com técnica ou magia bastante, povos de planetas diferentes se encontram (e às vezes guerreiam); colônias são fundadas em planetas vazios e, um dia, declaram independência.
- Aba Mundo → **O que muda**: técnicas vivas e perdidas, escolas, religiões, cidades, submundo e ideias que circulam.
- Teste do plano: uma técnica inventada, ensinada, esquecida e redescoberta.

## Parte 10 — Viver o mundo por dentro

- **Aba Viver** (ou "Conversar" na página de qualquer personagem):
  - **Conversar**: pergunte o que quiser — por que ele odeia, ama ou teme alguém; o que quer; o que sabe sobre um lugar ou pessoa; o que acha de alguém; peça uma promessa; acuse; plante uma dúvida. Ele responde com o que **realmente sabe** (os fatos que conhece), com o jeito dele, e pode esconder, mentir, se irritar ou se abrir. Fale **como deus**, **como um desconhecido** ou **como outro personagem** (e aí conta o que ele sente por esse personagem).
  - Exemplo: a Daren, "por que você odeia o Kai?". Como deus: "Kai sabe o que fez." (e, se você insiste, "Já disse que isso não é da sua conta."). Como Mira, em quem ele confia: conta o que viu; insistindo, confessa a vergonha que sentiu do pai.
  - Promessas, confissões e dúvidas plantadas viram **propostas** (você aceita ou risca; avançar o tempo não aceita sozinho). A conversa pode virar **cena** (capítulo em rascunho).
  - **Acompanhar**: siga alguém por um dia, uma semana ou um mês (cena a cena, resumo do dia ou só o importante) — o que faz, o que acontece em volta, o que ouve dizer e o que pensa e sente. Salve como rascunho de capítulo.
  - **Ponto de vista**: o mundo pelos olhos dele — o que viveu, o que ouviu dizer, o que sente, o que quer e quantas coisas importantes ainda não chegaram até ele.
- **IA local** (opcional, botão "IA local…"): um programa no seu computador (Ollama ou llama.cpp) só é chamado quando você conversa, e só reescreve a fala no jeito do personagem — recebe apenas o que ele sabe. Sem ela, as respostas são montadas a partir dos fatos.
- Teste do plano: perguntar a Daren por que ele odeia Kai.

## Parte 11 — Histórias e cultura

- **Aba Histórias**:
  - **Fios de história**: cada objetivo forte (vingança, amor, ambição) é um fio, com estado (nascendo, crescendo, em tensão, perto do clímax, resolvido, abandonado) e os caminhos possíveis. Mudanças de rumo viram notícia ("O fio 'A vingança de Daren' mudou: Daren hesitou"). Você puxa, deixa correr ou corta; fios abandonados podem voltar anos depois. **Arcos** de personagem (da vingança para a dúvida) ficam marcados para você fechar.
  - **Sementes**: "Surpreenda-me" — o mundo sugere uma história curta com personagens, lugar e conflito reais ("Nelia, de Sokov, esconde Tarik, ferido, em plena guerra"), com título, resumo e gancho. Você escreve, descarta ou deixa o mundo resolver.
  - **Obras**: escritores, bardos, pintores, dramaturgos, sacerdotes e veteranos criam obras sobre o que viveram — cada uma com autor, tema real (o fato), estilo e **viés**. Obras são copiadas, proibidas, queimadas por ocupantes, perdidas em ruínas e **reencontradas**: quem acha lê com os valores do seu tempo, e as duas versões circulam (uma leitura empática diminui o rancor entre os povos).
  - **Cultura**: o legado dos acontecimentos — guerra vira feriado ou dia de luto, herói vira canção (que dá moral na guerra), traição vira provérbio, escola vira tradição, pacto vira superstição. Legados mudam com o tempo (o luto vira festa, a canção ganha versos, o provérbio perde o sentido), e a verdade fica no fato.
  - **Cronista**: anais do ano, biografias e relatos de guerra, como historiador neutro, com o viés de um povo ou como um bardo exagerado.
  - **Segredos e ganchos**: quem sabe e quem suspeita de cada segredo, e quando ele vem à tona (você marca). Promessas, profecias e objetos citados voltam (a promessa é posta à prova, a profecia se cumpre, o objeto reaparece).
  - **Diretor de drama**: ritmo (calmo, equilibrado, intenso) e tom (sombrio, esperançoso, trágico, épico, misto). Ele alterna calmaria, tensão, clímax e reconstrução, e depois de calmaria longa acende uma faísca num conflito que já existia.
- **Boatos**: notícias que viajam longe podem chegar distorcidas ("Um boato chegou a Kresk: …").
- IA local: agora também pelo **Ollama** (como no plano) — em "IA local…", o caminho do ollama e o nome do modelo.
- Teste do plano: um livro escrito por um soldado, reinterpretado séculos depois.

## Ajustes de leitura

No livro, o botão **Aa** (ou Configurações, no menu) escolhe a fonte do texto, a fonte da escrita (capítulos e notas; por padrão uma letra manuscrita) e o tamanho da letra, com prévia. Fica guardado para as próximas vezes.

O programa completo e polido fica para o fim da Parte 13. Até lá, cada parte termina com testes e uma tela de depuração.

## Plano

13 partes: Fundação · Texto vira fatos · Mentes e tempo · Universo e natureza · Sistemas por escrita e poder · Sociedades · Guerras e intervenção · Pactos e forças cósmicas · Mundo em transformação · Viver o mundo por dentro · Histórias e cultura · Laboratório e integridade · Modo Viver.

## Licenças

Fontes (SIL Open Font License, em `assets/fonts/`): EB Garamond, IM FELL English, UnifrakturMaguntia, Caveat, Kalam, Dancing Script, Petit Formal Script, Noto Sans Symbols/Symbols 2/Math (símbolos de reserva). A arte do menu é do autor do projeto.
