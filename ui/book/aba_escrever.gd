extends AbaLivro
## Aba "Escrever": o capítulo na página esquerda; na direita, a estante,
## a margem (fatos propostos, ecos, dúvidas, avisos de continuidade) e as versões.

var _cap_atual := ""
var _esq: VBoxContainer
var _dir: VBoxContainer
var _modo_dir := "margem"
var _editor: TextEdit
var _leitura: RichTextLabel
var _rodape: RichTextLabel
var _arvore: Tree
var _botoes_modo: Dictionary = {}
var _conteudo_dir: VBoxContainer


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_esq = esq
	_dir = dir
	_cap_atual = dado if u.capitulos.has(dado) else ""
	if _cap_atual == "" and livro.has_meta("ultimo_capitulo") and u.capitulos.has(livro.get_meta("ultimo_capitulo")):
		_cap_atual = livro.get_meta("ultimo_capitulo")
	if _cap_atual == "":
		for l in u.livros:
			if not l["capitulos"].is_empty():
				_cap_atual = l["capitulos"][0]
				break
	if _cap_atual == "":
		_modo_dir = "estante"
	elif livro.has_meta("modo_escrever"):
		_modo_dir = livro.get_meta("modo_escrever")

	var abas := HBoxContainer.new()
	for m in [["estante", "Estante"], ["margem", "Margem"], ["versoes", "Versões"]]:
		var b := Tema.botao(m[1])
		b.toggle_mode = true
		b.pressed.connect(_trocar_modo.bind(m[0]))
		_botoes_modo[m[0]] = b
		abas.add_child(b)
	_dir.add_child(abas)
	_conteudo_dir = VBoxContainer.new()
	_conteudo_dir.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dir.add_child(_conteudo_dir)

	_mostrar_capitulo()
	if _cap_atual != "":
		Extrator.analisar(u, _cap_atual)
	_trocar_modo(_modo_dir)


func _trocar_modo(modo: String) -> void:
	_modo_dir = modo
	livro.set_meta("modo_escrever", modo)
	for m in _botoes_modo:
		_botoes_modo[m].button_pressed = m == modo
	_atualizar_rotulo_margem()
	Tema.limpar(_conteudo_dir)
	match modo:
		"estante":
			_montar_estante()
		"margem":
			_montar_margem()
		"versoes":
			_montar_versoes()


func _atualizar_rotulo_margem() -> void:
	if not _botoes_modo.has("margem"):
		return
	var n := u.propostas_do_capitulo(_cap_atual).size() if _cap_atual != "" else 0
	_botoes_modo["margem"].text = "Margem (%d)" % n if n > 0 else "Margem"


# ---------------------------------------------------------------- estante

func _montar_estante() -> void:
	_conteudo_dir.add_child(Tema.secao("Livros e capítulos"))
	_arvore = Tree.new()
	_arvore.hide_root = true
	_arvore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arvore.item_selected.connect(_ao_selecionar)
	_conteudo_dir.add_child(_arvore)
	var b_livro := Tema.botao("+ Livro", "Criar um livro novo neste universo")
	b_livro.pressed.connect(_novo_livro)
	var b_cap := Tema.botao("+ Capítulo", "Criar um capítulo no livro selecionado")
	b_cap.pressed.connect(_novo_capitulo)
	var b_ren := Tema.botao("Renomear", "Renomear o livro selecionado")
	b_ren.pressed.connect(_renomear)
	var b_cima := Tema.botao("↑", "Mover para cima")
	b_cima.pressed.connect(_mover.bind(-1))
	var b_baixo := Tema.botao("↓", "Mover para baixo")
	b_baixo.pressed.connect(_mover.bind(1))
	var b_apagar := Tema.botao("Apagar", "Apagar o livro ou capítulo selecionado (o texto vai para as notas)")
	b_apagar.pressed.connect(_apagar)
	_conteudo_dir.add_child(linha([b_livro, b_cap, b_ren]))
	_conteudo_dir.add_child(linha([b_cima, b_baixo, b_apagar]))
	_recarregar_arvore()


