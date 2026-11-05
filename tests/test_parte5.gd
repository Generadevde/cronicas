extends TesteBase
## Parte 5: leis escritas em português, poderes, corpo e vida, e nada sem efeito.


func _mundo() -> Dictionary:
	var u := Universo.novo("Aldra")
	u.extras["semente"] = 5555
	u.definir_relogio(DataMundo.criar(412, 10))
	var aldra := u.criar_entidade("Aldra", "planeta")
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "5000"}])
	var kresk := u.criar_entidade("Kresk", "cidade")
	Mapa.colocar(u, aldra, "", 10, 10)
	Mapa.colocar(u, varn, aldra, 10, 10)
	Mapa.colocar(u, kresk, aldra, 14, 10)
	var chama := u.criar_entidade("Chama Antiga", "magia", [], [{"chave": "força", "valor": "4"}])
	var mira := u.criar_entidade("Mira", "pessoa", [], [{"chave": "idade", "valor": "30 anos"}, {"chave": "poderes", "valor": "Chama Antiga"},
		{"chave": "personalidade", "valor": "corajosa"}])
	var kai := u.criar_entidade("Kai", "pessoa", [], [{"chave": "idade", "valor": "40 anos"}, {"chave": "personalidade", "valor": "cruel"}])
	var borin := u.criar_entidade("Borin", "pessoa", [], [{"chave": "ofício", "valor": "guerreiro"}, {"chave": "força", "valor": "2"}])
	var daren := u.criar_entidade("Daren", "pessoa", [], [{"chave": "idade", "valor": "20 anos"}])
	for p in [[mira, varn], [kai, varn], [borin, kresk], [daren, varn]]:
		u.estado(p[0])["local"] = p[1]
	return {"u": u, "aldra": aldra, "varn": varn, "kresk": kresk, "chama": chama, "mira": mira, "kai": kai, "borin": borin, "daren": daren}


func test_le_as_leis_do_plano() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var r := Regras.interpretar(u, "Neste mundo, quem usa magia envelhece um ano por feitiço.")
	igual(r["quando"].get("acao", ""), "usar_poder", "gatilho: usar magia")
	igual(r["quando"].get("categoria", ""), "magia", "só magia")
	igual(r["efeitos"][0]["peca"], "envelhecer", "efeito: envelhecer")
	igual(int(r["efeitos"][0]["dias"]), 360, "um ano")
	igual(r["entendida"], "toda", "entendida toda")
	r = Regras.interpretar(u, "Guerreiros de Kresk ficam 10% mais fortes a cada vitória.")
	igual(r["quando"].get("acao", ""), "vitoria", "a cada vitória")
	igual(r["quem"].get("lugar", ""), m["kresk"], "de Kresk")
	verdadeiro(r["quem"]["palavras"].any(func(p): return str(p).begins_with("guerr")), "guerreiros")
	igual(r["efeitos"][0]["peca"], "poder", "mais fortes")
	verdadeiro(absf(float(r["efeitos"][0]["pct"]) - 0.1) < 0.001, "10%")
	r = Regras.interpretar(u, "Lobos-guardiões atacam quem corta árvores da floresta antiga.")
	igual(r["quando"]["tipo"], "termo", "gatilho escrito pelo autor")
	verdadeiro(r["quando"]["raizes"].has("cort") and r["quando"]["raizes"].has("arvo"), "raízes do termo")
	igual(r["efeitos"][0]["peca"], "ferir", "ataque fere")
	r = Regras.interpretar(u, "Quem bebe da fonte de Varn esquece o último ano.")
	igual(r["quando"]["tipo"], "termo", "beber da fonte é termo")
	igual(r["efeitos"][0]["peca"], "esquecer", "esquece")
	igual(int(r["efeitos"][0]["dias"]), 360, "o último ano")
	r = Regras.interpretar(u, "A cada 100 anos, um eclipse desperta os mortos de Aldra.")
	igual(r["quando"]["tipo"], "periodico", "periódico")
	igual(int(r["quando"]["a_cada"]), 36000, "100 anos")
	igual(r["efeitos"][0]["peca"], "reviver", "mortos despertam")
	igual(r["efeitos"][0].get("lugar_alvo", ""), m["aldra"], "em Aldra")
	r = Regras.interpretar(u, "chuva de sangue → todos em Varn sentem medo; lavouras caem 30%")
	igual(r["quando"]["tipo"], "termo", "seta: termo")
	igual(r["efeitos"].size(), 2, "dois efeitos")
	igual(r["efeitos"][0]["alvo"], "todos_no_lugar", "todos em Varn")
	igual(r["efeitos"][1]["peca"], "natureza", "lavouras")
	r = Regras.interpretar(u, "Quem mata alguém, se estiver ferido, sente culpa 50% das vezes.")
	igual(r["quando"].get("acao", ""), "matar", "matar")
	verdadeiro(r["se"].any(func(c): return c["tipo"] == "ferido"), "condição ferido")
	verdadeiro(r["se"].any(func(c): return c["tipo"] == "chance"), "chance")
	r = Regras.interpretar(u, "Os elfos vivem 700 anos.")
	igual(r["efeitos"][0]["peca"], "expectativa", "expectativa de vida")


