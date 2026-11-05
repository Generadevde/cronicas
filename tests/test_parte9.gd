extends TesteBase
## Parte 9: mundo em transformação — técnicas e escolas, religiões, cidades e ruínas,
## espiões, submundo, propaganda, monstros, torneios, migrações, revoluções,
## alianças por casamento, colonização e contato entre mundos.
## Teste do plano: uma técnica inventada, ensinada, esquecida e redescoberta.


func _mundo(semente: int = 9090) -> Dictionary:
	var u := Universo.novo("Aldra")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(300, 10))
	var planeta := u.criar_entidade("Aldra", "planeta")
	var reino := u.criar_entidade("Reino de Varn", "reino", [], [{"chave": "forma de governo", "valor": "monarquia"}, {"chave": "território", "valor": "Varn, Kresk"},
		{"chave": "líder", "valor": "Ostric"}])
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "4000"}])
	var kresk := u.criar_entidade("Kresk", "vila", [], [{"chave": "população", "valor": "900"}])
	Mapa.colocar(u, planeta, "", 10, 10)
	Mapa.colocar(u, varn, planeta, 10, 10)
	Mapa.colocar(u, kresk, planeta, 13, 11)
	var ostric := _pessoa(u, "Ostric", 50, "orgulhoso e ambicioso", varn)
	return {"u": u, "planeta": planeta, "reino": reino, "varn": varn, "kresk": kresk, "ostric": ostric}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String, extra: Array = []) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}] + extra)
	u.estado(e)["local"] = lugar
	return e


func _morre(u: Universo, eid: String) -> String:
	return Simulador.registrar(u, {"tipo": "morte", "descricao": "%s morreu." % u.entidade(eid)["nome"], "sujeitos": [eid],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "morte", "mudancas": [{"op": "morrer", "quem": eid}]}})


func test_tecnica_inventada_ensinada_esquecida_e_redescoberta() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var kael := _pessoa(u, "Kael", 30, "curioso, ambicioso e corajoso", m["varn"], [{"chave": "desejos", "valor": "ser o guerreiro mais forte"}])
	var mira := _pessoa(u, "Mira", 18, "leal e curiosa", m["varn"])
	Simulador.registrar(u, {"tipo": "aprendizado", "descricao": "Mira passou a aprender com Kael.", "sujeitos": [mira, kael],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "aprendizado"}})
	Simulador.preparar(u)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# Inventada.
	var fi := Tecnicas.inventar(u, kael, rng)
	var t: String = u.fatos.obter(fi)["dados"]["tecnica"]
	verdadeiro(Tecnicas.eh_tecnica(u, t), "a técnica existe")
	igual(u.valor_campo(t, "criador"), "Kael", "com nome e criador: " + u.entidade(t)["nome"])
	verdadeiro(Tecnicas.conhecem(u, t).has(kael), "Kael a conhece")
	verdadeiro(Poderes.de(u, kael).has(t), "e usa nas lutas")
	verdadeiro(u.fatos.obter(fi)["causas"].size() > 0, "a invenção tem causa (o desejo de Kael)")
	# Ensinada.
	var dias := 0
	while not Tecnicas.conhecem(u, t).has(mira) and dias < 3 * 360:
		Simulador.avancar(u, 28)
		dias += 28
	verdadeiro(Tecnicas.conhecem(u, t).has(mira), "Kael ensinou a Mira")
	var ensino: Array = u.fatos.sobre(t).filter(func(f): return f["tipo"] == "ensino de técnica")
	verdadeiro(not ensino.is_empty() and ensino[0]["sujeitos"].has(mira), "o ensino é fato")
	# Esquecida.
	_morre(u, kael)
	var ultima := _morre(u, mira)
	Simulador.avancar(u, 35)
	verdadeiro(Tecnicas.perdida(u, t), "a técnica se perdeu")
	var perda: Array = u.fatos.sobre(t).filter(func(f): return f["tipo"] == "técnica perdida")
	igual(perda.size(), 1, "a perda é fato")
	verdadeiro(perda[0]["causas"].has(ultima), "causada pela morte de Mira (a última que sabia)")
	igual(str(u.estado(t)["vestigio"]), m["varn"], "ficaram vestígios em Varn")
	# Redescoberta, muitos anos depois.
	var anos := 0
	var curioso := ""
	while Tecnicas.perdida(u, t) and anos < 400:
		if curioso == "" or not Estado.vivo(u, curioso):
			curioso = _pessoa(u, "Estudioso %d" % anos, 20, "muito curioso e corajoso", m["varn"], [{"chave": "desejos", "valor": "ser um guerreiro lendário"}])
		Simulador.avancar(u, 360)
		anos += 1
	falso(Tecnicas.perdida(u, t), "a técnica foi redescoberta (depois de %d anos)" % anos)
	var red: Array = u.fatos.sobre(t).filter(func(f): return f["tipo"] == "redescoberta")
	igual(red.size(), 1, "a redescoberta é fato")
	verdadeiro(red[0]["causas"].has(perda[0]["id"]), "remonta à perda")
	verdadeiro(red[0]["descricao"].contains("perdida havia"), red[0]["descricao"])
	var cadeia := u.fatos.cadeia_de_causas(red[0]["id"], 50)
	verdadeiro(cadeia.any(func(c): return c["id"] == ultima), "a cadeia passa pela morte da última mestra")
	igual(Auditor.auditar(u).size(), 0, "auditor limpo")


