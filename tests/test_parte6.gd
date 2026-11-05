extends TesteBase
## Parte 6: sociedades (governo, sucessão, revolta, golpe), economia, humor,
## reputação relativa, gerações e leis da sociedade.


func _mundo(semente: int = 6060) -> Dictionary:
	var u := Universo.novo("Aldra")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(412, 10))
	var planeta := u.criar_entidade("Aldra", "planeta", [], [{"chave": "clima", "valor": "temperado"}])
	var reino := u.criar_entidade("Reino de Aldor", "reino", [], [{"chave": "forma de governo", "valor": "monarquia hereditária"},
		{"chave": "líder", "valor": "Ostric"}, {"chave": "impostos", "valor": "altos"}])
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "8000"}])
	var kresk := u.criar_entidade("Kresk", "cidade", [], [{"chave": "população", "valor": "3000"}])
	Mapa.colocar(u, planeta, "", 20, 10)
	Mapa.colocar(u, reino, planeta, 20, 10)
	Mapa.colocar(u, varn, reino, 20, 10)
	Mapa.colocar(u, kresk, reino, 23, 11)
	var ostric := _pessoa(u, "Ostric Valebrum", 55, "orgulhoso e cruel", varn)
	var herdeiro := _pessoa(u, "Edric Valebrum", 30, "calmo e leal", varn)
	var tessa := _pessoa(u, "Tessa Corvo", 34, "corajosa, ambiciosa e impulsiva", varn)
	var lia := _pessoa(u, "Lia Ferro", 28, "gentil e alegre", varn)
	Simulador.registrar(u, {"tipo": "filiação", "descricao": "Edric é filho de Ostric.", "sujeitos": [herdeiro, ostric],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"mudancas": [{"op": "familia", "pai": ostric, "filho": herdeiro}]}})
	return {"u": u, "reino": reino, "varn": varn, "kresk": kresk, "ostric": ostric, "herdeiro": herdeiro, "tessa": tessa, "lia": lia}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}])
	u.estado(e)["local"] = lugar
	return e


func test_reconhece_sociedades_e_tipos() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var rep := u.criar_entidade("República de Kresk", "república", [], [{"chave": "território", "valor": "Kresk"}])
	var guilda := u.criar_entidade("Guilda dos Mercadores", "guilda", [], [{"chave": "sede", "valor": "Varn"}])
	var todas := Sociedades.todas(u)
	verdadeiro(todas.has(m["reino"]) and todas.has(rep) and todas.has(guilda), "três sociedades")
	igual(Sociedades.tipo(u, m["reino"]), "monarquia", "reino é monarquia")
	igual(Sociedades.tipo(u, rep), "republica", "república")
	igual(Sociedades.tipo(u, guilda), "corporacao", "guilda")
	igual(Sociedades.lider(u, m["reino"]), m["ostric"], "o rei vem da ficha")
	verdadeiro(Sociedades.territorio(u, m["reino"]).has(m["varn"]), "Varn é do reino")
	igual(Sociedades.de_lugar(u, m["kresk"]), rep, "Kresk é da república (a mais próxima)")
	igual(Sociedades.de_lugar(u, m["varn"]), m["reino"], "Varn é do reino (a guilda não governa)")
	falso(Pendencias.listar(u).any(func(i): return i["tipo"] == "campo" and i["chave"] in ["forma de governo", "líder", "impostos", "território", "sede"]), "campos de governo têm efeito")


