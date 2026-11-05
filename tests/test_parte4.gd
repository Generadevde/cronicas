extends TesteBase
## Parte 4: universo e natureza (mapa, viagens, línguas, natureza, povoador, eras).


## Um planeta pequeno feito à mão: Aldra › Vale de Varn › Varn e Kresk (longe).
func _mundo() -> Dictionary:
	var u := Universo.novo("Aldra")
	u.extras["semente"] = 12345  # mundo sempre igual nos testes
	u.definir_relogio(DataMundo.criar(412, 10))
	var planeta := u.criar_entidade("Aldra", "planeta", [], [{"chave": "clima", "valor": "temperado"}])
	var vale := u.criar_entidade("Vale de Varn", "região", [], [{"chave": "clima", "valor": "temperado"}])
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "6000"}])
	var kresk := u.criar_entidade("Kresk", "cidade")
	Mapa.colocar(u, planeta, "", 20, 10)
	Mapa.colocar(u, vale, planeta, 10, 12)
	Mapa.colocar(u, varn, vale, 20, 13)
	Mapa.colocar(u, kresk, planeta, 40, 12)
	return {"u": u, "planeta": planeta, "vale": vale, "varn": varn, "kresk": kresk}


func test_mapa_guarda_hierarquia_e_vira_fato() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	igual(Mapa.pai(u, m["varn"]), m["vale"], "Varn fica no vale")
	igual(Mapa.ancestrais(u, m["varn"]), [m["vale"], m["planeta"]], "cadeia de lugares")
	verdadeiro(Mapa.descendentes(u, m["planeta"]).has(m["varn"]), "o planeta contém Varn")
	igual(Mapa.em(u, m["vale"], 20, 13), m["varn"], "acha pelo ponto")
	verdadeiro(u.fatos.sobre(m["varn"]).any(func(f): return f["tipo"] == "mapa"), "colocar no mapa vira fato")
	Mapa.colocar(u, m["planeta"], m["varn"], 1, 1)
	igual(Mapa.pai(u, m["planeta"]), "", "não deixa um lugar ficar dentro de si mesmo")


func test_dias_de_viagem_pelo_mapa() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var d := u.dias_de_viagem(m["varn"], m["kresk"])
	verdadeiro(d > 20, "Varn e Kresk ficam longe (veio %d dias)" % d)
	igual(u.dias_de_viagem(m["kresk"], m["varn"]), d, "ida e volta iguais")
	igual(u.dias_de_viagem(m["varn"], m["varn"]), 0, "mesmo lugar")
	var solto := u.criar_entidade("Ilha Perdida", "ilha")
	igual(u.dias_de_viagem(m["varn"], solto), -1, "fora do mapa: não sabe")
	# O autor pode dizer o tamanho do planeta e a escala muda.
	u.editar_entidade(m["planeta"], {"campos": [{"chave": "largura", "valor": "1.120 km"}]})
	verdadeiro(u.dias_de_viagem(m["varn"], m["kresk"]) < d, "planeta menor, viagem mais curta")
	verdadeiro(Informacao._atraso(u, m["varn"], m["kresk"]) > Informacao.DIAS_MESMO_LUGAR, "notícia demora a viagem")


