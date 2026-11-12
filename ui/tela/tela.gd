extends Control
## A tela única do Crônica: a página no centro (você escreve "por cima"),
## a margem à direita (o que o Livro entendeu, perguntas, avisos) e a estante
## fina à esquerda (Universo, Mapa, Tempo, Leis, Laboratório…), que abre painéis
## por cima da página. As linhas do mundo aparecem em outra tinta.

## Painéis da estante: cada um junta páginas do motor (as abas antigas) ou telas próprias.
const PAINEIS := {
	"universo": {"nome": "Universo", "abas": [["wiki", "Páginas"], ["criadores", "Criar"], ["sociedades", "Povos"], ["guerras", "Guerras"],
		["historias", "Histórias"], ["modo_viver", "Entrar num personagem"], ["viver", "Conversar"], ["indice", "Índice"]]},
	"mapa": {"nome": "Mapa", "abas": [["mapa", "Mapa"], ["mundo", "Lugares"]]},
	"tempo": {"nome": "Linha do tempo", "abas": [["jornal", "Acontecimentos"], ["fatos", "Fatos e causas"]]},
	"leis": {"nome": "Leis do mundo", "abas": [["leis", "Leis"], ["cosmos", "Cosmos"]]},
	"laboratorio": {"nome": "Laboratório", "abas": [["=confronto", "Confronto"], ["laboratorio", "E se… (ramos)"]]},
	"perguntar": {"nome": "Perguntar ao Livro", "abas": [["pesquisa", "Busca"], ["notas", "Notas"]]},
	"estante": {"nome": "Estante", "abas": [["=estante", "Sagas e livros"]]},
	"opcoes": {"nome": "Opções", "abas": [["=opcoes", "Opções"]]},
}
const TRILHO := [["universo", "Universo"], ["mapa", "Mapa"], ["tempo", "Tempo"], ["leis", "Leis"], ["laboratorio", "Laboratório"]]

var universo: Universo
var aba_atual := "escrever"
var ritmo_vivo := 0
var cid := ""                     ## o livro (página) aberto
var painel_atual := ""
var _adiados: Dictionary = {}
var _editor: TextEdit
var _titulo: LineEdit
var _margem: VBoxContainer
var _proposta: VBoxContainer
var _cab_nome: Label
var _cab_data: Label
var _status: Label
var _barra: Control
var _trilho: Control
var _lado_margem: Control
var _folha: PanelContainer
var _painel: PanelContainer
var _painel_esq: VBoxContainer
var _painel_dir: VBoxContainer
var _painel_abas: HBoxContainer
var _painel_titulo: Label
var _rodape: Control
var _leitura: RichTextLabel
var _cena: Button
var _som: SomMaquina
var _tam_antes := 0
var _foco_total := false
var _aba_obj
var _ia_leituras: Array = []      ## o que a IA leu e espera o seu sim: [{frase, linhas}]
var _ia_fila: Array = []
var _ia_thread: Thread


func _ready() -> void:
	universo = Cronica.universo
	if universo == null:
		Cronica.ir_para.call_deferred("menu")
		return
	Tema.carregar_preferencias()
	universo.extras["escrita_por_cima"] = true
	_som = SomMaquina.new()
	add_child(_som)
	_montar()
	_abrir_onde_parou()


# ---------------------------------------------------------------- montagem

func _montar() -> void:
	theme = Tema.construir()
	var fundo := ColorRect.new()
	fundo.color = Tema.COURO_ESCURO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	if str(Tema.prefs.get("tema", "antigo")) == "antigo":
		Tema.fundo_mesa(self)
	var tudo := VBoxContainer.new()
	tudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tudo.add_theme_constant_override("separation", 0)
	add_child(tudo)
	_barra = _montar_barra()
	tudo.add_child(_barra)
	var meio := HBoxContainer.new()
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meio.add_theme_constant_override("separation", 0)
	tudo.add_child(meio)
	_trilho = _montar_trilho()
	meio.add_child(_trilho)
	var centro := MarginContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_stretch_ratio = 2.6
	for lado in ["left", "right", "top", "bottom"]:
		centro.add_theme_constant_override("margin_" + lado, 16)
	meio.add_child(centro)
	_folha = _papel()
	centro.add_child(_folha)
	_montar_folha()
	_painel = _papel()
	_painel.visible = false
	centro.add_child(_painel)
	_montar_painel()
	_lado_margem = _montar_margem_lado()
	meio.add_child(_lado_margem)


func _papel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Tema.PAPEL
	s.border_color = Tema.PAPEL_BORDA
	s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 22
	s.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", s)
	return p


func _botao_mesa(texto: String, dica: String, icone: String = "") -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Tema.F_FELL)
	b.add_theme_font_size_override("font_size", Tema.px(17))
	for k in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(k, Tema.TEXTO_CLARO)
	b.add_theme_color_override("font_hover_color", Tema.OURO_CLARO)
	b.add_theme_color_override("font_pressed_color", Tema.OURO_CLARO)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(Tema.TEXTO_CLARO_SUAVE, 0.55)
	s.set_border_width_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	var h: StyleBoxFlat = s.duplicate()
	h.border_color = Tema.OURO_CLARO
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icone != "":
		b.add_child(Icone.new(icone, Tema.TEXTO_CLARO, 18))
	return b