## O teste da Parte 5 no plano: "quem usa magia envelhece um ano por feitiço" funcionando.
func test_magia_envelhece_na_simulacao() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var lei := Regras.criar(u, "Neste mundo, quem usa magia envelhece um ano por feitiço.")
	verdadeiro(not lei.is_empty(), "lei criada")
	var antes := Estado.idade(u, m["mira"])
	igual(antes, 30, "Mira tem 30")
	# 1) Numa luta da simulação.
	var usou := false
	for semente in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		var r := Poderes.na_luta(u, m["mira"], m["kai"], rng, [])
		if not r["fatos"].is_empty():
			usou = true
			verdadeiro(float(r["bonus"].get(m["mira"], 1.0)) > 1.0, "a magia ajuda na luta")
			break
	verdadeiro(usou, "Mira usou a magia numa luta")
	igual(Estado.idade(u, m["mira"]), 31, "envelheceu um ano")
	var efeito: Array = u.fatos.todos().filter(func(f): return f["tipo"] == "efeito de lei")
	verdadeiro(not efeito.is_empty(), "o efeito virou fato")
	verdadeiro(efeito[0]["causas"].size() >= 1 and u.fatos.obter(efeito[0]["causas"][0])["dados"].get("acao", "") == "usar_poder", "causado pelo uso da magia")
	# 2) Escrito num capítulo.
	var l := u.criar_livro("Livro")
	var c := u.criar_capitulo(l, "Fogo")
	u.atualizar_capitulo(c, {"data": DataMundo.criar(412, 20), "texto": "Mira lançou um feitiço contra Kai."})
	var props := Extrator.analisar(u, c).filter(func(p): return p["acao"] == "usar_poder")
	igual(props.size(), 1, "a margem propõe o uso de magia")
	var fid := u.aceitar_proposta(props[0]["id"])
	igual(Estado.idade(u, m["mira"]), 32, "o capítulo também envelhece")
	# 3) Desfazer o uso desfaz o efeito.
	u.desfazer_fato(fid)
	igual(Estado.idade(u, m["mira"]), 31, "desfazer devolve o ano")
	# 4) Quem não usa magia não envelhece; desligar a lei para o efeito.
	Regras.ligar(u, lei["id"], false)
	Poderes.usar(u, m["mira"], m["chama"], "", [])
	igual(Estado.idade(u, m["mira"]), 31, "lei suspensa não age")
	igual(Auditor.auditar(u), [], "auditor sem problemas")


func test_guerreiros_de_kresk_ficam_mais_fortes() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Regras.criar(u, "Guerreiros de Kresk ficam 10% mais fortes a cada vitória.")
	var p0 := Estado.poder(u, m["borin"])
	Simulador.registrar(u, {"tipo": "luta", "descricao": "Borin venceu Kai.", "sujeitos": [m["borin"], m["kai"]], "lugar": m["kresk"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "vitoria"}})
	verdadeiro(absf(Estado.poder(u, m["borin"]) - p0 * 1.1) < 0.01, "Borin +10% (%.2f → %.2f)" % [p0, Estado.poder(u, m["borin"])])
	var pk := Estado.poder(u, m["kai"])
	Simulador.registrar(u, {"tipo": "luta", "descricao": "Kai venceu Daren.", "sujeitos": [m["kai"], m["daren"]], "lugar": m["varn"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "vitoria"}})
	igual(Estado.poder(u, m["kai"]), pk, "Kai não é guerreiro de Kresk")


