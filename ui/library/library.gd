extends Control
## A Biblioteca dos Universos: a estante com todos os universos e o lugar
## para começar um novo, descrito com as suas palavras.

var _lista: VBoxContainer
var _nome: LineEdit
var _descricao: TextEdit
var _status: Label


func _ready() -> void:
	theme = Tema.construir()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Tema.fundo_mesa(self)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 22)
	add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	var topo := HBoxContainer.new()
	var titulo := Tema.rotulo("Biblioteca dos Universos", 38, Tema.F_GOTICA, Tema.OURO_CLARO)
	topo.add_child(titulo)
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(espaco)
	var voltar := Tema.botao_mesa("Voltar ao menu")
	voltar.pressed.connect(func(): Cronica.ir_para("menu"))
	topo.add_child(voltar)
	coluna.add_child(topo)

	var capa := PanelContainer.new()
	capa.add_theme_stylebox_override("panel", Tema.estilo_capa())
	capa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(capa)
	var paginas := HBoxContainer.new()
	paginas.add_theme_constant_override("separation", 0)
	capa.add_child(paginas)

	# Página esquerda: a estante.
	var esq := _pagina(paginas, "direita")
	esq.add_child(Tema.titulo("A Estante", 34))
	esq.add_child(Tema.ornamento())
	var rol := ScrollContainer.new()
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 14)
	rol.add_child(_lista)
	esq.add_child(rol)

	# Página direita: novo universo.
	var dir := _pagina(paginas, "esquerda")
	dir.add_child(Tema.titulo("Novo Universo", 34))
	dir.add_child(Tema.ornamento())
	dir.add_child(Tema.secao("Nome do universo"))
	_nome = LineEdit.new()
	_nome.placeholder_text = "Como se chama este universo?"
	_nome.add_theme_font_override("font", Tema.F_FELL)
	_nome.add_theme_font_size_override("font_size", 24)
	dir.add_child(_nome)
	dir.add_child(Tema.secao("Descreva o universo"))
	var dica := Tema.rotulo("Tema, tom, época, inspirações, regras, o que existe e o que não existe. " +
		"Escreva do seu jeito, sem lista nem campo fixo.", 16, Tema.F_ITALICO, Tema.TINTA_SUAVE)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dir.add_child(dica)
	_descricao = TextEdit.new()
	_descricao.placeholder_text = "Ex.: Mundo atual, parecido com o nosso. Há trinta anos começaram a nascer pessoas com poderes…"
	_descricao.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_descricao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dir.add_child(_descricao)
	var linha := HBoxContainer.new()
	var criar := Tema.botao_principal("Criar e abrir")
	criar.pressed.connect(_criar)
	linha.add_child(criar)
	_status = Tema.rotulo("", 16, Tema.F_ITALICO, Tema.VERMELHO)
	linha.add_child(_status)
	dir.add_child(linha)

	_preencher()
	if Cronica.has_meta("criar_universo"):
		Cronica.remove_meta("criar_universo")
		_nome.grab_focus.call_deferred()


func _pagina(pai: HBoxContainer, lombada: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.estilo_pagina(lombada))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _preencher() -> void:
	Tema.limpar(_lista)
	var universos := Cronica.biblioteca.listar()
	if universos.is_empty():
		var vazio := Tema.rotulo("A estante está vazia.\nCrie o seu primeiro universo na página ao lado.", 19, Tema.F_ITALICO, Tema.TINTA_SUAVE)
		vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(vazio)
		return
	for info in universos:
		var cartao := VBoxContainer.new()
		cartao.add_theme_constant_override("separation", 2)
		cartao.add_child(Tema.rotulo(info["nome"], 28, Tema.F_GOTICA))
		if info["descricao"] != "":
			var d := Tema.rotulo(TextUtil.trecho(info["descricao"], 0, 160), 16, Tema.F_ITALICO, Tema.TINTA_SUAVE)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cartao.add_child(d)
		var quando := Tema.rotulo("atualizado em " + str(info["atualizado_em"]).replace("T", " às ").substr(0, 22), 14, Tema.F_FELL_IT, Tema.TINTA_SUAVE)
		var abrir := Tema.botao_principal("Abrir")
		abrir.pressed.connect(func():
			if Cronica.abrir(info["id"]):
				Cronica.ir_para("livro"))
		var apagar := Tema.botao("Apagar", "Manda o universo para a lixeira (dá para recuperar)")
		apagar.pressed.connect(_apagar.bind(info))
		var linha := HBoxContainer.new()
		linha.add_child(abrir)
		linha.add_child(apagar)
		linha.add_child(quando)
		cartao.add_child(linha)
		var sep := HSeparator.new()
		sep.add_theme_color_override("separator", Color(Tema.TINTA_SUAVE, 0.3))
		cartao.add_child(sep)
		_lista.add_child(cartao)


func _apagar(info: Dictionary) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Apagar universo"
	d.dialog_text = "Mandar \"%s\" para a lixeira?\nEle sai da estante, mas os arquivos ficam guardados na pasta lixeira." % info["nome"]
	d.ok_button_text = "Sim"
	d.cancel_button_text = "Não"
	d.confirmed.connect(func():
		if Cronica.universo != null and Cronica.universo.id == info["id"]:
			Cronica.universo = null
		Cronica.biblioteca.apagar(info["id"])
		_preencher())
	add_child(d)
	d.popup_centered()


func _criar() -> void:
	if _nome.text.strip_edges() == "":
		_status.text = "Dê um nome ao universo."
		_nome.grab_focus()
		return
	Cronica.criar_universo(_nome.text, _descricao.text)
	Cronica.ir_para("livro")