func test_viajar_leva_tempo_e_a_chegada_tem_causa() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var daren := u.criar_entidade("Daren", "pessoa", [], [{"chave": "personalidade", "valor": "rancoroso, impulsivo e corajoso"}])
	var kai := u.criar_entidade("Kai", "pessoa", [], [{"chave": "personalidade", "valor": "cruel"}])
	u.estado(daren)["local"] = m["varn"]
	u.estado(kai)["local"] = m["kresk"]
	var partida := Simulador.registrar(u, {"tipo": "viagem", "descricao": "Daren partiu para Kresk.", "sujeitos": [daren],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": Viagens.ops_de_ida(u, daren, m["varn"], m["kresk"])}})
	verdadeiro(Viagens.viajando(u, daren), "está a caminho")
	igual(u.estado(daren)["local"], "", "na estrada não está em lugar nenhum")
	var dias := u.dias_de_viagem(m["varn"], m["kresk"])
	Simulador.avancar(u, dias + 7)
	igual(u.estado(daren)["local"], m["kresk"], "chegou")
	var chegada: Array = u.fatos.sobre(daren).filter(func(f): return f["tipo"] == "chegada")
	verdadeiro(not chegada.is_empty() and chegada[0]["causas"].has(partida), "a chegada foi causada pela partida")
	# Desfazer a partida desfaz a chegada.
	u.desfazer_fato(partida)
	falso(Viagens.viajando(u, daren), "sem viagem")
	verdadeiro(chegada.is_empty() or not u.fatos.obter(chegada[0]["id"])["canon"], "chegada deixou de valer")


func test_terreno_e_sempre_o_mesmo_e_o_autor_pinta() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var a := Mapa.terreno(u, m["planeta"])
	igual(a.size(), Mapa.LINHAS, "linhas")
	igual(a[0].size(), Mapa.COLS, "colunas")
	igual(Mapa.terreno(u, m["planeta"]), a, "mesma semente, mesmo terreno")
	var total := 0.0
	for v in Mapa.composicao(u, m["planeta"]).values():
		total += v
	verdadeiro(absf(total - 1.0) < 0.001, "composição soma 1")
	verdadeiro(Mapa.pintar(u, m["planeta"], 3, 3, "montanha"), "pintou")
	igual(Mapa.terreno_em(u, m["planeta"], 3, 3), "montanha", "pintura vale")
	Mapa.registrar_pintura(u, m["planeta"], 1)
	verdadeiro(u.fatos.todos().any(func(f): return f["descricao"].begins_with("O autor redesenhou")), "pintar vira fato")
	# O terreno de dentro herda o de fora: um lugar numa montanha tem montanhas.
	Mapa.pintar(u, m["planeta"], 30, 5, "montanha")
	var pico := u.criar_entidade("Pico Gelado", "região")
	Mapa.colocar(u, pico, m["planeta"], 30, 5)
	var comp := Mapa.composicao(u, pico)
	verdadeiro(float(comp.get("montanha", 0.0)) + float(comp.get("colina", 0.0)) > 0.25, "região na montanha é montanhosa")


func test_linguas_aprendem_com_exemplos() -> void:
	var u := Universo.novo("Teste")
	Linguas.definir(u, "Élfico", {"pessoas": ["Aelindra", "Thalion", "Elaria", "Faelith", "Miralen", "Sylvaris", "Aerendil", "Lirael"]})
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var nomes: Array = []
	for i in 12:
		var n := Linguas.gerar(u, "Élfico", "pessoas", rng)
		verdadeiro(n.length() >= 3, "nome com tamanho razoável: " + n)
		falso(n in ["Aelindra", "Thalion", "Elaria", "Faelith", "Miralen", "Sylvaris", "Aerendil", "Lirael"], "não copia exemplo: " + n)
		nomes.append(n)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	igual(Linguas.gerar(u, "Élfico", "pessoas", rng2), nomes[0], "mesma semente, mesmo nome")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "língua"), "língua vira fato")
	var floresta := u.criar_entidade("Lothwen", "floresta", [], [{"chave": "língua", "valor": "élfico"}])
	igual(Linguas.do_lugar(u, floresta), "Élfico", "lugar diz a língua")


func test_interpretar_texto_de_intervencao() -> void:
	var a := Natureza.interpretar("uma seca terrível por um ano")
	igual(a.size(), 1, "uma coisa")
	igual(a[0]["tipo"], "seca", "seca")
	verdadeiro(float(a[0]["forca"]) > 1.0, "terrível é forte")
	igual(int(a[0]["dias"]), 360, "por um ano")
	var b := Natureza.interpretar("peste e gafanhotos por 3 meses")
	verdadeiro(b.map(func(x): return x["tipo"]).has("epidemia") and b.map(func(x): return x["tipo"]).has("praga"), "duas coisas")
	igual(int(b[0]["dias"]), 90, "3 meses")
	igual(Natureza.interpretar("um inverno qualquer").size(), 0, "inverno comum não é catástrofe")
	igual(Natureza.interpretar("nevasca leve")[0]["forca"], 0.5, "leve é fraco")


