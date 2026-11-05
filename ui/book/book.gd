extends Control
## A tela do livro: o universo aberto como um livro grande sobre a mesa.
## Fitas coloridas à direita trocam de aba; cada aba monta as duas páginas.

const ABAS := [
	{"id": "escrever", "nome": "Escrever", "cor": "#8E2A22", "script": preload("res://ui/book/aba_escrever.gd")},
	{"id": "jornal", "nome": "Jornal", "cor": "#2F6B6B", "script": preload("res://ui/book/aba_jornal.gd")},
	{"id": "mundo", "nome": "Mundo", "cor": "#2F4F8A", "script": preload("res://ui/book/aba_mundo.gd")},
	{"id": "mapa", "nome": "Mapa", "cor": "#3F6A3A", "script": preload("res://ui/book/aba_mapa.gd")},
	{"id": "universo", "nome": "Universo", "cor": "#6A2F4F", "script": preload("res://ui/book/aba_universo.gd")},
	{"id": "sociedades", "nome": "Sociedades", "cor": "#2E5E5A", "script": preload("res://ui/book/aba_sociedades.gd")},
	{"id": "guerras", "nome": "Guerras", "cor": "#5E1A3A", "script": preload("res://ui/book/aba_guerras.gd")},
	{"id": "leis", "nome": "Leis", "cor": "#7A5A1A", "script": preload("res://ui/book/aba_leis.gd")},
	{"id": "wiki", "nome": "Wiki", "cor": "#5B6B2A", "script": preload("res://ui/book/aba_wiki.gd")},
	{"id": "criadores", "nome": "Criadores", "cor": "#5A3A7A", "script": preload("res://ui/book/aba_criadores.gd")},
	{"id": "pesquisa", "nome": "Pesquisa", "cor": "#8A4E22", "script": preload("res://ui/book/aba_pesquisa.gd")},
	{"id": "notas", "nome": "Notas", "cor": "#4A4A44", "script": preload("res://ui/book/aba_notas.gd")},
	{"id": "indice", "nome": "Índice", "cor": "#6B4F2A", "script": preload("res://ui/book/aba_indice.gd")},
	{"id": "fatos", "nome": "Fatos", "cor": "#A87A2A", "script": preload("res://ui/book/aba_fatos.gd")},
]

## Abas que se redesenham sozinhas quando o tempo do mundo anda.
const ABAS_VIVAS := ["jornal", "mundo", "mapa", "sociedades", "guerras", "leis", "wiki", "fatos", "indice"]

var universo: Universo
var aba_atual := ""
var _aba_obj: AbaLivro
var _esq: VBoxContainer
var _dir: VBoxContainer
var _fitas: Dictionary = {}
var _data_label: Label
var _busca: LineEdit
var _adiados: Dictionary = {}
var _dado_atual := ""
var _status: Label
var _timer_vivo: Timer
var ritmo_vivo := 0  ## dias do mundo por segundo real (0 = pausado)


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
	_busca.custom_minimum_size = Vector2(220, 0)
	_busca.add_theme_stylebox_override("normal", Tema._traco(Color(Tema.OURO, 0.05), Color(Tema.OURO, 0.35), 1, 6, 5))
	_busca.add_theme_stylebox_override("focus", Tema._traco(Color(Tema.OURO, 0.1), Tema.OURO_CLARO, 1, 6, 5))
	_busca.add_theme_color_override("font_color", Tema.TEXTO_CLARO)
	_busca.add_theme_color_override("font_placeholder_color", Tema.TEXTO_CLARO_SUAVE)
	_busca.add_theme_color_override("caret_color", Tema.TEXTO_CLARO)
	_busca.text_submitted.connect(func(t: String):
		ir_para_aba("pesquisa", t)
		_busca.text = "")
	topo.add_child(_busca)
	_status = Tema.rotulo("", 15, Tema.F_FELL_IT, Tema.TEXTO_CLARO_SUAVE)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(_status)
	var avancar := MenuButton.new()
	avancar.text = "Avançar o tempo ▾"
	avancar.flat = false
	Tema.estilo_mesa(avancar)
	var menu := avancar.get_popup()
	var opcoes := [["1 dia", 1], ["1 semana", 7], ["1 mês", 30], ["1 ano", 360], ["10 anos", 3600], ["Até algo importante", -1]]
	for i in opcoes.size():
		menu.add_item(opcoes[i][0], i)
	menu.id_pressed.connect(func(i: int): avancar_tempo(opcoes[i][1]))
	topo.add_child(avancar)
	var b_leitura := Tema.botao_mesa("Aa", "Ajustes de leitura: fonte e tamanho da letra")
	b_leitura.pressed.connect(abrir_ajustes_de_leitura)
	topo.add_child(b_leitura)
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
	fitas.add_theme_constant_override("separation", 3)
	var topo_fitas := Control.new()
	topo_fitas.custom_minimum_size = Vector2(0, 22)
	fitas.add_child(topo_fitas)
	for a in ABAS:
		var f := Button.new()
		f.text = a["nome"]
		f.focus_mode = Control.FOCUS_NONE
		f.alignment = HORIZONTAL_ALIGNMENT_LEFT
		f.add_theme_font_override("font", Tema.F_FELL)
		f.add_theme_font_size_override("font_size", Tema.px(16))
		var claro: bool = a["id"] == "fatos"
		var cor_texto := Color("#1E1006") if claro else Color("#F5E6C4")
		for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			f.add_theme_color_override(estado, cor_texto)
		f.pressed.connect(ir_para_aba.bind(a["id"], ""))
		_fitas[a["id"]] = {"botao": f, "cor": Color(a["cor"])}
		fitas.add_child(f)
	corpo.add_child(fitas)
	_estilizar_fitas()

	_timer_vivo = Timer.new()
	_timer_vivo.wait_time = 1.0
	_timer_vivo.timeout.connect(_passo_vivo)
	add_child(_timer_vivo)
	ritmo_vivo = int(universo.extra("preferencias", {}).get("ritmo_vivo", 0))
	definir_ritmo(ritmo_vivo)
	atualizar_cabecalho()


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
			s.content_margin_top = 4
			s.content_margin_bottom = 4
			s.corner_radius_top_right = 3
			s.corner_radius_bottom_right = 3
			if ativa:
				s.shadow_color = Color(0, 0, 0, 0.45)
				s.shadow_size = 4
			f.add_theme_stylebox_override(estado, s)
		f.custom_minimum_size = Vector2(150 if ativa else 132, 0)