func _recarregar_arvore() -> void:
	if _arvore == null or not is_instance_valid(_arvore):
		return
	_arvore.clear()
	var raiz := _arvore.create_item()
	for l in u.livros:
		var it := _arvore.create_item(raiz)
		it.set_text(0, l["titulo"])
		it.set_custom_font(0, Tema.F_VERSALETE)
		it.set_metadata(0, "liv:" + l["id"])
		for cid in l["capitulos"]:
			var ci := _arvore.create_item(it)
			ci.set_text(0, _rotulo_cap(u.capitulos[cid]))
			ci.set_metadata(0, "cap:" + cid)
			if cid == _cap_atual:
				ci.select(0)
	if u.livros.is_empty():
		var vazio := _arvore.create_item(raiz)
		vazio.set_text(0, "Nenhum livro ainda. Crie o primeiro.")
		vazio.set_selectable(0, false)


func _rotulo_cap(cap: Dictionary) -> String:
	var t: String = cap["titulo"] if cap["titulo"] != "" else "(sem título)"
	if cap["marcado"]:
		t = "❧ " + t
	if not cap["canon"]:
		t += "  · rascunho"
	return t


func _selecionado() -> String:
	if _arvore == null or not is_instance_valid(_arvore):
		return "cap:" + _cap_atual if _cap_atual != "" else ""
	var it := _arvore.get_selected()
	return "" if it == null else str(it.get_metadata(0))


func _livro_do_selecionado() -> String:
	var s := _selecionado()
	if s.begins_with("liv:"):
		return s.substr(4)
	if s.begins_with("cap:"):
		return u.capitulo(s.substr(4)).get("livro", "")
	return u.livros.back()["id"] if not u.livros.is_empty() else ""


func _ao_selecionar() -> void:
	var s := _selecionado()
	if s.begins_with("cap:") and s.substr(4) != _cap_atual:
		_abrir_capitulo(s.substr(4))


func _abrir_capitulo(cid: String) -> void:
	if _cap_atual != "":
		u.guardar_versao(_cap_atual)
		Extrator.analisar(u, _cap_atual)
	_cap_atual = cid
	_mostrar_capitulo()
	if cid != "":
		Extrator.analisar(u, cid)
	_atualizar_rotulo_margem()


func _novo_livro() -> void:
	livro.pedir_texto("Novo livro", "Título do livro", "", func(t: String):
		if t.strip_edges() == "":
			return
		var lid := u.criar_livro(t)
		_abrir_capitulo(u.criar_capitulo(lid, "Capítulo 1"))
		_recarregar_arvore())


func _novo_capitulo() -> void:
	var lid := _livro_do_selecionado()
	if lid == "":
		_novo_livro()
		return
	var n: int = u.livro(lid)["capitulos"].size() + 1
	_abrir_capitulo(u.criar_capitulo(lid, "Capítulo %d" % n))
	_recarregar_arvore()


func _renomear() -> void:
	var lid := _livro_do_selecionado()
	if lid == "":
		return
	livro.pedir_texto("Renomear livro", "Título do livro", u.livro(lid)["titulo"], func(t: String):
		u.renomear_livro(lid, t)
		_recarregar_arvore())


func _mover(delta: int) -> void:
	var s := _selecionado()
	if s.begins_with("liv:"):
		u.mover_livro(s.substr(4), delta)
	elif s.begins_with("cap:"):
		u.mover_capitulo(s.substr(4), delta)
	_recarregar_arvore()
	_reselecionar(s)


func _reselecionar(meta: String) -> void:
	var it := _arvore.get_root().get_first_child() if _arvore.get_root() else null
	while it != null:
		if str(it.get_metadata(0)) == meta:
			it.select(0)
			return
		var filho := it.get_first_child()
		while filho != null:
			if str(filho.get_metadata(0)) == meta:
				filho.select(0)
				return
			filho = filho.get_next()
		it = it.get_next()


