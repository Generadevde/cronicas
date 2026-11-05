extends AbaLivro
## Aba "Leis": as Leis do Universo escritas em português (à esquerda) e tudo o que
## ainda não tem efeito no mundo (à direita), para você decidir o que cada coisa faz.

const EXEMPLOS := [
	"Neste mundo, quem usa magia envelhece um ano por feitiço.",
	"Guerreiros de Kresk ficam 10% mais fortes a cada vitória.",
	"Quem bebe da fonte de Varn esquece o último ano.",
	"A cada 100 anos, um eclipse desperta os mortos de Aldra.",
	"chuva de sangue → todos em Varn sentem medo; lavouras caem 30%",
	"Os elfos vivem 700 anos.",
]


func montar(esq: VBoxContainer, dir: VBoxContainer, _dado: String) -> void:
	var e := VBoxContainer.new()
	esq.add_child(rolagem(e))
	var d := VBoxContainer.new()
	dir.add_child(rolagem(d))
	_leis(e)
	_sem_efeito(d)


func _dica(t: String, tam: int = 15) -> Label:
	var l := Tema.rotulo(t, tam, Tema.italico(), Tema.TINTA_SUAVE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _rico(texto: String) -> RichTextLabel:
	var r := Tema.texto_rico()
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.meta_clicked.connect(livro.navegar)
	r.text = texto
	return r


# ---------------------------------------------------------------- leis

func _leis(pai: VBoxContainer) -> void:
	pai.add_child(Tema.titulo("Leis do Universo", 30))
	pai.add_child(_dica("Escreva uma lei em português. O programa separa QUANDO (o gatilho), QUEM (a quem vale), O QUÊ (o efeito) e SE (condições), e o mundo passa a seguir sozinho. Para dizer o efeito de algo seu, use a seta: \"chuva de sangue → todos sentem medo\"."))
	var caixa := TextEdit.new()
	caixa.placeholder_text = "Ex.: Quem usa magia envelhece um ano por feitiço."
	caixa.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	caixa.custom_minimum_size = Vector2(0, 64)
	caixa.add_theme_font_override("font", Tema.escrita())
	caixa.add_theme_font_size_override("font_size", Tema.px_escrita(19))
	pai.add_child(caixa)
	var exemplos := HFlowContainer.new()
	for ex in EXEMPLOS:
		var b := Tema.botao(ex.left(28) + ("…" if ex.length() > 28 else ""), ex)
		b.add_theme_font_size_override("font_size", Tema.px(14))
		b.pressed.connect(func(): caixa.text = ex)
		exemplos.add_child(b)
	pai.add_child(exemplos)
	var criar := Tema.botao_principal("Criar lei")
	criar.pressed.connect(func():
		var t := caixa.text.strip_edges()
		if t == "":
			return
		var r := Regras.criar(u, t)
		if r.is_empty():
			return
		Regras.passo(u, 0, null)
		livro.avisar("Lei criada%s." % (" (entendida em parte: confira)" if r["entendida"] == "parte" else ""))
		livro.ir_para_aba("leis"))
	pai.add_child(criar)

	pai.add_child(Tema.ornamento())
	pai.add_child(Tema.secao("Magia e tecnologia"))
	var l := Cosmos.leis(u)
	var sliders := {}
	var efeitos := {"magia": "Quanto a magia funciona: 0 = magia não existe (poderes mágicos falham); mais alto = feitiços mais fortes.",
		"tecnologia": "Quanto o mundo sabe fazer: lavouras rendem mais e as viagens ficam mais rápidas."}
	for k in [["magia", "Magia"], ["tecnologia", "Tecnologia"]]:
		var rot := Tema.rotulo("%s: %s" % [k[1], Cosmos.palavra_nivel(float(l[k[0]]))], 17, Tema.F_FELL)
		rot.custom_minimum_size = Vector2(190, 0)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(l[k[0]])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(0, 26)
		s.value_changed.connect(func(v: float): rot.text = "%s: %s" % [k[1], Cosmos.palavra_nivel(v)])
		sliders[k[0]] = s
		pai.add_child(linha([rot, s]))
		pai.add_child(_dica(efeitos[k[0]], 14))
	var guardar := Tema.botao("Guardar magia e tecnologia")
	guardar.pressed.connect(func():
		Cosmos.definir_leis(u, {"magia": sliders["magia"].value, "tecnologia": sliders["tecnologia"].value})
		livro.avisar("Guardado."))
	pai.add_child(guardar)

	pai.add_child(Tema.ornamento())
	var leis := Regras.todas(u).filter(func(r): return not r.get("apagada", false))
	pai.add_child(Tema.secao("As leis (%d)" % leis.size()))
	if leis.is_empty():
		pai.add_child(_dica("Nenhuma lei ainda."))
	for r in leis:
		pai.add_child(_ficha_da_lei(r))


func _ficha_da_lei(r: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var t := Tema.rotulo(Regras._frase(r["texto"]), 19, Tema.F_FELL, Tema.TINTA if r["ligada"] else Color(Tema.TINTA, 0.45))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var s := "[color=#5A3A1A][b]Quando:[/b][/color] %s\n" % Paginas._e(Regras.descrever_quando(u, r["quando"]))
	s += "[color=#5A3A1A][b]Quem:[/b][/color] %s\n" % Paginas._e(Regras.descrever_quem(u, r["quem"]))
	for e in r["efeitos"]:
		s += "[color=#5A3A1A][b]O quê:[/b][/color] %s\n" % Paginas._e(Pecas.descrever(u, e))
	s += "[color=#5A3A1A][b]Se:[/b][/color] %s\n" % Paginas._e(Regras.descrever_se(u, r["se"]))
	s += "[i][color=#5A3A1A]%s · disparou %d vez%s[/color][/i]\n" % ["valendo" if r["ligada"] else "suspensa", int(r.get("disparos", 0)), "es" if int(r.get("disparos", 0)) != 1 else ""]
	for a in r["avisos"]:
		s += "[i][color=#7A2418]%s[/color][/i]\n" % Paginas._e(a)
	v.add_child(_rico(s))
	var ligar := Tema.botao("Suspender" if r["ligada"] else "Religar")
	ligar.pressed.connect(func():
		Regras.ligar(u, r["id"], not r["ligada"])
		livro.ir_para_aba("leis"))
	var reescrever := Tema.botao("Reescrever")
	reescrever.pressed.connect(func():
		livro.pedir_texto("Reescrever a lei", "A lei em português", r["texto"], func(novo: String):
			Regras.reescrever(u, r["id"], novo)
			livro.ir_para_aba("leis")))
	var apagar := Tema.botao("Apagar", "A lei deixa de valer (fica guardada); o que ela já fez continua no mundo")
	apagar.pressed.connect(func():
		livro.confirmar("Apagar a lei \"%s\"?\nO que ela já causou continua valendo (dá para desfazer cada fato)." % r["texto"], func():
			Regras.apagar(u, r["id"])
			livro.ir_para_aba("leis")))
	v.add_child(linha([ligar, reescrever, apagar]))
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", Tema._traco(Color(0, 0, 0, 0), Color(Tema.TINTA_SUAVE, 0.25), 1, 0, 2))
	v.add_child(sep)
	return v


# ---------------------------------------------------------------- ainda sem efeito

func _sem_efeito(pai: VBoxContainer) -> void:
	var itens := Pendencias.listar(u)
	pai.add_child(Tema.titulo("Ainda sem efeito", 30))
	if itens.is_empty():
		pai.add_child(_dica("Tudo o que você escreveu tem efeito no mundo (ou você disse que é só descrição).", 17))
	else:
		pai.add_child(_dica("Coisas que você escreveu e o mundo ainda não sabe usar. Defina o efeito escrevendo (vira lei e vale sempre) ou diga que é só descrição.", 15))
	for it in itens:
		pai.add_child(_item(it))
	var plan := Pendencias.campos_planejados(u)
	if not plan.is_empty():
		pai.add_child(Tema.ornamento())
		pai.add_child(Tema.secao("Já têm lugar nas próximas partes"))
		var linhas: Array = []
		for k in plan:
			linhas.append("\"%s\" → Parte %d" % [k, int(plan[k])])
		pai.add_child(_dica(" · ".join(linhas), 15))


func _item(it: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(Tema.rotulo(it["titulo"], 14, Tema.F_VERSALETE, Tema.VERMELHO))
	var t := Tema.rotulo(it["texto"], 18, Tema.F_FELL)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if str(it.get("detalhe", "")) != "":
		v.add_child(_dica(it["detalhe"], 14))
	var botoes: Array = []
	var dicas := {
		"pedido": ["O que aconteceu?", "ex.: o outro esquece tudo; o outro passa a ser leal a Kai"],
		"intervencao": ["O que isso faz?", "ex.: todos em Varn sentem medo; lavouras caem 30%"],
		"lei": ["Reescrever a lei", "A lei em português"],
		"campo": ["O que este campo faz?", "ex.: fica desconfiado; sente medo"],
		"duvida": ["O que essa ação faz?", "ex.: o outro fica ferido; o outro sente raiva"],
	}
	var d: Array = dicas.get(it["tipo"], ["Efeito", ""])
	var definir := Tema.botao("Definir efeito" if it["tipo"] != "lei" else "Reescrever")
	definir.pressed.connect(func():
		livro.pedir_texto(d[0], d[1], it["texto"] if it["tipo"] == "lei" else "", func(efeito: String):
			if efeito.strip_edges() == "":
				return
			Pendencias.definir(u, it, efeito)
			livro.avisar("Definido. Daqui em diante isso tem efeito.")
			livro.atualizar_cabecalho()
			livro.ir_para_aba("leis")))
	botoes.append(definir)
	if it["tipo"] in ["intervencao", "campo", "duvida"]:
		var so := Tema.botao("É só descrição")
		so.pressed.connect(func():
			Pendencias.so_descricao(u, it)
			livro.atualizar_cabecalho()
			livro.ir_para_aba("leis"))
		botoes.append(so)
	if it["tipo"] == "pedido":
		var nao := Tema.botao("Não funcionou")
		nao.pressed.connect(func():
			Pendencias.so_descricao(u, it)
			livro.atualizar_cabecalho()
			livro.ir_para_aba("leis"))
		botoes.append(nao)
	if it["tipo"] == "duvida":
		var abrir := Tema.botao("Abrir o capítulo")
		abrir.pressed.connect(func(): livro.ir_para_aba("escrever", it["capitulo"]))
		botoes.append(abrir)
	var fl := HFlowContainer.new()
	for b in botoes:
		fl.add_child(b)
	v.add_child(fl)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", Tema._traco(Color(0, 0, 0, 0), Color(Tema.TINTA_SUAVE, 0.25), 1, 0, 2))
	v.add_child(sep)
	return v
