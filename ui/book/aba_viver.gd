extends AbaLivro
## Aba "Viver": o mundo por dentro. Escolha um personagem e converse com ele (como
## deus, como um desconhecido ou como outro personagem), acompanhe-o de perto ou veja
## o mundo pelos olhos dele.

static var _quem := ""
static var _modo := "conversar"
static var _como := "deus"
static var _como_quem := ""
static var _conversa := ""
static var _diario: Array = []
static var _vel := "dia"

var _dir: VBoxContainer


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	if u.entidades.has(dado) and Estado.tem_mente(u, dado):
		if dado != _quem:
			_conversa = ""
			_diario = []
		_quem = dado
	esq.add_child(Tema.secao("Viver o mundo por dentro"))
	var mentes := Simulador._mentes(u)
	mentes.sort_custom(func(a, b): return u.entidade(a)["nome"] < u.entidade(b)["nome"])
	if _quem == "" or not u.entidades.has(_quem):
		_quem = mentes[0] if not mentes.is_empty() else ""
	var sel := OptionButton.new()
	for i in mentes.size():
		sel.add_item(u.entidade(mentes[i])["nome"])
		sel.set_item_metadata(i, mentes[i])
		if mentes[i] == _quem:
			sel.select(i)
	sel.item_selected.connect(func(i: int):
		_quem = str(sel.get_item_metadata(i))
		_conversa = ""
		_diario = []
		livro.ir_para_aba("viver", _quem))
	esq.add_child(sel)
	var modos := HBoxContainer.new()
	for m in [["conversar", "Conversar"], ["acompanhar", "Acompanhar"], ["ver", "Ponto de vista"]]:
		var b := Tema.botao(m[1])
		b.toggle_mode = true
		b.button_pressed = m[0] == _modo
		b.pressed.connect(func():
			_modo = m[0]
			livro.ir_para_aba("viver", _quem))
		modos.add_child(b)
	esq.add_child(modos)
	if _quem == "":
		esq.add_child(Tema.rotulo("Ninguém com mente própria ainda.", 16, Tema.italico(), Tema.TINTA_SUAVE))
		return
	var ficha := Tema.texto_rico()
	ficha.meta_clicked.connect(livro.navegar)
	ficha.text = Paginas.estado(u, _quem)
	esq.add_child(ficha)
	var ia := Tema.botao("IA local…", "Opcional: um programa de IA no seu computador (ex.: llama.cpp) para dar voz aos personagens. Só é carregado quando usado.")
	ia.pressed.connect(func():
		var cfg := IALocal.config()
		livro.pedir_texto("IA local (opcional)", "caminho do programa | caminho do modelo (.gguf) — vazio desliga", ("%s | %s" % [cfg.get("comando", ""), cfg.get("modelo", "")]) if not cfg.is_empty() else "", func(t: String):
			var partes := t.split("|")
			var cmd := partes[0].strip_edges() if partes.size() > 0 else ""
			var mod := partes[1].strip_edges() if partes.size() > 1 else ""
			IALocal.salvar_config(cmd, mod, cmd != "")
			livro.avisar("IA local %s." % ("ligada" if IALocal.disponivel() else "desligada (respostas montadas a partir do que o personagem sabe)"))
			livro.ir_para_aba("viver", _quem)))
	esq.add_child(ia)
	match _modo:
		"conversar":
			_montar_conversa(esq)
		"acompanhar":
			_montar_acompanhar()
		_:
			var t := Tema.texto_rico()
			t.meta_clicked.connect(livro.navegar)
			t.text = Acompanhar.ponto_de_vista(u, _quem)
			_dir.add_child(t)


# ---------------------------------------------------------------- conversar

