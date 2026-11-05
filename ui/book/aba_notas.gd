extends AbaLivro
## Aba "Notas": notas privadas do autor. A simulação nunca lê nem altera.

var _lista: ItemList
var _dir: VBoxContainer
var _atual := ""


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	esq.add_child(Tema.secao("Notas do autor"))
	var aviso := Tema.rotulo("Só você lê. O mundo nunca toca nestas páginas.", 15, Tema.italico(), Tema.TINTA_SUAVE)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esq.add_child(aviso)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _abrir(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	var b_nova := Tema.botao("+ Nota")
	b_nova.pressed.connect(func():
		_atual = u.criar_nota("Nova nota")
		_preencher()
		_abrir(_atual))
	var b_apagar := Tema.botao("Apagar")
	b_apagar.pressed.connect(func():
		if _atual == "":
			return
		livro.confirmar("Apagar a nota \"%s\"?" % u.nota(_atual)["titulo"], func():
			u.apagar_nota(_atual)
			_atual = ""
			_preencher()
			_abrir("")))
	esq.add_child(linha([b_nova, b_apagar]))
	_atual = dado
	_preencher()
	if _atual == "" and not u.notas.is_empty():
		_atual = u.notas.back()["id"]
	_abrir(_atual)


func _preencher() -> void:
	_lista.clear()
	for n in u.notas:
		var i := _lista.add_item(n["titulo"] if n["titulo"] != "" else "(sem título)")
		_lista.set_item_metadata(i, n["id"])
		if n["id"] == _atual:
			_lista.select(i)


func _abrir(nid: String) -> void:
	_atual = nid
	Tema.limpar(_dir)
	var n := u.nota(nid)
	if n.is_empty():
		_dir.add_child(Tema.titulo("Notas"))
		_dir.add_child(Tema.ornamento())
		var dica := Tema.rotulo("Ideias soltas, segredos, planos para o futuro.\nCrie uma nota ao lado.", 19, Tema.italico(), Tema.TINTA_SUAVE)
		dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dir.add_child(dica)
		return
	var titulo := campo("Título", n["titulo"])
	titulo.add_theme_font_override("font", Tema.F_FELL)
	titulo.add_theme_font_size_override("font_size", Tema.px(26))
	var texto := TextEdit.new()
	texto.text = n["texto"]
	texto.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto.placeholder_text = "Escreva…"
	texto.add_theme_font_override("font", Tema.escrita())
	texto.add_theme_font_size_override("font_size", Tema.px_escrita(21))
	var salvar := func():
		u.atualizar_nota(_atual, titulo.text, texto.text)
		for i in _lista.item_count:
			if str(_lista.get_item_metadata(i)) == _atual:
				_lista.set_item_text(i, titulo.text if titulo.text != "" else "(sem título)")
	titulo.text_changed.connect(func(_t: String): salvar.call())
	texto.text_changed.connect(salvar)
	_dir.add_child(titulo)
	_dir.add_child(texto)
