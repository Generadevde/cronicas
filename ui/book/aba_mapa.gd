extends AbaLivro
## Aba "Mapa": o mapa em texto com zoom (cosmos → planeta → região → cidade → casa).
## Página direita: o mapa. Página esquerda: o lugar escolhido (a página da cidade),
## as ferramentas (ver, escrever aqui, pintar, colocar) e "Intervir aqui".

const ATALHOS := [["Seca", "uma seca"], ["Praga", "uma praga nas lavouras"], ["Peste", "uma peste"],
	["Inverno rigoroso", "um inverno rigoroso"], ["Enchente", "uma enchente"], ["Fartura", "um tempo de fartura"],
	["Incêndio", "um incêndio"], ["Feras", "feras famintas"], ["Terremoto", "um terremoto"]]

var _mapa: MapaTexto
var _esq: VBoxContainer
var _dir: VBoxContainer
var _modo := "ver"
var _pincel := "floresta"
var _pintadas := 0
var _colocar := ""


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_esq = esq
	_dir = dir
	var lugar := str(livro.get_meta("mapa_lugar", ""))
	var sel := str(livro.get_meta("mapa_sel", ""))
	if u.entidades.has(dado):
		if Mapa.no_mapa(u, dado):
			lugar = Mapa.pai(u, dado)
			sel = dado
		else:
			sel = dado
	if lugar != "" and (not u.entidades.has(lugar) or u.entidade(lugar)["removida"]):
		lugar = ""
	# Sem lugar escolhido: abre no mundo onde a história está (o único planeta, se houver um só).
	if lugar == "" and not livro.has_meta("mapa_lugar"):
		var planetas: Array = Mapa.filhos(u, "").filter(func(x): return Mapa.especie(u, x) == "planeta")
		if planetas.size() == 1:
			lugar = planetas[0]
	_modo = str(livro.get_meta("mapa_modo", "ver"))
	livro.set_meta("mapa_lugar", lugar)
	livro.set_meta("mapa_sel", sel)

	# Página direita: título, o mapa e as camadas.
	var titulo := Tema.titulo(u.entidade(lugar)["nome"] if lugar != "" else "O Cosmos", 30)
	dir.add_child(titulo)
	var trilha := Tema.texto_rico()
	trilha.fit_content = true
	trilha.scroll_active = false
	trilha.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	trilha.meta_clicked.connect(func(m): _ir(str(m).trim_prefix("lugar:"), ""))
	trilha.text = "[center]" + _trilha(lugar) + "[/center]"
	dir.add_child(trilha)
	_mapa = MapaTexto.new()
	_mapa.selecionado = sel
	var acid_sel := str(livro.get_meta("mapa_acidente", ""))
	_mapa.acidente_sel = acid_sel
	_mapa.mostrar(u, lugar)
	_mapa.celula_clicada.connect(_clicou)
	_mapa.celula_arrastada.connect(_arrastou)
	_mapa.soltou.connect(_soltou)
	dir.add_child(_mapa)
	var camadas := HBoxContainer.new()
	for c in [["Lugares", "mostrar_nomes"], ["Natureza", "mostrar_natureza"], ["Acontecimentos", "mostrar_eventos"]]:
		var cb := CheckBox.new()
		cb.text = c[0]
		cb.button_pressed = bool(livro.get_meta("mapa_" + c[1], true))
		_mapa.set(c[1], cb.button_pressed)
		cb.toggled.connect(func(v: bool):
			livro.set_meta("mapa_" + c[1], v)
			_mapa.set(c[1], v)
			_mapa.queue_redraw())
		camadas.add_child(cb)
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camadas.add_child(espaco)
	if lugar != "":
		var subir := Tema.botao("↑ Subir", "Ver o lugar de cima")
		subir.pressed.connect(func(): _ir(Mapa.pai(u, lugar), lugar))
		camadas.add_child(subir)
	else:
		var gerar := Tema.botao("Gerar planeta", "Cria um planeta com clima, luas, regiões e terreno")
		gerar.pressed.connect(func():
			var p := Povoador.gerar_planeta(u)
			livro.avisar("Nasceu o planeta %s." % u.entidade(p)["nome"])
			_ir("", p))
		camadas.add_child(gerar)
	dir.add_child(camadas)

	# Página esquerda: ferramentas e o lugar escolhido.
	var conteudo := VBoxContainer.new()
	esq.add_child(rolagem(conteudo))
	conteudo.add_child(Tema.secao("Ferramentas"))
	var modos := HBoxContainer.new()
	for m in [["ver", "Ver", "Clique para escolher; duas vezes para entrar"],
			["escrever", "Escrever aqui", "Clique num ponto e escreva o que existe ali"],
			["pintar", "Pintar", "Pinte o terreno com o pincel"],
			["colocar", "Colocar", "Ponha no mapa algo que ainda não está nele (ou mova o escolhido)"]]:
		var b := Tema.botao(m[1], m[2])
		b.toggle_mode = true
		b.button_pressed = _modo == m[0]
		b.pressed.connect(func():
			livro.set_meta("mapa_modo", m[0])
			livro.ir_para_aba("mapa"))
		modos.add_child(b)
	conteudo.add_child(modos)
	match _modo:
		"escrever":
			conteudo.add_child(_dica("Clique num ponto e escreva o que existe ali: \"uma casa na montanha\", \"uma torre em ruínas perto do rio chamada Vigia Negra\", \"uma vila de pescadores na costa\". Para dar nome à natureza, clique nela e escreva: \"montanha do sul\", \"rio da pedra azul\", \"floresta das corujas\"."))
		"pintar":
			var op := OptionButton.new()
			var ids: Array = Mapa.TERRENOS.keys().filter(func(k): return k != "vazio")
			for i in ids.size():
				op.add_item(Mapa.TERRENOS[ids[i]]["nome"])
				if ids[i] == str(livro.get_meta("mapa_pincel", "floresta")):
					op.select(i)
			_pincel = ids[op.selected]
			op.item_selected.connect(func(i: int):
				_pincel = ids[i]
				livro.set_meta("mapa_pincel", _pincel))
			conteudo.add_child(linha([Tema.rotulo("Pincel:", 17, Tema.F_FELL), op]))
			conteudo.add_child(_dica("Clique e arraste sobre o mapa."))
		"colocar":
			var op2 := OptionButton.new()
			var opcoes: Array = []
			if sel != "" and u.entidades.has(sel):
				opcoes.append([sel, "↦ mover %s" % u.entidade(sel)["nome"]])
			for e in u.entidades_ativas():
				if not Mapa.no_mapa(u, e["id"]) and Mapa.especie(u, e["id"]) != "" and e["id"] != lugar:
					opcoes.append([e["id"], e["nome"] + " · " + e["tipo"]])
			for o in opcoes:
				op2.add_item(o[1])
			if opcoes.is_empty():
				conteudo.add_child(_dica("Todos os lugares já estão no mapa. Escolha um lugar no mapa para movê-lo, ou crie em Criadores."))
			else:
				_colocar = opcoes[0][0]
				op2.item_selected.connect(func(i: int): _colocar = opcoes[i][0])
				conteudo.add_child(op2)
				conteudo.add_child(_dica("Clique no ponto do mapa onde fica."))

	conteudo.add_child(Tema.ornamento())
	if acid_sel != "" and sel == "":
		var ac: Dictionary = {}
		for a in Mapa.acidentes(u, lugar):
			if a["chave"] == acid_sel:
				ac = a
		if not ac.is_empty():
			_painel_acidente(conteudo, ac, lugar)
			return
	var foco := sel if sel != "" and u.entidades.has(sel) else lugar
	if foco == "":
		conteudo.add_child(Tema.rotulo("O Cosmos", 26, Tema.F_FELL))
		conteudo.add_child(_dica("Aqui ficam os mundos. Gere um planeta, ou crie um lugar em Criadores e use \"Colocar\". Um planeta gerado vem com regiões; em cada lugar, \"Povoar\" cria povoados, famílias, uma facção e figuras históricas."))
		return
	conteudo.add_child(Tema.rotulo(u.entidade(foco)["nome"], 26, Tema.F_FELL))
	conteudo.add_child(Tema.rotulo(u.entidade(foco)["tipo"], 16, Tema.italico(), Tema.TINTA_SUAVE))
	var info := Tema.texto_rico()
	info.fit_content = true
	info.scroll_active = false
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info.meta_clicked.connect(livro.navegar)
	info.text = Paginas.lugar(u, foco)
	conteudo.add_child(info)
	var acoes := HFlowContainer.new()
	if foco != lugar:
		var entrar := Tema.botao("Entrar", "Ver o mapa de dentro deste lugar")
		entrar.pressed.connect(func(): _ir(foco, ""))
		acoes.add_child(entrar)
	var wiki := Tema.botao("Abrir na wiki")
	wiki.pressed.connect(func(): livro.ir_para_aba("wiki", foco))
	acoes.add_child(wiki)
	var povoar := Tema.botao("Povoar", "Cria povoados, famílias, uma facção e figuras históricas coerentes com o lugar")
	povoar.pressed.connect(func():
		livro.confirmar("Povoar %s?\nVocê pode revisar e desfazer depois (o que for criado fica guardado)." % u.entidade(foco)["nome"], func():
			var r := Povoador.povoar(u, foco)
			livro.set_meta("ultimo_povoamento", r["fato"])
			livro.avisar("%d coisas criadas em %s." % [r["criados"].size(), u.entidade(foco)["nome"]])
			livro.ir_para_aba("mapa")))
	acoes.add_child(povoar)
	var ultimo := str(livro.get_meta("ultimo_povoamento", ""))
	if ultimo != "" and u.fatos.obter(ultimo).get("canon", false):
		var desfazer := Tema.botao("Desfazer povoamento", "Retira o que o último \"Povoar\" criou (fica guardado)")
		desfazer.pressed.connect(func():
			var n := Povoador.desfazer(u, ultimo)
			livro.set_meta("ultimo_povoamento", "")
			livro.avisar("%d coisas retiradas." % n)
			livro.ir_para_aba("mapa"))
		acoes.add_child(desfazer)
	if Mapa.no_mapa(u, foco) and foco != lugar:
		var tirar := Tema.botao("Tirar do mapa")
		tirar.pressed.connect(func():
			Mapa.tirar(u, foco)
			livro.set_meta("mapa_sel", "")
			livro.ir_para_aba("mapa"))
		acoes.add_child(tirar)
	conteudo.add_child(acoes)

	conteudo.add_child(Tema.secao("Intervir aqui"))
	var texto := campo("O que acontece em %s? (ex.: uma seca terrível por um ano)" % u.entidade(foco)["nome"])
	var atalhos := HFlowContainer.new()
	for a in ATALHOS:
		var b := Tema.botao(a[0])
		b.add_theme_font_size_override("font_size", Tema.px(16))
		b.pressed.connect(func(): texto.text = a[1])
		atalhos.add_child(b)
	var agir := Tema.botao_principal("Acontecer")
	var fazer := func():
		var r := Natureza.intervir(u, foco, texto.text)
		if r["fato"] == "":
			return
		if r["entendidos"].is_empty():
			livro.avisar("Registrado como fato. O mundo ainda não sabe o efeito disso (as regras escritas chegam na Parte 5).")
		else:
			livro.avisar("Aconteceu: %s. Avance o tempo para ver o mundo reagir." % ", ".join(r["entendidos"].map(func(t): return Natureza.EVENTOS[t]["nome"])))
		livro.ir_para_aba("mapa")
	agir.pressed.connect(fazer)
	texto.text_submitted.connect(func(_t): fazer.call())
	conteudo.add_child(texto)
	conteudo.add_child(atalhos)
	conteudo.add_child(agir)