func _montar_barra() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	m.add_child(h)
	h.add_child(Tema.rotulo("Crônica", 30, Tema.F_GOTICA, Tema.OURO_CLARO))
	_cab_nome = Tema.rotulo("", 18, Tema.F_FELL_IT, Tema.TEXTO_CLARO_SUAVE)
	_cab_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cab_nome.clip_text = true
	h.add_child(_cab_nome)
	_status = Tema.rotulo("", 15, Tema.F_FELL_IT, Tema.OURO_CLARO)
	h.add_child(_status)
	_cab_data = Tema.rotulo("", 16, Tema.F_FELL, Tema.TEXTO_CLARO_SUAVE)
	h.add_child(_cab_data)
	var b_est := _botao_mesa("Estante", "Sagas e livros deste universo")
	b_est.pressed.connect(func(): abrir_painel("estante"))
	h.add_child(b_est)
	var b_foco := _botao_mesa("Foco", "Só a página, sem mais nada (Esc volta)")
	b_foco.pressed.connect(func(): _alternar_foco())
	h.add_child(b_foco)
	var b_op := _botao_mesa("Opções", "Tema, letra, tamanho e som")
	b_op.pressed.connect(func(): abrir_painel("opcoes"))
	h.add_child(b_op)
	var b_menu := _botao_mesa("Menu", "Voltar ao menu (tudo fica salvo)")
	b_menu.pressed.connect(func(): Cronica.ir_para("menu"))
	h.add_child(b_menu)
	return m


func _montar_trilho() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	for par in TRILHO:
		v.add_child(_botao_trilho(par[0], par[1], Tema.TEXTO_CLARO_SUAVE))
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(esp)
	v.add_child(_botao_trilho("perguntar", "Perguntar", Tema.OURO_CLARO))
	return m


func _botao_trilho(id: String, nome: String, cor: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(78, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = str(PAINEIS[id]["nome"])
	b.flat = true
	b.set_meta("painel", id)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icone.new(id, cor, 26)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := Tema.rotulo(nome, 13, Tema.F_VERSALETE, cor)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(func(): abrir_painel(id) if painel_atual != id else fechar_painel())
	return b


func _montar_folha() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_folha.add_child(v)
	_titulo = LineEdit.new()
	_titulo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.placeholder_text = "Título do livro"
	_titulo.flat = true
	_titulo.add_theme_font_override("font", Tema.F_GOTICA)
	_titulo.add_theme_font_size_override("font_size", Tema.px(32))
	_titulo.text_changed.connect(func(t: String):
		if cid != "":
			universo.atualizar_capitulo(cid, {"titulo": t})
			atualizar_cabecalho())
	v.add_child(_titulo)
	_editor = TextEdit.new()
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.placeholder_text = "Escreva por cima, uma coisa por linha. Por exemplo:\n\nNa cidade de Austin viviam 3.700 habitantes até a chegada do imperador.\n\nO que você escreve vira mundo. O mundo responde em outra tinta."
	_editor.add_theme_font_override("font", Tema.escrita())
	_editor.add_theme_font_size_override("font_size", Tema.px_escrita(20))
	_editor.add_theme_constant_override("line_spacing", 9)
	_editor.add_theme_color_override("font_color", Tema.TINTA)
	_editor.add_theme_color_override("font_placeholder_color", Color(Tema.TINTA_SUAVE, 0.75))
	_editor.add_theme_color_override("caret_color", Tema.TINTA)
	for k in ["normal", "focus", "read_only"]:
		_editor.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	_editor.caret_blink = true
	_editor.text_changed.connect(_ao_escrever)
	v.add_child(_editor)
	_leitura = Tema.texto_rico()
	_leitura.visible = false
	_leitura.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_leitura.meta_clicked.connect(navegar)
	v.add_child(_leitura)
	_proposta = VBoxContainer.new()
	_proposta.add_theme_constant_override("separation", 4)
	v.add_child(_proposta)
	v.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_rodape = h
	v.add_child(h)
	var b1 := _botao_papel("Enquanto isso…", "O que aconteceu longe daqui enquanto você escrevia")
	b1.pressed.connect(_enquanto_isso)
	h.add_child(b1)
	_cena = _botao_papel("Descer numa cena", "Dentro da cena o tempo do mundo não anda: você escreve o momento com calma")
	_cena.toggle_mode = true
	_cena.toggled.connect(func(v2: bool):
		universo.extras["escrita_sem_tempo"] = v2
		_cena.text = "Sair da cena" if v2 else "Descer numa cena"
		avisar("Em cena: o tempo não anda." if v2 else "Fora da cena: o tempo volta a andar."))
	h.add_child(_cena)
	var b3 := MenuButton.new()
	b3.text = "Passar o tempo"
	b3.flat = false
	b3.tooltip_text = "O mundo anda sozinho e conta o que houve"
	_estilo_papel(b3)
	var pm := b3.get_popup()
	var passos := [["Um dia", 1], ["Uma semana", 7], ["Um mês", 30], ["Um ano", 360], ["Dez anos", 3600], ["Até algo importante acontecer", -1]]
	for i in passos.size():
		pm.add_item(str(passos[i][0]), i)
	pm.id_pressed.connect(func(i: int): _passar_tempo(int(passos[i][1])))
	h.add_child(b3)
	var b4 := _botao_papel("E se…", "Abre um ramo: uma cópia do universo para testar outra história sem tocar na oficial")
	b4.pressed.connect(func(): abrir_painel("laboratorio", "laboratorio"))
	h.add_child(b4)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(esp)
	var b5 := _botao_papel("Ler", "Ver a página com os nomes como links")
	b5.toggle_mode = true
	b5.toggled.connect(func(lendo: bool):
		b5.text = "Escrever" if lendo else "Ler"
		if lendo and cid != "":
			_leitura.text = Paginas.capitulo(universo, cid)
		_leitura.visible = lendo
		_editor.visible = not lendo)
	h.add_child(b5)


func _estilo_papel(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Tema.F_FELL)
	b.add_theme_font_size_override("font_size", Tema.px(17))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(Tema.TINTA_SUAVE, 0.8)
	s.set_border_width_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	var h: StyleBoxFlat = s.duplicate()
	h.bg_color = Color(Tema.OURO, 0.18)
	var p: StyleBoxFlat = s.duplicate()
	p.bg_color = Color(Tema.OURO, 0.32)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Tema.TINTA)


func _botao_papel(texto: String, dica: String = "") -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	_estilo_papel(b)
	return b


func _botao_cheio(texto: String, cor: Color, dica: String = "") -> Button:
	var b := _botao_papel(texto, dica)
	for k in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = cor if k == "normal" else cor.lightened(0.12)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(k, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Tema.PAPEL_CLARO)
	return b


func _montar_margem_lado() -> Control:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_stretch_ratio = 1.0
	m.custom_minimum_size = Vector2(300, 0)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 12)
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(s)
	_margem = VBoxContainer.new()
	_margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margem.add_theme_constant_override("separation", 10)
	s.add_child(_margem)
	return m