## O teste da Parte 4 no plano: gerar um planeta, entrar numa cidade e causar uma seca.
func test_gerar_planeta_entrar_numa_cidade_e_causar_seca() -> void:
	var u := Universo.novo("Aldra")
	u.extras["semente"] = 777
	u.definir_relogio(DataMundo.criar(412, 60))
	var planeta := Povoador.gerar_planeta(u)
	var regioes := Mapa.filhos(u, planeta)
	verdadeiro(regioes.size() >= 3, "planeta com regiões (%d)" % regioes.size())
	verdadeiro(u.valor_campo(planeta, "luas") != "", "planeta tem luas")
	var r := Povoador.povoar(u, planeta)
	verdadeiro(r["criados"].size() > 10, "povoou (%d criados)" % r["criados"].size())
	var cidade := ""
	for eid in Mapa.descendentes(u, planeta):
		if Mapa.especie(u, eid) == "povoado" and Natureza.populacao_inicial(u, eid) >= 1000:
			cidade = eid
			break
	verdadeiro(cidade != "", "achou uma cidade")
	if cidade == "":
		return
	var gente := Natureza._mentes_em(u, cidade)
	verdadeiro(not gente.is_empty(), "cidade tem moradores com mente")
	var pop0 := float(Natureza.de(u, cidade)["pop"])
	var seca := Natureza.intervir(u, cidade, "uma seca terrível por um ano")
	igual(seca["entendidos"], ["seca"], "entendeu a seca")
	verdadeiro(Natureza.eventos_ativos(u, cidade).any(func(ev): return ev["fato"] == seca["fato"]), "seca valendo")
	Simulador.avancar(u, 300)
	var reg := Natureza.de(u, cidade)
	verdadeiro(float(reg["especies"]["lavouras"]["n"]) < 0.5, "lavouras secaram")
	verdadeiro(float(reg["pop"]) < pop0, "gente sofreu")
	var da_seca := u.fatos.todos().filter(func(f): return f["canon"] and f["lugar"] == cidade and f["tipo"] in ["colheita perdida", "fome"])
	verdadeiro(da_seca.size() >= 2, "colheita perdida e fome viraram fato")
	for f in da_seca:
		var cadeia := u.fatos.cadeia_de_causas(f["id"]).map(func(c): return c["id"] if c is Dictionary else c)
		verdadeiro(cadeia.has(seca["fato"]), "'%s' vem da seca" % f["descricao"])
	var fome: Array = da_seca.filter(func(f): return f["tipo"] == "fome")
	if not fome.is_empty():
		verdadeiro(Estado.emocoes_atuais(u, gente[0]).any(func(e): return e["emocao"] == "medo") or not Estado.vivo(u, gente[0]) or u.estado(gente[0])["local"] != cidade,
			"quem mora lá sente medo")
	igual(Auditor.auditar(u).filter(func(p): return p["tipo"] != "aviso"), [], "auditor sem problemas")
	# Desfazer a seca: as consequências deixam de valer.
	u.desfazer_fato(seca["fato"])
	igual(Natureza.eventos_ativos(u, cidade).filter(func(ev): return ev["fato"] == seca["fato"]).size(), 0, "seca desfeita")
	for f in da_seca:
		falso(u.fatos.obter(f["id"])["canon"], "consequência desfeita: " + f["descricao"])


func test_natureza_sem_intervencao_fica_estavel() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Simulador.avancar(u, 360 * 2)
	var reg := Natureza.de(u, m["varn"])
	verdadeiro(float(reg["comida"]) > 0.7, "sem catástrofe, há comida (%.2f)" % float(reg["comida"]))
	verdadeiro(float(reg["pop"]) > 5000, "população se mantém")
	var vivos := 0
	for nome in reg["especies"]:
		if float(reg["especies"][nome]["n"]) > 0:
			vivos += 1
	verdadeiro(vivos >= reg["especies"].size() - 1, "espécies não somem do nada")


