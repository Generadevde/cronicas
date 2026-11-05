extends AbaLivro
## Aba "Wiki": lista de entidades à esquerda, a página da entidade à direita.

var _lista: ItemList
var _filtro: LineEdit
var _pagina: RichTextLabel
var _atual := ""


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	esq.add_child(Tema.secao("Enciclopédia do universo"))
	_filtro = campo("Filtrar por nome ou tipo…")
	_filtro.text_changed.connect(func(_t): _preencher())
	esq.add_child(_filtro)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _abrir(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	var b_nova := Tema.botao("+ Nova entidade")
	b_nova.pressed.connect(func(): livro.ir_para_aba("criadores", "nova"))
	esq.add_child(b_nova)

	_pagina = Tema.texto_rico()
	_pagina.meta_clicked.connect(livro.navegar)
	dir.add_child(_pagina)
	var b_editar := Tema.botao("Editar ficha")
	b_editar.pressed.connect(func():
		if _atual != "":
			livro.ir_para_aba("criadores", _atual))
	dir.add_child(b_editar)

	_atual = dado if u.entidades.has(dado) else ""
	_preencher()
	if _atual == "" and _lista.item_count > 0:
		_abrir(str(_lista.get_item_metadata(0)))
	else:
		_abrir(_atual)


func _preencher() -> void:
	_lista.clear()
	var f := TextUtil.chave(_filtro.text)
	for e in u.entidades_ativas():
		if f != "" and not TextUtil.chave(e["nome"]).contains(f) and not TextUtil.chave(e["tipo"]).contains(f):
			continue
		var i := _lista.add_item("%s  ·  %s" % [e["nome"], e["tipo"]])
		_lista.set_item_metadata(i, e["id"])
		if e["id"] == _atual:
			_lista.select(i)


func _abrir(eid: String) -> void:
	_atual = eid
	if eid == "":
		_pagina.text = Paginas.cabecalho("Wiki") + \
			"\n[center][i]Nenhuma entidade ainda. Crie pessoas, lugares, magias, criaturas — o que quiser — na aba Criadores.[/i][/center]"
		return
	_pagina.text = Paginas.entidade(u, eid)
	_pagina.scroll_to_line(0)