func _montar_painel() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_painel.add_child(v)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 12)
	v.add_child(topo)
	_painel_titulo = Tema.rotulo("", 28, Tema.F_GOTICA, Tema.TINTA)
	topo.add_child(_painel_titulo)
	_painel_abas = HBoxContainer.new()
	_painel_abas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_painel_abas.add_theme_constant_override("separation", 4)
	topo.add_child(_painel_abas)
	var voltar := _botao_cheio("Voltar à página", Tema.TINTA, "Esc também volta")
	voltar.pressed.connect(fechar_painel)
	topo.add_child(voltar)
	v.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	_painel_esq = VBoxContainer.new()
	_painel_esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_painel_esq)
	_painel_dir = VBoxContainer.new()
	_painel_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_painel_dir)


# ---------------------------------------------------------------- o livro aberto

func _abrir_onde_parou() -> void:
	var pref: Dictionary = universo.extra("preferencias", {})
	var ultimo := str(pref.get("ultimo_capitulo", ""))
	if ultimo == "" or not universo.capitulos.has(ultimo):
		ultimo = ""
		for l in universo.livros:
			for c in l["capitulos"]:
				ultimo = str(c)
	if ultimo == "":
		# Universo limpo: uma saga e um livro em branco, para já poder escrever.
		var saga := universo.criar_livro("Saga I") if universo.livros.is_empty() else str(universo.livros[0]["id"])
		ultimo = universo.criar_capitulo(saga, "Livro I")
	abrir_livro(ultimo)


func abrir_livro(p_cid: String) -> void:
	if not universo.capitulos.has(p_cid):
		return
	cid = p_cid
	universo.extra("preferencias", {})["ultimo_capitulo"] = cid
	set_meta("ultimo_capitulo", cid)
	var cap := universo.capitulo(cid)
	Escrita.preparar(universo, cid)
	_titulo.text = str(cap["titulo"])
	_editor.text = str(cap["texto"])
	_tam_antes = _editor.text.length()
	var r := RealceMundo.new()
	r.u = universo
	r.cid = cid
	_editor.syntax_highlighter = r
	_editor.set_caret_line(_editor.get_line_count() - 1)
	_editor.set_caret_column(_editor.get_line(_editor.get_line_count() - 1).length())
	_cena.set_pressed_no_signal(bool(universo.extras.get("escrita_sem_tempo", false)))
	_cena.text = "Sair da cena" if _cena.button_pressed else "Descer numa cena"
	fechar_painel()
	atualizar_cabecalho()
	_mostrar_proposta()
	_montar_margem()
	_editor.grab_focus.call_deferred()


