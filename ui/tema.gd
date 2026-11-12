class_name Tema
extends RefCounted
## Visual de livro antigo: mesa de madeira, luz de vela, papel envelhecido,
## tinta escura e detalhes dourados. Tudo construído em código para ficar
## fácil de ajustar num lugar só.

static var TINTA := Color("#2A1A0E")
static var TINTA_SUAVE := Color("#5A3A1A")
static var PAPEL := Color("#EAD3A2")
static var PAPEL_CLARO := Color("#F3E4C0")
static var PAPEL_BORDA := Color("#B48A52")
static var COURO := Color("#3A1E0C")
static var COURO_ESCURO := Color("#24120A")
static var OURO := Color("#D7A64A")
static var OURO_CLARO := Color("#F2C46A")
static var TEXTO_CLARO := Color("#F0DDB2")
static var TEXTO_CLARO_SUAVE := Color("#C9A46A")
static var VERMELHO := Color("#7A2418")
static var AZUL_LINK := Color("#233B66")

## A tinta do mundo (o que o mundo escreve na página).
static var TINTA_MUNDO := Color("#2C4A7C")

## Temas do programa (Opções). Cada um troca todas as cores de uma vez.
const PALETAS := {
	"antigo": {"nome": "Livro antigo", "TINTA": "#2A1A0E", "TINTA_SUAVE": "#5A3A1A", "PAPEL": "#EAD3A2", "PAPEL_CLARO": "#F3E4C0", "PAPEL_BORDA": "#B48A52",
		"COURO": "#3A1E0C", "COURO_ESCURO": "#24120A", "OURO": "#D7A64A", "OURO_CLARO": "#F2C46A", "TEXTO_CLARO": "#F0DDB2", "TEXTO_CLARO_SUAVE": "#C9A46A",
		"VERMELHO": "#7A2418", "AZUL_LINK": "#233B66", "TINTA_MUNDO": "#2C4A7C"},
	"escuro": {"nome": "Escuro", "TINTA": "#E6DCC6", "TINTA_SUAVE": "#A99C84", "PAPEL": "#26231F", "PAPEL_CLARO": "#322E29", "PAPEL_BORDA": "#4E463A",
		"COURO": "#171513", "COURO_ESCURO": "#0E0D0B", "OURO": "#D7A64A", "OURO_CLARO": "#F2C46A", "TEXTO_CLARO": "#E6DCC6", "TEXTO_CLARO_SUAVE": "#A99C84",
		"VERMELHO": "#E08A76", "AZUL_LINK": "#9DBBF0", "TINTA_MUNDO": "#8FB4F2"},
	"claro": {"nome": "Claro", "TINTA": "#1E1B18", "TINTA_SUAVE": "#5E574E", "PAPEL": "#FAF7F0", "PAPEL_CLARO": "#FFFFFF", "PAPEL_BORDA": "#CFC8B8",
		"COURO": "#E6E1D6", "COURO_ESCURO": "#D6D0C3", "OURO": "#8A5A12", "OURO_CLARO": "#6A4410", "TEXTO_CLARO": "#2A2620", "TEXTO_CLARO_SUAVE": "#6A6256",
		"VERMELHO": "#A22A1C", "AZUL_LINK": "#1F4E9E", "TINTA_MUNDO": "#1F4E9E"},
}


static func aplicar_paleta() -> void:
	var p: Dictionary = PALETAS.get(str(prefs.get("tema", "antigo")), PALETAS["antigo"])
	TINTA = Color(p["TINTA"]); TINTA_SUAVE = Color(p["TINTA_SUAVE"]); PAPEL = Color(p["PAPEL"]); PAPEL_CLARO = Color(p["PAPEL_CLARO"])
	PAPEL_BORDA = Color(p["PAPEL_BORDA"]); COURO = Color(p["COURO"]); COURO_ESCURO = Color(p["COURO_ESCURO"]); OURO = Color(p["OURO"])
	OURO_CLARO = Color(p["OURO_CLARO"]); TEXTO_CLARO = Color(p["TEXTO_CLARO"]); TEXTO_CLARO_SUAVE = Color(p["TEXTO_CLARO_SUAVE"])
	VERMELHO = Color(p["VERMELHO"]); AZUL_LINK = Color(p["AZUL_LINK"]); TINTA_MUNDO = Color(p["TINTA_MUNDO"])