func _atualizar_data() -> void:
	_data_label.text = "· " + DataMundo.texto(universo.relogio)


## Data, número de notícias novas na fita do Jornal e estado do mundo vivo.
func atualizar_cabecalho() -> void:
	if _data_label == null:
		return
	_atualizar_data()
	var n := Observatorio.noticias(universo, universo.jornal_lido_ate(), 0.3).size()
	if _fitas.has("jornal"):
		_fitas["jornal"]["botao"].text = "Jornal (%d)" % n if n > 0 else "Jornal"
	if _fitas.has("guerras"):
		var ng := Guerras.ativas(universo).size()
		_fitas["guerras"]["botao"].text = "Guerras (%d)" % ng if ng > 0 else "Guerras"
	if _fitas.has("leis"):
		var p := Pendencias.listar(universo).size()
		_fitas["leis"]["botao"].text = "Leis (%d)" % p if p > 0 else "Leis"
		_fitas["leis"]["botao"].tooltip_text = "%d coisa(s) ainda sem efeito no mundo" % p if p > 0 else ""
	if ritmo_vivo > 0:
		_status.text = "mundo vivo"
	elif _status.text == "mundo vivo":
		_status.text = ""


## Avança o tempo do mundo. 'dias' = -1 avança até algo importante (no máximo 50 anos).
func avancar_tempo(dias: int) -> void:
	var antes := DataMundo.ordem(universo.relogio)
	var novos: Array
	if dias < 0:
		novos = Simulador.avancar(universo, 360 * 50, {"parar_em_importante": true, "foco": foco()})
	else:
		novos = Simulador.avancar(universo, dias, {"foco": foco()})
	var passou := DataMundo.ordem(universo.relogio) - antes
	var importantes := novos.filter(func(f): return Simulador.importancia(universo, f) >= 0.35).size()
	avisar("%d dias se passaram · %d acontecimentos importantes" % [passou, importantes])
	_depois_de_simular()


func _depois_de_simular() -> void:
	atualizar_cabecalho()
	if aba_atual in ABAS_VIVAS:
		var dado := _dado_atual
		ir_para_aba(aba_atual, dado)


## Lugares em foco: os citados no capítulo aberto ficam parados enquanto você escreve.
func foco() -> Array:
	if aba_atual != "escrever" or not has_meta("ultimo_capitulo"):
		return []
	var cap := universo.capitulo(str(get_meta("ultimo_capitulo")))
	if cap.is_empty():
		return []
	var lugares: Array = []
	for m in Ligador.new(universo).encontrar(cap["texto"]):
		if Sugestoes.categoria(universo.entidade(m["entidade"]).get("tipo", "")) == "lugar" and not lugares.has(m["entidade"]):
			lugares.append(m["entidade"])
	return lugares


func definir_ritmo(dias_por_segundo: int) -> void:
	ritmo_vivo = dias_por_segundo
	universo.extra("preferencias", {})["ritmo_vivo"] = dias_por_segundo
	if _timer_vivo == null:
		return
	if dias_por_segundo > 0:
		_timer_vivo.start()
	else:
		_timer_vivo.stop()
	atualizar_cabecalho()


func _passo_vivo() -> void:
	if ritmo_vivo <= 0:
		return
	var novos := Simulador.avancar(universo, ritmo_vivo, {"foco": foco()})
	atualizar_cabecalho()
	if aba_atual in ["jornal", "mundo"] and novos.any(func(f): return Simulador.importancia(universo, f) >= 0.35):
		_depois_de_simular()


## Mensagem curta no alto da tela, que some sozinha.
func avisar(texto: String) -> void:
	if _status == null:
		return
	_status.text = texto
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(_status) and _status.text == texto:
			_status.text = "mundo vivo" if ritmo_vivo > 0 else "")


# ---------------------------------------------------------------- navegação

func ir_para_aba(id: String, dado: String = "") -> void:
	_dado_atual = dado
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

## Fonte do texto, fonte da escrita e tamanho da letra. Ao confirmar, o livro se remonta.
func abrir_ajustes_de_leitura() -> void:
	AjustesLeitura.abrir(self, func():
		var aba := aba_atual
		var dado := _dado_atual
		for c in get_children():
			if c is Window:
				continue
			remove_child(c)
			c.queue_free()
		_fitas.clear()
		theme = Tema.construir()
		_construir()
		ir_para_aba(aba, dado))


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