func test_sucessao_por_heranca() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var morte := Simulador.registrar(u, {"tipo": "morte", "descricao": "Ostric morreu.", "sujeitos": [m["ostric"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "morte", "mudancas": [{"op": "morrer", "quem": m["ostric"]}]}})
	Simulador.avancar(u, 7)
	igual(Sociedades.lider(u, m["reino"]), m["herdeiro"], "o filho herdou o trono")
	var suc: Array = u.fatos.sobre(m["reino"]).filter(func(f): return f["tipo"] == "sucessão")
	igual(suc.size(), 1, "sucessão virou fato")
	verdadeiro(suc[0]["causas"].has(morte), "causada pela morte do rei")
	igual(Sociedades.historia_do_governo(u, m["reino"]).size(), 2, "a dinastia guarda os dois")
	igual(Sociedades.casa(u, m["herdeiro"]), "Valebrum", "a casa Valebrum")


func test_sucessao_por_eleicao() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var rep := u.criar_entidade("República de Kresk", "república", [], [{"chave": "território", "valor": "Kresk"},
		{"chave": "líder", "valor": "Corvin"}, {"chave": "conselho", "valor": "Mara, Tobias"}])
	var corvin := _pessoa(u, "Corvin", 60, "calmo", m["kresk"])
	var mara := _pessoa(u, "Mara", 40, "sociável, gentil e carismática", m["kresk"])
	var tobias := _pessoa(u, "Tobias", 45, "reservado e frio", m["kresk"])
	Simulador.registrar(u, {"tipo": "luta", "descricao": "Mara venceu um bandido.", "sujeitos": [mara, tobias], "lugar": m["kresk"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "vitoria"}})
	Simulador.registrar(u, {"tipo": "morte", "descricao": "Corvin morreu.", "sujeitos": [corvin],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "morte", "mudancas": [{"op": "morrer", "quem": corvin}]}})
	Simulador.avancar(u, 7)
	igual(Sociedades.lider(u, rep), mara, "eleita a mais bem vista e sociável")


## O teste da Parte 6 no plano: uma fome que vira revolta que vira mudança de governo.
func test_fome_vira_revolta_vira_novo_governo() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var seca := Natureza.intervir(u, m["varn"], "uma seca terrível por dois anos")
	var seca2 := Natureza.intervir(u, m["kresk"], "uma seca terrível por dois anos")
	var houve_queda := false
	for i in 8:
		Simulador.avancar(u, 120)
		if u.fatos.todos().any(func(f): return f["canon"] and f["tipo"] == "queda do governo"):
			houve_queda = true
			break
	var tipos := u.fatos.todos().filter(func(f): return f["canon"]).map(func(f): return f["tipo"])
	verdadeiro(tipos.has("fome"), "a fome chegou")
	verdadeiro(tipos.has("inquietação"), "o povo ficou inquieto")
	verdadeiro(tipos.has("revolta"), "houve revolta")
	verdadeiro(houve_queda, "o governo caiu")
	if not houve_queda:
		return
	var queda: Dictionary = u.fatos.todos().filter(func(f): return f["tipo"] == "queda do governo")[0]
	var cadeia := u.fatos.cadeia_de_causas(queda["id"], 20).map(func(f): return f["id"])
	verdadeiro(cadeia.has(seca["fato"]) or cadeia.has(seca2["fato"]), "a queda vem da seca (seca → fome → inquietação → revolta → queda)")
	verdadeiro(Sociedades.lider(u, m["reino"]) != m["ostric"], "outro governa")
	verdadeiro(Pecas.marcas(u, m["ostric"]).has("deposto") or not Estado.vivo(u, m["ostric"]), "o rei foi deposto")
	igual(Auditor.auditar(u), [], "auditor sem problemas")


func test_golpe() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	u.editar_entidade(m["reino"], {"campos": u.entidade(m["reino"])["campos"] + [{"chave": "conselho", "valor": "Tessa Corvo, Lia Ferro"}]})
	Estado.relacao(u, m["tessa"], m["ostric"], {"raiva": 0.9})
	verdadeiro(Sociedades.lealdade(u, m["tessa"], m["ostric"]) < 0.25, "Tessa não é leal")
	verdadeiro(Sociedades.lealdade(u, m["lia"], m["ostric"]) > Sociedades.lealdade(u, m["tessa"], m["ostric"]), "Lia é mais leal")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ids := Sociedades.golpe(u, m["reino"], m["tessa"], m["ostric"], rng)
	igual(ids.size(), 2, "tentativa e resultado")
	var res := u.fatos.obter(ids[1])
	verdadeiro(res["tipo"] in ["golpe vitorioso", "golpe fracassado"], "resultado do golpe")
	verdadeiro(res["causas"].has(ids[0]), "causado pela tentativa")