func _apagar() -> void:
	var s := _selecionado()
	if s.begins_with("liv:"):
		var l := u.livro(s.substr(4))
		livro.confirmar("Apagar o livro \"%s\" e seus %d capítulos?\nO texto escrito vai para as notas do autor." % [l["titulo"], l["capitulos"].size()], func():
			if l["capitulos"].has(_cap_atual):
				_cap_atual = ""
			u.apagar_livro(l["id"])
			_recarregar_arvore()
			_mostrar_capitulo())
	elif s.begins_with("cap:"):
		var cap := u.capitulo(s.substr(4))
		livro.confirmar("Apagar o capítulo \"%s\"?\nO texto vai para as notas do autor." % cap["titulo"], func():
			if cap["id"] == _cap_atual:
				_cap_atual = ""
			u.apagar_capitulo(cap["id"])
			_recarregar_arvore()
			_mostrar_capitulo())


# ---------------------------------------------------------------- página do capítulo (esquerda)

func _mostrar_capitulo() -> void:
	Tema.limpar(_esq)
	var cap := u.capitulo(_cap_atual)
	if cap.is_empty():
		_esq.add_child(Tema.titulo("Escrever"))
		_esq.add_child(Tema.ornamento())
		var dica := Tema.rotulo("Crie um livro na estante ao lado e comece a escrever.\n\n" +
			"Os nomes das entidades viram links sozinhos, e o que acontece no texto aparece na margem para você confirmar.",
			19, Tema.italico(), Tema.TINTA_SUAVE)
		dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_esq.add_child(dica)
		return
	livro.set_meta("ultimo_capitulo", _cap_atual)

	var titulo := campo("Título do capítulo", cap["titulo"])
	titulo.add_theme_font_override("font", Tema.F_FELL)
	titulo.add_theme_font_size_override("font_size", Tema.px(26))
	titulo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.text_changed.connect(func(t: String):
		u.atualizar_capitulo(_cap_atual, {"titulo": t})
		_atualizar_item_arvore())
	_esq.add_child(titulo)

	var ano := SpinBox.new()
	ano.min_value = -1000000
	ano.max_value = 1000000
	ano.value = cap["data"]["ano"]
	ano.prefix = "Ano"
	ano.tooltip_text = "Ano em que o capítulo acontece no mundo"
	var dia := SpinBox.new()
	dia.min_value = 1
	dia.max_value = DataMundo.DIAS_POR_ANO
	dia.value = cap["data"]["dia"]
	dia.prefix = "dia"
	var mudar_data := func(_v: float):
		u.atualizar_capitulo(_cap_atual, {"data": DataMundo.criar(int(ano.value), int(dia.value))})
	ano.value_changed.connect(mudar_data)
	dia.value_changed.connect(mudar_data)
	var canon := CheckBox.new()
	canon.text = "Canon"
	canon.button_pressed = cap["canon"]
	canon.tooltip_text = "Canon vale no mundo. Desmarcado = rascunho: não gera fatos."
	canon.toggled.connect(func(v: bool):
		u.atualizar_capitulo(_cap_atual, {"canon": v})
		_atualizar_item_arvore()
		if _modo_dir == "margem":
			_trocar_modo("margem"))
	var marca := CheckBox.new()
	marca.text = "Marcador"
	marca.button_pressed = cap["marcado"]
	marca.toggled.connect(func(v: bool):
		u.atualizar_capitulo(_cap_atual, {"marcado": v})
		_atualizar_item_arvore())
	var b_ler := Tema.botao("Ler", "Alternar entre escrever e ler com os nomes como links")
	b_ler.toggle_mode = true
	_esq.add_child(linha([ano, dia, canon, marca, b_ler]))

	_editor = TextEdit.new()
	_editor.text = cap["texto"]
	_editor.placeholder_text = "Era uma vez…"
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.add_theme_font_override("font", Tema.escrita())
	_editor.add_theme_font_size_override("font_size", Tema.px_escrita(21))
	_editor.add_theme_constant_override("line_spacing", 6)
	_editor.text_changed.connect(func():
		u.atualizar_capitulo(_cap_atual, {"texto": _editor.text})
		livro.adiar(_atualizar_rodape)
		livro.adiar(_analisar_depois_de_parar, 2.0))
	_esq.add_child(_editor)

	_leitura = Tema.texto_rico()
	_leitura.visible = false
	_leitura.meta_clicked.connect(livro.navegar)
	_esq.add_child(_leitura)

	b_ler.toggled.connect(func(lendo: bool):
		b_ler.text = "Escrever" if lendo else "Ler"
		if lendo:
			_leitura.text = Paginas.capitulo(u, _cap_atual)
		_leitura.visible = lendo
		_editor.visible = not lendo)

	_rodape = RichTextLabel.new()
	_rodape.bbcode_enabled = true
	_rodape.fit_content = true
	_rodape.scroll_active = false
	_rodape.add_theme_font_size_override("normal_font_size", Tema.px_texto(16))
	_rodape.meta_clicked.connect(livro.navegar)
	_esq.add_child(_rodape)
	_atualizar_rodape()


