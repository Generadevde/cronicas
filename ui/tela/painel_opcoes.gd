class_name PainelOpcoes
extends RefCounted
## Opções: tema do programa, letra da página, letra do resto, tamanho e som de máquina.
## Cada escolha vale na hora (a tela se remonta) e fica guardada.

const PREVIA := "Na cidade de Austin viviam 3.700 habitantes até a chegada do imperador."


static func montar(tela, pai: VBoxContainer) -> void:
	Tema._garantir_prefs()
	pai.add_theme_constant_override("separation", 12)
	var aplicar := func(mud: Dictionary):
		Tema.salvar_preferencias(mud)
		tela.reconstruir.call_deferred("opcoes")

	pai.add_child(Tema.secao("Tema"))
	var temas := HBoxContainer.new()
	temas.add_theme_constant_override("separation", 12)
	for id in Tema.PALETAS:
		var p: Dictionary = Tema.PALETAS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 86)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(p["nome"])
		var s := StyleBoxFlat.new()
		s.bg_color = Color(p["PAPEL"])
		s.border_color = Tema.OURO if Tema.prefs["tema"] == id else Color(p["PAPEL_BORDA"])
		s.set_border_width_all(4 if Tema.prefs["tema"] == id else 1)
		s.border_width_left = 22
		if Tema.prefs["tema"] != id:
			s.border_color = Color(p["COURO_ESCURO"])
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, s)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 30
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Tema.rotulo(str(p["nome"]), 19, Tema.F_FELL, Color(p["TINTA"])))
		v.add_child(Tema.rotulo("a linha do mundo", 16, Tema.F_FELL_IT, Color(p["TINTA_MUNDO"])))
		b.add_child(v)
		b.pressed.connect(func(): aplicar.call({"tema": id}))
		temas.add_child(b)
	pai.add_child(temas)

	pai.add_child(Tema.secao("Letra da página (o que você escreve)"))
	pai.add_child(_seletor("escrita", aplicar))
	pai.add_child(Tema.secao("Letra do resto (margem, páginas, painéis)"))
	pai.add_child(_seletor("texto", aplicar))

	pai.add_child(Tema.secao("Tamanho da letra"))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	var menos := Tema.botao("A−", "Menor")
	var mais := Tema.botao("A+", "Maior")
	var pct := Tema.rotulo("%d%%" % int(round(float(Tema.prefs["tamanho"]) * 100)), 19, Tema.F_FELL, Tema.TINTA)
	pct.custom_minimum_size = Vector2(70, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menos.pressed.connect(func(): aplicar.call({"tamanho": float(Tema.prefs["tamanho"]) - 0.1}))
	mais.pressed.connect(func(): aplicar.call({"tamanho": float(Tema.prefs["tamanho"]) + 0.1}))
	var padrao := Tema.botao("Voltar ao normal")
	padrao.pressed.connect(func(): aplicar.call({"tamanho": 1.0}))
	for c in [menos, pct, mais, padrao]:
		linha.add_child(c)
	pai.add_child(linha)

	pai.add_child(Tema.secao("Som"))
	var som := CheckBox.new()
	som.text = "Som de máquina de escrever ao digitar"
	som.button_pressed = bool(Tema.prefs.get("som", true))
	som.toggled.connect(func(v: bool):
		Tema.salvar_preferencias({"som": v})
		if v:
			tela._som.tecla())
	pai.add_child(som)

	pai.add_child(Tema.ornamento())
	var previa := Label.new()
	previa.text = PREVIA
	previa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	previa.add_theme_font_override("font", Tema.escrita())
	previa.add_theme_font_size_override("font_size", Tema.px_escrita(20))
	previa.add_theme_color_override("font_color", Tema.TINTA)
	pai.add_child(previa)
	var previa2 := Tema.rotulo("Naquela noite, o povo de Austin fechou as portas.", 20, Tema.F_FELL_IT, Tema.TINTA_MUNDO)
	previa2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(previa2)


static func _seletor(chave: String, aplicar: Callable) -> OptionButton:
	var o := OptionButton.new()
	var ids: Array = Tema.FONTES.keys()
	for i in ids.size():
		o.add_item(str(Tema.FONTES[ids[i]]["nome"]))
		if ids[i] == Tema.prefs[chave]:
			o.select(i)
	o.item_selected.connect(func(i: int): aplicar.call({chave: ids[i]}))
	return o
