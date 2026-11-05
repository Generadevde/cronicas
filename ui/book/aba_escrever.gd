extends AbaLivro
## Aba "Escrever": estante de livros e capítulos à esquerda, a página do capítulo à direita.

var _arvore: Tree
var _cap_atual := ""
var _dir: VBoxContainer
var _editor: TextEdit
var _leitura: RichTextLabel
var _rodape: RichTextLabel


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	esq.add_child(Tema.secao("Livros e capítulos"))
	_arvore = Tree.new()
	_arvore.hide_root = true
	_arvore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arvore.item_selected.connect(_ao_selecionar)
	esq.add_child(_arvore)

	var b_livro := Tema.botao("+ Livro", "Criar um livro novo neste universo")
	b_livro.pressed.connect(_novo_livro)
	var b_cap := Tema.botao("+ Capítulo", "Criar um capítulo no livro selecionado")
	b_cap.pressed.connect(_novo_capitulo)
	var b_ren := Tema.botao("Renomear", "Renomear o livro selecionado")
	b_ren.pressed.connect(_renomear)
	esq.add_child(linha([b_livro, b_cap, b_ren]))
	var b_cima := Tema.botao("↑", "Mover para cima")
	b_cima.pressed.connect(_mover.bind(-1))
	var b_baixo := Tema.botao("↓", "Mover para baixo")
	b_baixo.pressed.connect(_mover.bind(1))
	var b_apagar := Tema.botao("Apagar", "Apagar o livro ou capítulo selecionado (o texto vai para as notas)")
	b_apagar.pressed.connect(_apagar)
	esq.add_child(linha([b_cima, b_baixo, b_apagar]))

	_cap_atual = dado if u.capitulos.has(dado) else ""
	if _cap_atual == "" and livro.has_meta("ultimo_capitulo") and u.capitulos.has(livro.get_meta("ultimo_capitulo")):
		_cap_atual = livro.get_meta("ultimo_capitulo")
	if _cap_atual == "":
		for l in u.livros:
			if not l["capitulos"].is_empty():
				_cap_atual = l["capitulos"][0]
				break
	_recarregar_arvore()
	_mostrar_capitulo()


func _recarregar_arvore() -> void:
	_arvore.clear()
	var raiz := _arvore.create_item()
	for l in u.livros:
		var it := _arvore.create_item(raiz)
		it.set_text(0, l["titulo"])
		it.set_custom_font(0, Tema.F_VERSALETE)
		it.set_metadata(0, "liv:" + l["id"])
		for cid in l["capitulos"]:
			var cap: Dictionary = u.capitulos[cid]
			var ci := _arvore.create_item(it)
			ci.set_text(0, _rotulo_cap(cap))
			ci.set_metadata(0, "cap:" + cid)
			if cid == _cap_atual:
				ci.select(0)
	if u.livros.is_empty():
		var vazio := _arvore.create_item(raiz)
		vazio.set_text(0, "Nenhum livro ainda. Crie o primeiro.")
		vazio.set_selectable(0, false)


func _rotulo_cap(cap: Dictionary) -> String:
	var t: String = cap["titulo"] if cap["titulo"] != "" else "(sem título)"
	if cap["marcado"]:
		t = "❧ " + t
	if not cap["canon"]:
		t += "  · rascunho"
	return t


func _selecionado() -> String:
	var it := _arvore.get_selected()
	return "" if it == null else str(it.get_metadata(0))


func _livro_do_selecionado() -> String:
	var s := _selecionado()
	if s.begins_with("liv:"):
		return s.substr(4)
	if s.begins_with("cap:"):
		return u.capitulo(s.substr(4)).get("livro", "")
	return u.livros.back()["id"] if not u.livros.is_empty() else ""


func _ao_selecionar() -> void:
	var s := _selecionado()
	if s.begins_with("cap:") and s.substr(4) != _cap_atual:
		_cap_atual = s.substr(4)
		_mostrar_capitulo()