func _analisar_depois_de_parar() -> void:
	if _cap_atual == "" or not u.capitulos.has(_cap_atual):
		return
	var novas := Extrator.analisar(u, _cap_atual)
	if not novas.is_empty() and _modo_dir == "margem":
		_trocar_modo("margem")
	else:
		_atualizar_rotulo_margem()


func _atualizar_item_arvore() -> void:
	if _arvore == null or not is_instance_valid(_arvore):
		return
	var it := _arvore.get_selected()
	if it != null and str(it.get_metadata(0)) == "cap:" + _cap_atual:
		it.set_text(0, _rotulo_cap(u.capitulo(_cap_atual)))


func _atualizar_rodape() -> void:
	if _rodape == null or not is_instance_valid(_rodape) or not u.capitulos.has(_cap_atual):
		return
	var texto: String = u.capitulo(_cap_atual)["texto"]
	var vistos := {}
	var nomes: Array = []
	for m in Ligador.new(u).encontrar(texto):
		if vistos.has(m["entidade"]):
			continue
		vistos[m["entidade"]] = true
		nomes.append(Paginas.link("ent:" + m["entidade"], u.entidade(m["entidade"])["nome"]))
	var s := "[color=#5A3A1A]%d palavras" % TextUtil.palavras(texto).size()
	if not nomes.is_empty():
		s += " · nesta página: [/color]" + ", ".join(nomes)
	else:
		s += "[/color]"
	_rodape.text = s


# ---------------------------------------------------------------- margem (direita)

func _montar_margem() -> void:
	var cap := u.capitulo(_cap_atual)
	if cap.is_empty():
		_conteudo_dir.add_child(Tema.rotulo("Abra um capítulo para ver a margem.", 18, Tema.italico(), Tema.TINTA_SUAVE))
		return
	var topo := HBoxContainer.new()
	var titulo := Tema.rotulo("Ecos do capítulo", 26, Tema.F_FELL_IT)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	var b_analisar := Tema.botao("Analisar agora", "Ler o capítulo de novo e propor fatos")
	b_analisar.pressed.connect(func():
		Extrator.analisar(u, _cap_atual)
		_trocar_modo("margem"))
	topo.add_child(b_analisar)
	_conteudo_dir.add_child(topo)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 12)
	_conteudo_dir.add_child(rolagem(lista))

	if not cap["canon"]:
		lista.add_child(_aviso("Rascunho", "Este capítulo é rascunho: não gera fatos nem muda o mundo. Marque \"Canon\" quando quiser que valha.", Tema.TINTA_SUAVE))

	for a in Continuidade.verificar_capitulo(u, _cap_atual):
		lista.add_child(_aviso("Continuidade", a["mensagem"], Tema.VERMELHO))

	var pendentes := u.propostas_do_capitulo(_cap_atual)
	if pendentes.is_empty() and cap["canon"]:
		var vazio := Tema.rotulo("Nada novo por aqui. Escreva: quando alguém vencer, morrer, chegar a algum lugar, se casar, trair… a margem propõe o fato.", 16, Tema.italico(), Tema.TINTA_SUAVE)
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista.add_child(vazio)
	for p in pendentes:
		match p["status"]:
			"pendente":
				lista.add_child(_cartao_fato(p))
			"eco":
				lista.add_child(_cartao_eco(p))
			"duvida":
				lista.add_child(_cartao_duvida(p))

	var aceitas: Array = u.propostas.filter(func(p): return p["capitulo"] == _cap_atual and p["status"] == "aceita")
	if not aceitas.is_empty():
		lista.add_child(Tema.secao("Já valendo no mundo (%d)" % aceitas.size()))
		for p in aceitas:
			var l := Tema.rotulo("• " + p["descricao"], 16)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var b := Tema.botao("Desfazer", "O fato continua guardado, mas deixa de valer; o mundo é recalculado sem ele")
			b.pressed.connect(func():
				u.desfazer_proposta(p["id"])
				_trocar_modo("margem"))
			lista.add_child(linha([l, b]))


