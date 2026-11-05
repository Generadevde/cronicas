extends TesteBase
## Parte 8: pactos e forças cósmicas — entidades que oferecem pactos, preços
## escondidos, o Autor e o arauto, poderes que mudam as regras do motor.
## Teste do plano: um pacto cujo preço chega anos depois.


func _mundo(semente: int = 8080) -> Dictionary:
	var u := Universo.novo("Cinzas")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(500, 10))
	var planeta := u.criar_entidade("Velha Terra", "planeta")
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "3000"}])
	var kresk := u.criar_entidade("Kresk", "cidade", [], [{"chave": "população", "valor": "2000"}])
	Mapa.colocar(u, planeta, "", 10, 10)
	Mapa.colocar(u, varn, planeta, 10, 10)
	Mapa.colocar(u, kresk, planeta, 14, 11)
	var daren := _pessoa(u, "Daren", 25, "rancoroso, impulsivo, ambicioso e orgulhoso", varn, [{"chave": "força", "valor": "5"}])
	var kai := _pessoa(u, "Kai", 30, "cruel e orgulhoso", kresk, [{"chave": "força", "valor": "90"}])
	var lia := _pessoa(u, "Lia", 24, "gentil, sociável e devota", varn, [])
	var mae := u.criar_entidade("Mãe das Cinzas", "demônio", [], [{"chave": "natureza", "valor": "demônio antigo"},
		{"chave": "o que oferece", "valor": "vingança"}, {"chave": "o que cobra", "valor": "a alma do primeiro filho, em dez anos"}])
	# Kai matou o pai de Daren: Daren jura vingança (e Kai é muito mais forte).
	Simulador.registrar(u, {"tipo": "ódio", "descricao": "Daren jurou vingança contra Kai.", "sujeitos": [daren, kai],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"mudancas": [{"op": "objetivo", "quem": daren, "tipo": "vingança", "alvo": kai, "forca": 0.95}]}})
	return {"u": u, "varn": varn, "kresk": kresk, "daren": daren, "kai": kai, "lia": lia, "mae": mae, "planeta": planeta}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String, extra: Array) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}] + extra)
	u.estado(e)["local"] = lugar
	return e


func test_le_o_preco() -> void:
	var p := Pactos.ler_preco("a alma do primeiro filho, em dez anos")
	igual(p["quem"], "filho", "quem paga: o primeiro filho")
	igual(int(p["dias"]), 3600, "em dez anos")
	igual(p["efeito"], "morre", "a alma = a vida")
	var p2 := Pactos.ler_preco("a cidade inteira dorme por cem anos")
	igual(p2["quem"], "cidade", "a cidade paga")
	igual(p2["efeito"], "sono eterno", "sono eterno")
	var p3 := Pactos.ler_preco("vinte anos de vida")
	igual(p3["efeito"], "envelhece 20 anos", "anos de vida")
	verdadeiro(int(p3["dias"]) >= 3 * 360, "sem prazo escrito: chega em alguns anos")


