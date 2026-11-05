extends TesteBase
## A escrita no centro: cada frase que você escreve molda o mundo, e o mundo anda junto.
## Vários mundos bem diferentes, escritos do zero: uma ilha com slimes, uma nave sem
## oxigênio, anões e dragões, um rei cruel, uma lei e uma personagem no meio da história.


func _escrever(u: Universo, cid: String, texto: String) -> Array:
	var cap := u.capitulo(cid)
	u.atualizar_capitulo(cid, {"texto": str(cap["texto"]) + texto + " "})
	return Escrita.processar(u, cid)


func _novo(nome: String, semente: int = 5) -> Dictionary:
	var u := Universo.novo(nome)
	u.extras["semente"] = semente
	var l := u.criar_livro(nome)
	return {"u": u, "cap": u.criar_capitulo(l, "Começo")}


func _achar(u: Universo, nome: String) -> String:
	for e in u.entidades_ativas():
		if e["nome"] == nome:
			return e["id"]
	return ""


func test_le_o_tempo_das_frases() -> void:
	igual(Leitor.tempo(Leitor._limpo("Três anos depois, a guerra acabou.")), 1080, "três anos")
	igual(Leitor.tempo(Leitor._limpo("No dia seguinte, Mira acordou.")), 1, "dia seguinte")
	igual(Leitor.tempo(Leitor._limpo("Trinta dias se passaram.")), 30, "trinta dias")
	igual(Leitor.tempo(Leitor._limpo("Passaram-se duas semanas.")), 14, "duas semanas")
	igual(Leitor.tempo(Leitor._limpo("Mira acordou cedo.")), 0, "sem tempo dito")
	igual(Escrita.frases_prontas("Uma frase pronta. Outra pronta! Ainda escrevendo").size(), 2, "a frase sendo escrita fica de fora")


func test_a_ilha_dos_slimes() -> void:
	var m := _novo("Ilha")
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	var c := _escrever(u, cid, "Existe apenas uma ilha, chamada Aru, com 30 pessoas.")
	var aru := _achar(u, "Aru")
	verdadeiro(aru != "" and u.entidade(aru)["tipo"] == "ilha", "a ilha nasceu")
	verdadeiro(Mapa.no_mapa(u, aru), "e está no mapa")
	igual(Mapa.terreno_em(u, Mapa.pai(u, aru), 0, 0), "agua", "só existe a ilha: o resto é mar")
	igual(Ameacas._pessoas(u, aru).size(), 30, "30 pessoas vivem em Aru")
	igual(int(c[0]["dias"]), 0, "descrever o mundo não faz o tempo andar")
	_escrever(u, cid, "Essas pessoas precisam sobreviver.")
	verdadeiro(Recursos.de(u, aru).has("comida"), "a comida passou a ser contada")
	_escrever(u, cid, "À noite, slimes começam a aparecer e atacam as pessoas.")
	var slime := _achar(u, "Slime")
	verdadeiro(slime != "", "a criatura nasceu")
	igual(str(Ameacas.dados(u, slime).get("quando", "")), "noite", "aparece à noite")
	igual(str(Ameacas.dados(u, slime).get("efeito", "")), "atacar", "e ataca")
	c = _escrever(u, cid, "Trinta dias se passaram.")
	igual(int(c[0]["dias"]), 30, "o tempo andou trinta dias")
	verdadeiro(int(Ameacas.dados(u, slime).get("ataques", 0)) > 0, "os slimes atacaram (%d vezes)" % int(Ameacas.dados(u, slime).get("ataques", 0)))
	verdadeiro(u.fatos.todos().any(func(f): return f["canon"] and f["tipo"] in ["luta contra criaturas", "ferimento", "morte"]), "houve luta, ferido ou morto")
	verdadeiro(Ameacas._pessoas(u, aru).any(func(p): return Estado.emocoes_atuais(u, p).any(func(e): return e["emocao"] == "medo")), "as pessoas têm medo")
	verdadeiro(not c[0]["mundo"].is_empty(), "a margem mostra o que o mundo fez")
	verdadeiro(str(c[0]["sugestao"]) != "", "o mundo sugere uma continuação: " + str(c[0]["sugestao"]).substr(0, 80))
	igual(Integridade.total(Integridade.auditar_tudo(u)), 0, "tudo coerente: %s" % str(Integridade.auditar_tudo(u)))
	# Apagar a frase dos slimes desfaz o que ela criou.
	var texto := str(u.capitulo(cid)["texto"]).replace("À noite, slimes começam a aparecer e atacam as pessoas. ", "")
	u.atualizar_capitulo(cid, {"texto": texto})
	var d := Escrita.processar(u, cid)
	verdadeiro(d.any(func(x): return x.get("desfeita", false)), "a frase apagada foi desfeita")
	verdadeiro(u.entidade(slime)["removida"], "os slimes saíram do mundo")
	falso(u.fatos.todos().any(func(f): return f["canon"] and f["tipo"] == "ataque de criaturas"), "e os ataques deixaram de ter acontecido")
	igual(Auditor.auditar(u).size(), 0, "sem pontas soltas")