func _ao_escrever() -> void:
	if cid == "":
		return
	var t := _editor.text
	if bool(Tema.prefs.get("som", true)) and t.length() > _tam_antes:
		if t.ends_with("\n") or (_editor.get_caret_column() == 0 and _editor.get_caret_line() > 0):
			_som.fim_de_linha()
		else:
			_som.tecla()
	_tam_antes = t.length()
	universo.atualizar_capitulo(cid, {"texto": t})
	adiar(_ler_frases, 1.0)


## Cada linha terminada molda o mundo; a margem mostra o que o Livro entendeu.
func _ler_frases() -> void:
	if cid == "" or not universo.capitulos.has(cid):
		return
	var novos := Escrita.processar(universo, cid)
	if novos.is_empty():
		return
	var ultimo: Dictionary = novos[novos.size() - 1]
	if str(ultimo.get("sugestao", "")) != "":
		_propor(str(ultimo["sugestao"]), ultimo.get("mundo", []).map(func(m): return m["fato"]))
	# Linhas que o Livro só conseguiu anotar: a IA local (se houver) tenta ler melhor.
	if IALocal.disponivel():
		for c in novos:
			var tipos: Array = c.get("itens", []).map(func(i): return str(i["tipo"]))
			if tipos == ["acontecimento"]:
				_ia_fila.append(str(c["frase"]))
		_ia_proxima()
	atualizar_cabecalho()
	_montar_margem()


func _ia_proxima() -> void:
	if _ia_fila.is_empty() or (_ia_thread != null and _ia_thread.is_alive()):
		return
	if _ia_thread != null:
		_ia_thread.wait_to_finish()
	var frase: String = _ia_fila.pop_front()
	var pedido := Interprete.pedido(universo, frase, str(universo.capitulo(cid).get("foco", "")))
	avisar("A IA está lendo a linha…")
	_ia_thread = Thread.new()
	_ia_thread.start(func():
		var saida := IALocal.gerar(pedido, 80)
		_ia_chegou.call_deferred(frase, saida))


func _ia_chegou(frase: String, saida: String) -> void:
	var linhas := Interprete.limpar(universo, saida, frase) if saida != "" else []
	if not linhas.is_empty():
		_ia_leituras.append({"frase": frase, "linhas": linhas})
		avisar("A IA leu uma linha: confira na margem.")
		_montar_margem()
	_ia_proxima()


func _exit_tree() -> void:
	if _ia_thread != null:
		_ia_thread.wait_to_finish()


# ---------------------------------------------------------------- o mundo propõe

func _propor(texto: String, fatos: Array) -> void:
	universo.capitulo(cid)["proposta"] = {"texto": texto, "fatos": fatos}
	universo.marcar_mudanca()
	_mostrar_proposta()


func _mostrar_proposta() -> void:
	Tema.limpar(_proposta)
	var p: Dictionary = universo.capitulo(cid).get("proposta", {})
	if p.is_empty() or str(p.get("texto", "")) == "":
		return
	var caixa := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Tema.TINTA_MUNDO, 0.09)
	s.border_color = Color(Tema.TINTA_MUNDO, 0.7)
	s.set_border_width_all(1)
	s.set_content_margin_all(10)
	caixa.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	caixa.add_child(v)
	var l := Tema.rotulo(str(p["texto"]), 20, Tema.F_FELL_IT, Tema.TINTA_MUNDO)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var porque := Tema.rotulo("", 15, Tema.italico(), Tema.TINTA_SUAVE)
	porque.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	porque.visible = false
	v.add_child(porque)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Tema.rotulo("o mundo propõe", 13, Tema.F_VERSALETE, Tema.TINTA_SUAVE))
	var ac := _botao_cheio("Aceitar", Tema.TINTA_MUNDO.darkened(0.15) if Tema.prefs.get("tema", "") == "escuro" else Tema.TINTA_MUNDO, "Entra na página, na tinta do mundo")
	ac.pressed.connect(func(): _aceitar_proposta(false))
	h.add_child(ac)
	var mu := _botao_papel("Mudar", "Entra na página para você reescrever do seu jeito")
	mu.pressed.connect(func(): _aceitar_proposta(true))
	h.add_child(mu)
	var ri := _botao_papel("Riscar", "Isso não aconteceu: o mundo desfaz o que tinha feito")
	ri.pressed.connect(_riscar_proposta)
	h.add_child(ri)
	var pq := _botao_papel("Por quê?", "De onde veio isso")
	pq.pressed.connect(func():
		porque.text = _porque(p.get("fatos", []))
		porque.visible = not porque.visible)
	h.add_child(pq)
	v.add_child(h)
	_proposta.add_child(caixa)


## O motivo de cada acontecimento: a cadeia de causas, em palavras.
func _porque(fatos: Array) -> String:
	var linhas: Array = []
	for fid in fatos:
		if not universo.fatos.existe(str(fid)):
			continue
		var f: Dictionary = universo.fatos.obter(str(fid))
		var causas: Array = []
		for c in f.get("causas", []):
			if universo.fatos.existe(str(c)):
				causas.append(str(universo.fatos.obter(str(c))["descricao"]))
		linhas.append("%s\n   porque: %s" % [f["descricao"], "; ".join(causas.slice(0, 3)) if not causas.is_empty() else "o mundo seguiu seu curso"])
	return "\n".join(linhas) if not linhas.is_empty() else "O mundo seguiu seu curso."