func _aviso(titulo: String, texto: String, cor: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(Tema.rotulo(titulo, 15, Tema.F_VERSALETE, cor))
	var l := Tema.rotulo(texto, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return v


func _cartao(cabecalho: String, cor: Color, descricao: String, frase: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(Tema.rotulo(cabecalho, 15, Tema.F_VERSALETE, cor))
	var d := Tema.rotulo(descricao, 18)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	if frase != "":
		var f := Tema.rotulo("“%s”" % frase, 15, Tema.italico(), Tema.TINTA_SUAVE)
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(f)
	return v


func _cartao_fato(p: Dictionary) -> Control:
	var v := _cartao("Fato", Color("#4A5A1E"), p["descricao"], p["frase"])
	var aceitar := Tema.botao("Aceitar")
	aceitar.pressed.connect(func():
		u.aceitar_proposta(p["id"])
		_trocar_modo("margem"))
	var ajustar := Tema.botao("Ajustar")
	ajustar.pressed.connect(_ajustar.bind(p))
	var riscar := Tema.botao("Riscar")
	riscar.pressed.connect(func():
		u.riscar_proposta(p["id"])
		_trocar_modo("margem"))
	v.add_child(linha([aceitar, ajustar, riscar]))
	return v


func _cartao_eco(p: Dictionary) -> Control:
	var v := _cartao("Eco proposto", Color("#233B66"), p["descricao"], "")
	var aceitar := Tema.botao("Aceitar")
	aceitar.pressed.connect(func():
		u.aceitar_proposta(p["id"])
		_trocar_modo("margem"))
	var riscar := Tema.botao("Riscar")
	riscar.pressed.connect(func():
		u.riscar_proposta(p["id"])
		_trocar_modo("margem"))
	v.add_child(linha([aceitar, riscar]))
	return v


func _cartao_duvida(p: Dictionary) -> Control:
	var v := _cartao("Dúvida", Tema.VERMELHO, "Não entendi o que acontece aqui. O que significa a palavra?", p["frase"])
	var palavra := campo("palavra", p.get("palavra", ""))
	palavra.custom_minimum_size = Vector2(120, 0)
	var opcoes := OptionButton.new()
	var ids: Array = []
	for id in Extrator.ACOES:
		if id in ["vitoria_um", "derrota_um"]:
			continue
		opcoes.add_item(Extrator.ACOES[id]["nome"])
		ids.append(id)
	var ensinar := Tema.botao("Ensinar", "A palavra passa a valer em todo o universo")
	ensinar.pressed.connect(func():
		u.ensinar(palavra.text, ids[opcoes.selected], p["id"])
		_trocar_modo("margem"))
	var ignorar := Tema.botao("Só descrição", "Esta frase não muda nada no mundo")
	ignorar.pressed.connect(func():
		u.riscar_proposta(p["id"])
		_trocar_modo("margem"))
	# Nenhuma ação da lista serve? Escreva o efeito: vira lei e vale sempre que a palavra aparecer.
	var definir := Tema.botao("Definir efeito", "Escreva o que essa ação faz (vira lei do universo)")
	definir.pressed.connect(func():
		livro.pedir_texto("O que \"%s\" faz?" % palavra.text, "ex.: o outro fica ferido; o outro sente raiva", "", func(efeito: String):
			if efeito.strip_edges() == "":
				return
			var item := {"tipo": "duvida", "proposta": p["id"], "palavra": palavra.text.strip_edges()}
			Pendencias.definir(u, item, efeito)
			livro.atualizar_cabecalho()
			_trocar_modo("margem")))
	v.add_child(linha([palavra, Tema.rotulo("=", 18), opcoes]))
	v.add_child(linha([ensinar, definir, ignorar]))
	return v


## Ajustar: trocar o tipo de acontecimento, inverter quem faz e quem sofre, editar o texto.
func _ajustar(p: Dictionary) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Ajustar fato"
	d.ok_button_text = "Aceitar ajustado"
	d.cancel_button_text = "Cancelar"
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(460, 0)
	var opcoes := OptionButton.new()
	var ids: Array = []
	for id in Extrator.ACOES:
		opcoes.add_item(Extrator.ACOES[id]["nome"])
		ids.append(id)
		if id == p["acao"]:
			opcoes.select(ids.size() - 1)
	var sujeitos: Array = p["sujeitos"].duplicate()
	var descricao := LineEdit.new()
	descricao.text = p["descricao"]
	var refazer := func():
		descricao.text = Extrator.descrever(u, ids[opcoes.selected], sujeitos, p["lugar"])
	opcoes.item_selected.connect(func(_i): refazer.call())
	var inverter := Tema.botao("Inverter quem faz e quem sofre")
	inverter.disabled = sujeitos.size() < 2
	inverter.pressed.connect(func():
		sujeitos.reverse()
		refazer.call())
	v.add_child(Tema.secao("O que aconteceu"))
	v.add_child(opcoes)
	v.add_child(inverter)
	v.add_child(Tema.secao("Como fica escrito no banco de fatos"))
	v.add_child(descricao)
	d.add_child(v)
	d.confirmed.connect(func():
		u.aceitar_proposta(p["id"], {"acao": ids[opcoes.selected], "sujeitos": sujeitos, "descricao": descricao.text})
		_trocar_modo("margem"))
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	livro.add_child(d)
	d.popup_centered()


# ---------------------------------------------------------------- versões

func _montar_versoes() -> void:
	var cap := u.capitulo(_cap_atual)
	_conteudo_dir.add_child(Tema.secao("Versões guardadas deste capítulo"))
	if cap.is_empty():
		return
	var b := Tema.botao("Guardar versão agora")
	b.pressed.connect(func():
		u.guardar_versao(_cap_atual)
		_trocar_modo("versoes"))
	_conteudo_dir.add_child(b)
	var lista := VBoxContainer.new()
	_conteudo_dir.add_child(rolagem(lista))
	var versoes: Array = cap.get("versoes", [])
	if versoes.is_empty():
		lista.add_child(Tema.rotulo("Nenhuma versão ainda. Uma versão é guardada sempre que você troca de capítulo.", 16, Tema.italico(), Tema.TINTA_SUAVE))
	for i in range(versoes.size() - 1, -1, -1):
		var ver: Dictionary = versoes[i]
		var quando: String = str(ver["quando"]).replace("T", " às ")
		var l := Tema.rotulo("%s · %d palavras\n%s" % [quando, TextUtil.palavras(ver["texto"]).size(), TextUtil.trecho(ver["texto"], 0, 70)], 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r := Tema.botao("Restaurar", "Volta para esta versão (a atual é guardada antes)")
		r.pressed.connect(func():
			u.restaurar_versao(_cap_atual, i)
			_mostrar_capitulo()
			_trocar_modo("versoes"))
		lista.add_child(linha([l, r]))
