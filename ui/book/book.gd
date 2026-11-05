extends Control
## A tela do livro: o universo aberto como um livro grande sobre a mesa.
## Fitas coloridas à direita trocam de aba; cada aba monta as duas páginas.

const ABAS := [
	{"id": "escrever", "nome": "Escrever", "cor": "#8E2A22", "script": preload("res://ui/book/aba_escrever.gd")},
	{"id": "wiki", "nome": "Wiki", "cor": "#5B6B2A", "script": preload("res://ui/book/aba_wiki.gd")},
	{"id": "criadores", "nome": "Criadores", "cor": "#5A3A7A", "script": preload("res://ui/book/aba_criadores.gd")},
	{"id": "pesquisa", "nome": "Pesquisa", "cor": "#8A4E22", "script": preload("res://ui/book/aba_pesquisa.gd")},
	{"id": "notas", "nome": "Notas", "cor": "#2F6B6B", "script": preload("res://ui/book/aba_notas.gd")},
	{"id": "indice", "nome": "Índice", "cor": "#2F4F8A", "script": preload("res://ui/book/aba_indice.gd")},
	{"id": "fatos", "nome": "Fatos", "cor": "#A87A2A", "script": preload("res://ui/book/aba_fatos.gd")},
]

var universo: Universo
var aba_atual := ""
var _aba_obj: AbaLivro
var _esq: VBoxContainer
var _dir: VBoxContainer
var _fitas: Dictionary = {}
var _data_label: Label
var _busca: LineEdit
var _adiados: Dictionary = {}


func _ready() -> void:
	theme = Tema.construir()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	universo = Cronica.universo
	if universo == null:
		Cronica.ir_para.call_deferred("biblioteca")
		return
	_construir()
	ir_para_aba(str(get_meta("aba_inicial", "escrever")))


func _construir() -> void:
	Tema.fundo_mesa(self)
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 18)
	add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	# Cabeçalho sobre a mesa.
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 16)
	var nome := Tema.rotulo(universo.nome, 36, Tema.F_GOTICA, Tema.OURO_CLARO)
	nome.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	nome.add_theme_constant_override("shadow_offset_y", 2)
	topo.add_child(nome)
	_data_label = Tema.rotulo("", 18, Tema.F_FELL_IT, Tema.TEXTO_CLARO_SUAVE)
	_data_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(_data_label)
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(espaco)
	_busca = LineEdit.new()
	_busca.placeholder_text = "Pesquisar no universo…"
	_busca.custom_minimum_size = Vector2(300, 0)
	_busca.add_theme_stylebox_override("normal", Tema._caixa(Color(Tema.OURO, 0.08), Color("#8A6430"), 1, 3, 12, 6))
	_busca.add_theme_stylebox_override("focus", Tema._caixa(Color(Tema.OURO, 0.15), Tema.OURO, 1, 3, 12, 6))
	_busca.add_theme_color_override("font_color", Tema.TEXTO_CLARO)
	_busca.add_theme_color_override("font_placeholder_color", Tema.TEXTO_CLARO_SUAVE)
	_busca.add_theme_color_override("caret_color", Tema.TEXTO_CLARO)
	_busca.text_submitted.connect(func(t: String):
		ir_para_aba("pesquisa", t)
		_busca.text = "")
	topo.add_child(_busca)
	var b_estante := Tema.botao_mesa("Estante")
	b_estante.pressed.connect(func(): Cronica.ir_para("biblioteca"))
	topo.add_child(b_estante)
	var b_menu := Tema.botao_mesa("Menu")
	b_menu.pressed.connect(func(): Cronica.ir_para("menu"))
	topo.add_child(b_menu)
	coluna.add_child(topo)
	_atualizar_data()

	# O livro: capa de couro com duas páginas, fitas à direita.
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 0)
	coluna.add_child(corpo)

	var capa := PanelContainer.new()
	capa.add_theme_stylebox_override("panel", Tema.estilo_capa())
	capa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(capa)
	var paginas := HBoxContainer.new()
	paginas.add_theme_constant_override("separation", 0)
	capa.add_child(paginas)
	_esq = _criar_pagina(paginas, "direita", 0.82)
	_dir = _criar_pagina(paginas, "esquerda", 1.18)

	var fitas := VBoxContainer.new()
	fitas.add_theme_constant_override("separation", 5)
	var topo_fitas := Control.new()
	topo_fitas.custom_minimum_size = Vector2(0, 40)
	fitas.add_child(topo_fitas)
	for a in ABAS:
		var f := Button.new()
		f.text = a["nome"]
		f.focus_mode = Control.FOCUS_NONE
		f.alignment = HORIZONTAL_ALIGNMENT_LEFT
		f.add_theme_font_override("font", Tema.F_FELL)
		f.add_theme_font_size_override("font_size", 17)
		var claro: bool = a["id"] == "fatos"
		var cor_texto := Color("#1E1006") if claro else Color("#F5E6C4")
		for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			f.add_theme_color_override(estado, cor_texto)
		f.pressed.connect(ir_para_aba.bind(a["id"], ""))
		_fitas[a["id"]] = {"botao": f, "cor": Color(a["cor"])}
		fitas.add_child(f)
	corpo.add_child(fitas)
	_estilizar_fitas()