func test_escola_nasce_e_ensina() -> void:
	var m := _mundo(9191)
	var u: Universo = m["u"]
	var a := _pessoa(u, "Bran", 40, "sociável e curioso", m["varn"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t: String = u.fatos.obter(Tecnicas.inventar(u, a, rng, "magia"))["dados"]["tecnica"]
	for n in ["Ivo", "Tula"]:
		var p := _pessoa(u, n, 25, "calmo", m["varn"])
		Simulador.registrar(u, {"tipo": "ensino", "descricao": "%s aprendeu." % n, "sujeitos": [p, t], "causas": [Tecnicas._ultimo_fato(u, t)],
			"dados": {"mudancas": [{"op": "aprender", "tecnica": t, "quem": p}]}})
	for i in 6:
		_pessoa(u, "Jovem %d" % i, 15, "curioso", m["varn"])
	Simulador.avancar(u, 6 * 360)
	var esc := Escolas.da_tecnica(u, t)
	verdadeiro(esc != "", "nasceu uma escola em volta da técnica")
	verdadeiro(Tecnicas.conhecem(u, t).size() > 3, "a escola ensinou alunos (%d conhecem)" % Tecnicas.conhecem(u, t).size())
	# Proibida, se a magia for proibida no reino.
	u.editar_entidade(m["reino"], {"campos": u.entidade(m["reino"])["campos"] + [{"chave": "leis", "valor": "A magia é proibida"}]})
	Simulador.avancar(u, 400)
	verdadeiro(u.estado(esc)["escola"].get("proibida", false) or u.estado(esc)["escola"].get("fechada", false), "a escola de magia foi proibida")


func test_religiao_nasce_e_morre() -> void:
	var m := _mundo(9292)
	var u: Universo = m["u"]
	var p := _pessoa(u, "Oren", 40, "devoto", m["varn"])
	var segs: Array = []
	for i in 3:
		segs.append(_pessoa(u, "Fiel %d" % i, 30, "leal", m["varn"]))
	var fp := Simulador.registrar(u, {"tipo": "profeta", "descricao": "Oren começou a pregar em Varn que o fogo purifica.", "sujeitos": [m["varn"], p], "lugar": m["varn"],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"mudancas": [{"op": "marca", "quem": p, "marca": "profeta"}]
			+ segs.map(func(s): return {"op": "marca", "quem": s, "marca": "seguidor de Oren"})}})
	Simulador.avancar(u, 120)
	var rs := Religioes.todas(u)
	igual(rs.size(), 1, "nasceu uma religião")
	var r: String = rs[0]
	verdadeiro(u.valor_campo(r, "crença").contains("fogo purifica"), "com a crença do profeta: " + u.valor_campo(r, "crença"))
	verdadeiro(u.fatos.cadeia_de_causas(u.fatos.sobre(r).filter(func(f): return f["tipo"] == "religião nova")[0]["id"], 5).any(func(c): return c["id"] == fp), "nasceu do profeta")
	for x in Religioes.fieis(u, r):
		_morre(u, x)
	Simulador.avancar(u, 120)
	verdadeiro(u.estado(r).get("extinta", false), "sem fiéis, a religião desapareceu")
	verdadeiro(u.entidades_ativas().any(func(e): return e["nome"].begins_with("Ruínas do Templo")), "o templo virou ruína")


func test_cidade_cresce_e_vira_ruina() -> void:
	var m := _mundo(9393)
	var u: Universo = m["u"]
	Simulador.avancar(u, 100)
	igual(Cidades.porte(u, m["varn"]), "vila", "Varn começa como vila (4 mil)")
	Natureza.de(u, m["varn"])["pop"] = 6000.0
	Simulador.avancar(u, 100)
	igual(Cidades.porte(u, m["varn"]), "cidade", "cresceu e virou cidade")
	verdadeiro(u.fatos.sobre(m["varn"]).any(func(f): return f["tipo"] == "crescimento"), "o crescimento é fato")
	Natureza.de(u, m["kresk"])["pop"] = 0.0
	Simulador.avancar(u, 100)
	verdadeiro(Cidades.em_ruinas(u, m["kresk"]), "Kresk deserta virou ruínas")


func test_espioes_submundo_e_propaganda() -> void:
	var m := _mundo(9494)
	var u: Universo = m["u"]
	var rep := u.criar_entidade("República de Kresk", "república", [], [{"chave": "forma de governo", "valor": "república"}, {"chave": "território", "valor": "Kresk"},
		{"chave": "inimigos", "valor": "Reino de Varn"}, {"chave": "líder", "valor": "Tala"}])
	_pessoa(u, "Tala", 45, "prudente", m["kresk"])
	var traira := _pessoa(u, "Vesk", 30, "ambicioso, ganancioso e desleal", m["varn"])
	# Um segredo no reino.
	Simulador.registrar(u, {"tipo": "segredo", "descricao": "Ostric esconde o tesouro sob o templo.", "sujeitos": [m["ostric"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"secreto": true, "mudancas": []}})
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 20:
		Intriga._espioes(u, rng)
	verdadeiro(Intriga.espiao_de(u, traira) == rep, "Vesk virou espião da República")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] in ["segredo roubado", "espião descoberto"]), "roubou um segredo ou foi descoberto")
	# Submundo: fome e gente fria.
	for n in ["Rato", "Corvo", "Faca"]:
		_pessoa(u, n, 25, "frio, cruel e ambicioso", m["varn"])
	Humor.de(u, m["varn"])["raiva"] = 0.6
	Simulador.avancar(u, 7)
	for i in 10:
		Intriga._submundo(u, rng)
	verdadeiro(Intriga.guilda_em(u, m["varn"]) != "", "nasceu uma guilda de ladrões em Varn")
	# Propaganda depois de uma batalha perdida.
	var g := Guerras.declarar(u, rep, m["reino"], "")
	var antes := u.fatos.quantidade()
	Simulador.avancar(u, 120)
	var prop: Array = u.fatos.todos().filter(func(f): return f["tipo"] == "propaganda")
	verdadeiro(not prop.is_empty() or Guerras.dados(u, g)["batalhas"].is_empty(), "depois de uma derrota, o governo espalhou sua versão")
	if not prop.is_empty():
		verdadeiro(prop[0]["descricao"].begins_with("Segundo"), prop[0]["descricao"])