## Página de um acidente da natureza (serra, mar, rio…): nome, tamanho, o que há perto.
func _painel_acidente(conteudo: VBoxContainer, a: Dictionary, lugar: String) -> void:
	conteudo.add_child(Tema.rotulo(a["nome"], 26, Tema.F_FELL))
	var nome_tipo: String = "rio" if a["grupo"] == "rio" else {"oceano": "mar", "lago": "lago"}.get(a["tipo"], Mapa.TERRENOS.get(a["grupo"], {}).get("nome", a["grupo"]))
	conteudo.add_child(Tema.rotulo(nome_tipo, 16, Tema.italico(), Tema.TINTA_SUAVE))
	var km := Mapa.km_por_celula(u, lugar)
	var info := ""
	if km > 0:
		var n: int = a["celulas"].size()
		info += ("[b]Extensão:[/b] uns %s km\n" % Paginas._numero(n * km)) if a["grupo"] == "rio" else ("[b]Tamanho:[/b] uns %s km²\n" % Paginas._numero(n * km * km))
	var perto: Array = []
	for f in Mapa.filhos(u, lugar):
		if Mapa.entidades_de_acidente(u, lugar).has(f):
			continue
		var p := Mapa.posicao(u, f)
		for k in a["celulas"]:
			if Vector2(Vector2i(int(p["x"]), int(p["y"])) - k).length() <= 2.0:
				perto.append(f)
				break
	if not perto.is_empty():
		info += "[b]Perto:[/b] %s\n" % ", ".join(perto.map(func(f): return Paginas.link("ent:" + f, u.entidade(f)["nome"])))
	if a["eid"] != "" and u.entidades.has(a["eid"]):
		info += "[b]Página:[/b] %s\n" % Paginas.link("ent:" + a["eid"], a["nome"])
	var rt := Tema.texto_rico()
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rt.meta_clicked.connect(livro.navegar)
	rt.text = info
	conteudo.add_child(rt)
	var acoes := HFlowContainer.new()
	var renomear := Tema.botao("Renomear")
	renomear.pressed.connect(func():
		livro.pedir_texto("Novo nome", "ex.: Montanhas do Sul", a["nome"], func(t: String):
			Mapa.nomear_acidente(u, lugar, a, t, a["eid"])
			if a["eid"] != "" and u.entidades.has(a["eid"]):
				u.editar_entidade(a["eid"], {"nome": t})
			livro.ir_para_aba("mapa")))
	acoes.add_child(renomear)
	if a["eid"] == "" or not u.entidades.has(a["eid"]):
		var pagina := Tema.botao("Criar página na wiki", "Vira um lugar do universo: dá para escrever sobre ele, morar perto, lutar ali")
		pagina.pressed.connect(func():
			var termo: String = "rio" if a["grupo"] == "rio" else {"oceano": "mar", "lago": "lago", "montanha": "serra", "colina": "colinas", "planicie": "planície"}.get(a["tipo"], a["grupo"])
			var eid := u.criar_entidade(a["nome"], termo)
			var k: Vector2i = a["celulas"][a["celulas"].size() / 2] if a["grupo"] == "rio" else a["celulas"][0]
			Mapa.colocar(u, eid, lugar, k.x, k.y, false)
			Mapa.nomear_acidente(u, lugar, a, a["nome"], eid)
			livro.ir_para_aba("mapa"))
		acoes.add_child(pagina)
	else:
		var wiki := Tema.botao("Abrir na wiki")
		wiki.pressed.connect(func(): livro.ir_para_aba("wiki", a["eid"]))
		acoes.add_child(wiki)
	conteudo.add_child(acoes)


