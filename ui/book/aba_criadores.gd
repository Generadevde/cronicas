extends AbaLivro
## Aba "Criadores": criar e editar qualquer entidade com tipo e campos livres.
## As sugestões de campos são só um atalho; nada é fixo.

var _lista: ItemList
var _mostrar_retiradas: CheckBox
var _dir: VBoxContainer
var _atual := ""   ## "" = criando uma nova
var _nome: LineEdit
var _tipo: LineEdit
var _apelidos: LineEdit
var _campos_box: VBoxContainer
var _status: Label


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	esq.add_child(Tema.secao("Criadores"))
	var b_nova := Tema.botao_principal("+ Nova entidade")
	b_nova.pressed.connect(func(): _editar(""))
	esq.add_child(b_nova)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _editar(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	_mostrar_retiradas = CheckBox.new()
	_mostrar_retiradas.text = "Mostrar retiradas"
	_mostrar_retiradas.toggled.connect(func(_v): _preencher())
	esq.add_child(_mostrar_retiradas)
	_preencher()
	_editar(dado if u.entidades.has(dado) else "")


func _preencher() -> void:
	_lista.clear()
	var todas: Array = u.entidades.values()
	todas.sort_custom(func(a, b): return TextUtil.chave(a["nome"]) < TextUtil.chave(b["nome"]))
	for e in todas:
		if e["removida"] and not _mostrar_retiradas.button_pressed:
			continue
		var i := _lista.add_item(("(retirada) " if e["removida"] else "") + e["nome"])
		_lista.set_item_metadata(i, e["id"])
		if e["removida"]:
			_lista.set_item_custom_fg_color(i, Color(Tema.TINTA, 0.45))
		if e["id"] == _atual:
			_lista.select(i)


func _editar(eid: String) -> void:
	_atual = eid
	Tema.limpar(_dir)
	var e := u.entidade(eid)
	_dir.add_child(Tema.titulo("Nova entidade" if e.is_empty() else e["nome"], 34))
	_dir.add_child(Tema.ornamento())

	var form := VBoxContainer.new()
	form.add_child(Tema.secao("Nome"))
	_nome = campo("Como se chama?", e.get("nome", ""))
	form.add_child(_nome)
	form.add_child(Tema.secao("O que é"))
	_tipo = campo("Escreva o que quiser: pessoa, cidade flutuante, magia de sangue, dragão que fala…", e.get("tipo", ""))
	form.add_child(_tipo)
	form.add_child(Tema.secao("Também chamado de"))
	_apelidos = campo("Apelidos e outros nomes, separados por vírgula", ", ".join(e.get("apelidos", [])))
	form.add_child(_apelidos)

	form.add_child(Tema.secao("Ficha"))
	var explica := Tema.rotulo("Cada linha é um campo livre: dê o nome que quiser e escreva à vontade.", 16, Tema.F_ITALICO, Tema.TINTA_SUAVE)
	explica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(explica)
	_campos_box = VBoxContainer.new()
	form.add_child(_campos_box)
	for c in e.get("campos", []):
		_adicionar_campo(c["chave"], c["valor"])
	var b_campo := Tema.botao("+ Campo")
	b_campo.pressed.connect(func(): _adicionar_campo("", "", true))
	var b_sugerir := Tema.botao("Sugerir campos", "Sugere campos a partir do que você escreveu em \"O que é\"")
	b_sugerir.pressed.connect(_sugerir)
	form.add_child(linha([b_campo, b_sugerir]))
	_dir.add_child(rolagem(form))

	var b_salvar := Tema.botao_principal("Salvar ficha")
	b_salvar.pressed.connect(_salvar)
	var botoes: Array = [b_salvar]
	if not e.is_empty():
		var b_wiki := Tema.botao("Ver na wiki")
		b_wiki.pressed.connect(func(): livro.ir_para_aba("wiki", _atual))
		botoes.append(b_wiki)
		if e["removida"]:
			var b_rest := Tema.botao("Restaurar")
			b_rest.pressed.connect(func():
				u.restaurar_entidade(_atual)
				_preencher()
				_editar(_atual))
			botoes.append(b_rest)
		else:
			var b_ret := Tema.botao("Retirar do universo", "Some das listas, mas a história dela continua guardada")
			b_ret.pressed.connect(func():
				livro.confirmar("Retirar \"%s\" do universo?\nOs fatos sobre ela continuam guardados, e dá para restaurar depois." % e["nome"], func():
					u.remover_entidade(_atual)
					_preencher()
					_editar("")))
			botoes.append(b_ret)
	_status = Tema.rotulo("", 16, Tema.F_ITALICO, Tema.TINTA_SUAVE)
	botoes.append(_status)
	_dir.add_child(linha(botoes))
	if e.is_empty():
		_nome.grab_focus.call_deferred()


func _adicionar_campo(chave: String, valor: String, focar: bool = false) -> void:
	var h := HBoxContainer.new()
	var k := LineEdit.new()
	k.placeholder_text = "campo"
	k.text = chave
	k.custom_minimum_size = Vector2(150, 0)
	k.add_theme_font_override("font", Tema.F_VERSALETE)
	var v := TextEdit.new()
	v.placeholder_text = "escreva…"
	v.text = valor
	v.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.scroll_fit_content_height = true
	v.custom_minimum_size = Vector2(0, 40)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := Tema.botao("×", "Remover este campo")
	x.pressed.connect(func(): h.queue_free())
	h.add_child(k)
	h.add_child(v)
	h.add_child(x)
	_campos_box.add_child(h)
	if focar:
		k.grab_focus.call_deferred()


func _campos_do_formulario() -> Array:
	var lista: Array = []
	for h in _campos_box.get_children():
		if h.is_queued_for_deletion():
			continue
		var k: LineEdit = h.get_child(0)
		var v: TextEdit = h.get_child(1)
		lista.append({"chave": k.text, "valor": v.text})
	return lista


func _sugerir() -> void:
	var existentes := {}
	for c in _campos_do_formulario():
		existentes[TextUtil.chave(c["chave"])] = true
	var n := 0
	for s in Sugestoes.campos_para(_tipo.text):
		if not existentes.has(TextUtil.chave(s)):
			_adicionar_campo(s, "")
			n += 1
	_status.text = "%d campos sugeridos. Apague os que não quiser." % n if n > 0 else "Nenhuma sugestão nova."


func _salvar() -> void:
	if _nome.text.strip_edges() == "":
		_status.text = "Dê um nome antes de salvar."
		_nome.grab_focus()
		return
	var campos := _campos_do_formulario()
	if _atual == "":
		_atual = u.criar_entidade(_nome.text, _tipo.text, Array(_apelidos.text.split(",")), campos)
	else:
		u.editar_entidade(_atual, {"nome": _nome.text, "tipo": _tipo.text,
			"apelidos": Array(_apelidos.text.split(",")), "campos": campos})
	_preencher()
	_editar(_atual)
	_status.text = "Salvo."