func test_monstros_e_torneio() -> void:
	var m := _mundo(9595)
	var u: Universo = m["u"]
	for i in 4:
		_pessoa(u, "Caçador %d" % i, 30, "corajoso", m["varn"], [{"chave": "ofício", "valor": "caçador"}])
	_pessoa(u, "Brava", 25, "muito corajosa", m["kresk"])
	Simulador.avancar(u, 7)
	var regv := Natureza.de(u, m["varn"])
	var pred := ""
	for nome in regv["especies"]:
		if regv["especies"][nome]["papel"] == "predador":
			pred = nome
	verdadeiro(pred != "", "Varn tem predadores (%s)" % pred)
	Simulador.avancar(u, 360)
	var mig: Array = u.fatos.todos().filter(func(f): return f["tipo"] == "feras migram")
	verdadeiro(not mig.is_empty(), "caçados demais, os predadores fugiram para o vizinho")
	if not mig.is_empty():
		igual(mig[0]["lugar"], m["kresk"], "para Kresk")
	# Torneio.
	for i in 8:
		_pessoa(u, "Lutador %d" % i, 22, "corajoso e orgulhoso", m["varn"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ft := Aventura.torneio(u, m["reino"], rng)
	verdadeiro(ft != "", "houve torneio")
	var f := u.fatos.obter(ft)
	verdadeiro(f["descricao"].contains("venceu o torneio"), f["descricao"])
	verdadeiro(Pecas.marcas(u, f["sujeitos"][0]).any(func(x): return x.begins_with("campeão")), "o campeão ficou marcado")


func test_ideia_vira_revolucao() -> void:
	var m := _mundo(9696)
	var u: Universo = m["u"]
	var ideal := _pessoa(u, "Sel", 28, "curiosa, corajosa e sociável", m["varn"])
	for i in 6:
		_pessoa(u, "Povo %d" % i, 30, "calmo", m["varn"])
	Simulador.avancar(u, 7)
	Simulador.registrar(u, {"tipo": "ideia nova", "descricao": "Sel começou a defender que ninguém deve ter rei.", "sujeitos": [ideal, m["reino"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"ideia": "ninguém deve ter rei", "mudancas": [{"op": "marca", "quem": ideal, "marca": "acredita que ninguém deve ter rei"}]}})
	var anos := 0
	while Sociedades.tipo(u, m["reino"]) == "monarquia" and anos < 12:
		Humor.de(u, m["varn"])["raiva"] = 0.6
		Humor.de(u, m["kresk"])["raiva"] = 0.6
		var rng := RandomNumberGenerator.new()
		rng.seed = anos
		Povos._ideias(u, rng)
		anos += 1
	igual(Sociedades.tipo(u, m["reino"]), "republica", "a revolução fez do reino uma república")
	var rev: Array = u.fatos.sobre(m["reino"]).filter(func(f): return f["tipo"] == "revolução")
	igual(rev.size(), 1, "a revolução é fato")
	verdadeiro(u.fatos.cadeia_de_causas(rev[0]["id"], 20).any(func(c): return c["tipo"] == "ideia nova"), "remonta à ideia de Sel")


func test_alianca_por_casamento_e_migracao() -> void:
	var m := _mundo(9797)
	var u: Universo = m["u"]
	var rep := u.criar_entidade("República de Kresk", "república", [], [{"chave": "forma de governo", "valor": "república"}, {"chave": "território", "valor": "Kresk"},
		{"chave": "líder", "valor": "Tala"}])
	var tala := _pessoa(u, "Tala", 45, "prudente", m["kresk"])
	Simulador.registrar(u, {"tipo": "casamento", "descricao": "Ostric e Tala se casaram.", "sujeitos": [m["ostric"], tala],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "casamento"}})
	var rng := RandomNumberGenerator.new()
	Povos._romance(u, rng)
	verdadeiro(u.estado(m["reino"]).get("aliados", []).has(rep), "o casamento virou aliança")
	verdadeiro(Guerras._aliados(u, m["reino"], rep), "e a aliança vale na guerra")
	# Fome e peste: o povo de Kresk migra.
	Simulador.avancar(u, 7)
	Natureza.de(u, m["kresk"])["comida"] = 0.2
	Natureza.intervir(u, m["kresk"], "peste terrível")
	for i in 10:
		rng.seed = i
		Povos._migracoes(u, rng)
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "migração de um povo"), "o povo de Kresk migrou")