func test_criar_escrevendo_no_mapa() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var lido := Povoador.ler_texto_do_mapa("uma torre em ruínas perto do rio chamada Vigia Negra")
	igual(lido["nome"], "Vigia Negra", "nome")
	igual(lido["tipo"], "torre", "tipo")
	igual(lido["terreno"], "agua", "perto do rio")
	igual(Povoador.ler_texto_do_mapa("uma vila de pescadores na costa")["tipo"], "vila de pescadores", "tipo composto")
	var r := Povoador.criar_por_texto(u, "uma casa na montanha", m["vale"], 5, 5)
	var casa: String = r["eid"]
	igual(u.entidade(casa)["tipo"], "casa", "tipo casa")
	igual(Mapa.posicao(u, casa)["pai"], m["vale"], "está no vale")
	igual(Mapa.terreno_em(u, m["vale"], 5, 5), "montanha", "a palavra do autor vira terreno")
	verdadeiro(Mapa.e_lugar(u, casa), "o mundo trata como lugar")
	verdadeiro(not r["sugestao"].is_empty(), "sugere quem mora")
	var moradores := Povoador.completar(u, casa, r["sugestao"])
	igual(moradores.size(), 1, "um morador")
	igual(u.estado(moradores[0])["local"], casa, "mora na casa")
	verdadeiro(Estado.idade(u, moradores[0]) >= 25, "tem idade")
	var ruina := Povoador.criar_por_texto(u, "uma torre em ruínas chamada Vigia Negra", m["vale"], 8, 8)
	igual(u.entidade(ruina["eid"])["nome"], "Vigia Negra", "nome dado pelo autor")
	verdadeiro(ruina["sugestao"].is_empty(), "ruína não tem morador")


func test_povoar_e_desfazer() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var r := Povoador.povoar(u, m["vale"])
	var criados: Array = r["criados"]
	var povoados := criados.filter(func(e): return Mapa.especie(u, e) == "povoado")
	verdadeiro(povoados.size() >= 2, "criou povoados")
	var pessoas := criados.filter(func(e): return Sugestoes.categoria(u.entidade(e)["tipo"]) == "pessoa" and Estado.vivo(u, e))
	verdadeiro(pessoas.size() >= 4, "criou famílias")
	verdadeiro(pessoas.any(func(p): return not u.estado(p)["familia"]["filhos"].is_empty()), "com filhos")
	verdadeiro(pessoas.all(func(p): return u.estado(p)["local"] != ""), "todos moram em algum lugar")
	var mortos := criados.filter(func(e): return Sugestoes.categoria(u.entidade(e)["tipo"]) == "pessoa" and not Estado.vivo(u, e))
	verdadeiro(not mortos.is_empty(), "figuras históricas já mortas")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "lenda"), "viraram lenda")
	igual(Auditor.auditar(u).filter(func(p): return p["tipo"] != "aviso"), [], "auditor sem problemas")
	var n := Povoador.desfazer(u, r["fato"])
	igual(n, criados.size(), "desfez tudo")
	verdadeiro(criados.all(func(e): return u.entidade(e)["removida"]), "retirados, não apagados")


func test_eras_leis_e_lendas() -> void:
	var u := Universo.novo("Aldra")
	u.definir_relogio(DataMundo.criar(412, 1))
	Cosmos.criar_era(u, "Era das Cinzas", 0, 299)
	Cosmos.criar_era(u, "Era do Império", 300)
	igual(Cosmos.era_de(u, 120)["nome"], "Era das Cinzas", "ano 120")
	igual(Cosmos.era_de(u, 412)["nome"], "Era do Império", "ano atual")
	var f := Cosmos.acontecimento_antigo(u, 50, "o céu se partiu")
	igual(u.fatos.obter(f)["dados"]["era"], "Era das Cinzas", "lenda sabe a era")
	igual(int(u.fatos.obter(f)["data"]["ano"]), 50, "no ano 50")
	Cosmos.definir_leis(u, {"magia": 0.9, "texto": "A magia cobra memórias."})
	verdadeiro(u.fatos.todos().any(func(x): return x["tipo"] == "leis do universo"), "leis viram fato")
	igual(Cosmos.palavra_nivel(0.9), "por toda parte", "nível em palavras")


