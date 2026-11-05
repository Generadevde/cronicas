extends TesteBase
## Parte 11: histórias e cultura — fios, legado, obras, cronista, diretor de drama,
## tom, arcos, ganchos, segredos, boatos, sementes de histórias.
## Teste do plano: um livro escrito por um soldado, reinterpretado séculos depois.


func _mundo(semente: int = 1111) -> Dictionary:
	var u := Universo.novo("Areth")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(1200, 10))
	var planeta := u.criar_entidade("Areth", "planeta")
	var sok := u.criar_entidade("Sokovia", "república", [], [{"chave": "forma de governo", "valor": "república"}, {"chave": "território", "valor": "Sokov"}, {"chave": "líder", "valor": "Dravek"},
		{"chave": "admiram", "valor": "verdade e paz"}])
	var ber := u.criar_entidade("Bermudit", "reino", [], [{"chave": "forma de governo", "valor": "monarquia"}, {"chave": "território", "valor": "Duna"}, {"chave": "líder", "valor": "Azim"}])
	var sokov := u.criar_entidade("Sokov", "cidade", [], [{"chave": "população", "valor": "6000"}])
	var duna := u.criar_entidade("Duna", "cidade", [], [{"chave": "população", "valor": "5000"}])
	Mapa.colocar(u, planeta, "", 10, 10)
	Mapa.colocar(u, sokov, planeta, 8, 8)
	Mapa.colocar(u, duna, planeta, 12, 9)
	var dravek := _pessoa(u, "Dravek", 50, "orgulhoso e ambicioso", sokov)
	var azim := _pessoa(u, "Azim", 55, "orgulhoso e corajoso", duna)
	var vask := _pessoa(u, "Vask", 30, "rancoroso, orgulhoso e corajoso", sokov, [{"chave": "ofício", "valor": "soldado"}])
	return {"u": u, "sok": sok, "ber": ber, "sokov": sokov, "duna": duna, "dravek": dravek, "azim": azim, "vask": vask, "planeta": planeta}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String, extra: Array = []) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}] + extra)
	u.estado(e)["local"] = lugar
	return e


func test_livro_de_soldado_reinterpretado_seculos_depois() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var g := Guerras.declarar(u, m["ber"], m["sok"], "conquista")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var b := Guerras.batalha(u, g, rng)
	Simulador.registrar(u, {"tipo": "conhecer", "descricao": "Vask lutou na batalha.", "sujeitos": [m["vask"]], "causas": [b],
		"dados": {"mudancas": [{"op": "conhecer", "quem": m["vask"], "fato": b}, {"op": "relacao", "de": m["vask"], "para": m["azim"], "deltas": {"raiva": 0.8}}]}})
	# O soldado escreve o livro.
	var fo := Obras.criar(u, m["vask"], b, rng, "livro")
	var o: String = u.fatos.obter(fo)["sujeitos"][1]
	verdadeiro(Obras.eh_obra(u, o), "o livro existe: " + u.entidade(o)["nome"])
	igual(u.valor_campo(o, "autor"), "Vask", "escrito por Vask")
	verdadeiro(u.valor_campo(o, "viés").contains("ódio aos de Bermudit"), "cheio de ódio pelos inimigos: " + u.valor_campo(o, "viés"))
	verdadeiro(u.fatos.obter(fo)["causas"].has(b), "o tema é a batalha real")
	verdadeiro(Obras.texto(u, o).contains("Nunca esquecerei"), "trechos com o viés do autor")
	# O tempo passa: Sokov vira ruínas e o livro se perde lá.
	Natureza.de(u, m["sokov"])["pop"] = 0.0
	for i in 3:
		Simulador.avancar(u, 360)
	verdadeiro(Cidades.em_ruinas(u, m["sokov"]), "Sokov virou ruínas")
	var dias := 0
	while not Obras.perdida(u, o) and dias < 20 * 360:
		Simulador.avancar(u, 360)
		dias += 360
	verdadeiro(Obras.perdida(u, o), "o livro se perdeu nas ruínas")
	igual(str(Obras.dados(u, o).get("vestigio", "")), m["sokov"], "os vestígios ficaram em Sokov")
	# Séculos depois, uma historiadora encontra o livro.
	u.definir_relogio(DataMundo.criar(1520, 10))
	var ilka := _pessoa(u, "Ilka", 35, "muito curiosa, gentil e empática", m["sokov"], [{"chave": "ofício", "valor": "historiadora"}])
	var rancor_antes := Guerras.rancor(u, m["sok"], m["ber"])
	var anos := 0
	while Obras.perdida(u, o) and anos < 40:
		Simulador.avancar(u, 360)
		anos += 1
	falso(Obras.perdida(u, o), "o livro foi reencontrado")
	var leituras: Array = Obras.dados(u, o)["leituras"]
	igual(leituras.size(), 2, "duas versões circulam")
	igual(leituras[1]["por"], ilka, "a leitura nova é da historiadora")
	verdadeiro(str(leituras[1]["texto"]).contains("testemunho"), "lido com os valores do tempo dela: " + str(leituras[1]["texto"]))
	var re: Array = u.fatos.sobre(o).filter(func(f): return f["tipo"] == "obra reencontrada")
	igual(re.size(), 1, "o reencontro é fato")
	verdadeiro(re[0]["descricao"].contains("escrito há 3"), re[0]["descricao"])
	verdadeiro(re[0]["dados"]["mudancas"].any(func(op): return op["op"] == "rancor" and float(op["delta"]) < 0), "a nova leitura muda a cultura (o rancor entre os povos diminui)")
	verdadeiro(u.fatos.cadeia_de_causas(re[0]["id"], 100).any(func(c): return c["id"] == b), "a cadeia chega até a batalha que o soldado viveu")
	igual(Auditor.auditar(u).size(), 0, "auditor limpo")