func _aceitar_proposta(para_mudar: bool) -> void:
	var p: Dictionary = universo.capitulo(cid).get("proposta", {})
	if p.is_empty():
		return
	var texto := str(p["texto"])
	Escrita.usar_sugestao(universo, cid, texto)
	universo.capitulo(cid).erase("proposta")
	_editor.text = str(universo.capitulo(cid)["texto"])
	_tam_antes = _editor.text.length()
	var ultima := _editor.get_line_count() - 1
	if para_mudar:
		var linha := maxi(ultima - 1, 0)
		_editor.select(linha, 0, linha, _editor.get_line(linha).length())
		_editor.set_caret_line(linha)
		avisar("Reescreva do seu jeito: quando a linha mudar, ela passa a ser sua.")
	else:
		_editor.set_caret_line(ultima)
		_editor.set_caret_column(_editor.get_line(ultima).length())
	_editor.grab_focus()
	_mostrar_proposta()


func _riscar_proposta() -> void:
	var p: Dictionary = universo.capitulo(cid).get("proposta", {})
	var n := 0
	for fid in p.get("fatos", []):
		if universo.fatos.existe(str(fid)) and universo.fatos.obter(str(fid))["canon"]:
			n += universo.desfazer_fato(str(fid))
	universo.capitulo(cid).erase("proposta")
	universo.marcar_mudanca()
	avisar("Riscado: o mundo desfez %d coisa(s)." % n if n > 0 else "Riscado.")
	_mostrar_proposta()
	_montar_margem()


func _enquanto_isso() -> void:
	var cap := universo.capitulo(cid)
	var desde := int(cap.get("enquanto_seq", 0))
	var foco_l := str(cap.get("foco", ""))
	var lista: Array = []
	var ultimo := desde
	for f in universo.fatos.todos():
		ultimo = maxi(ultimo, int(f["seq"]))
		if int(f["seq"]) <= desde or not f["canon"] or f["dados"].get("silencioso", false) or f["tipo"] in ["escrita", "reserva", "notícia", "presença", "acontecimento"]:
			continue
		if f["origem"]["tipo"] != BancoDeFatos.ORIGEM_SIMULACAO or (foco_l != "" and str(f["lugar"]) == foco_l):
			continue
		var imp := float(f["dados"].get("importancia", 0.2))
		if imp >= 0.4:
			lista.append({"fato": f["id"], "texto": f["descricao"], "importancia": imp, "data": f["data"], "seq": int(f["seq"])})
	cap["enquanto_seq"] = ultimo
	if lista.is_empty():
		avisar("Longe daqui, nada de importante aconteceu ainda. Passe o tempo ou continue escrevendo.")
		return
	lista.sort_custom(func(a, b): return float(a["importancia"]) > float(b["importancia"]))
	lista = lista.slice(0, 3)
	lista.sort_custom(func(a, b): return int(a["seq"]) < int(b["seq"]))
	var t := "Enquanto isso, " + " ".join(lista.map(func(x): return str(x["texto"])))
	_propor(t, lista.map(func(x): return x["fato"]))


func _passar_tempo(dias: int) -> void:
	var antes := Acompanhar._ultimo_seq(universo)
	var ordem_antes := DataMundo.ordem(universo.relogio)
	if dias < 0:
		Simulador.avancar(universo, 360 * 50, {"parar_em_importante": true, "foco": []})
	else:
		Simulador.avancar(universo, dias, {"foco": []})
	var passou := DataMundo.ordem(universo.relogio) - ordem_antes
	var mundo := Escrita._o_que_o_mundo_fez(universo, antes, str(universo.capitulo(cid).get("foco", "")))
	universo.capitulo(cid)["data"] = DataMundo.copiar(universo.relogio)
	atualizar_cabecalho()
	var t := Escrita.sugestao(universo, mundo, passou)
	if t == "":
		avisar("O tempo passou em silêncio: nada de importante aconteceu.")
	else:
		_propor(t, mundo.map(func(m): return m["fato"]))
	_montar_margem()


# ---------------------------------------------------------------- a margem

func _cartao(cabecalho: String, cor: Color, borda: bool = false) -> VBoxContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Tema.PAPEL.darkened(0.04) if not borda else Tema.PAPEL_CLARO
	s.border_color = cor if borda else Tema.PAPEL_BORDA
	s.set_border_width_all(2 if borda else 1)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(Tema.rotulo(cabecalho, 14, Tema.F_VERSALETE, cor))
	_margem.add_child(p)
	return v


