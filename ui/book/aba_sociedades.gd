extends AbaLivro
## Aba "Sociedades": reinos, repúblicas, tribos, guildas… à esquerda; a página da
## sociedade escolhida à direita (governo, governante, dinastia, conselho, povo,
## riqueza, leis, fé, cultura e como ela vê as pessoas).

var _lista: ItemList
var _pagina: RichTextLabel
var _atual := ""

const MODELO := [
	{"chave": "forma de governo", "valor": "monarquia"},
	{"chave": "líder", "valor": ""},
	{"chave": "território", "valor": ""},
	{"chave": "conselho", "valor": ""},
	{"chave": "leis", "valor": ""},
	{"chave": "impostos", "valor": "comuns"},
	{"chave": "religião", "valor": ""},
	{"chave": "admiram", "valor": ""},
	{"chave": "desprezam", "valor": ""},
]


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	esq.add_child(Tema.secao("Sociedades do universo"))
	var dica := Tema.rotulo("Qualquer facção ou lugar com governo na ficha (\"forma de governo\", \"líder\", \"território\", \"leis\", \"religião\", \"admiram\", \"desprezam\", \"impostos\"…). Tudo texto livre.", 14, Tema.italico(), Tema.TINTA_SUAVE)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esq.add_child(dica)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _abrir(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	var nova := Tema.botao_principal("+ Nova sociedade")
	nova.pressed.connect(func():
		livro.pedir_texto("Nova sociedade", "Nome (ex.: Reino de Aldor, Tribo do Lobo, Guilda dos Mercadores)", "", func(nome: String):
			if nome.strip_edges() == "":
				return
			var t := "reino"
			var n := TextUtil.normalizar(nome)
			for w in ["republica", "tribo", "guilda", "ordem", "igreja", "imperio", "cla", "colmeia", "companhia", "seita", "conselho"]:
				if n.contains(w):
					t = w
			var sid := u.criar_entidade(nome.strip_edges(), t, [], MODELO.duplicate(true))
			livro.ir_para_aba("criadores", sid)))
	esq.add_child(nova)

	_pagina = Tema.texto_rico()
	_pagina.meta_clicked.connect(livro.navegar)
	dir.add_child(_pagina)
	var ficha := Tema.botao("Editar ficha")
	ficha.pressed.connect(func():
		if _atual != "":
			livro.ir_para_aba("criadores", _atual))
	var trocar := Tema.botao("Pôr no governo…", "Você decide quem governa (vira fato do autor)")
	trocar.pressed.connect(func():
		if _atual == "":
			return
		livro.pedir_texto("Quem passa a governar?", "Nome de uma pessoa", "", func(nome: String):
			var ps := Sociedades.pessoas_no_texto(u, nome)
			if ps.is_empty():
				livro.avisar("Não achei ninguém com esse nome.")
				return
			Simulador.registrar(u, {"tipo": "sucessão", "descricao": "Por vontade do autor, %s passou a governar %s." % [u.entidade(ps[0])["nome"], u.entidade(_atual)["nome"]],
				"sujeitos": [_atual, ps[0]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "sociedades"},
				"dados": {"importancia": 0.7, "mudancas": [{"op": "definir", "quem": _atual, "chave": "lider", "valor": ps[0]},
					{"op": "definir", "quem": _atual, "chave": "sem_governante", "valor": false}]}})
			livro.ir_para_aba("sociedades", _atual)))
	var mapa := Tema.botao("Ver no mapa")
	mapa.pressed.connect(func():
		var terr := Sociedades.territorio_base(u, _atual)
		if not terr.is_empty():
			livro.ir_para_aba("mapa", terr[0]))
	dir.add_child(linha([ficha, trocar, mapa]))

	var todas := Sociedades.todas(u)
	for sid in todas:
		var i := _lista.add_item("%s  ·  %s" % [u.entidade(sid)["nome"], Sociedades.NOMES_TIPO.get(Sociedades.tipo(u, sid), "")])
		_lista.set_item_metadata(i, sid)
	_atual = dado if todas.has(dado) else (todas[0] if not todas.is_empty() else "")
	for i in _lista.item_count:
		if _lista.get_item_metadata(i) == _atual:
			_lista.select(i)
	_abrir(_atual)


func _abrir(sid: String) -> void:
	_atual = sid
	if sid == "":
		_pagina.text = Paginas.cabecalho("Sociedades") + "\n[i]Nenhuma sociedade ainda. Crie uma (ou use \"Povoar\" no mapa, que cria facções).[/i]"
		return
	var e := u.entidade(sid)
	_pagina.text = Paginas.cabecalho(e["nome"], Paginas._e(e["tipo"])) + Paginas.sociedade(u, sid)
	_pagina.scroll_to_line(0)