const F_CORPO := preload("res://assets/fonts/EBGaramond.ttf")
const F_FELL := preload("res://assets/fonts/IMFellEnglish.ttf")
const F_FELL_IT := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
const F_VERSALETE := preload("res://assets/fonts/IMFellEnglishSC.ttf")
const F_GOTICA := preload("res://assets/fonts/UnifrakturMaguntia.ttf")

## Fontes que o autor pode escolher (Ajustes de leitura). "ajuste" corrige o
## tamanho aparente de cada uma (a Caveat, por exemplo, é pequena).
const FONTES := {
	"elite": {"nome": "Special Elite — máquina de escrever", "normal": "SpecialElite-Regular.ttf", "italico": "", "ajuste": 0.9},
	"courier": {"nome": "Courier Prime — máquina limpa", "normal": "CourierPrime-Regular.ttf", "italico": "", "ajuste": 0.92},
	"garamond": {"nome": "EB Garamond — livro impresso", "normal": "EBGaramond.ttf", "italico": "EBGaramond-Italic.ttf", "ajuste": 1.0},
	"fell": {"nome": "IM Fell — livro antigo", "normal": "IMFellEnglish.ttf", "italico": "IMFellEnglish-Italic.ttf", "ajuste": 1.0},
	"kalam": {"nome": "Kalam — manuscrita, bem legível", "normal": "Kalam.ttf", "italico": "", "ajuste": 0.92},
	"caveat": {"nome": "Caveat — escrita à mão", "normal": "Caveat.ttf", "italico": "", "ajuste": 1.22},
	"dancing": {"nome": "Dancing Script — cursiva", "normal": "DancingScript.ttf", "italico": "", "ajuste": 1.1},
	"petit": {"nome": "Petit Formal Script — caligrafia de pena", "normal": "PetitFormalScript.ttf", "italico": "", "ajuste": 0.88},
}
const PASTA_FONTES := "res://assets/fonts/"
const CONFIG := "user://config.cfg"
const PREFS_PADRAO := {"texto": "garamond", "escrita": "elite", "tamanho": 1.0, "tema": "antigo", "som": true}

static var _tema: Theme
static var prefs: Dictionary = {}
static var _cache_fontes: Dictionary = {}


# ---------------------------------------------------------------- ajustes de leitura

static func carregar_preferencias() -> void:
	prefs = PREFS_PADRAO.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) == OK:
		for k in PREFS_PADRAO:
			prefs[k] = cfg.get_value("leitura", k, PREFS_PADRAO[k])
		# Quem vem da versão antiga começa com a letra de máquina de escrever.
		if not cfg.has_section_key("leitura", "tema"):
			prefs["escrita"] = PREFS_PADRAO["escrita"]
	if not FONTES.has(prefs["texto"]):
		prefs["texto"] = PREFS_PADRAO["texto"]
	if not FONTES.has(prefs["escrita"]):
		prefs["escrita"] = PREFS_PADRAO["escrita"]
	prefs["tamanho"] = clampf(float(prefs["tamanho"]), 0.75, 1.6)
	if not PALETAS.has(str(prefs["tema"])):
		prefs["tema"] = "antigo"
	aplicar_paleta()


## Guarda as escolhas e refaz o tema (as telas precisam se remontar depois).
static func salvar_preferencias(novas: Dictionary) -> void:
	_garantir_prefs()
	for k in novas:
		prefs[k] = novas[k]
	prefs["tamanho"] = clampf(float(prefs["tamanho"]), 0.75, 1.6)
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)
	for k in PREFS_PADRAO:
		cfg.set_value("leitura", k, prefs[k])
	cfg.save(CONFIG)
	aplicar_paleta()
	_tema = null


static func _garantir_prefs() -> void:
	if prefs.is_empty():
		carregar_preferencias()


static func _fonte(arquivo: String) -> Font:
	if not _cache_fontes.has(arquivo):
		var f: Font = load(PASTA_FONTES + arquivo)
		if f != null and f.fallbacks.is_empty():
			f.fallbacks = simbolos()
		_cache_fontes[arquivo] = f
	return _cache_fontes[arquivo]


## Fontes de símbolos (♣ ▲ ☠ ⚔ ✦ …) usadas quando a fonte principal não tem o desenho.
static func simbolos() -> Array[Font]:
	if not _cache_fontes.has("@simbolos"):
		var lista: Array[Font] = []
		for a in ["NotoSansSymbols2-Regular.ttf", "NotoSansSymbols.ttf", "NotoSansMath-Regular.ttf"]:
			var f: Font = load(PASTA_FONTES + a)
			if f != null:
				lista.append(f)
		_cache_fontes["@simbolos"] = lista
	return _cache_fontes["@simbolos"]


