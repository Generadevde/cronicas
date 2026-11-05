extends AbaLivro
## Aba "Guerras": à esquerda, as guerras do universo (as de agora primeiro); à direita,
## o painel da guerra: lados e aliados, forças (tamanho, tipo, moral, comandante,
## suprimentos), a frente de batalha, a previsão de quem vence e por quê, as batalhas
## e os botões para intervir — como deus ou como autor.

var _lista: ItemList
var _pagina: RichTextLabel
var _botoes: Array = []
var _atual := ""


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	esq.add_child(Tema.secao("Guerras do universo"))
	var dica := Tema.rotulo("Guerras nascem da simulação (fome, vingança, fé, ambição, inimigos escritos na ficha) ou de você. Entre quando quiser e mude o rumo.", 14, Tema.italico(), Tema.TINTA_SUAVE)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esq.add_child(dica)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _abrir(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	var declarar := Tema.botao_principal("+ Declarar guerra")
	declarar.pressed.connect(_declarar)
	var forca := Tema.botao("+ Nova força", "Exército, frota, esquadrilha, legião… (vira entidade com ficha)")
	forca.pressed.connect(func():
		livro.pedir_texto("Nova força", "Nome (ex.: Legião de Ferro de Sokovia, 300 navios de Bermudit)", "", func(nome: String):
			if nome.strip_edges() == "":
				return
			var sid := ""
			for m in Ligador.new(u).encontrar(nome):
				if Sociedades.eh_sociedade(u, m["entidade"]):
					sid = m["entidade"]
			var tam := Combate.ler_numero(nome)
			var f := Forcas.criar(u, nome.strip_edges(), sid, tam if tam > 0 else 1000.0)
			livro.ir_para_aba("criadores", f)))
	esq.add_child(linha([declarar, forca]))

	_pagina = Tema.texto_rico()
	_pagina.meta_clicked.connect(livro.navegar)
	dir.add_child(_pagina)
	var acoes := [
		["Reforços…", "Mandar soldados para um lado", _reforcos],
		["Traição…", "Uma força (ou seu comandante) muda de lado", _traicao],
		["Desastre…", "Tempestade, peste, inverno na frente de batalha", _desastre],
		["Aliado…", "Alguém inesperado entra na guerra", _aliado],
		["Morte de um general…", "Um comandante morre", _morte],
		["Escrever…", "Escreva o que acontece (\"o rei fez um pacto e recebeu um exército de fantasmas\")", _escrever],
		["Fazer a paz", "A guerra acaba agora, por vontade sua", _paz],
		["Ver no mapa", "A frente de batalha no mapa", _mapa],
	]
	var l1: Array = []
	var l2: Array = []
	for i in acoes.size():
		var b := Tema.botao(acoes[i][0], acoes[i][1])
		b.pressed.connect(acoes[i][2])
		_botoes.append(b)
		(l1 if i < 4 else l2).append(b)
	dir.add_child(linha(l1))
	dir.add_child(linha(l2))

	var todas := Guerras.todas(u)
	todas.sort_custom(func(a, b):
		var aa: bool = Guerras.dados(u, a)["ativa"]
		var bb: bool = Guerras.dados(u, b)["ativa"]
		if aa != bb:
			return aa
		return int(Guerras.dados(u, a)["inicio"]) > int(Guerras.dados(u, b)["inicio"]))
	for g in todas:
		var d := Guerras.dados(u, g)
		var i := _lista.add_item("%s %s  ·  %s" % ["⚔" if d["ativa"] else "†", u.entidade(g)["nome"], "agora" if d["ativa"] else "acabou"])
		_lista.set_item_metadata(i, g)
	_atual = dado if todas.has(dado) else (todas[0] if not todas.is_empty() else "")
	for i in _lista.item_count:
		if _lista.get_item_metadata(i) == _atual:
			_lista.select(i)
	_abrir(_atual)


func _abrir(g: String) -> void:
	_atual = g
	var ativa: bool = g != "" and bool(Guerras.dados(u, g).get("ativa", false))
	for i in _botoes.size():
		_botoes[i].disabled = not ativa and i < 7
	if g == "":
		_pagina.text = Paginas.cabecalho("Guerras") + "\n[i]Nenhuma guerra ainda. Que bom (por enquanto).\n\nDeclare uma aqui, escreva num capítulo (\"Sokovia declarou guerra a Bermudit\") ou deixe o tempo correr: fome, vingança, fé e ambição também começam guerras.[/i]"
		return
	var e := u.entidade(g)
	var nl := str(u.estado(g).get("nome_lendario", ""))
	_pagina.text = Paginas.cabecalho(e["nome"], ("lembrada como " + nl) if nl != "" else "guerra") + Paginas.guerra(u, g)
	_pagina.scroll_to_line(0)


func _depois(r: Dictionary) -> void:
	if str(r.get("texto", "")) != "":
		livro.avisar(r["texto"])
	livro.atualizar_cabecalho()
	livro.ir_para_aba("guerras", _atual)


## Sociedades citadas num texto, na ordem.
func _sociedades(texto: String) -> Array:
	var lista: Array = []
	for m in Ligador.new(u).encontrar(texto):
		var s := Guerras.sociedade_de(u, m["entidade"])
		if s != "" and not lista.has(s):
			lista.append(s)
	return lista


func _declarar() -> void:
	livro.pedir_texto("Declarar guerra", "Quem ataca quem, e por quê (ex.: Sokovia contra Bermudit, por vingança)", "", func(t: String):
		var s := _sociedades(t)
		if s.size() < 2:
			livro.avisar("Cite duas sociedades (reinos, repúblicas, tribos…).")
			return
		var motivo := ""
		var n := TextUtil.normalizar(t)
		for k in [", por ", " porque ", " por causa de ", " pela ", " pelo "]:
			var i := n.find(k)
			if i >= 0:
				motivo = t.substr(i + k.length()).strip_edges().trim_suffix(".")
				break
		var g := Guerras.declarar(u, s[0], s[1], motivo)
		if g == "":
			livro.avisar("Essas duas já estão em guerra.")
			return
		_atual = g
		_depois({"texto": "Guerra declarada."}))


func _reforcos() -> void:
	livro.pedir_texto("Reforços", "Para quem e quantos (ex.: Bermudit, 5 mil; ou Sokovia, 300 cavaleiros)", "", func(t: String):
		var s := _sociedades(t)
		var d := Guerras.dados(u, _atual)
		var sid: String = s[0] if not s.is_empty() and Guerras.lado_de(u, _atual, s[0]) != "" else d["b"][0]
		var tam := Combate.ler_numero(t)
		var p := {"sid": sid, "tamanho": tam if tam > 0 else 1000.0}
		var n := " " + TextUtil.normalizar(t) + " "
		for tipo in Forcas.TIPOS:
			if tipo == "infantaria":
				continue
			for w in Forcas.TIPOS[tipo]["palavras"]:
				if n.contains(" " + w + " "):
					p["nome"] = "%s de %s" % [Forcas.TIPOS[tipo]["nome"].capitalize(), u.entidade(sid)["nome"]]
					p["tipo"] = tipo
		_depois(Guerras.intervir(u, _atual, "reforcos", p)))


func _traicao() -> void:
	livro.pedir_texto("Traição", "Quem trai? (o nome da força ou do comandante)", "", func(t: String):
		var alvo := ""
		for m in Ligador.new(u).encontrar(t):
			if Forcas.eh_forca(u, m["entidade"]):
				alvo = m["entidade"]
			else:
				for f in Forcas.todas(u):
					if Forcas.comandante(u, f) == m["entidade"]:
						alvo = f
		_depois(Guerras.intervir(u, _atual, "traicao", {"forca": alvo})))


func _desastre() -> void:
	livro.pedir_texto("Desastre na frente de batalha", "O que acontece (ex.: tempestade de areia, peste, inverno rigoroso)", "", func(t: String):
		_depois(Guerras.intervir(u, _atual, "desastre", {"texto": t})))


func _aliado() -> void:
	livro.pedir_texto("Aliado inesperado", "Quem entra e ao lado de quem (ex.: Tribo do Vento, ao lado de Bermudit)", "", func(t: String):
		var s := _sociedades(t)
		if s.is_empty():
			livro.avisar("Cite a sociedade que entra na guerra.")
			return
		var lado := "b"
		if s.size() > 1 and Guerras.lado_de(u, _atual, s[1]) != "":
			lado = Guerras.lado_de(u, _atual, s[1])
		_depois(Guerras.intervir(u, _atual, "aliado", {"sid": s[0], "lado": lado})))


func _morte() -> void:
	livro.pedir_texto("Morte de um general", "Quem morre, e como (ex.: Ilsa Varga, atingida por uma flecha)", "", func(t: String):
		var quem := ""
		for m in Ligador.new(u).encontrar(t):
			if Estado.tem_mente(u, m["entidade"]):
				quem = m["entidade"]
				break
		var como := ""
		var i := t.find(",")
		if i >= 0:
			como = t.substr(i + 1).strip_edges().trim_suffix(".")
		_depois(Guerras.intervir(u, _atual, "morte_general", {"quem": quem, "como": como})))


func _escrever() -> void:
	livro.pedir_texto("O que acontece nesta guerra?", "Ex.: Desesperado, o rei de Bermudit fez um pacto com o Ser da Quinta Dimensão e recebeu um exército de fantasmas do deserto.", "", func(t: String):
		if t.strip_edges() == "":
			return
		_depois(Guerras.intervir(u, _atual, "livre", {"texto": t})))


func _paz() -> void:
	livro.confirmar("Acabar com esta guerra agora, sem vencedor?", func():
		_depois(Guerras.intervir(u, _atual, "paz", {})))


func _mapa() -> void:
	if _atual == "":
		return
	var fr := Guerras.frente(u, _atual)
	if fr == "" and not Guerras.dados(u, _atual)["ocupados"].is_empty():
		fr = Guerras.dados(u, _atual)["ocupados"][0]
	if fr != "":
		livro.ir_para_aba("mapa", fr)
	else:
		livro.avisar("Esta guerra não tem frente no mapa.")