func _texto(pai: Control, t: String, tam: int = 17, cor: Color = Tema.TINTA, fonte: Font = null) -> Label:
	var l := Tema.rotulo(t, tam, fonte if fonte != null else Tema.corpo(), cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if fonte == null or fonte == Tema.italico():
		l.add_theme_constant_override("line_spacing", -Tema.px(11))
	pai.add_child(l)
	return l


func _linha(pai: Control) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	h.add_theme_constant_override("v_separation", 6)
	pai.add_child(h)
	return h


func _montar_margem() -> void:
	if _margem == null:
		return
	Tema.limpar(_margem)
	var cartoes := Escrita.cartoes(universo, cid)
	var ultimo: Dictionary = cartoes[cartoes.size() - 1] if not cartoes.is_empty() else {}
	# 1. O que o Livro entendeu da última linha.
	if ultimo.is_empty():
		var v0 := _cartao("A margem", Tema.TINTA_SUAVE)
		_texto(v0, "Aqui o Livro mostra o que entendeu de cada linha, pergunta quando tem dúvida e avisa quando algo grande se aproxima.", 16, Tema.TINTA_SUAVE, Tema.italico())
	else:
		var v := _cartao("Entendi da última linha" if not ultimo.get("desfeita", false) else "Linha desfeita", Tema.TINTA_SUAVE)
		_texto(v, "“%s”" % str(ultimo["frase"]).strip_edges(), 14, Tema.TINTA_SUAVE, Tema.italico())
		var consulta := ""
		for it in ultimo.get("itens", []):
			match str(it["tipo"]):
				"consulta":
					consulta = str(it["texto"])
				"pergunta":
					pass
				_:
					var eid := str(it.get("id", ""))
					if eid != "" and not universo.entidade(eid).is_empty():
						var b := LinkButton.new()
						b.text = str(it["texto"])
						b.add_theme_font_size_override("font_size", Tema.px_texto(17))
						b.add_theme_color_override("font_color", Tema.AZUL_LINK)
						b.pressed.connect(func(): navegar("ent:" + eid))
						v.add_child(b)
					else:
						_texto(v, str(it["texto"]))
		if ultimo.get("itens", []).is_empty() and not ultimo.get("desfeita", false):
			_texto(v, str(ultimo.get("texto", "Não entendi esta linha como mudança no mundo.")), 16)
		if int(ultimo.get("dias", 0)) > 0:
			_texto(v, "O tempo andou: %s." % DataMundo.texto(universo.relogio), 15, Tema.TINTA_SUAVE, Tema.italico())
		if str(ultimo.get("raiz", "")) != "" and not ultimo.get("desfeita", false):
			var nao := LinkButton.new()
			nao.text = "não foi isso que eu quis dizer"
			nao.add_theme_font_size_override("font_size", Tema.px_texto(15))
			nao.add_theme_color_override("font_color", Tema.VERMELHO)
			nao.pressed.connect(func():
				var n := Escrita.desfazer(universo, cid, str(ultimo["raiz"]))
				avisar("Desfeito: %d coisa(s) saíram do mundo. Reescreva a linha de outro jeito." % n)
				_montar_margem())
			v.add_child(nao)
		if consulta != "":
			var vc := _cartao("O Livro responde", Tema.TINTA_MUNDO)
			_texto(vc, consulta, 16)
	# 1b. O que a IA local leu de uma linha que o Livro só tinha anotado.
	for li in _ia_leituras.slice(0, 2):
		var vi := _cartao("A IA leu assim", Tema.TINTA_MUNDO, true)
		_texto(vi, "“%s”" % str(li["frase"]).strip_edges(), 14, Tema.TINTA_SUAVE, Tema.italico())
		for l in li["linhas"]:
			_texto(vi, "· " + str(l), 16)
		var hi := _linha(vi)
		var sim := _botao_cheio("Vale assim", Tema.TINTA_MUNDO, "Estas frases passam a valer no mundo, presas à sua linha")
		sim.pressed.connect(func():
			_ia_leituras.erase(li)
			var itens := Interprete.aplicar(universo, cid, str(li["frase"]), li["linhas"])
			avisar("Entendido: %d coisa(s) no mundo." % itens.size() if not itens.is_empty() else "O Livro não conseguiu usar essa leitura; a linha continua só anotada.")
			_montar_margem())
		hi.add_child(sim)
		var nao2 := _botao_papel("Não é isso", "A linha continua só anotada como acontecimento")
		nao2.pressed.connect(func():
			_ia_leituras.erase(li)
			_montar_margem())
		hi.add_child(nao2)
	# 2. Perguntas do Livro: quem ainda não tem nome.
	var perguntas := 0
	for e in universo.entidades_ativas():
		if perguntas >= 2 or universo.valor_campo(e["id"], "nome") != "ainda sem nome":
			continue
		perguntas += 1
		_cartao_pergunta(e)
	# 3. Dúvidas: linhas que o Livro não soube ler.
	for p in universo.propostas:
		if p["capitulo"] == cid and p["status"] == "duvida":
			var vd := _cartao("O Livro ficou em dúvida", Tema.VERMELHO)
			_texto(vd, "Não entendi o que acontece em: “%s”" % str(p.get("frase", "")).strip_edges(), 16)
			var hd := _linha(vd)
			var so := _botao_papel("É só descrição", "Esta linha não muda nada no mundo")
			var pid := str(p["id"])
			so.pressed.connect(func():
				universo.riscar_proposta(pid)
				_montar_margem())
			hd.add_child(so)
			break
	# 4. O que está por vir.
	for pv in LeitorMais.pendentes(universo).slice(0, 2):
		_cartao_por_vir(pv)
	# 4b. Avisos antes de momentos grandes com quem você escreveu.
	for av in Pressagios.listar(universo, 2):
		var va := _cartao("Algo grande se aproxima", Tema.VERMELHO, true)
		_texto(va, str(av["texto"]), 17)
		var ha := _linha(va)
		var esc := _botao_cheio("Escrever o momento", Tema.VERMELHO)
		esc.pressed.connect(func(): _editor.grab_focus())
		ha.add_child(esc)
		var seg := _botao_papel("Deixar seguir", "O mundo decide sozinho; este aviso não aparece mais")
		seg.pressed.connect(func():
			Pressagios.dispensar(universo, str(av["chave"]))
			_montar_margem())
		ha.add_child(seg)
		if str(av["outro"]) != "":
			var lab2 := _botao_papel("Testar no Laboratório")
			lab2.pressed.connect(func(): abrir_painel("laboratorio", "=confronto", str(av["outro"])))
			ha.add_child(lab2)
	# 5. Lutas em aberto.
	for f in Lutas.pendentes(universo).slice(0, 1):
		var vl := _cartao("Uma luta ficou em aberto", Tema.VERMELHO, true)
		_texto(vl, str(f["descricao"]), 16)
		_texto(vl, "Escreva quem venceu, ou passe o tempo e o mundo decide (você poderá trocar).", 15, Tema.TINTA_SUAVE, Tema.italico())
	# Rodapé da margem.
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margem.add_child(esp)
	var pessoas := 0
	var lugares := 0
	for e in universo.entidades_ativas():
		if e["tipo"] == "pessoa":
			pessoas += 1
		elif Mapa.e_lugar(universo, e["id"]):
			lugares += 1
	var st := Tema.rotulo("salvo · %d personagens · %d lugares · %d leis" % [pessoas, lugares, Regras.todas(universo).size() + universo.extra("regras_do_livro", []).size()],
		14, Tema.italico(), Tema.TEXTO_CLARO_SUAVE)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_margem.add_child(st)


func _cartao_pergunta(e: Dictionary) -> void:
	var eid := str(e["id"])
	var titulo := universo.valor_campo(eid, "cargo")
	var v := _cartao("O Livro pergunta", Tema.TINTA_SUAVE)
	_texto(v, "Quem é %s? Ainda não tem nome." % str(e["nome"]).to_lower(), 18)
	var h := _linha(v)
	var definir := func(nome: String):
		if nome.strip_edges() == "":
			return
		var cs: Array = universo.entidade(eid)["campos"].filter(func(c): return c["chave"] != "nome")
		universo.editar_entidade(eid, {"nome": nome.strip_edges(), "campos": cs, "apelidos": [titulo] if titulo != "" else []})
		avisar("%s agora se chama %s." % [str(e["nome"]), nome.strip_edges()])
		_montar_margem()
	var eu := _botao_cheio("Eu escrevo", Tema.TINTA)
	eu.pressed.connect(func(): pedir_texto("Como se chama %s?" % str(e["nome"]).to_lower(), "o nome", "", definir))
	h.add_child(eu)
	var inv := _botao_papel("O mundo inventa")
	inv.pressed.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		definir.call(Linguas.gerar(universo, Linguas.do_lugar(universo, str(universo.estado(eid).get("local", ""))), "pessoas", rng)))
	h.add_child(inv)
	var dep := _botao_papel("Depois")
	dep.pressed.connect(func():
		var cs: Array = universo.entidade(eid)["campos"].duplicate(true)
		for c in cs:
			if c["chave"] == "nome":
				c["valor"] = "sem nome por enquanto"
		universo.editar_entidade(eid, {"campos": cs})
		_montar_margem())
	h.add_child(dep)