## Fonte do mapa: Garamond com os símbolos de reserva.
static func fonte_mapa() -> Font:
	if not _cache_fontes.has("@mapa"):
		var v := FontVariation.new()
		v.base_font = F_CORPO
		v.fallbacks = simbolos()
		_cache_fontes["@mapa"] = v
	return _cache_fontes["@mapa"]


static func _fonte_de(id: String, italica: bool) -> Font:
	var d: Dictionary = FONTES.get(id, FONTES["garamond"])
	if italica:
		if d["italico"] != "":
			return _fonte(d["italico"])
		var chave: String = "inclinada:" + id
		if not _cache_fontes.has(chave):
			var v := FontVariation.new()
			v.base_font = _fonte(d["normal"])
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.18, 1), Vector2.ZERO)
			_cache_fontes[chave] = v
		return _cache_fontes[chave]
	return _fonte(d["normal"])


## Fonte do texto (wiki, páginas, listas).
static func corpo() -> Font:
	_garantir_prefs()
	return _fonte_de(prefs["texto"], false)


static func italico() -> Font:
	_garantir_prefs()
	return _fonte_de(prefs["texto"], true)


## Fonte da escrita (o capítulo que você escreve e lê).
static func escrita() -> Font:
	_garantir_prefs()
	return _fonte_de(prefs["escrita"], false)


static func caminho_escrita() -> String:
	_garantir_prefs()
	return PASTA_FONTES + FONTES[prefs["escrita"]]["normal"]


## Tamanho em pixels já com a escala escolhida.
static func px(tamanho: float) -> int:
	_garantir_prefs()
	return int(round(tamanho * float(prefs["tamanho"])))


static func px_texto(tamanho: float) -> int:
	_garantir_prefs()
	return px(tamanho * float(FONTES[prefs["texto"]]["ajuste"]))


static func px_escrita(tamanho: float) -> int:
	_garantir_prefs()
	return px(tamanho * float(FONTES[prefs["escrita"]]["ajuste"]))


# ---------------------------------------------------------------- o tema

