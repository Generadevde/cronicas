extends TesteBase
## Parte 3: mentes e tempo.


func _mundo() -> Dictionary:
	var u := Universo.novo("Aldra")
	var varn := u.criar_entidade("Varn", "cidade")
	var kresk := u.criar_entidade("Kresk", "cidade")
	var kai := u.criar_entidade("Kai", "pessoa", [], [{"chave": "personalidade", "valor": "arrogante e cruel"}, {"chave": "força", "valor": "3"}])
	var lucas := u.criar_entidade("Lucas", "pessoa", [], [{"chave": "personalidade", "valor": "calmo e gentil"}])
	var daren := u.criar_entidade("Daren", "pessoa", [], [
		{"chave": "personalidade", "valor": "rancoroso, corajoso e orgulhoso"},
		{"chave": "força", "valor": "1"},
		{"chave": "desejos", "valor": "vingar Lucas"}])
	var orvan := u.criar_entidade("Orvan", "pessoa", [], [{"chave": "personalidade", "valor": "sábio, gentil e paciente"}, {"chave": "poder", "valor": "12"}])
	var livro := u.criar_livro("Livro I")
	var c := u.criar_capitulo(livro, "A Praça")
	u.atualizar_capitulo(c, {"data": DataMundo.criar(411, 100), "texto":
		"Daren é filho de Lucas. Kai enfrentou Lucas na praça de Varn, e Lucas perdeu. Orvan está em Varn. Kai foi para Kresk."})
	for p in Extrator.analisar(u, c):
		if p["status"] == "pendente":
			u.aceitar_proposta(p["id"])
	u.relogio = DataMundo.criar(411, 101)
	u.estado(daren)["local"] = varn
	return {"u": u, "varn": varn, "kresk": kresk, "kai": kai, "lucas": lucas, "daren": daren, "orvan": orvan}


func test_personalidade_vem_do_texto_livre() -> void:
	var m := _mundo()
	var t := Personalidade.tracos(m["u"], m["daren"])
	verdadeiro(t["rancor"] > 0.7, "rancoroso")
	verdadeiro(t["coragem"] > 0.7, "corajoso")
	verdadeiro(Personalidade.tracos(m["u"], m["lucas"])["empatia"] > 0.6, "gentil vira empatia")
	igual(Personalidade.tracos(m["u"], m["daren"]), t, "sempre o mesmo resultado")


func test_desejo_vingar_aponta_para_quem_fez_mal() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Simulador.preparar(u)
	var objs := Estado.objetivos_ativos(u, m["daren"])
	verdadeiro(objs.any(func(o): return o["tipo"] == "vingança" and o["alvo"] == m["kai"]), "\"vingar Lucas\" vira vingança contra Kai, que derrotou Lucas")


func test_numeros_de_poder() -> void:
	igual(Combate.ler_numero("98 mil"), 98000.0, "98 mil")
	igual(Combate.ler_numero("70.000"), 70000.0, "70.000")
	igual(Combate.ler_numero("1,5 milhão"), 1500000.0, "1,5 milhão")
	igual(Combate.ler_numero("nível 40"), 40.0, "nível 40")


func test_chance_de_luta_desigual() -> void:
	var u := Universo.novo("T")
	var a := u.criar_entidade("Jhon Black", "pessoa", [], [{"chave": "força", "valor": "98 mil"}])
	var b := u.criar_entidade("Sirius Dal", "pessoa", [], [{"chave": "força", "valor": "70 mil"}])
	var c := Combate.chance(u, a, b)
	verdadeiro(c > 0.55 and c < 0.8, "98 mil contra 70 mil dá vantagem, não certeza (veio %.2f)" % c)


func test_emocao_esfria_mais_devagar_em_quem_e_rancoroso() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Estado.emocionar(u, m["daren"], "raiva", 0.8, m["kai"], "")
	Estado.emocionar(u, m["lucas"], "raiva", 0.8, m["kai"], "")
	Simulador._andar_relogio(u, 360)
	var fd := Estado.emocao_por(u, m["daren"], m["kai"], ["raiva"])
	var fl := Estado.emocao_por(u, m["lucas"], m["kai"], ["raiva"])
	verdadeiro(fd > fl, "a raiva do rancoroso dura mais (%.2f > %.2f)" % [fd, fl])


func test_relogio_anda() -> void:
	var u := Universo.novo("T")
	u.relogio = DataMundo.criar(411, 355)
	Simulador.avancar(u, 10)
	igual(u.relogio, DataMundo.criar(412, 5), "virou o ano")