func _cartao_por_vir(pv: Dictionary) -> void:
	var v := _cartao("Algo grande se aproxima", Tema.VERMELHO, true)
	_texto(v, str(pv["texto"]), 17)
	var h := _linha(v)
	var esc := _botao_cheio("Escrever o momento", Tema.VERMELHO)
	esc.pressed.connect(func(): _editor.grab_focus())
	h.add_child(esc)
	var seguir := _botao_papel("Deixar o mundo trazer", "O mundo faz acontecer e propõe a linha")
	seguir.pressed.connect(func():
		var fid := LeitorMais.cumprir(universo, pv)
		_propor(str(universo.fatos.obter(fid)["descricao"]), [fid])
		_montar_margem())
	h.add_child(seguir)
	var lab := _botao_papel("Testar no Laboratório")
	lab.pressed.connect(func(): abrir_painel("laboratorio", "=confronto", str(pv["quem"])))
	h.add_child(lab)


# ---------------------------------------------------------------- painéis por cima da página

func abrir_painel(id: String, aba: String = "", dado: String = "") -> void:
	if not PAINEIS.has(id):
		return
	painel_atual = id
	var def: Dictionary = PAINEIS[id]
	if aba == "":
		aba = str(def["abas"][0][0])
	_painel_titulo.text = str(def["nome"])
	Tema.limpar(_painel_abas)
	if def["abas"].size() > 1:
		for par in def["abas"]:
			var b := _botao_papel(str(par[1]))
			b.toggle_mode = true
			b.button_pressed = par[0] == aba
			var alvo := str(par[0])
			b.pressed.connect(func(): abrir_painel(id, alvo))
			_painel_abas.add_child(b)
	Tema.limpar(_painel_esq)
	Tema.limpar(_painel_dir)
	_painel_dir.visible = true
	_aba_obj = null
	aba_atual = aba
	if aba.begins_with("="):
		_painel_dir.visible = aba != "=opcoes" and aba != "=estante"
		match aba:
			"=opcoes":
				PainelOpcoes.montar(self, _painel_esq)
			"=estante":
				PainelEstante.montar(self, _painel_esq)
			"=confronto":
				PainelConfronto.montar(self, _painel_esq, _painel_dir, dado)
	else:
		var script: GDScript = load("res://ui/book/aba_%s.gd" % aba)
		_aba_obj = script.new(self)
		_aba_obj.montar(_painel_esq, _painel_dir, dado)
	_folha.visible = false
	_painel.visible = true
	_lado_margem.visible = false


