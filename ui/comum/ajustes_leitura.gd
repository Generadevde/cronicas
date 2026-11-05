class_name AjustesLeitura
extends RefCounted
## Janela "Ajustes de leitura": fonte do texto, fonte da escrita e tamanho da letra,
## com uma prévia. As escolhas ficam guardadas para as próximas vezes.

const PREVIA := "Kai enfrentou Lucas na praça de Varn, sob o olhar da cidade inteira."


## Abre a janela sobre 'pai'. 'ao_aplicar' é chamado depois de salvar (para remontar a tela).
static func abrir(pai: Node, ao_aplicar: Callable) -> ConfirmationDialog:
	Tema._garantir_prefs()
	var escolha := Tema.prefs.duplicate()
	var d := ConfirmationDialog.new()
	d.title = "Ajustes de leitura"
	d.ok_button_text = "Aplicar"
	d.cancel_button_text = "Cancelar"
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 10)
	d.add_child(v)

	var previa_texto := Label.new()
	var previa_escrita := Label.new()
	for l in [previa_texto, previa_escrita]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(540, 0)
		l.add_theme_color_override("font_color", Tema.TINTA)
	var atualizar := func():
		var t: Dictionary = Tema.FONTES[escolha["texto"]]
		var e: Dictionary = Tema.FONTES[escolha["escrita"]]
		previa_texto.add_theme_font_override("font", Tema._fonte(t["normal"]))
		previa_texto.add_theme_font_size_override("font_size", int(round(19 * float(t["ajuste"]) * float(escolha["tamanho"]))))
		previa_escrita.add_theme_font_override("font", Tema._fonte(e["normal"]))
		previa_escrita.add_theme_font_size_override("font_size", int(round(21 * float(e["ajuste"]) * float(escolha["tamanho"]))))
		previa_texto.text = "Texto: " + PREVIA
		previa_escrita.text = PREVIA

	v.add_child(Tema.secao("Fonte do texto (wiki, jornal, páginas)"))
	v.add_child(_seletor(escolha, "texto", atualizar))
	v.add_child(Tema.secao("Fonte da escrita (os capítulos)"))
	v.add_child(_seletor(escolha, "escrita", atualizar))
	v.add_child(Tema.secao("Tamanho da letra"))
	var linha := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = 0.75
	slider.max_value = 1.6
	slider.step = 0.05
	slider.value = float(escolha["tamanho"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 28)
	var pct := Tema.rotulo("%d%%" % int(round(slider.value * 100)), 17, Tema.F_FELL, Tema.TINTA_SUAVE)
	pct.custom_minimum_size = Vector2(60, 0)
	slider.value_changed.connect(func(x: float):
		escolha["tamanho"] = x
		pct.text = "%d%%" % int(round(x * 100))
		atualizar.call())
	linha.add_child(slider)
	linha.add_child(pct)
	v.add_child(linha)
	v.add_child(Tema.ornamento())
	v.add_child(previa_texto)
	v.add_child(previa_escrita)
	atualizar.call()

	d.confirmed.connect(func():
		Tema.salvar_preferencias(escolha)
		ao_aplicar.call())
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	pai.add_child(d)
	d.popup_centered(Vector2i(600, 0))
	d.reset_size.call_deferred()
	return d


static func _seletor(escolha: Dictionary, chave: String, atualizar: Callable) -> OptionButton:
	var op := OptionButton.new()
	var ids: Array = Tema.FONTES.keys()
	for i in ids.size():
		op.add_item(Tema.FONTES[ids[i]]["nome"])
		if ids[i] == escolha[chave]:
			op.select(i)
	op.item_selected.connect(func(i: int):
		escolha[chave] = ids[i]
		atualizar.call())
	return op