func _criar_pagina(pai: HBoxContainer, lombada: String, peso: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.estilo_pagina(lombada))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = peso
	pai.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _estilizar_fitas() -> void:
	for id in _fitas:
		var f: Button = _fitas[id]["botao"]
		var cor: Color = _fitas[id]["cor"]
		var ativa: bool = id == aba_atual
		for estado in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = cor.lightened(0.12) if estado == "hover" else cor
			s.content_margin_left = 14
			s.content_margin_right = 26 if ativa else 16
			s.content_margin_top = 8
			s.content_margin_bottom = 8
			s.corner_radius_top_right = 3
			s.corner_radius_bottom_right = 3
			if ativa:
				s.shadow_color = Color(0, 0, 0, 0.45)
				s.shadow_size = 4
			f.add_theme_stylebox_override(estado, s)
		f.custom_minimum_size = Vector2(150 if ativa else 132, 0)


func _atualizar_data() -> void:
	_data_label.text = "· " + DataMundo.texto(universo.relogio)


# ---------------------------------------------------------------- navegação

func ir_para_aba(id: String, dado: String = "") -> void:
	var def: Dictionary = {}
	for a in ABAS:
		if a["id"] == id:
			def = a
	if def.is_empty():
		return
	aba_atual = id
	Tema.limpar(_esq)
	Tema.limpar(_dir)
	_aba_obj = def["script"].new(self)
	_aba_obj.montar(_esq, _dir, dado)
	_estilizar_fitas()


## Abre um link: "ent:<id>", "cap:<id>", "fato:<id>", "nota:<id>".
func navegar(meta) -> void:
	var m := str(meta)
	var partes := m.split(":", true, 1)
	if partes.size() < 2:
		return
	match partes[0]:
		"ent":
			ir_para_aba("wiki", partes[1])
		"cap":
			ir_para_aba("escrever", partes[1])
		"fato":
			ir_para_aba("fatos", partes[1])
		"nota":
			ir_para_aba("notas", partes[1])


## Chama uma função uma vez, depois de uma pausa curta (para não refazer a cada tecla).
func adiar(f: Callable, segundos: float = 0.4) -> void:
	var chave := str(f.get_object_id()) + f.get_method()
	if _adiados.has(chave):
		return
	_adiados[chave] = true
	get_tree().create_timer(segundos).timeout.connect(func():
		_adiados.erase(chave)
		if f.is_valid():
			f.call())


# ---------------------------------------------------------------- diálogos

func pedir_texto(titulo: String, dica: String, inicial: String, ao_confirmar: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = titulo
	d.ok_button_text = "Confirmar"
	d.cancel_button_text = "Cancelar"
	var l := LineEdit.new()
	l.placeholder_text = dica
	l.text = inicial
	l.custom_minimum_size = Vector2(380, 0)
	d.add_child(l)
	d.register_text_enter(l)
	d.confirmed.connect(func(): ao_confirmar.call(l.text))
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered()
	l.grab_focus.call_deferred()
	l.select_all.call_deferred()


func confirmar(mensagem: String, ao_confirmar: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Confirmar"
	d.dialog_text = mensagem
	d.ok_button_text = "Sim"
	d.cancel_button_text = "Não"
	d.confirmed.connect(ao_confirmar)
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered()
