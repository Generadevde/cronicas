extends AbaLivro
## Aba "Cosmos": as forças acima das pessoas. À esquerda, o Autor (você, dentro do
## mundo), os arautos e as entidades que oferecem pactos; à direita, a página da
## escolhida, com os pactos (os secretos também: você vê tudo, como deus) e os botões
## para revelar algo ao arauto, fazer um pacto ou criar uma força nova.

var _lista: ItemList
var _pagina: RichTextLabel
var _atual := ""
var _b_revelar: Button
var _b_pacto: Button


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	esq.add_child(Tema.secao("Forças cósmicas"))
	var dica := Tema.rotulo("Qualquer entidade com \"o que oferece\" e \"o que cobra\" na ficha procura quem está sem saída e oferece pactos. O preço chega depois.", 14, Tema.italico(), Tema.TINTA_SUAVE)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esq.add_child(dica)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _abrir(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	var nova := Tema.botao_principal("+ Nova força cósmica")
	nova.pressed.connect(func():
		livro.pedir_texto("Nova força cósmica", "Nome (ex.: Mãe das Cinzas, o Ser da Quinta Dimensão)", "", func(nome: String):
			if nome.strip_edges() == "":
				return
			var e := u.criar_entidade(nome.strip_edges(), "entidade", [], [{"chave": "natureza", "valor": ""}, {"chave": "vontade", "valor": ""},
				{"chave": "o que oferece", "valor": ""}, {"chave": "o que cobra", "valor": ""}, {"chave": "onde age", "valor": ""}])
			livro.ir_para_aba("criadores", e)))
	var autor := Tema.botao("Existir como o Autor" if Autor.entidade(u) == "" else "Novo arauto…",
		"Você no mundo: fora do mapa, sem envelhecer nem morrer" if Autor.entidade(u) == "" else "Alguém passa a conhecer o Autor")
	autor.pressed.connect(func():
		if Autor.entidade(u) == "":
			livro.pedir_texto("Você no mundo", "Com que nome? (ex.: o Autor, o Escriba, a Voz)", "o Autor", func(nome: String):
				var a := Autor.existir(u, nome)
				livro.ir_para_aba("cosmos", a))
		else:
			livro.pedir_texto("Novo arauto", "Quem passa a conhecer o Autor?", "", func(nome: String):
				var p := _pessoa(nome)
				if p == "":
					livro.avisar("Não achei essa pessoa.")
					return
				Autor.tornar_arauto(u, p)
				livro.ir_para_aba("cosmos", p)))
	esq.add_child(linha([nova, autor]))

	_pagina = Tema.texto_rico()
	_pagina.meta_clicked.connect(livro.navegar)
	dir.add_child(_pagina)
	_b_revelar = Tema.botao("Revelar…", "Uma visão, uma ordem ou uma profecia para o arauto")
	_b_revelar.pressed.connect(_revelar)
	_b_pacto = Tema.botao("Fazer um pacto…", "Você decide: quem, o desejo e o preço")
	_b_pacto.pressed.connect(_pacto)
	var ficha := Tema.botao("Editar ficha")
	ficha.pressed.connect(func():
		if _atual != "":
			livro.ir_para_aba("criadores", _atual))
	dir.add_child(linha([_b_revelar, _b_pacto, ficha]))

	var itens: Array = []
	var a := Autor.entidade(u)
	if a != "":
		itens.append([a, "✶ %s  ·  você" % u.entidade(a)["nome"]])
	for p in Autor.arautos(u):
		itens.append([p, "    %s  ·  arauto" % u.entidade(p)["nome"]])
	for s in Pactos.ofertantes(u):
		if s != a:
			var n := Pactos.pactos_de(u, s).size()
			itens.append([s, "◉ %s  ·  %s" % [u.entidade(s)["nome"], ("%d pacto%s" % [n, "" if n == 1 else "s"]) if n > 0 else "sem pactos"]])
	for it in itens:
		var i := _lista.add_item(it[1])
		_lista.set_item_metadata(i, it[0])
	var ids: Array = itens.map(func(x): return x[0])
	_atual = dado if ids.has(dado) else (ids[0] if not ids.is_empty() else "")
	for i in _lista.item_count:
		if _lista.get_item_metadata(i) == _atual:
			_lista.select(i)
	_abrir(_atual)


func _abrir(eid: String) -> void:
	_atual = eid
	_b_revelar.disabled = eid == "" or not Autor.eh_arauto(u, eid)
	_b_pacto.disabled = eid == "" or not Pactos.ofertantes(u).has(eid)
	if eid == "":
		_pagina.text = Paginas.cabecalho("Cosmos") + "\n[i]Nenhuma força cósmica ainda.\n\nCrie uma (um deus, um demônio, um ser antigo) e escreva na ficha o que ela oferece e o que cobra. Ou passe a existir no mundo como o Autor e escolha um arauto.[/i]"
		return
	_pagina.text = Paginas.entidade(u, eid)
	_pagina.scroll_to_line(0)


func _pessoa(nome: String) -> String:
	for m in Ligador.new(u).encontrar(nome):
		if Estado.tem_mente(u, m["entidade"]):
			return m["entidade"]
	return ""


func _revelar() -> void:
	livro.pedir_texto("Revelar ao arauto", "Comece com visão:, ordem: ou profecia: (ex.: profecia: quando a lua sangrar, Varn cairá)", "visão: ", func(t: String):
		var tipo := "visao"
		var texto := t.strip_edges()
		var n := TextUtil.normalizar(texto)
		for k in [["ordem", "ordem"], ["profecia", "profecia"], ["visao", "visao"]]:
			if n.begins_with(k[0]):
				tipo = k[1]
				texto = texto.substr(texto.find(":") + 1).strip_edges() if texto.find(":") >= 0 else texto.substr(k[0].length()).strip_edges()
		if texto == "":
			return
		Autor.revelar(u, _atual, texto, tipo)
		livro.avisar("Revelado. %s vai reagir com a própria mente." % u.entidade(_atual)["nome"])
		livro.ir_para_aba("cosmos", _atual))


func _pacto() -> void:
	livro.pedir_texto("Fazer um pacto com %s" % u.entidade(_atual)["nome"], "Quem e o que deseja (ex.: Daren, vingança contra Kai)", "", func(t: String):
		var p := _pessoa(t)
		if p == "":
			livro.avisar("Não achei a pessoa.")
			return
		var d := Pactos.desejo(u, p)
		var n := TextUtil.normalizar(t)
		if n.contains("vinga"):
			for m in Ligador.new(u).encontrar(t):
				if m["entidade"] != p and Estado.tem_mente(u, m["entidade"]):
					d = {"tipo": "vinganca", "alvo": m["entidade"], "texto": "vingança contra " + u.entidade(m["entidade"])["nome"], "desespero": 1.0}
		elif n.contains("cura"):
			d = {"tipo": "cura", "alvo": p, "texto": "ser curado", "desespero": 1.0}
		elif n.contains("forc") or n.contains("poder"):
			d = {"tipo": "forca", "alvo": "", "texto": "poder", "desespero": 1.0}
		elif n.contains("riqu") or n.contains("ouro"):
			d = {"tipo": "riqueza", "alvo": "", "texto": "riqueza", "desespero": 1.0}
		if d.is_empty():
			var i := t.find(",")
			d = {"tipo": "outro", "alvo": "", "texto": t.substr(i + 1).strip_edges() if i >= 0 else "um desejo", "desespero": 1.0}
		var ser := _atual
		livro.pedir_texto("O preço", "O que %s cobra (vazio = o que está na ficha)" % u.entidade(ser)["nome"], Pactos.preco_escrito(u, ser), func(preco: String):
			Pactos.fazer(u, ser, p, d, preco, true, [], true)
			livro.avisar("Pacto feito. O preço fica em segredo até chegar a hora.")
			livro.atualizar_cabecalho()
			livro.ir_para_aba("cosmos", ser)))
