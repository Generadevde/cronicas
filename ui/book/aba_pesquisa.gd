extends AbaLivro
## Aba "Pesquisa": busca em entidades, capítulos e notas, sem acento e com erros de digitação.

const ROTULOS := {"entidade": "wiki", "capitulo": "capítulo", "nota": "nota"}

var _consulta: LineEdit
var _resultados: ItemList
var _previa: RichTextLabel
var _itens: Array = []


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	esq.add_child(Tema.secao("Pesquisar no universo"))
	_consulta = campo("Nome, apelido, palavra do texto…", dado)
	_consulta.text_changed.connect(func(_t): _buscar())
	_consulta.text_submitted.connect(func(_t): _abrir_selecionado())
	esq.add_child(_consulta)
	_resultados = ItemList.new()
	_resultados.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_resultados.item_selected.connect(_mostrar)
	_resultados.item_activated.connect(func(_i): _abrir_selecionado())
	esq.add_child(_resultados)
	var dica := Tema.rotulo("Clique duas vezes para abrir.", 15, Tema.italico(), Tema.TINTA_SUAVE)
	esq.add_child(dica)

	_previa = Tema.texto_rico()
	_previa.meta_clicked.connect(livro.navegar)
	dir.add_child(_previa)
	_buscar()
	_consulta.grab_focus.call_deferred()


func _buscar() -> void:
	_resultados.clear()
	_itens = Pesquisa.buscar(u, _consulta.text)
	for r in _itens:
		var i := _resultados.add_item("%s   (%s)" % [r["titulo"], ROTULOS.get(r["tipo"], r["tipo"])])
		_resultados.set_item_tooltip(i, r["detalhe"])
	if _itens.is_empty():
		_previa.text = Paginas.cabecalho("Pesquisa") + "\n[center][i]%s[/i][/center]" % (
			"Escreva algo para pesquisar." if _consulta.text.strip_edges() == "" else "Nada encontrado.")
	else:
		_resultados.select(0)
		_mostrar(0)


func _mostrar(i: int) -> void:
	var r: Dictionary = _itens[i]
	match r["tipo"]:
		"entidade":
			_previa.text = Paginas.entidade(u, r["id"])
		"capitulo":
			_previa.text = Paginas.capitulo(u, r["id"])
		"nota":
			_previa.text = Paginas.nota(u, r["id"])
	_previa.scroll_to_line(0)


func _abrir_selecionado() -> void:
	var sel := _resultados.get_selected_items()
	if sel.is_empty():
		return
	var r: Dictionary = _itens[sel[0]]
	var prefixo := {"entidade": "ent:", "capitulo": "cap:", "nota": "nota:"}
	livro.navegar(prefixo[r["tipo"]] + r["id"])