func test_termo_escrito_no_capitulo() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Regras.criar(u, "Quem bebe da fonte de Varn esquece o último ano.")
	var lembranca := Simulador.registrar(u, {"tipo": "encontro", "descricao": "Daren viu Kai matar Lucas.", "sujeitos": [m["daren"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "data": DataMundo.criar(412, 5),
		"dados": {"mudancas": [{"op": "lembrar", "quem": m["daren"], "peso": 0.9}, {"op": "emocao", "quem": m["daren"], "emocao": "odio", "forca": 0.8, "alvo": m["kai"]}]}})
	verdadeiro(Estado.conhece(u, m["daren"], lembranca), "lembra")
	var l := u.criar_livro("Livro")
	var c := u.criar_capitulo(l, "A Fonte")
	u.atualizar_capitulo(c, {"data": DataMundo.criar(412, 30), "texto": "Cansado, Daren bebeu da fonte de Varn."})
	var props := Extrator.analisar(u, c).filter(func(p): return p["acao"] == "regra")
	igual(props.size(), 1, "a margem reconhece o termo da lei")
	u.aceitar_proposta(props[0]["id"])
	falso(Estado.conhece(u, m["daren"], lembranca), "esqueceu")
	verdadeiro(Estado.emocoes_atuais(u, m["daren"]).filter(func(e): return e["emocao"] == "odio").is_empty(), "o ódio foi junto")


func test_termo_numa_intervencao_e_seta() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Regras.criar(u, "chuva de sangue → todos em Varn sentem medo; lavouras caem 30%")
	var lav0 := float(Natureza.de(u, m["varn"])["especies"]["lavouras"]["n"])
	var r := Natureza.intervir(u, m["varn"], "uma chuva de sangue")
	igual(r["leis"].size(), 1, "a lei do autor valeu")
	verdadeiro(Estado.emocoes_atuais(u, m["mira"]).any(func(e): return e["emocao"] == "medo"), "Mira sentiu medo")
	verdadeiro(float(Natureza.de(u, m["varn"])["especies"]["lavouras"]["n"]) < lav0 * 0.8, "lavouras caíram")
	falso(u.fatos.obter(r["fato"])["dados"]["sem_efeito"], "não ficou sem efeito")


func test_leis_periodicas() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var morto := u.criar_entidade("Velho Tarn", "pessoa")
	u.estado(morto)["local"] = m["varn"]
	Simulador.registrar(u, {"tipo": "morte", "descricao": "Velho Tarn morreu.", "sujeitos": [morto], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": [{"op": "morrer", "quem": morto}]}})
	Regras.criar(u, "A cada 2 anos, um eclipse desperta os mortos de Aldra.")
	Simulador.avancar(u, 360)
	falso(Estado.vivo(u, morto), "ainda não")
	Simulador.avancar(u, 400)
	verdadeiro(Estado.vivo(u, morto), "o eclipse despertou o morto")
	verdadeiro(Pecas.marcas(u, morto).has("morto-vivo"), "marcado como morto-vivo")


func test_corpo_envelhece_e_morre() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var velho := u.criar_entidade("Ancião", "pessoa", [], [{"chave": "idade", "valor": "92 anos"}])
	var elfo := u.criar_entidade("Lirael", "pessoa", [], [{"chave": "idade", "valor": "92 anos"}, {"chave": "raça", "valor": "elfa"}])
	Regras.criar(u, "Os elfos vivem 700 anos.")
	igual(Corpo.expectativa(u, elfo), 700.0, "a lei dá 700 anos aos elfos")
	igual(Corpo.expectativa(u, velho), 70.0, "humano comum")
	verdadeiro(Corpo.fator_idade(u, velho) < 0.8, "velho perde força")
	igual(Corpo.fator_idade(u, elfo), 1.0, "a elfa está no auge")
	Simulador.avancar(u, 360 * 8)
	falso(Estado.vivo(u, velho), "o ancião morreu de velhice")
	verdadeiro(Estado.vivo(u, elfo), "a elfa segue viva")
	var morte: Array = u.fatos.sobre(velho).filter(func(f): return f["tipo"] == "morte natural")
	igual(morte.size(), 1, "morte natural virou fato")


func test_poder_com_custo_limite_e_narrativo() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	u.editar_entidade(m["chama"], {"campos": [{"chave": "custo", "valor": "envelhece dez anos"}, {"chave": "limite", "valor": "uma vez por ano"},
		{"chave": "efeitos permitidos", "valor": "o outro fica ferido"}]})
	Poderes.usar(u, m["mira"], m["chama"], m["kai"], [])
	igual(Estado.idade(u, m["mira"]), 40, "o custo cobrou dez anos")
	verdadeiro(Estado.saude_atual(u, m["kai"]) < 1.0, "efeito permitido: Kai ferido")
	falso(Poderes.pode_usar(u, m["mira"], m["chama"]), "limite: uma vez por ano")
	var destino := u.criar_entidade("Tecer o Destino", "dom", [], [{"chave": "efeito", "valor": "reescreve o destino de alguém"}])
	verdadeiro(Poderes.narrativo(u, destino), "poder narrativo")
	var r := Poderes.usar(u, m["kai"], destino, m["daren"], [])
	verdadeiro(r["pedido"] != "", "virou pedido ao autor")
	verdadeiro(Pendencias.listar(u).any(func(i): return i["tipo"] == "pedido"), "aparece em 'ainda sem efeito'")
	Poderes.responder_pedido(u, r["pedido"], "o outro esquece tudo; o outro passa a ser leal a Kai")
	igual(Poderes.pedidos(u).size(), 0, "pedido respondido")


func test_nada_sem_efeito() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	u.editar_entidade(m["kai"], {"campos": u.entidade(m["kai"])["campos"] + [{"chave": "segredos", "valor": "matou o próprio irmão"}, {"chave": "aparência", "valor": "alto"}]})
	var itens := Pendencias.listar(u)
	verdadeiro(itens.any(func(i): return i["tipo"] == "campo" and i["chave"] == "segredos"), "campo 'segredos' sem efeito aparece")
	falso(itens.any(func(i): return i["tipo"] == "campo" and i["chave"] == "aparência"), "aparência é descrição")
	falso(itens.any(func(i): return i["tipo"] == "campo" and i["chave"] == "ofício"), "ofício fica para a Parte 6")
	var item: Dictionary = itens.filter(func(i): return i["tipo"] == "campo" and i["chave"] == "segredos")[0]
	Pendencias.definir(u, item, "fica desconfiado")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "efeito de lei" and f["sujeitos"].has(m["kai"])), "quem tem segredos ficou desconfiado")
	falso(Pendencias.listar(u).any(func(i): return i["tipo"] == "campo" and i["chave"] == "segredos"), "saiu da lista")
	var iv := Natureza.intervir(u, m["varn"], "um cometa cruza o céu")
	verdadeiro(Pendencias.listar(u).any(func(i): return i["tipo"] == "intervencao"), "intervenção sem efeito aparece")
	var it2: Dictionary = Pendencias.listar(u).filter(func(i): return i["tipo"] == "intervencao")[0]
	Pendencias.definir(u, it2, "todos em Varn sentem esperança")
	verdadeiro(Estado.emocoes_atuais(u, m["mira"]).any(func(e): return e["emocao"] == "esperanca"), "o efeito aconteceu")
	var r := Natureza.intervir(u, m["kresk"], "um cometa cruza o céu")
	igual(r["leis"].size(), 1, "da próxima vez já sabe")
	falso(Pendencias.listar(u).any(func(i): return i["tipo"] == "intervencao"), "nada pendente")


func test_leis_sobrevivem_a_salvar() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Regras.criar(u, "Neste mundo, quem usa magia envelhece um ano por feitiço.")
	var d: Dictionary = JSON.parse_string(JSON.stringify(u.para_dicionario()))
	var v := Universo.de_dicionario(d)
	igual(Regras.todas(v).size(), 1, "lei guardada")
	Poderes.usar(v, m["mira"], m["chama"], "", [])
	igual(Estado.idade(v, m["mira"]), 31, "e continua valendo")