func fechar_painel() -> void:
	painel_atual = ""
	aba_atual = "escrever"
	_aba_obj = null
	if _painel == null:
		return
	_painel.visible = false
	_folha.visible = true
	_lado_margem.visible = not _foco_total
	atualizar_cabecalho()
	_montar_margem()


func _alternar_foco() -> void:
	_foco_total = not _foco_total
	fechar_painel()
	_barra.visible = not _foco_total
	_trilho.visible = not _foco_total
	_lado_margem.visible = not _foco_total
	_rodape.visible = not _foco_total
	if _foco_total:
		_editor.grab_focus()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if painel_atual != "":
			fechar_painel()
		elif _foco_total:
			_alternar_foco()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_F11:
		_alternar_foco()


## Refaz a tela inteira (depois de trocar tema, letra ou tamanho).
func reconstruir(painel: String = "") -> void:
	for c in get_children():
		if c is Window or c == _som:
			continue
		remove_child(c)
		c.queue_free()
	_montar()
	abrir_livro(cid)
	if painel != "":
		abrir_painel(painel)


# ---------------------------------------------------------------- o que as páginas do motor esperam da tela

func atualizar_cabecalho() -> void:
	if _cab_nome == null:
		return
	var cap := universo.capitulo(cid)
	var saga := universo.livro(str(cap.get("livro", ""))) if not cap.is_empty() else {}
	_cab_nome.text = "%s · %s · %s" % [universo.nome, str(saga.get("titulo", "")), str(cap.get("titulo", ""))]
	_cab_data.text = DataMundo.texto(universo.relogio)


func ir_para_aba(id: String, dado: String = "") -> void:
	if id == "escrever":
		if dado != "" and universo.capitulos.has(dado):
			abrir_livro(dado)
		else:
			fechar_painel()
		return
	for pid in PAINEIS:
		for par in PAINEIS[pid]["abas"]:
			if par[0] == id:
				abrir_painel(pid, id, dado)
				return


func navegar(meta) -> void:
	var partes := str(meta).split(":", true, 1)
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


func avisar(texto: String) -> void:
	if _status == null:
		return
	_status.text = texto
	get_tree().create_timer(7.0).timeout.connect(func():
		if is_instance_valid(_status) and _status.text == texto:
			_status.text = "")


func adiar(f: Callable, segundos: float = 0.4) -> void:
	var chave := str(f.get_object_id()) + f.get_method()
	if _adiados.has(chave):
		return
	_adiados[chave] = true
	get_tree().create_timer(segundos).timeout.connect(func():
		_adiados.erase(chave)
		if f.is_valid():
			f.call())


func avancar_tempo(dias: int) -> void:
	_passar_tempo(dias)
	if painel_atual != "":
		abrir_painel(painel_atual, aba_atual)


func definir_ritmo(_dias_por_segundo: int) -> void:
	pass


func foco() -> Array:
	return []


func abrir_ajustes_de_leitura() -> void:
	abrir_painel("opcoes")


func pedir_texto(titulo: String, dica: String, inicial: String, ao_confirmar: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = titulo
	d.ok_button_text = "Confirmar"
	d.cancel_button_text = "Cancelar"
	var l := LineEdit.new()
	l.placeholder_text = dica
	l.text = inicial
	l.custom_minimum_size = Vector2(420, 0)
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
