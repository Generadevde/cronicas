extends Control
## Menu principal sobre a arte do autor. Os botões ficam invisíveis em cima
## dos botões desenhados na arte e acendem um brilho dourado ao passar o mouse.

const ARTE := preload("res://assets/ui/menu_arte.png")
const TAMANHO_ARTE := Vector2(1672, 941)

## Retângulos dos botões desenhados na arte (em pixels da imagem original).
const BOTOES := [
	{"id": "continuar", "nome": "Continuar", "ret": Rect2(910, 238, 410, 70)},
	{"id": "novo", "nome": "Novo Universo", "ret": Rect2(918, 326, 412, 68)},
	{"id": "biblioteca", "nome": "Biblioteca", "ret": Rect2(922, 406, 416, 68)},
	{"id": "configuracoes", "nome": "Configurações", "ret": Rect2(926, 487, 420, 69)},
	{"id": "ajuda", "nome": "Ajuda", "ret": Rect2(930, 567, 424, 69)},
	{"id": "sair", "nome": "Sair", "ret": Rect2(934, 648, 432, 70)},
]

var _arte: TextureRect
var _botoes: Dictionary = {}


func _ready() -> void:
	theme = Tema.construir()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color("#140A04")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_arte = TextureRect.new()
	_arte.texture = ARTE
	_arte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arte)

	var brilho := StyleBoxFlat.new()
	brilho.bg_color = Color(1.0, 0.85, 0.45, 0.0)
	brilho.draw_center = false
	brilho.border_color = Tema.OURO_CLARO
	brilho.set_border_width_all(2)
	brilho.set_corner_radius_all(6)
	brilho.shadow_color = Color(Tema.OURO_CLARO, 0.55)
	brilho.shadow_size = 10
	var vazio := StyleBoxEmpty.new()
	for b in BOTOES:
		var botao := Button.new()
		botao.flat = true
		botao.tooltip_text = b["nome"]
		botao.focus_mode = Control.FOCUS_ALL
		botao.add_theme_stylebox_override("normal", vazio)
		botao.add_theme_stylebox_override("pressed", brilho)
		botao.add_theme_stylebox_override("hover", brilho)
		botao.add_theme_stylebox_override("focus", brilho)
		botao.pressed.connect(_acao.bind(b["id"]))
		add_child(botao)
		_botoes[b["id"]] = {"botao": botao, "ret": b["ret"]}

	var versao := Tema.rotulo("Parte 1 · versão em construção", 14, Tema.F_FELL_IT, Color(Tema.TEXTO_CLARO_SUAVE, 0.8))
	versao.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	versao.position = Vector2(14, -28)
	versao.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(versao)

	resized.connect(_posicionar)
	_posicionar()
	if Cronica.ultimo_universo() == "":
		_botoes["continuar"]["botao"].tooltip_text = "Continuar (nenhum universo ainda: abre a biblioteca)"
	_botoes["continuar"]["botao"].grab_focus.call_deferred()


## Converte os retângulos da arte para a tela, respeitando o redimensionamento.
func _posicionar() -> void:
	var escala: float = min(size.x / TAMANHO_ARTE.x, size.y / TAMANHO_ARTE.y)
	var desenho := TAMANHO_ARTE * escala
	var origem := (size - desenho) / 2.0
	for id in _botoes:
		var r: Rect2 = _botoes[id]["ret"]
		var b: Button = _botoes[id]["botao"]
		b.position = origem + r.position * escala
		b.size = r.size * escala


func _acao(id: String) -> void:
	match id:
		"continuar":
			var ultimo := Cronica.ultimo_universo()
			if ultimo != "" and Cronica.abrir(ultimo):
				Cronica.ir_para("livro")
			else:
				Cronica.ir_para("biblioteca")
		"novo":
			Cronica.set_meta("criar_universo", true)
			Cronica.ir_para("biblioteca")
		"biblioteca":
			Cronica.ir_para("biblioteca")
		"configuracoes":
			AjustesLeitura.abrir(self, func(): theme = Tema.construir())
		"ajuda":
			_aviso("Ajuda", "Bem-vindo, Autor.\n\n" +
				"• Biblioteca: seus universos. Crie um novo descrevendo-o com suas palavras.\n" +
				"• No livro, as fitas à direita trocam de seção:\n" +
				"   Escrever — livros e capítulos; os nomes viram links sozinhos.\n" +
				"   Wiki — a página de cada pessoa, lugar, magia ou o que você criar.\n" +
				"   Criadores — crie qualquer coisa; tipo e campos são livres.\n" +
				"   Pesquisa — encontre qualquer coisa, mesmo com erro de digitação.\n" +
				"   Notas — só você lê.\n" +
				"   Índice — onde cada nome aparece e os capítulos marcados.\n" +
				"   Fatos — o banco de fatos e o auditor (tela de depuração).\n\n" +
				"Tudo é salvo sozinho.")
		"sair":
			Cronica.salvar_agora()
			get_tree().quit()


func _aviso(titulo: String, texto: String) -> void:
	var d := AcceptDialog.new()
	d.title = titulo
	d.dialog_text = texto
	d.ok_button_text = "Fechar"
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_acao("sair")