func test_pacto_cujo_preco_chega_anos_depois() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var desejo := Pactos.desejo(u, m["daren"])
	igual(desejo.get("tipo", ""), "vinganca", "o desejo sem saída: vingança")
	verdadeiro(float(desejo["desespero"]) > 0.7, "desesperado (Kai é muito mais forte): %.2f" % float(desejo.get("desespero", 0)))
	# A entidade procura e oferece; Daren aceita.
	var dias := 0
	while Pactos.pactos_de(u, m["mae"]).is_empty() and dias < 360:
		Simulador.avancar(u, 28)
		dias += 28
	igual(Pactos.pactos_de(u, m["mae"]).size(), 1, "a Mãe das Cinzas fez um pacto")
	var pacto: Dictionary = Pactos.pactos_de(u, m["mae"])[0]
	igual(pacto["com"], m["daren"], "com Daren")
	var fp := u.fatos.obter(pacto["fato"])
	verdadeiro(fp["dados"].get("secreto", false), "o pacto é secreto")
	verdadeiro(u.fatos.cadeia_de_causas(fp["id"], 10).any(func(c): return c["tipo"] == "oferta de pacto"), "nasceu de uma oferta")
	# O desejo se cumpre de verdade.
	falso(Estado.vivo(u, m["kai"]), "Kai morreu")
	var cumprido: Array = u.fatos.consequencias(fp["id"]).filter(func(f): return f["tipo"] == "desejo cumprido")
	igual(cumprido.size(), 1, "o desejo cumprido é fato, causado pelo pacto")
	verdadeiro(cumprido[0]["descricao"].contains("sem que ninguém soubesse"), "o mundo vê o efeito, não a causa")
	# Ninguém mais fica sabendo do pacto.
	Simulador.avancar(u, 60)
	falso(Estado.conhece(u, m["lia"], fp["id"]), "Lia não sabe do pacto (é secreto)")
	verdadeiro(Estado.conhece(u, m["daren"], fp["id"]), "Daren sabe")
	# Daren tem um filho.
	var filho := _pessoa(u, "Tomas", 0, "curioso", m["varn"], [])
	Simulador.registrar(u, {"tipo": "nascimento", "descricao": "Nasceu Tomas, filho de Daren.", "sujeitos": [filho, m["daren"]], "lugar": m["varn"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"mudancas": [{"op": "nascer", "quem": filho, "lugar": m["varn"]}, {"op": "familia", "pai": m["daren"], "filho": filho}]}})
	# Anos depois, o preço chega.
	Simulador.avancar(u, 9 * 360)
	verdadeiro(Estado.vivo(u, filho), "antes dos dez anos, nada")
	Simulador.avancar(u, 400)
	falso(Estado.vivo(u, filho), "o primeiro filho pagou o preço")
	var preco: Array = u.fatos.consequencias(fp["id"]).filter(func(f): return f["tipo"] == "preço do pacto")
	igual(preco.size(), 1, "o preço é fato, causado pelo pacto")
	verdadeiro(preco[0]["descricao"].contains("há 10 anos"), preco[0]["descricao"])
	verdadeiro(Pactos.pactos_de(u, m["mae"])[0]["cobrado"], "pacto cobrado")
	falso(preco[0]["dados"].get("secreto", false), "o preço não é segredo: o mundo descobre")
	Simulador.avancar(u, 30)
	verdadeiro(Estado.conhece(u, m["lia"], preco[0]["id"]), "Lia ficou sabendo do preço")
	igual(Auditor.auditar(u).size(), 0, "auditor limpo")
	# Tudo reconstruível.
	AutoAtualizador.reconstruir(u)
	falso(Estado.vivo(u, filho), "depois de reconstruir, o filho continua morto")
	verdadeiro(Pactos.pactos_de(u, m["mae"])[0]["cobrado"], "e o pacto continua cobrado")


func test_quem_recusa() -> void:
	var m := _mundo(8181)
	var u: Universo = m["u"]
	u.editar_entidade(m["daren"], {"campos": [{"chave": "idade", "valor": "25 anos"}, {"chave": "personalidade", "valor": "prudente, gentil e calmo"}, {"chave": "força", "valor": "5"}]})
	var d := Pactos.desejo(u, m["daren"])
	falso(Pactos.aceita(u, m["daren"], d, Pactos.ler_preco("a alma do primeiro filho, em dez anos")), "um prudente e gentil recusa entregar o filho")


func test_pacto_feito_pelo_autor_e_guerra() -> void:
	var m := _mundo(8282)
	var u: Universo = m["u"]
	u.estado(m["daren"])["objetivos"] = []  # sem vingança: Daren fica em casa
	var fid := Pactos.fazer(u, m["mae"], m["daren"], {"tipo": "forca", "texto": "força"}, "vinte anos de vida, em dois anos", true, [], true)
	igual(u.fatos.obter(fid)["origem"]["tipo"], BancoDeFatos.ORIGEM_AUTOR, "pacto do autor")
	verdadeiro(Estado.poder(u, m["daren"]) > 10.0, "Daren ficou mais forte")
	var idade_antes := Estado.idade(u, m["daren"])
	Simulador.avancar(u, 2 * 360 + 14)
	verdadeiro(Estado.idade(u, m["daren"]) >= idade_antes + 20, "pagou vinte anos de vida (%d → %d)" % [idade_antes, Estado.idade(u, m["daren"])])