func test_vinganca_acontece_sozinha() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var poder_antes := Estado.poder(u, m["daren"])
	Simulador.avancar(u, 360 * 6)
	var tipos := {}
	for f in u.fatos.todos():
		if f["origem"]["tipo"] == BancoDeFatos.ORIGEM_SIMULACAO and f["sujeitos"].has(m["daren"]):
			tipos[f["tipo"]] = true
	verdadeiro(tipos.has("aprendizado") or tipos.has("pedido recusado") or tipos.has("treino"), "Daren buscou mestre ou treinou (%s)" % str(tipos.keys()))
	verdadeiro(Estado.poder(u, m["daren"]) > poder_antes, "Daren ficou mais forte")
	verdadeiro(tipos.has("viagem") or tipos.has("luta") or tipos.has("perdão"), "a vingança andou: viagem, luta ou perdão (%s)" % str(tipos.keys()))
	igual(Auditor.auditar(u).size(), 0, "nenhum fato sem causa nem problema")


func test_noticia_viaja_e_quem_sabe_reage() -> void:
	var u := Universo.novo("T")
	var varn := u.criar_entidade("Varn", "cidade")
	var kresk := u.criar_entidade("Kresk", "cidade")
	var kai := u.criar_entidade("Kai", "pessoa")
	var lucas := u.criar_entidade("Lucas", "pessoa")
	var mira := u.criar_entidade("Mira", "pessoa", [], [{"chave": "personalidade", "valor": "rancorosa"}])
	var l := u.criar_livro("L")
	var c := u.criar_capitulo(l, "C")
	u.atualizar_capitulo(c, {"data": DataMundo.criar(10, 10), "texto": "Mira é filha de Lucas. Mira mora em Kresk. Lucas está em Varn. Kai matou Lucas em Varn."})
	for p in Extrator.analisar(u, c):
		if p["status"] == "pendente":
			u.aceitar_proposta(p["id"])
	for p in u.propostas.duplicate():
		if p["status"] == "eco":
			u.riscar_proposta(p["id"])  # sem ecos: queremos ver a notícia chegar
	u.relogio = DataMundo.criar(10, 11)
	verdadeiro(not Estado.conhece(u, mira, _fato_morte(u)), "Mira ainda não sabe")
	Simulador.avancar(u, 60)
	verdadeiro(Estado.conhece(u, mira, _fato_morte(u)), "a notícia chegou a Kresk")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "reação" and f["sujeitos"].has(mira) and f["sujeitos"].has(kai)), "Mira reagiu ao saber")
	verdadeiro(u.estado(mira)["objetivos"].any(func(o): return o["tipo"] == "vingança" and o["alvo"] == kai), "e quis vingança contra Kai")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "notícia" and f["lugar"] == kresk), "fato de notícia em Kresk")


func _fato_morte(u: Universo) -> String:
	for f in u.fatos.todos():
		if f["dados"].get("acao", "") == "morte_por":
			return f["id"]
	return ""


func test_reconstruir_depois_de_simular_da_o_mesmo_mundo() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Simulador.avancar(u, 360 * 2)
	var foto := func() -> String:
		var s := ""
		for e in u.entidades_ativas():
			var st := u.estado(e["id"])
			s += "%s|%s|%.3f|%d|%s;" % [e["nome"], st["local"], float(st["poder"]), st["objetivos"].size(), str(st["vivo"])]
		return s
	var antes: String = foto.call()
	AutoAtualizador.reconstruir(u)
	igual(foto.call(), antes, "o mundo relido do banco de fatos é o mesmo")


func test_parar_quando_algo_importante_acontece() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var inicio := DataMundo.ordem(u.relogio)
	var novos := Simulador.avancar(u, 360 * 20, {"parar_em_importante": true})
	verdadeiro(DataMundo.ordem(u.relogio) - inicio < 360 * 20, "parou antes de 20 anos")
	verdadeiro(novos.any(func(f): return Simulador.importancia(u, f) >= 0.6), "porque algo importante aconteceu")


func test_foco_congela_o_lugar() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Simulador.preparar(u)
	var antes := u.fatos.sobre(m["daren"]).size()
	Simulador.avancar(u, 60, {"foco": [m["varn"]], "aceitar_ecos": false})
	var depois: Array = u.fatos.sobre(m["daren"]).filter(func(f): return f["origem"]["tipo"] == BancoDeFatos.ORIGEM_SIMULACAO and f["tipo"] != "notícia" and f["tipo"] != "reação")
	igual(depois.size(), 0, "Daren, em Varn (foco), não agiu")
