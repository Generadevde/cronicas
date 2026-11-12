class_name PainelConfronto
extends RefCounted
## Laboratório de confronto: escolha dois lados, as condições, e veja o que acontece.
## É um ensaio: nada daqui muda a história oficial, a não ser que você leve para a página.


static func montar(tela, esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	var u: Universo = tela.universo
	esq.add_theme_constant_override("separation", 10)
	var aviso := Tema.rotulo("Nada daqui muda a história oficial.", 16, Tema.italico(), Tema.VERMELHO)
	esq.add_child(aviso)
	var lista: Array = u.entidades_ativas().filter(func(e): return str(e["tipo"]) != "planeta")
	# Primeiro quem você escreveu pelo nome; depois o resto do povo; por fim lugares e outras coisas.
	var peso := func(e: Dictionary) -> int:
		if e["tipo"] != "pessoa":
			return 2
		return 0 if u.valor_campo(e["id"], "descrição") != "" else 1
	lista.sort_custom(func(a, b): return peso.call(a) < peso.call(b) or (peso.call(a) == peso.call(b) and str(a["nome"]) < str(b["nome"])))
	if lista.size() < 2:
		var vazio := Tema.rotulo("O universo ainda não tem dois lados para pôr frente a frente.\n\nEscreva na página quem existe (por exemplo: \"Kai Dunmar jurou vingança contra John Black.\") e volte aqui.", 18, Tema.italico(), Tema.TINTA_SUAVE)
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		esq.add_child(vazio)
		return
	var lugares: Array = lista.filter(func(e): return Mapa.e_lugar(u, e["id"]))
	var sel_a := _seletor(lista, dado)
	var sel_b := _seletor(lista, "")
	if sel_a.selected < 0:
		sel_a.select(0)
	sel_b.select(1 if sel_a.selected != 1 else 0)
	esq.add_child(Tema.secao("De um lado"))
	esq.add_child(sel_a)
	var al_a := _aliados()
	esq.add_child(al_a)
	var contra := Tema.rotulo("contra", 26, Tema.F_GOTICA, Tema.VERMELHO)
	contra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esq.add_child(contra)
	esq.add_child(Tema.secao("Do outro"))
	esq.add_child(sel_b)
	var al_b := _aliados()
	esq.add_child(al_b)
	esq.add_child(Tema.secao("Condições"))
	var onde := OptionButton.new()
	onde.add_item("Onde: em lugar nenhum em especial")
	for l in lugares:
		onde.add_item("Onde: " + str(l["nome"]))
	esq.add_child(onde)
	var surpresa := OptionButton.new()
	for t in ["Ninguém ataca de surpresa", "O primeiro lado ataca de surpresa", "O segundo lado ataca de surpresa"]:
		surpresa.add_item(t)
	esq.add_child(surpresa)
	var morte := CheckBox.new()
	morte.text = "Lutam até o fim"
	esq.add_child(morte)
	var ver: Button = tela._botao_cheio("Ver o que acontece", Tema.VERMELHO)
	esq.add_child(ver)

	dir.add_theme_constant_override("separation", 8)
	var resultado := VBoxContainer.new()
	resultado.add_theme_constant_override("separation", 8)
	dir.add_child(resultado)
	var antigos := VBoxContainer.new()
	antigos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rol := ScrollContainer.new()
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	antigos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(antigos)
	dir.add_child(rol)

	var mostrar := func(e: Dictionary):
		Tema.limpar(resultado)
		resultado.add_child(Tema.secao("O que aconteceu neste ensaio"))
		var t := Tema.rotulo(str(e["texto"]), 20, Tema.F_FELL_IT, Tema.TINTA_MUNDO)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resultado.add_child(t)
		resultado.add_child(Tema.secao("Por quê"))
		for p in e["porque"]:
			var l := Tema.rotulo("· " + str(p), 17, Tema.corpo(), Tema.TINTA)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			resultado.add_child(l)
		var levar: Button = tela._botao_cheio("Levar para a história", Tema.TINTA_MUNDO, "Vira uma linha do mundo na página, para você aceitar, mudar ou riscar")
		levar.pressed.connect(func():
			tela.fechar_painel()
			tela._propor(str(e["texto"]), []))
		var h := HBoxContainer.new()
		h.add_child(levar)
		resultado.add_child(h)
		resultado.add_child(HSeparator.new())
	var listar := func():
		Tema.limpar(antigos)
		antigos.add_child(Tema.secao("Ensaios anteriores"))
		for e in u.extra("ensaios", []):
			var b := LinkButton.new()
			b.text = str(e["resumo"])
			b.add_theme_font_size_override("font_size", Tema.px_texto(16))
			b.add_theme_color_override("font_color", Tema.TINTA)
			b.pressed.connect(func(): mostrar.call(e))
			antigos.add_child(b)
	listar.call()
	ver.pressed.connect(func():
		var a := str(lista[sel_a.selected]["id"])
		var b := str(lista[sel_b.selected]["id"])
		if a == b:
			tela.avisar("Escolha dois lados diferentes.")
			return
		var cond := {"ate_a_morte": morte.button_pressed, "aliados": {a: int(al_a.get_meta("spin").value), b: int(al_b.get_meta("spin").value)}}
		if onde.selected > 0:
			cond["lugar"] = str(lugares[onde.selected - 1]["id"])
		if surpresa.selected > 0:
			cond["surpresa"] = a if surpresa.selected == 1 else b
		var e := Confronto.ensaiar(u, a, b, cond)
		if not e.is_empty():
			mostrar.call(e)
			listar.call())


static func _seletor(lista: Array, escolhido: String) -> OptionButton:
	var o := OptionButton.new()
	for i in lista.size():
		o.add_item("%s (%s)" % [str(lista[i]["nome"]), str(lista[i]["tipo"])])
		if str(lista[i]["id"]) == escolhido:
			o.select(i)
	return o


static func _aliados() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Tema.rotulo("aliados ao lado:", 16, Tema.italico(), Tema.TINTA_SUAVE))
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = 100000
	h.add_child(s)
	h.set_meta("spin", s)
	return h