func test_mapa_sobrevive_a_salvar_e_carregar() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Mapa.pintar(u, m["vale"], 1, 1, "deserto")
	Natureza.intervir(u, m["varn"], "praga")
	Simulador.avancar(u, 14)
	var d: Dictionary = JSON.parse_string(JSON.stringify(u.para_dicionario()))
	var v := Universo.de_dicionario(d)
	igual(Mapa.pai(v, m["varn"]), m["vale"], "posição volta")
	igual(Mapa.terreno_em(v, m["vale"], 1, 1), "deserto", "pintura volta")
	igual(u.dias_de_viagem(m["varn"], m["kresk"]), v.dias_de_viagem(m["varn"], m["kresk"]), "viagem igual")
	igual(Natureza.eventos_ativos(v, m["varn"]).filter(func(e): return e["tipo"] == "praga").size(), 1, "praga continua")


func test_natureza_do_mapa_tem_nomes_que_ficam() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var a := Mapa.acidentes(u, m["planeta"])
	verdadeiro(a.size() >= 3, "o planeta tem serras, mares, florestas… (%d)" % a.size())
	verdadeiro(a.all(func(x): return str(x["nome"]).length() > 3), "todos com nome")
	var nomes := a.map(func(x): return x["nome"])
	igual(Mapa.acidentes(u, m["planeta"]).map(func(x): return x["nome"]), nomes, "os nomes não mudam")
	var d: Dictionary = JSON.parse_string(JSON.stringify(u.para_dicionario()))
	var v := Universo.de_dicionario(d)
	igual(Mapa.acidentes(v, m["planeta"]).map(func(x): return x["nome"]), nomes, "nomes guardados ao salvar")
	for r in Mapa.rios(u, m["planeta"]):
		var g := Mapa.terreno(u, m["planeta"])
		var dentro_da_agua: Array = r["pontos"].slice(0, r["pontos"].size() - 1).filter(func(p): return g[p.y][p.x] == "agua")
		igual(dentro_da_agua.size(), 0, "rio não corre por dentro do mar")


func test_escrever_nome_da_natureza_no_mapa() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	igual(Povoador.ler_acidente("as montanhas do sul")["nome"], "Montanhas do Sul", "nome com maiúsculas certas")
	igual(Povoador.ler_acidente("rio da pedra azul")["grupo"], "rio", "rio")
	verdadeiro(Povoador.ler_acidente("uma casa na montanha").is_empty(), "casa não é natureza")
	var r := Povoador.criar_por_texto(u, "montanha do sul", m["vale"], 30, 15)
	var a := Mapa.acidente_em(u, m["vale"], 30, 15)
	igual(a.get("nome", ""), "Montanha do Sul", "a serra tem o nome que o autor escreveu")
	igual(a.get("eid", ""), r["eid"], "e tem página na wiki")
	verdadeiro(Mapa.e_lugar(u, r["eid"]), "é um lugar do universo")
	var rio := Povoador.criar_por_texto(u, "rio da pedra azul", m["vale"], 30, 15)
	var achado := Mapa.rio_perto(u, m["vale"], 30, 15)
	igual(achado.get("nome", ""), "Rio da Pedra Azul", "o rio nasceu ali com o nome")
	verdadeiro(u.entidades.has(rio["eid"]), "rio com página")
	Mapa.nomear_acidente(u, m["vale"], achado, "Rio Azul")
	verdadeiro(u.fatos.todos().any(func(f): return f["descricao"] == "Rio da Pedra Azul passou a se chamar Rio Azul."), "renomear vira fato")