static func construir() -> Theme:
	if _tema != null:
		return _tema
	_garantir_prefs()
	var t := Theme.new()
	t.default_font = corpo()
	t.default_font_size = px_texto(19)

	var negrito := FontVariation.new()
	negrito.base_font = corpo()
	negrito.variation_embolden = 0.7

	for tipo in ["Label", "CheckBox", "CheckButton", "ItemList", "Tree", "LineEdit", "TextEdit",
			"RichTextLabel", "AcceptDialog", "PopupMenu", "SpinBox"]:
		t.set_color("font_color", tipo, TINTA)
	t.set_color("default_color", "RichTextLabel", TINTA)
	t.set_font("normal_font", "RichTextLabel", corpo())
	t.set_font("italics_font", "RichTextLabel", italico())
	t.set_font("bold_font", "RichTextLabel", negrito)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]:
		t.set_font_size(k, "RichTextLabel", px_texto(19))
	t.set_color("selection_color", "RichTextLabel", Color(OURO, 0.4))
	t.set_constant("line_separation", "RichTextLabel", 2)

	# Botões: só a palavra, com um traço de tinta embaixo. Ao passar o mouse o
	# traço escurece e ganha um leve brilho de vela; marcado, o traço fica grosso.
	t.set_font("font", "Button", F_FELL)
	t.set_font_size("font_size", "Button", px(19))
	t.set_color("font_color", "Button", TINTA)
	t.set_color("font_hover_color", "Button", TINTA_SUAVE)
	t.set_color("font_pressed_color", "Button", VERMELHO)
	t.set_color("font_hover_pressed_color", "Button", VERMELHO)
	t.set_color("font_focus_color", "Button", TINTA)
	t.set_color("font_disabled_color", "Button", Color(TINTA, 0.35))
	t.set_stylebox("normal", "Button", _traco(Color(0, 0, 0, 0), Color(TINTA_SUAVE, 0.35), 1))
	t.set_stylebox("hover", "Button", _traco(Color(OURO_CLARO, 0.16), PAPEL_BORDA.darkened(0.25), 1))
	t.set_stylebox("pressed", "Button", _traco(Color(OURO, 0.14), VERMELHO, 2))
	t.set_stylebox("hover_pressed", "Button", _traco(Color(OURO, 0.2), VERMELHO, 2))
	t.set_stylebox("focus", "Button", _traco(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	t.set_stylebox("disabled", "Button", _traco(Color(0, 0, 0, 0), Color(TINTA_SUAVE, 0.15), 1))
	for tipo in ["OptionButton", "MenuButton"]:
		for estado in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(estado, tipo, t.get_stylebox(estado, "Button"))
		t.set_font("font", tipo, F_FELL)
		t.set_font_size("font_size", tipo, px(18))
		t.set_color("font_color", tipo, TINTA)
		t.set_color("font_hover_color", tipo, TINTA_SUAVE)
		t.set_color("font_pressed_color", tipo, TINTA)
		t.set_color("font_focus_color", tipo, TINTA)

	# Campos: sem caixa, só a linha do caderno; com foco, a linha fica dourada.
	var campo := _traco(Color(PAPEL_CLARO, 0.25), Color(TINTA_SUAVE, 0.45), 1, 4, 4)
	var campo_foco := _traco(Color(PAPEL_CLARO, 0.45), PAPEL_BORDA.darkened(0.2), 2, 4, 4)
	for tipo in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", tipo, campo)
		t.set_stylebox("focus", tipo, campo_foco)
		t.set_stylebox("read_only", tipo, campo)
		t.set_color("caret_color", tipo, TINTA)
		t.set_color("selection_color", tipo, Color(OURO, 0.45))
		t.set_color("font_placeholder_color", tipo, Color(TINTA_SUAVE, 0.6))
		t.set_color("font_readonly_color", tipo, TINTA_SUAVE)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))

	# Listas: direto no papel; o item escolhido ganha uma fita de tinta à esquerda.
	var lista := _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 2, 4)
	var selecionado := _caixa(Color(OURO, 0.22), Color(0, 0, 0, 0), 0, 0, 6, 2)
	selecionado.border_width_left = 3
	selecionado.border_color = VERMELHO
	var sobre := _caixa(Color(OURO_CLARO, 0.14), Color(0, 0, 0, 0), 0, 0, 6, 2)
	for tipo in ["ItemList", "Tree"]:
		t.set_stylebox("panel", tipo, lista)
		t.set_stylebox("focus", tipo, _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))
		t.set_stylebox("selected", tipo, selecionado)
		t.set_stylebox("selected_focus", tipo, selecionado)
		t.set_stylebox("hovered", tipo, sobre)
		t.set_color("font_selected_color", tipo, TINTA)
		t.set_color("font_hovered_color", tipo, TINTA)
		t.set_color("guide_color", tipo, Color(TINTA_SUAVE, 0.12))
		t.set_constant("v_separation", tipo, 6)
	t.set_stylebox("cursor", "Tree", selecionado)
	t.set_stylebox("cursor_unfocused", "Tree", selecionado)
	t.set_color("children_hl_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_color("relationship_line_color", "Tree", Color(TINTA_SUAVE, 0.3))

	# Janelas e menus: pergaminho.
	var pergaminho := _caixa(PAPEL, PAPEL_BORDA, 1, 3, 20, 16)
	pergaminho.shadow_color = Color(0, 0, 0, 0.5)
	pergaminho.shadow_size = 14
	t.set_stylebox("panel", "AcceptDialog", _caixa(PAPEL, Color(0, 0, 0, 0), 0, 0, 20, 14))
	var moldura := _caixa(PAPEL, PAPEL_BORDA, 1, 3, 0, 0)
	moldura.shadow_color = Color(0, 0, 0, 0.5)
	moldura.shadow_size = 14
	moldura.expand_margin_top = 38
	moldura.expand_margin_left = 12
	moldura.expand_margin_right = 12
	moldura.expand_margin_bottom = 12
	t.set_stylebox("embedded_border", "Window", moldura)
	t.set_stylebox("embedded_unfocused_border", "Window", moldura)
	t.set_constant("title_height", "Window", 34)
	t.set_font_size("title_font_size", "Window", px(18))
	t.set_color("close_color", "Window", TINTA_SUAVE)
	t.set_color("title_color", "Window", TINTA)
	t.set_font("title_font", "Window", F_VERSALETE)
	t.set_stylebox("panel", "PopupMenu", pergaminho)
	t.set_stylebox("hover", "PopupMenu", sobre)
	t.set_color("font_hover_color", "PopupMenu", VERMELHO)
	t.set_font("font", "PopupMenu", F_FELL)
	t.set_font_size("font_size", "PopupMenu", px(18))
	t.set_stylebox("panel", "PanelContainer", _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", pergaminho)
	t.set_color("font_color", "TooltipLabel", TINTA)

	# Barras de rolagem: um fio fino de tinta.
	for tipo in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", tipo, _caixa(Color(TINTA_SUAVE, 0.06), Color(0, 0, 0, 0), 0, 3, 3, 3))
		t.set_stylebox("grabber", tipo, _caixa(Color(TINTA_SUAVE, 0.35), Color(0, 0, 0, 0), 0, 3, 3, 3))
		t.set_stylebox("grabber_highlight", tipo, _caixa(Color(TINTA_SUAVE, 0.55), Color(0, 0, 0, 0), 0, 3, 3, 3))
		t.set_stylebox("grabber_pressed", tipo, _caixa(Color(VERMELHO, 0.6), Color(0, 0, 0, 0), 0, 3, 3, 3))

	# Controles deslizantes (o tamanho da letra).
	t.set_stylebox("slider", "HSlider", _caixa(Color(TINTA_SUAVE, 0.35), Color(0, 0, 0, 0), 0, 2, 0, 2))
	t.set_stylebox("grabber_area", "HSlider", _caixa(Color(VERMELHO, 0.7), Color(0, 0, 0, 0), 0, 2, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _caixa(VERMELHO, Color(0, 0, 0, 0), 0, 2, 0, 2))

	var sem_caixa := _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4, 2)
	for estado in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(estado, "CheckBox", sem_caixa)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 14)
	t.set_color("font_color", "CheckBox", TINTA)
	t.set_color("font_hover_color", "CheckBox", TINTA_SUAVE)
	t.set_color("font_pressed_color", "CheckBox", TINTA)
	t.set_color("font_focus_color", "CheckBox", TINTA)
	t.set_color("font_hover_pressed_color", "CheckBox", TINTA)
	t.set_font("font", "CheckBox", F_FELL)
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


## Só um traço embaixo (botões e campos), com um fundo quase invisível.
static func _traco(fundo: Color, linha: Color, largura: int, mx: int = 6, my: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = linha
	s.border_width_bottom = largura
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my + (2 - largura if largura < 2 else 0)
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
	s.border_color = PAPEL_BORDA
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 28
	s.content_margin_bottom = 24
	if lado_lombada == "direita":
		s.border_width_right = 6
		s.border_color = PAPEL_BORDA
		s.corner_radius_top_left = 4
		s.corner_radius_bottom_left = 4
	else:
		s.border_width_left = 6
		s.border_color = PAPEL_BORDA
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
	l.add_theme_font_size_override("font_size", px_texto(tamanho) if (fonte == null or fonte == italico()) else px(tamanho))
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
	var s := _caixa(Color(OURO, 0.9), OURO_CLARO, 1, 3, 18, 6)
	s.shadow_color = Color(OURO_CLARO, 0.35)
	s.shadow_size = 5
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = OURO_CLARO
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_color_override("font_color", Color("#1E1006"))
	b.add_theme_color_override("font_hover_color", Color("#1E1006"))
	return b


## Botão para usar sobre a mesa escura: palavra clara com um fio dourado embaixo.
static func botao_mesa(texto: String, dica: String = "") -> Button:
	var b := botao(texto, dica)
	estilo_mesa(b)
	return b


static func estilo_mesa(b: Control) -> void:
	b.add_theme_stylebox_override("normal", _traco(Color(0, 0, 0, 0), Color(OURO, 0.35), 1, 8, 4))
	b.add_theme_stylebox_override("hover", _traco(Color(OURO, 0.08), OURO_CLARO, 1, 8, 4))
	b.add_theme_stylebox_override("pressed", _traco(Color(OURO, 0.14), OURO_CLARO, 2, 8, 4))
	b.add_theme_stylebox_override("hover_pressed", _traco(Color(OURO, 0.14), OURO_CLARO, 2, 8, 4))
	b.add_theme_stylebox_override("focus", _traco(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8, 4))
	b.add_theme_color_override("font_color", TEXTO_CLARO)
	b.add_theme_color_override("font_hover_color", OURO_CLARO)
	b.add_theme_color_override("font_pressed_color", OURO_CLARO)
	b.add_theme_color_override("font_hover_pressed_color", OURO_CLARO)
	b.add_theme_color_override("font_focus_color", TEXTO_CLARO)
	b.add_theme_font_override("font", F_FELL)
	b.add_theme_font_size_override("font_size", px(19))


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