func test_autor_e_arauto() -> void:
	var m := _mundo(8383)
	var u: Universo = m["u"]
	var a := Autor.existir(u, "O Escriba")
	igual(u.entidade(a)["nome"], "O Escriba", "o Autor com o nome que quiser")
	falso(Estado.tem_mente(u, a), "fora da simulação das mentes")
	falso(Mapa.no_mapa(u, a), "fora do mapa")
	Autor.tornar_arauto(u, m["lia"])
	verdadeiro(Autor.eh_arauto(u, m["lia"]), "Lia conhece o Autor")
	var rf := Autor.revelar(u, m["lia"], "Quando a lua sangrar, Varn cairá.", "profecia")
	igual(u.fatos.obter(rf)["origem"]["tipo"], BancoDeFatos.ORIGEM_AUTOR, "a revelação é fato do autor")
	verdadeiro(Estado.conhece(u, m["lia"], rf), "o arauto sabe")
	falso(Estado.conhece(u, m["daren"], rf), "os outros não")
	Simulador.avancar(u, 14)
	var reacoes: Array = u.fatos.consequencias(rf).filter(func(f): return f["tipo"] == "reação do arauto")
	igual(reacoes.size(), 1, "o arauto reagiu com a própria mente")
	verdadeiro(reacoes[0]["descricao"].contains("espalhou"), "Lia (sociável e devota) espalhou: " + reacoes[0]["descricao"])
	Simulador.avancar(u, 21)
	verdadeiro(Estado.conhece(u, m["daren"], reacoes[0]["id"]), "o mundo ficou sabendo pelas notícias")
	# Uma ordem.
	var ro := Autor.revelar(u, m["lia"], "Vá para Kresk.", "ordem")
	Simulador.avancar(u, 21)
	var r2: Array = u.fatos.consequencias(ro)
	verdadeiro(not r2.is_empty(), "reagiu à ordem")
	if r2[0]["descricao"].contains("obedeceu"):
		Simulador.avancar(u, 30)
		igual(u.estado(m["lia"])["local"], m["kresk"], "obedeceu e foi para Kresk")
	# Pacto com o Autor, como com qualquer força.
	u.editar_entidade(a, {"campos": [{"chave": "o que oferece", "valor": "cura"}, {"chave": "o que cobra", "valor": "a voz, em um ano"}]})
	verdadeiro(Pactos.ofertantes(u).has(a), "o Autor também oferece pactos")


