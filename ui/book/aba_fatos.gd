extends AbaLivro
## Aba "Fatos" (tela de depuração da Parte 1): mostra o banco de fatos cru,
## as causas e consequências de cada fato, e roda o auditor de integridade.

var _lista: ItemList
var _pagina: RichTextLabel
var _fatos: Array = []


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	esq.add_child(Tema.secao("Banco de fatos · depuração"))
	var b_auditar := Tema.botao_principal("Rodar auditor")
	b_auditar.pressed.connect(_auditar)
	esq.add_child(b_auditar)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _mostrar(_fatos[i]["id"]))
	esq.add_child(_lista)
	esq.add_child(Tema.rotulo("%d fatos registrados" % u.fatos.quantidade(), 15, Tema.italico(), Tema.TINTA_SUAVE))

	_pagina = Tema.texto_rico()
	_pagina.meta_clicked.connect(func(meta):
		var m := str(meta)
		if m.begins_with("fato:"):
			_mostrar(m.substr(5))
		else:
			livro.navegar(m))
	dir.add_child(_pagina)

	_fatos = u.fatos.todos()
	_fatos.reverse()
	for f in _fatos:
		var i := _lista.add_item("#%d · %s · %s" % [f["seq"], f["tipo"], f["descricao"]])
		_lista.set_item_tooltip(i, f["descricao"])
	if u.fatos.existe(dado):
		_mostrar(dado)
	else:
		_auditar()


func _mostrar(fid: String) -> void:
	_pagina.text = Paginas.fato(u, fid)
	for i in _fatos.size():
		if _fatos[i]["id"] == fid:
			_lista.select(i)
			_lista.ensure_current_is_visible()
			break


func _auditar() -> void:
	var problemas := Auditor.auditar(u)
	var s := Paginas.cabecalho("Auditor", "integridade do universo")
	if problemas.is_empty():
		s += "\n[center]Nenhum problema encontrado em %d fatos.[/center]\n" % u.fatos.quantidade()
		s += "\n[color=#5A3A1A]Conferido: causas existem, nenhuma causa acontece depois do efeito, nenhum ciclo de causas, fatos da simulação têm origem, entidades citadas existem.[/color]"
	else:
		s += "\n[color=#7A2418]%d problema(s):[/color]\n" % problemas.size()
		for p in problemas:
			s += "• [b]%s[/b] em %s: %s\n" % [p["tipo"], Paginas.link("fato:" + p["fato"], p["fato"]), TextUtil.escapar_bbcode(p["mensagem"])]
	_pagina.text = s