func _novo_livro() -> void:
	livro.pedir_texto("Novo livro", "Título do livro", "", func(t: String):
		if t.strip_edges() == "":
			return
		var lid := u.criar_livro(t)
		_cap_atual = u.capitulo(u.criar_capitulo(lid, "Capítulo 1")).get("id", "")
		_recarregar_arvore()
		_mostrar_capitulo())


func _novo_capitulo() -> void:
	var lid := _livro_do_selecionado()
	if lid == "":
		_novo_livro()
		return
	var n: int = u.livro(lid)["capitulos"].size() + 1
	_cap_atual = u.criar_capitulo(lid, "Capítulo %d" % n)
	_recarregar_arvore()
	_mostrar_capitulo()


func _renomear() -> void:
	var lid := _livro_do_selecionado()
	if lid == "":
		return
	livro.pedir_texto("Renomear livro", "Título do livro", u.livro(lid)["titulo"], func(t: String):
		u.renomear_livro(lid, t)
		_recarregar_arvore())


func _mover(delta: int) -> void:
	var s := _selecionado()
	if s.begins_with("liv:"):
		u.mover_livro(s.substr(4), delta)
	elif s.begins_with("cap:"):
		u.mover_capitulo(s.substr(4), delta)
	_recarregar_arvore()
	_reselecionar(s)


func _reselecionar(meta: String) -> void:
	var it := _arvore.get_root().get_first_child() if _arvore.get_root() else null
	while it != null:
		if str(it.get_metadata(0)) == meta:
			it.select(0)
			return
		var filho := it.get_first_child()
		while filho != null:
			if str(filho.get_metadata(0)) == meta:
				filho.select(0)
				return
			filho = filho.get_next()
		it = it.get_next()


func _apagar() -> void:
	var s := _selecionado()
	if s.begins_with("liv:"):
		var l := u.livro(s.substr(4))
		livro.confirmar("Apagar o livro \"%s\" e seus %d capítulos?\nO texto escrito vai para as notas do autor." % [l["titulo"], l["capitulos"].size()], func():
			if l["capitulos"].has(_cap_atual):
				_cap_atual = ""
			u.apagar_livro(l["id"])
			_recarregar_arvore()
			_mostrar_capitulo())
	elif s.begins_with("cap:"):
		var cap := u.capitulo(s.substr(4))
		livro.confirmar("Apagar o capítulo \"%s\"?\nO texto vai para as notas do autor." % cap["titulo"], func():
			if cap["id"] == _cap_atual:
				_cap_atual = ""
			u.apagar_capitulo(cap["id"])
			_recarregar_arvore()
			_mostrar_capitulo())


# ---------------------------------------------------------------- página do capítulo