func test_poderes_que_mudam_o_motor() -> void:
	var m := _mundo(8484)
	var u: Universo = m["u"]
	u.estado(m["daren"])["objetivos"] = []
	var parar := u.criar_entidade("Instante Eterno", "dom", [], [{"chave": "efeito", "valor": "para o tempo por 30 dias"}, {"chave": "quem pode usar", "valor": "Lia"}])
	var antes := u.relogio.duplicate()
	Poderes.usar(u, m["lia"], parar, m["daren"], [])
	verdadeiro(not Motor.pausa(u).is_empty(), "o tempo parou")
	verdadeiro(Motor.pausa(u)["quem"].has(m["lia"]) and Motor.pausa(u)["quem"].has(m["daren"]), "menos para Lia e quem ela tocou")
	Simulador.avancar(u, 28)
	igual(u.relogio, antes, "o relógio do mundo não andou")
	Simulador.avancar(u, 14)
	verdadeiro(DataMundo.ordem(u.relogio) > DataMundo.ordem(antes), "acabada a pausa, o tempo volta a andar")
	falso(Pendencias.listar(u).any(func(i): return i["tipo"] == "pedido"), "não virou pedido: o motor sabe fazer")

	# Sono eterno sobre Varn.
	var sono := Simulador.registrar(u, {"tipo": "maldição", "descricao": "Uma maldição: Varn cai em sono eterno.", "sujeitos": [m["varn"]], "lugar": m["varn"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"mudancas": Pecas.operacoes(u, Pecas.ler(u, "Varn cai em sono eterno")[0], {"lugar": m["varn"]})}})
	verdadeiro(Motor.adormecido(u, m["varn"]), "Varn dorme")
	falso(Simulador._mentes(u).has(m["daren"]), "quem está em Varn saiu da simulação")
	var idade := Estado.idade(u, m["daren"])
	var fatos_antes := u.fatos.sobre(m["daren"]).size()
	Simulador.avancar(u, 360)
	igual(u.fatos.sobre(m["daren"]).size(), fatos_antes, "Daren não fez nada por um ano")
	Simulador.registrar(u, {"tipo": "maldição quebrada", "descricao": "A maldição de Varn foi quebrada.", "sujeitos": [m["varn"]], "lugar": m["varn"], "causas": [sono],
		"dados": {"mudancas": [{"op": "despertar", "lugar": m["varn"]}]}})
	falso(Motor.adormecido(u, m["varn"]), "Varn despertou")

	# Ver o futuro.
	var olho := u.criar_entidade("Olho do Amanhã", "dom", [], [{"chave": "efeito", "valor": "vê o futuro"}])
	u.estado(m["kai"])["local"] = m["kresk"]
	var uso := Poderes.usar(u, m["kai"], olho, "", [])
	var efeito: Array = uso["fatos"].map(func(i): return u.fatos.obter(i)).filter(func(f): return f["dados"].has("previsao"))
	igual(efeito.size(), 1, "a visão ficou guardada no fato")
	verdadeiro(efeito[0]["dados"]["previsao"] is Array, "uma lista do que vem")
	verdadeiro(Pecas.marcas(u, m["kai"]).has("viu o futuro"), "Kai viu o futuro")

	# Viagem ao passado: abre um galho.
	var fatos_hoje := u.fatos.quantidade()
	var g := Motor.galho(u, DataMundo.criar(500, 10))
	igual(g.relogio, DataMundo.criar(500, 10), "o galho começa no passado")
	verdadeiro(g.id != u.id, "é outro universo")
	igual(g.fatos.quantidade(), fatos_hoje, "nada se perde: os fatos de depois ficam guardados")
	verdadeiro(g.fatos.todos().any(func(f): return not f["canon"] and f["dados"].get("fora_do_galho", false)), "mas fora do canon do galho")
	verdadeiro(Estado.vivo(u, m["daren"]), "o universo original continua igual")


func test_seguidores_e_reacao() -> void:
	var m := _mundo(8585)
	var u: Universo = m["u"]
	u.estado(m["daren"])["objetivos"] = []
	var reino := u.criar_entidade("Igreja de Varn", "igreja", [], [{"chave": "forma de governo", "valor": "teocracia"}, {"chave": "território", "valor": "Varn"},
		{"chave": "líder", "valor": "Lia"}])
	for i in 6:
		_pessoa(u, "Fiel %d" % i, 30, "ambicioso e medroso", m["varn"], [])
	var h := Humor.de(u, m["varn"])
	h["fe"] = 0.8
	h["medo"] = 0.6
	Pactos.fazer(u, m["mae"], m["daren"], {"tipo": "riqueza", "texto": "riqueza"}, "", true, [], true)
	var dias := 0
	while not u.estado(reino).has("reagiu_" + m["mae"]) and dias < 6 * 360:
		Simulador.avancar(u, 90)
		dias += 90
	verdadeiro(u.entidades_ativas().any(func(e): return Pecas.marcas(u, e["id"]).has("seguidor de Mãe das Cinzas")), "a entidade ganhou seguidores")
	igual(u.estado(reino).get("reagiu_" + m["mae"], ""), "persegue", "a teocracia persegue o culto")