func test_contato_entre_mundos_e_colonia() -> void:
	var m := _mundo(9898)
	var u: Universo = m["u"]
	Cosmos.definir_leis(u, {"tecnologia": 0.95})
	var p2 := u.criar_entidade("Ul", "planeta")
	var p3 := u.criar_entidade("Vazio", "planeta")
	Mapa.colocar(u, p2, "", 30, 5)
	Mapa.colocar(u, p3, "", 35, 15)
	var cidade := u.criar_entidade("Ul-Ka", "cidade", [], [{"chave": "população", "valor": "2000"}])
	Mapa.colocar(u, cidade, p2, 10, 10)
	var cla := u.criar_entidade("Clã de Ul", "tribo", [], [{"chave": "forma de governo", "valor": "tribo"}, {"chave": "território", "valor": "Ul-Ka"}])
	for i in 4:
		_pessoa(u, "Viajante %d" % i, 25, "muito curioso", m["varn"])
	var rng := RandomNumberGenerator.new()
	for i in 80:
		rng.seed = i
		Povos._mundos(u, rng)
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "primeiro contato"), "houve primeiro contato entre os mundos")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "colonização"), "e uma colônia foi fundada num planeta vazio")


func test_mundo_povoado_continua_coerente() -> void:
	var u := Universo.novo("Transformação")
	u.extras["semente"] = 77
	var p := Povoador.gerar_planeta(u)
	Povoador.povoar(u, p)
	Simulador.avancar(u, 5 * 360)
	igual(Auditor.auditar(u).size(), 0, "auditor limpo depois de 5 anos")