func test_mudar_uma_frase_muda_o_mundo() -> void:
	var m := _novo("Muda")
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Existe uma vila chamada Orla com 10 pessoas.")
	var orla := _achar(u, "Orla")
	igual(Ameacas._pessoas(u, orla).size(), 10, "dez pessoas")
	u.atualizar_capitulo(cid, {"texto": "Existe uma vila chamada Orla com 25 pessoas. "})
	Escrita.processar(u, cid)
	orla = _achar(u, "Orla")
	igual(Ameacas._pessoas(u, orla).size(), 25, "mudou a frase: agora são 25 (as dez de antes saíram)")
	# Desfazer pela margem: a frase fica, mas não vale.
	var cards := Escrita.cartoes(u, cid)
	var raiz: String = cards.back()["raiz"]
	Escrita.desfazer(u, cid, raiz)
	igual(_achar(u, "Orla"), "", "desfeito pela margem")
	igual(Escrita.processar(u, cid).size(), 0, "e não volta sozinho")


func test_a_nave_sem_oxigenio() -> void:
	var m := _novo("Nave")
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Uma nave espacial chamada Aurora viaja sozinha pelo espaço com 12 tripulantes.")
	var aurora := _achar(u, "Aurora")
	verdadeiro(aurora != "", "a nave existe")
	verdadeiro(Ameacas._pessoas(u, aurora).any(func(p): return TextUtil.normalizar(Vivencia.oficio(u, p)).contains("engenh")), "tem quem saiba consertar")
	_escrever(u, cid, "O oxigênio está acabando.")
	igual(str(Recursos.de(u, aurora).get("oxigenio", {}).get("fonte", "")), "nenhuma", "o oxigênio não tem de onde vir")
	_escrever(u, cid, "Duas semanas depois, a tripulação se reuniu.")
	verdadeiro(u.fatos.todos().any(func(f): return f["canon"] and f["tipo"] in ["escassez", "conserto", "morte"]), "o oxigênio virou história (escassez, conserto ou morte)")
	igual(Integridade.total(Integridade.auditar_tudo(u)), 0, "coerente")


func test_anoes_e_dragoes_no_inverno() -> void:
	var m := _novo("Brasa")
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Existe uma cidade chamada Brasa, nas montanhas, com 200 anões mineiros.")
	var brasa := _achar(u, "Brasa")
	igual(u.valor_campo(brasa, "população"), "200", "200 anões na ficha")
	igual(Ameacas._pessoas(u, brasa).size(), 60, "60 deles com nome e história")
	verdadeiro(Ameacas._pessoas(u, brasa).all(func(p): return u.valor_campo(p, "povo") == "anão"), "todos anões")
	_escrever(u, cid, "Todo inverno, dragões descem das montanhas e queimam as casas.")
	var dragao := _achar(u, "Dragão")
	igual(str(Ameacas.dados(u, dragao).get("quando", "")), "inverno", "no inverno")
	igual(str(Ameacas.dados(u, dragao).get("efeito", "")), "destruir", "queimam")
	verdadeiro(float(Ameacas.dados(u, dragao)["forca"]) > 5.0, "dragão é forte")
	_escrever(u, cid, "Um ano depois.")
	var ataques: Array = u.fatos.todos().filter(func(f): return f["canon"] and f["tipo"] == "ataque de criaturas")
	verdadeiro(not ataques.is_empty(), "os dragões vieram")
	verdadeiro(ataques.all(func(f): return TextUtil.normalizar(Natureza.estacao(f["data"])) == "inverno"), "só no inverno")
	igual(Integridade.total(Integridade.auditar_tudo(u)), 0, "coerente: %s" % str(Integridade.auditar_tudo(u)["simulacao"].slice(0, 2)))


func test_o_rei_cruel() -> void:
	var m := _novo("Rei")
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Numa vila chamada Pedra Funda vivem 50 camponeses.")
	_escrever(u, cid, "Um rei cruel chamado Odo governa a vila e cobra impostos altos.")
	var odo := _achar(u, "Odo")
	verdadeiro(odo != "", "Odo existe")
	verdadeiro(u.valor_campo(odo, "cargo").begins_with("rei"), "é rei: " + u.valor_campo(odo, "cargo"))
	verdadeiro(u.valor_campo(odo, "personalidade").contains("cruel"), "é cruel")
	igual(str(u.estado(odo)["local"]), _achar(u, "Pedra Funda"), "mora na vila")
	var c := _escrever(u, cid, "O povo odeia o rei.")
	verdadeiro(str(c[0]["itens"][0]["texto"]).contains("odeiam"), c[0]["itens"][0]["texto"])
	var povo := Ameacas._pessoas(u, _achar(u, "Pedra Funda")).filter(func(p): return p != odo)
	verdadeiro(povo.all(func(p): return Estado.valor_relacao(u, p, odo, "raiva") >= 0.5), "o povo odeia Odo")