func test_fios_de_historia() -> void:
	var m := _mundo(1212)
	var u: Universo = m["u"]
	var daren := _pessoa(u, "Daren", 19, "rancoroso", m["sokov"])
	Simulador.registrar(u, {"tipo": "ódio", "descricao": "Daren jurou vingança contra Azim.", "sujeitos": [daren, m["azim"]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": [{"op": "objetivo", "quem": daren, "tipo": "vingança", "alvo": m["azim"], "forca": 0.9}]}})
	var fs: Array = Fios.todos(u).filter(func(f): return f["quem"] == daren)
	igual(fs.size(), 1, "um fio: a vingança de Daren")
	igual(fs[0]["nome"], "A vingança de Daren", "com nome")
	igual(fs[0]["estado"], "nascendo", "nascendo")
	verdadeiro(Fios.caminhos(u, fs[0]).any(func(c): return c.contains("abandonar")), "caminhos possíveis")
	Simulador.avancar(u, 30)
	Fios.cortar(u, fs[0]["id"])
	Simulador.avancar(u, 60)
	var f2: Array = Fios.todos(u).filter(func(f): return f["quem"] == daren)
	igual(f2[0]["estado"], "abandonado", "cortado, o fio foi abandonado")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "fio de história" and f["descricao"].contains("hesitou")), "a mudança de rumo virou notícia")


func test_legado_e_cronista() -> void:
	var m := _mundo(1313)
	var u: Universo = m["u"]
	var g := Guerras.declarar(u, m["ber"], m["sok"], "")
	var fim: Array = Guerras.terminar(u, g, "a", "")
	Simulador.avancar(u, 100)
	var cult_b := Legado.de(u, m["ber"])
	var cult_s := Legado.de(u, m["sok"])
	verdadeiro(cult_b.any(func(x): return x["tipo"] == "feriado"), "o vencedor ganhou um feriado")
	verdadeiro(cult_s.any(func(x): return x["tipo"] == "dia de luto"), "o perdedor, um dia de luto")
	verdadeiro(u.fatos.obter(str(cult_s[0]["fato"]))["causas"].has(fim[0]), "o legado tem origem registrada")
	u.definir_relogio(DataMundo.criar(1330, 10))
	var hoje := Legado.como_esta(u, cult_s[0])
	igual(hoje["tipo"], "festa", "um século depois, o luto virou festa")
	var anais := Cronista.anais(u, 1200)
	verdadeiro(anais.contains("declarou guerra"), "os anais contam a guerra")
	var povo := Cronista.anais(u, 1200, "povo", m["sok"])
	verdadeiro(povo.contains("nosso glorioso Sokovia") or povo.contains("pérfidos"), "no tom de um povo, com viés")
	var rel := Cronista.guerra(u, g, "bardo")
	verdadeiro(rel.contains("cantam os bardos"), "o bardo canta")


func test_diretor_tom_ganchos_segredos_boatos_sementes() -> void:
	var m := _mundo(1414)
	var u: Universo = m["u"]
	Diretor.definir(u, "intenso", "sombrio")
	verdadeiro(Diretor.fator(u, "epidemia") > 1.5, "sombrio e intenso: mais pestes")
	Diretor.definir(u, "calmo", "esperançoso")
	verdadeiro(Diretor.fator(u, "fartura") > 1.5 and Diretor.fator(u, "guerra") < 0.6, "esperançoso e calmo: mais fartura, menos guerra")
	igual(Diretor.fase(u), "calmaria", "o mundo começa em calmaria")
	# Segredo com hora marcada para vir à tona.
	var s := Simulador.registrar(u, {"tipo": "segredo", "descricao": "Azim não é filho do rei.", "sujeitos": [m["azim"]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"secreto": true, "mudancas": []}})
	verdadeiro(Enredo.segredos(u).any(func(x): return x["fato"] == s), "o segredo aparece com quem sabe")
	Enredo.revelar_em(u, s, DataMundo.criar(1201, 10))
	Simulador.avancar(u, 400)
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "segredo revelado" and f["causas"].has(s)), "na hora marcada, veio à tona")
	# Boato.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var b := Enredo.distorcer("Kai venceu Lucas com 3 golpes.", rng)
	verdadeiro(b != "Kai venceu Lucas com 3 golpes.", "o boato distorce: " + b)
	# Semente: o inimigo ferido e alguém de bom coração.
	var g := Guerras.declarar(u, m["ber"], m["sok"], "")
	var soldado := _pessoa(u, "Tarik", 25, "corajoso", m["sokov"])
	Simulador.registrar(u, {"tipo": "ferimento", "descricao": "Tarik foi ferido.", "sujeitos": [soldado], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": [{"op": "ferir", "quem": soldado, "descricao": "flecha", "gravidade": 0.5}]}})
	_pessoa(u, "Nelia", 40, "gentil, bondosa e empática", m["sokov"], [{"chave": "ofício", "valor": "curandeira"}])
	var sem := Enredo.semente(u, rng)
	verdadeiro(not sem.is_empty(), "o mundo sugeriu uma história")
	verdadeiro(sem.has("titulo") and sem.has("resumo") and sem.has("gancho") and not sem["personagens"].is_empty(), "com título, resumo, personagens e gancho: " + str(sem.get("resumo", "")))