func test_caravanas_levam_comida() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Natureza.intervir(u, m["varn"], "uma seca terrível por um ano")
	Natureza.intervir(u, m["kresk"], "fartura por um ano")
	Simulador.avancar(u, 360)
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "caravanas"), "caravanas de Kresk foram a Varn")
	verdadeiro(Economia.riqueza(u, m["reino"]) > 0, "o reino juntou impostos")
	verdadeiro(Economia.preco(u, m["varn"]) > Economia.preco(u, m["kresk"]), "o pão é mais caro onde falta")


func test_reputacao_relativa() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var ordem := u.criar_entidade("Ordem da Lâmina", "ordem", [], [{"chave": "sede", "valor": "Varn"}, {"chave": "admiram", "valor": "força, guerra"}])
	var templo := u.criar_entidade("Igreja da Aurora", "igreja", [], [{"chave": "sede", "valor": "Varn"}, {"chave": "desprezam", "valor": "violência e sangue"}])
	var kai := _pessoa(u, "Kai", 30, "cruel", m["varn"])
	for vitima in [m["lia"], m["herdeiro"]]:
		Simulador.registrar(u, {"tipo": "luta", "descricao": "Kai matou alguém.", "sujeitos": [kai, vitima], "lugar": m["varn"],
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "morte_por"}})
	var para_ordem := Reputacao.detalhe(u, ordem, kai)
	var para_templo := Reputacao.detalhe(u, templo, kai)
	verdadeiro(float(para_ordem["valor"]) > float(para_templo["valor"]) + 0.5, "a ordem e o templo julgam diferente")
	igual(Reputacao.palavra(para_templo), "carniceiro", "carniceiro para o templo")
	igual(Reputacao.detalhe(u, m["kresk"], kai)["conhecidos"], 0, "em Kresk ninguém sabe ainda")


func test_geracoes() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	Simulador.registrar(u, {"tipo": "casamento", "descricao": "Edric e Lia se casaram.", "sujeitos": [m["herdeiro"], m["lia"]], "lugar": m["varn"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "casamento"}})
	Estado.relacao(u, m["herdeiro"], m["tessa"], {"raiva": 0.9})
	u.estado(m["herdeiro"])["favorito"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var fid := Familia.nascer(u, m["herdeiro"], m["lia"], rng)
	var f := u.fatos.obter(fid)
	var filho: String = f["sujeitos"][0]
	verdadeiro(u.entidade(filho)["nome"].ends_with("Valebrum"), "sobrenome da casa")
	verdadeiro(u.estado(m["herdeiro"])["familia"]["filhos"].has(filho) and u.estado(m["lia"])["familia"]["filhos"].has(filho), "filho dos dois")
	igual(Estado.idade(u, filho), 0, "recém-nascido")
	verdadeiro(Estado.valor_relacao(u, filho, m["tessa"], "raiva") > 0.2, "herdou a inimizade com Tessa")
	verdadeiro(f["causas"].size() == 1 and u.fatos.obter(f["causas"][0])["tipo"] == "casamento", "o nascimento vem do casamento")
	var antes := Simulador._mentes(u).size()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 9
	for ano in 12:
		Familia.passo(u, 360, rng2)
	verdadeiro(Simulador._mentes(u).size() > antes, "nasceu mais gente com o tempo")


func test_leis_da_sociedade() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var chama := u.criar_entidade("Chama Antiga", "magia")
	u.editar_entidade(m["lia"], {"campos": u.entidade(m["lia"])["campos"] + [{"chave": "poderes", "valor": "Chama Antiga"}]})
	u.editar_entidade(m["reino"], {"campos": u.entidade(m["reino"])["campos"] + [{"chave": "leis", "valor": "A magia é proibida."}]})
	Simulador.avancar(u, 7)
	Poderes.usar(u, m["lia"], chama, "", [])
	verdadeiro(Pecas.marcas(u, m["lia"]).has("fugitivo"), "quem usa magia no reino vira fugitivo")
	var mira := _pessoa(u, "Mira", 20, "curiosa", "")
	u.editar_entidade(mira, {"campos": u.entidade(mira)["campos"] + [{"chave": "poderes", "valor": "Chama Antiga"}]})
	Poderes.usar(u, mira, chama, "", [])
	falso(Pecas.marcas(u, mira).has("fugitivo"), "fora do reino a lei não vale")