func test_uma_lei_e_uma_personagem() -> void:
	var m := _novo("Sal")
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Existe uma ilha chamada Sal com 10 pescadores.")
	_escrever(u, cid, "Neste mundo, quem mente perde a voz.")
	igual(Regras.todas(u).size(), 1, "virou lei")
	_escrever(u, cid, "Mira, a pescadora, encontra uma espada na praia.")
	var mira := _achar(u, "Mira")
	verdadeiro(mira != "", "Mira nasceu da frase")
	igual(u.valor_campo(mira, "ofício"), "pescadora", "pescadora")
	igual(str(u.estado(mira)["local"]), _achar(u, "Sal"), "em Sal")
	# A sugestão do mundo entra no texto sem ser lida de novo.
	var antes := Escrita.cartoes(u, cid).size()
	Escrita.usar_sugestao(u, cid, "Naquela noite, o mar ficou calmo. Mira dormiu com a espada.")
	igual(Escrita.processar(u, cid).size(), 0, "o texto do mundo não é relido")
	igual(Escrita.cartoes(u, cid).size(), antes, "nada novo na margem")


func _pos(u: Universo, nome: String) -> Vector2i:
	var p := Mapa.posicao(u, _achar(u, nome))
	return Vector2i(int(p.get("x", -1)), int(p.get("y", -1)))


func test_o_mapa_acompanha_onde_a_frase_diz() -> void:
	var m := _novo("Onde", 11)
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Existe uma cidade chamada Brasa.")
	var brasa := _pos(u, "Brasa")
	_escrever(u, cid, "Ao norte de Brasa existe uma torre chamada Vigia.")
	verdadeiro(_pos(u, "Vigia").y < brasa.y, "a torre ficou ao norte (%s, Brasa %s)" % [_pos(u, "Vigia"), brasa])
	igual(Mapa.pai(u, _achar(u, "Vigia")), Mapa.pai(u, _achar(u, "Brasa")), "no mesmo mapa")
	_escrever(u, cid, "Longe de Brasa, a leste, existe uma vila chamada Orla.")
	verdadeiro(_pos(u, "Orla").x - brasa.x >= 8, "a vila ficou longe, a leste (%s)" % _pos(u, "Orla"))
	_escrever(u, cid, "Perto de Brasa existe uma aldeia chamada Cinza.")
	verdadeiro(Vector2(_pos(u, "Cinza") - brasa).length() <= 5.0, "a aldeia ficou perto (%s)" % _pos(u, "Cinza"))
	_escrever(u, cid, "Existe uma torre em Brasa chamada Sino.")
	igual(Mapa.pai(u, _achar(u, "Sino")), _achar(u, "Brasa"), "a torre ficou dentro da cidade (no mapa dela)")
	var mundo := Mapa.pai(u, _achar(u, "Brasa"))
	if not Mapa.celulas_livres(u, mundo, ["montanha"]).is_empty():
		_escrever(u, cid, "Nas montanhas existe uma mina chamada Funda.")
		var p := _pos(u, "Funda")
		igual(Mapa.terreno_em(u, mundo, p.x, p.y), "montanha", "a mina ficou nas montanhas")


func test_a_vila_na_costa_da_ilha() -> void:
	var m := _novo("Costa", 12)
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Existe apenas uma ilha, chamada Aru, com 10 pessoas.")
	_escrever(u, cid, "Na costa norte da ilha existe uma vila chamada Porto.")
	var mundo := Mapa.pai(u, _achar(u, "Aru"))
	var p := _pos(u, "Porto")
	verdadeiro(p.y <= _pos(u, "Aru").y, "a vila ficou ao norte da ilha (%s, Aru %s)" % [p, _pos(u, "Aru")])
	falso(Mapa.terreno_em(u, mundo, p.x, p.y) == "agua", "em terra")
	var junto_do_mar := false
	for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = p + v
		if Mapa.terreno_em(u, mundo, q.x, q.y) == "agua":
			junto_do_mar = true
	verdadeiro(junto_do_mar, "encostada no mar")


func test_criaturas_vao_onde_esta_a_gente() -> void:
	var m := _novo("Gente", 13)
	var u: Universo = m["u"]
	var cid: String = m["cap"]
	_escrever(u, cid, "Existe apenas uma ilha, chamada Aru, com 20 pessoas.")
	_escrever(u, cid, "Ao sul de Aru, nas colinas, existe uma caverna chamada Boca Funda.")
	var c := _escrever(u, cid, "Essas pessoas precisam sobreviver. À noite, slimes começam a aparecer e atacam as pessoas.")
	var slime := _achar(u, "Slime")
	igual(str(Ameacas.dados(u, slime).get("lugar", "")), _achar(u, "Aru"), "os slimes atacam Aru, onde a gente está (não a caverna vazia)")
	verdadeiro(Recursos.de(u, _achar(u, "Aru")).has("comida"), "a comida é contada em Aru")
	falso(u.propostas.any(func(p): return p["capitulo"] == cid and p["status"] == "duvida"), "nenhuma dúvida sobre frases que o leitor entendeu")