func _montar_conversa(esq: VBoxContainer) -> void:
	var como := OptionButton.new()
	var opcoes: Array = [["deus", "Falar como deus", ""], ["desconhecido", "Falar como um desconhecido", ""]]
	for outro in u.estado(_quem)["relacoes"]:
		if u.entidades.has(outro) and Estado.tem_mente(u, outro):
			opcoes.append(["personagem", "Falar como " + u.entidade(outro)["nome"], outro])
	for i in opcoes.size():
		como.add_item(opcoes[i][1])
		if opcoes[i][0] == _como and opcoes[i][2] == _como_quem:
			como.select(i)
	como.item_selected.connect(func(i: int):
		_como = opcoes[i][0]
		_como_quem = opcoes[i][2]
		_conversa = ""
		livro.ir_para_aba("viver", _quem))
	esq.add_child(como)
	if _conversa == "" or Conversa.dados(u, _conversa).is_empty():
		_conversa = Conversa.nova(u, _quem, _como, _como_quem)
	var c := Conversa.dados(u, _conversa)
	var falas := Tema.texto_rico()
	falas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var linhas: Array = []
	for f in c["falas"]:
		if f["de"] == "voce":
			linhas.append("[i][color=#5A3A1A]— %s[/color][/i]" % Paginas._e(f["texto"]))
		else:
			linhas.append("[b]%s:[/b] %s" % [Paginas._e(u.entidade(_quem)["nome"]), Paginas._e(f["texto"])])
	falas.text = Paginas.cabecalho("Conversa com %s" % u.entidade(_quem)["nome"], "IA local ligada" if IALocal.disponivel() else "respostas montadas a partir do que ele sabe") + ("\n\n".join(linhas) if not linhas.is_empty() else "[i]Pergunte alguma coisa: por que ele odeia alguém, o que quer, o que sabe, peça uma promessa…[/i]")
	_dir.add_child(falas)
	falas.scroll_to_line(falas.get_line_count())
	var campo_p := campo("Pergunte (ex.: por que você odeia o Kai?)")
	campo_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var enviar := Tema.botao_principal("Perguntar")
	var faz := func():
		if campo_p.text.strip_edges() == "":
			return
		Conversa.perguntar(u, _conversa, campo_p.text)
		livro.ir_para_aba("viver", _quem)
	enviar.pressed.connect(faz)
	campo_p.text_submitted.connect(func(_t): faz.call())
	_dir.add_child(linha([campo_p, enviar]))
	for pid in Conversa.propostas(u, _conversa).map(func(p): return p["id"]):
		var p := u.proposta(pid)
		var l := Tema.rotulo("Pode virar fato: " + p["descricao"], 15, Tema.italico(), Tema.VERMELHO)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ok := Tema.botao("Aceitar")
		ok.pressed.connect(func():
			u.aceitar_proposta(pid)
			livro.ir_para_aba("viver", _quem))
		var no := Tema.botao("Riscar")
		no.pressed.connect(func():
			u.riscar_proposta(pid)
			livro.ir_para_aba("viver", _quem))
		_dir.add_child(linha([l, ok, no]))
	var cena := Tema.botao("Salvar como cena", "Vira um capítulo em rascunho no livro \"Cenas\"")
	cena.pressed.connect(func():
		var cap := Conversa.virar_cena(u, _conversa)
		livro.avisar("Cena salva como rascunho.")
		livro.ir_para_aba("escrever", cap))
	var outra := Tema.botao("Nova conversa")
	outra.pressed.connect(func():
		_conversa = ""
		livro.ir_para_aba("viver", _quem))
	_dir.add_child(linha([cena, outra]))


# ---------------------------------------------------------------- acompanhar

func _montar_acompanhar() -> void:
	var vel := OptionButton.new()
	var vs := ["cena", "dia", "importante"]
	for i in vs.size():
		vel.add_item(Acompanhar.MODOS[vs[i]])
		if vs[i] == _vel:
			vel.select(i)
	vel.item_selected.connect(func(i: int): _vel = vs[i])
	var botoes: Array = [vel]
	for par in [["Um dia", 1], ["Uma semana", 7], ["Um mês", 30]]:
		var b := Tema.botao(par[0])
		b.pressed.connect(func():
			_diario.append_array(Acompanhar.seguir(u, _quem, par[1], _vel))
			livro.atualizar_cabecalho()
			livro.ir_para_aba("viver", _quem))
		botoes.append(b)
	_dir.add_child(linha(botoes))
	var t := Tema.texto_rico()
	t.meta_clicked.connect(livro.navegar)
	var linhas: Array = []
	var dia := ""
	for x in _diario:
		var d := DataMundo.texto(x["data"])
		if d != dia:
			linhas.append("\n[font_size=%d][color=#5A3A1A]%s[/color][/font_size]" % [Tema.px(15), d])
			dia = d
		var txt := Paginas._e(str(x["texto"]))
		linhas.append(Paginas.link("fato:" + str(x["fato"]), str(x["texto"])) if str(x["fato"]) != "" else "[i]%s[/i]" % txt)
	t.text = Paginas.cabecalho("Acompanhando %s" % u.entidade(_quem)["nome"], "o mundo anda junto; pare quando quiser") + ("\n".join(linhas) if not linhas.is_empty() else "[i]Escolha quanto tempo acompanhar.[/i]")
	_dir.add_child(t)
	var salvar := Tema.botao("Salvar como rascunho de capítulo")
	salvar.disabled = _diario.is_empty()
	salvar.pressed.connect(func():
		var cap := Acompanhar.salvar(u, _quem, _diario)
		_diario = []
		livro.ir_para_aba("escrever", cap))
	var limpar := Tema.botao("Limpar")
	limpar.pressed.connect(func():
		_diario = []
		livro.ir_para_aba("viver", _quem))
	_dir.add_child(linha([salvar, limpar]))
