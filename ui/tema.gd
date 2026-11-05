class_name Tema
extends RefCounted
## Visual de livro antigo: mesa de madeira, luz de vela, papel envelhecido,
## tinta escura e detalhes dourados. Tudo construído em código para ficar
## fácil de ajustar num lugar só.

const TINTA := Color("#2A1A0E")
const TINTA_SUAVE := Color("#5A3A1A")
const PAPEL := Color("#EAD3A2")
const PAPEL_CLARO := Color("#F3E4C0")
const PAPEL_BORDA := Color("#B48A52")
const COURO := Color("#3A1E0C")
const COURO_ESCURO := Color("#24120A")
const OURO := Color("#D7A64A")
const OURO_CLARO := Color("#F2C46A")
const TEXTO_CLARO := Color("#F0DDB2")
const TEXTO_CLARO_SUAVE := Color("#C9A46A")
const VERMELHO := Color("#7A2418")
const AZUL_LINK := Color("#233B66")

const F_CORPO := preload("res://assets/fonts/EBGaramond.ttf")
const F_ITALICO := preload("res://assets/fonts/EBGaramond-Italic.ttf")
const F_FELL := preload("res://assets/fonts/IMFellEnglish.ttf")
const F_FELL_IT := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
const F_VERSALETE := preload("res://assets/fonts/IMFellEnglishSC.ttf")
const F_GOTICA := preload("res://assets/fonts/UnifrakturMaguntia.ttf")

static var _tema: Theme