func _mostrar_capitulo() -> void:
	Tema.limpar(_dir)
	var cap := u.capitulo(_cap_atual)
	if cap.is_empty():
		_dir.add_child(Tema.titulo("Escrever"))
		_dir.add_child(Tema.ornamento())
		var dica := Tema.rotulo("Escolha um capítulo na estante ao lado, ou crie um livro novo.\n\n" +
			"Os nomes das entidades que você criar viram links sozinhos enquanto você escreve.",
			19, Tema.F_ITALICO, Tema.TINTA_SUAVE)
		dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dir.add_child(dica)
		return
	livro.set_meta("ultimo_capitulo", _cap_atual)

	var titulo := campo("Título do capítulo", cap["titulo"])
	titulo.add_theme_font_override("font", Tema.F_FELL)
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.text_changed.connect(func(t: String):
		u.atualizar_capitulo(_cap_atual, {"titulo": t})
		var it := _arvore.get_selected()
		if it != null and str(it.get_metadata(0)) == "cap:" + _cap_atual:
			it.set_text(0, _rotulo_cap(u.capitulo(_cap_atual))))
	_dir.add_child(titulo)

	var ano := SpinBox.new()
	ano.min_value = -100000
	ano.max_value = 1000000
	ano.value = cap["data"]["ano"]
	ano.prefix = "Ano"
	ano.tooltip_text = "Ano em que o capítulo acontece no mundo"
	var dia := SpinBox.new()
	dia.min_value = 1
	dia.max_value = DataMundo.DIAS_POR_ANO
	dia.value = cap["data"]["dia"]
	dia.prefix = "dia"
	var mudar_data := func(_v: float):
		u.atualizar_capitulo(_cap_atual, {"data": DataMundo.criar(int(ano.value), int(dia.value))})
	ano.value_changed.connect(mudar_data)
	dia.value_changed.connect(mudar_data)
	var canon := CheckBox.new()
	canon.text = "Canon"
	canon.button_pressed = cap["canon"]
	canon.tooltip_text = "Canon vale no mundo. Desmarcado = rascunho, não afeta nada."
	canon.toggled.connect(func(v: bool):
		u.atualizar_capitulo(_cap_atual, {"canon": v})
		_atualizar_item_arvore())
	var marca := CheckBox.new()
	marca.text = "Marcador"
	marca.button_pressed = cap["marcado"]
	marca.tooltip_text = "Marcar como capítulo importante"
	marca.toggled.connect(func(v: bool):
		u.atualizar_capitulo(_cap_atual, {"marcado": v})
		_atualizar_item_arvore())
	var b_ler := Tema.botao("Ler", "Alternar entre escrever e ler com os nomes como links")
	b_ler.toggle_mode = true
	_dir.add_child(linha([ano, dia, canon, marca, b_ler]))

	_editor = TextEdit.new()
	_editor.text = cap["texto"]
	_editor.placeholder_text = "Era uma vez…"
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.add_theme_font_size_override("font_size", 20)
	_editor.text_changed.connect(func():
		u.atualizar_capitulo(_cap_atual, {"texto": _editor.text})
		livro.adiar(_atualizar_rodape))
	_dir.add_child(_editor)

	_leitura = Tema.texto_rico()
	_leitura.visible = false
	_leitura.meta_clicked.connect(livro.navegar)
	_dir.add_child(_leitura)

	b_ler.toggled.connect(func(lendo: bool):
		b_ler.text = "Escrever" if lendo else "Ler"
		if lendo:
			_leitura.text = Paginas.capitulo(u, _cap_atual)
		_leitura.visible = lendo
		_editor.visible = not lendo)

	_rodape = RichTextLabel.new()
	_rodape.bbcode_enabled = true
	_rodape.fit_content = true
	_rodape.scroll_active = false
	_rodape.add_theme_font_size_override("normal_font_size", 16)
	_rodape.meta_clicked.connect(livro.navegar)
	_dir.add_child(_rodape)
	_atualizar_rodape()


func _atualizar_item_arvore() -> void:
	var it := _arvore.get_selected()
	if it != null and str(it.get_metadata(0)) == "cap:" + _cap_atual:
		it.set_text(0, _rotulo_cap(u.capitulo(_cap_atual)))


func _atualizar_rodape() -> void:
	if _rodape == null or not is_instance_valid(_rodape) or not u.capitulos.has(_cap_atual):
		return
	var texto: String = u.capitulo(_cap_atual)["texto"]
	var vistos := {}
	var nomes: Array = []
	for m in Ligador.new(u).encontrar(texto):
		if vistos.has(m["entidade"]):
			continue
		vistos[m["entidade"]] = true
		nomes.append(Paginas.link("ent:" + m["entidade"], u.entidade(m["entidade"])["nome"]))
	var palavras := TextUtil.palavras(texto).size()
	var s := "[color=#5A3A1A]%d palavras" % palavras
	if not nomes.is_empty():
		s += " · nesta página: [/color]" + ", ".join(nomes)
	else:
		s += "[/color]"
	_rodape.text = s