func _dica(t: String) -> Label:
	var l := Tema.rotulo(t, 15, Tema.italico(), Tema.TINTA_SUAVE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _trilha(lugar: String) -> String:
	var partes: Array = [Paginas.link("lugar:", "Cosmos")]
	var cadeia := Mapa.ancestrais(u, lugar)
	for i in range(cadeia.size() - 1, -1, -1):
		partes.append(Paginas.link("lugar:" + cadeia[i], u.entidade(cadeia[i])["nome"]))
	if lugar != "":
		partes.append("[b]%s[/b]" % Paginas._e(u.entidade(lugar)["nome"]))
	return " › ".join(partes)


func _ir(lugar: String, sel: String) -> void:
	livro.set_meta("mapa_lugar", lugar)
	livro.set_meta("mapa_sel", sel)
	livro.ir_para_aba("mapa")


func _clicou(x: int, y: int, eid: String) -> void:
	var lugar: String = _mapa.lugar
	match _modo:
		"pintar":
			_pintadas = 0
			_arrastou(x, y)
			return
		"colocar":
			if _colocar != "" and eid == "":
				Mapa.colocar(u, _colocar, lugar, x, y)
				_ir(lugar, _colocar)
			return
		"escrever":
			if eid == "" or Mapa.entidades_de_acidente(u, lugar).has(eid):
				livro.pedir_texto("O que existe aqui?", "ex.: uma casa na montanha", "", func(t: String):
					if t.strip_edges() == "":
						return
					var r := Povoador.criar_por_texto(u, t, lugar, x, y)
					_ir(lugar, r["eid"])
					_propor_completar(r))
				return
	# Ver: escolher; clicar de novo no mesmo (logo em seguida) entra.
	if eid == "" or Mapa.entidades_de_acidente(u, lugar).has(eid):
		var a := Mapa.acidente_em(u, lugar, x, y)
		livro.set_meta("mapa_sel", "")
		livro.set_meta("mapa_acidente", a.get("chave", ""))
		livro.ir_para_aba("mapa")
		return
	livro.set_meta("mapa_acidente", "")
	var agora := Time.get_ticks_msec()
	var antes: Dictionary = livro.get_meta("mapa_clique", {"eid": "", "t": 0})
	livro.set_meta("mapa_clique", {"eid": eid, "t": agora})
	if eid != "" and eid == antes["eid"] and agora - int(antes["t"]) < 450:
		_ir(eid, "")
		return
	if eid != str(livro.get_meta("mapa_sel", "")):
		livro.set_meta("mapa_sel", eid)
		livro.ir_para_aba("mapa")


func _propor_completar(r: Dictionary) -> void:
	var sug: Dictionary = r["sugestao"]
	if sug.is_empty():
		return
	var nomes: Array = sug["moradores"].map(func(m): return "%s (%d anos, %s)" % [m["nome"], int(m["idade"]), m["oficio"]])
	livro.confirmar("Completar %s?\n\nQuem mora ali: %s\nDesde o ano %d — %s." % [u.entidade(r["eid"])["nome"], ", ".join(nomes), int(sug["desde"]), sug["por_que"]], func():
		Povoador.completar(u, r["eid"], sug)
		livro.ir_para_aba("mapa"))


func _arrastou(x: int, y: int) -> void:
	if _modo != "pintar":
		return
	if Mapa.pintar(u, _mapa.lugar, x, y, _pincel):
		_pintadas += 1
		_mapa.queue_redraw()


func _soltou() -> void:
	if _modo == "pintar" and _pintadas > 0:
		Mapa.registrar_pintura(u, _mapa.lugar, _pintadas)
		_pintadas = 0