static func construir() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = F_CORPO
	t.default_font_size = 19

	var negrito := FontVariation.new()
	negrito.base_font = F_CORPO
	negrito.variation_embolden = 0.7

	for tipo in ["Label", "CheckBox", "CheckButton", "ItemList", "Tree", "LineEdit", "TextEdit",
			"RichTextLabel", "AcceptDialog", "PopupMenu", "SpinBox"]:
		t.set_color("font_color", tipo, TINTA)
	t.set_color("default_color", "RichTextLabel", TINTA)
	t.set_font("normal_font", "RichTextLabel", F_CORPO)
	t.set_font("italics_font", "RichTextLabel", F_ITALICO)
	t.set_font("bold_font", "RichTextLabel", negrito)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	t.set_font_size("italics_font_size", "RichTextLabel", 19)
	t.set_font_size("bold_font_size", "RichTextLabel", 19)
	t.set_color("selection_color", "RichTextLabel", Color(OURO, 0.4))

	# Botões: moldura de tinta sobre papel, dourado ao passar o mouse.
	t.set_font("font", "Button", F_FELL)
	t.set_font_size("font_size", "Button", 19)
	t.set_color("font_color", "Button", TINTA)
	t.set_color("font_hover_color", "Button", TINTA)
	t.set_color("font_pressed_color", "Button", TINTA)
	t.set_color("font_focus_color", "Button", TINTA)
	t.set_color("font_disabled_color", "Button", Color(TINTA, 0.4))
	t.set_stylebox("normal", "Button", _caixa(Color(PAPEL_CLARO, 0.55), TINTA_SUAVE, 1, 2, 12, 5))
	t.set_stylebox("hover", "Button", _caixa(Color(OURO_CLARO, 0.45), OURO, 2, 2, 12, 5))
	t.set_stylebox("pressed", "Button", _caixa(Color(OURO, 0.6), TINTA, 2, 2, 12, 5))
	t.set_stylebox("focus", "Button", _caixa(Color(0, 0, 0, 0), OURO, 2, 2, 12, 5))
	t.set_stylebox("disabled", "Button", _caixa(Color(PAPEL_CLARO, 0.25), Color(TINTA_SUAVE, 0.4), 1, 2, 12, 5))

	# Campos de texto: papel um pouco mais claro com borda fina.
	var campo := _caixa(Color(PAPEL_CLARO, 0.7), Color(TINTA_SUAVE, 0.6), 1, 2, 10, 6)
	var campo_foco := _caixa(Color(PAPEL_CLARO, 0.9), OURO, 2, 2, 10, 6)
	for tipo in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", tipo, campo)
		t.set_stylebox("focus", tipo, campo_foco)
		t.set_stylebox("read_only", tipo, campo)
		t.set_color("caret_color", tipo, TINTA)
		t.set_color("selection_color", tipo, Color(OURO, 0.45))
		t.set_color("font_placeholder_color", tipo, Color(TINTA_SUAVE, 0.65))
		t.set_color("font_readonly_color", tipo, TINTA_SUAVE)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))

	# Listas e árvores: transparentes sobre o papel.
	var lista := _caixa(Color(PAPEL_CLARO, 0.35), Color(TINTA_SUAVE, 0.35), 1, 2, 6, 6)
	var selecionado := _caixa(Color(OURO, 0.45), Color(0, 0, 0, 0), 0, 2, 4, 2)
	for tipo in ["ItemList", "Tree"]:
		t.set_stylebox("panel", tipo, lista)
		t.set_stylebox("focus", tipo, _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))
		t.set_stylebox("selected", tipo, selecionado)
		t.set_stylebox("selected_focus", tipo, selecionado)
		t.set_stylebox("hovered", tipo, _caixa(Color(OURO_CLARO, 0.2), Color(0, 0, 0, 0), 0, 2, 4, 2))
		t.set_color("font_selected_color", tipo, TINTA)
		t.set_color("font_hovered_color", tipo, TINTA)
		t.set_color("guide_color", tipo, Color(0, 0, 0, 0))
	t.set_stylebox("cursor", "Tree", selecionado)
	t.set_stylebox("cursor_unfocused", "Tree", selecionado)
	t.set_color("children_hl_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_color("relationship_line_color", "Tree", Color(TINTA_SUAVE, 0.3))

	# Janelas e menus: pergaminho.
	var pergaminho := _caixa(PAPEL, PAPEL_BORDA, 2, 4, 18, 14)
	pergaminho.shadow_color = Color(0, 0, 0, 0.5)
	pergaminho.shadow_size = 12
	t.set_stylebox("panel", "AcceptDialog", pergaminho)
	t.set_stylebox("embedded_border", "Window", pergaminho)
	t.set_stylebox("embedded_unfocused_border", "Window", pergaminho)
	t.set_color("title_color", "Window", TINTA)
	t.set_font("title_font", "Window", F_VERSALETE)
	t.set_stylebox("panel", "PopupMenu", pergaminho)
	t.set_stylebox("hover", "PopupMenu", selecionado)
	t.set_color("font_hover_color", "PopupMenu", TINTA)
	t.set_stylebox("panel", "PanelContainer", _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", pergaminho)
	t.set_color("font_color", "TooltipLabel", TINTA)

	var sem_caixa := _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4, 2)
	for estado in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(estado, "CheckBox", sem_caixa)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_color("font_color", "CheckBox", TINTA)
	t.set_color("font_hover_color", "CheckBox", TINTA)
	t.set_color("font_pressed_color", "CheckBox", TINTA)
	t.set_color("font_focus_color", "CheckBox", TINTA)
	t.set_color("font_hover_pressed_color", "CheckBox", TINTA)
	_tema = t
	return t


static func _caixa(fundo: Color, borda: Color, largura: int, raio: int, mx: int, my: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(raio)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


# ---------------------------------------------------------------- peças prontas

## Mesa de madeira escura com a luz da vela vindo do canto.
static func fundo_mesa(pai: Control, vela_x: float = 0.06) -> void:
	var madeira := TextureRect.new()
	madeira.set_anchors_preset(Control.PRESET_FULL_RECT)
	madeira.stretch_mode = TextureRect.STRETCH_SCALE
	madeira.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	madeira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#4A2810"), Color("#2B160A"), Color("#140A04")])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.55)
	tex.fill_to = Vector2(1.1, 1.1)
	madeira.texture = tex
	pai.add_child(madeira)

	var vela := TextureRect.new()
	vela.set_anchors_preset(Control.PRESET_FULL_RECT)
	vela.stretch_mode = TextureRect.STRETCH_SCALE
	vela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gv := Gradient.new()
	gv.colors = PackedColorArray([Color(1.0, 0.69, 0.31, 0.40), Color(1.0, 0.55, 0.2, 0.10), Color(1, 0.5, 0.2, 0.0)])
	gv.offsets = PackedFloat32Array([0.0, 0.25, 0.5])
	var tv := GradientTexture2D.new()
	tv.gradient = gv
	tv.fill = GradientTexture2D.FILL_RADIAL
	tv.fill_from = Vector2(vela_x, 0.08)
	tv.fill_to = Vector2(vela_x + 0.5, 0.6)
	vela.texture = tv
	pai.add_child(vela)


## Papel de uma página, com sombra na direção da lombada.
static func estilo_pagina(lado_lombada: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPEL
	s.border_color = Color("#8A6638")
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 28
	s.content_margin_bottom = 24
	if lado_lombada == "direita":
		s.border_width_right = 6
		s.border_color = Color("#B48A52")
		s.corner_radius_top_left = 4
		s.corner_radius_bottom_left = 4
	else:
		s.border_width_left = 6
		s.border_color = Color("#B48A52")
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_right = 4
	return s


static func estilo_capa() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COURO
	s.border_color = Color("#5C3418")
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 12
	s.content_margin_bottom = 16
	s.shadow_color = Color(0, 0, 0, 0.65)
	s.shadow_size = 24
	s.shadow_offset = Vector2(0, 10)
	return s


static func rotulo(texto: String, tamanho: int = 19, fonte: Font = null, cor: Color = TINTA) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	if fonte != null:
		l.add_theme_font_override("font", fonte)
	l.add_theme_color_override("font_color", cor)
	return l


static func titulo(texto: String, tamanho: int = 40, cor: Color = TINTA) -> Label:
	var l := rotulo(texto, tamanho, F_GOTICA, cor)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func secao(texto: String, cor: Color = TINTA_SUAVE) -> Label:
	return rotulo(texto, 16, F_VERSALETE, cor)


static func botao(texto: String, dica: String = "") -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.focus_mode = Control.FOCUS_ALL
	return b


## Botão dourado com brilho, como o "Continuar" do menu.
static func botao_principal(texto: String) -> Button:
	var b := botao(texto)
	var s := _caixa(OURO, OURO_CLARO, 1, 2, 16, 6)
	s.shadow_color = Color(OURO_CLARO, 0.45)
	s.shadow_size = 6
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = OURO_CLARO
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_color_override("font_color", Color("#1E1006"))
	b.add_theme_color_override("font_hover_color", Color("#1E1006"))
	return b


## Botão para usar sobre a mesa escura.
static func botao_mesa(texto: String) -> Button:
	var b := botao(texto)
	b.add_theme_stylebox_override("normal", _caixa(Color(OURO, 0.08), Color("#8A6430"), 1, 3, 14, 5))
	b.add_theme_stylebox_override("hover", _caixa(Color(OURO, 0.25), OURO, 1, 3, 14, 5))
	b.add_theme_stylebox_override("pressed", _caixa(Color(OURO, 0.4), OURO_CLARO, 1, 3, 14, 5))
	b.add_theme_color_override("font_color", TEXTO_CLARO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", TEXTO_CLARO)
	return b


static func ornamento() -> Label:
	var l := rotulo("—— ◆ ——", 16, F_FELL, TINTA_SUAVE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func texto_rico() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.selection_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.meta_underlined = false
	return r


static func limpar(no: Node) -> void:
	for c in no.get_children():
		no.remove_child(c)
		c.queue_free()
