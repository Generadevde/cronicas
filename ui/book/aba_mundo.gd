extends AbaLivro
## Aba "Mundo": o relógio do universo e o ritmo do mundo vivo à esquerda;
## à direita, a linha do tempo e o observatório.

var _modo := "linha"
var _dir: VBoxContainer
var _filtro_ent := ""
var _so_importantes := true
var _obs_ent := ""
var _obs_dias := 360


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	if u.entidades.has(dado):
		_modo = "observatorio"
		_obs_ent = dado
	esq.add_child(Tema.secao("O relógio do mundo"))
	var data := Tema.rotulo(DataMundo.texto(u.relogio), 34, Tema.F_FELL)
	data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esq.add_child(data)
	esq.add_child(Tema.ornamento())

	esq.add_child(Tema.secao("Avançar o tempo"))
	var grade := GridContainer.new()
	grade.columns = 3
	for par in [["1 dia", 1], ["1 semana", 7], ["1 mês", 30], ["1 ano", 360], ["10 anos", 3600], ["Até algo importante", -1]]:
		var b := Tema.botao(par[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(livro.avancar_tempo.bind(par[1]))
		grade.add_child(b)
	esq.add_child(grade)

	esq.add_child(Tema.secao("Mundo vivo"))
	var ritmo := OptionButton.new()
	var ritmos := [["Pausado", 0], ["1 dia por segundo", 1], ["1 semana por segundo", 7], ["1 mês por segundo", 30]]
	for r in ritmos:
		ritmo.add_item(r[0])
	for i in ritmos.size():
		if ritmos[i][1] == livro.ritmo_vivo:
			ritmo.select(i)
	ritmo.item_selected.connect(func(i: int): livro.definir_ritmo(ritmos[i][1]))
	esq.add_child(ritmo)
	var explica := Tema.rotulo("Com o mundo vivo, o tempo corre enquanto o livro está aberto. O lugar do capítulo que você está escrevendo fica parado (em foco).", 15, Tema.F_ITALICO, Tema.TINTA_SUAVE)
	explica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esq.add_child(explica)

	esq.add_child(Tema.secao("Definir a data à mão"))
	var ano := SpinBox.new()
	ano.min_value = -1000000
	ano.max_value = 1000000
	ano.value = u.relogio["ano"]
	ano.prefix = "Ano"
	var dia := SpinBox.new()
	dia.min_value = 1
	dia.max_value = DataMundo.DIAS_POR_ANO
	dia.value = u.relogio["dia"]
	dia.prefix = "dia"
	var aplicar := Tema.botao("Definir", "Muda o calendário sem simular nada (ex.: começar a história no ano 412)")
	aplicar.pressed.connect(func():
		u.definir_relogio(DataMundo.criar(int(ano.value), int(dia.value)))
		livro.atualizar_cabecalho()
		livro.ir_para_aba("mundo"))
	esq.add_child(linha([ano, dia, aplicar]))

	var abas := HBoxContainer.new()
	for m in [["linha", "Linha do tempo"], ["observatorio", "Observatório"]]:
		var b := Tema.botao(m[1])
		b.toggle_mode = true
		b.button_pressed = m[0] == _modo
		b.pressed.connect(func():
			_modo = m[0]
			_montar_direita())
		abas.add_child(b)
	dir.add_child(abas)
	_montar_direita()


func _montar_direita() -> void:
	while _dir.get_child_count() > 1:
		var c := _dir.get_child(1)
		_dir.remove_child(c)
		c.queue_free()
	for i in _dir.get_child(0).get_child_count():
		var b: Button = _dir.get_child(0).get_child(i)
		b.button_pressed = (i == 0 and _modo == "linha") or (i == 1 and _modo == "observatorio")
	if _modo == "linha":
		_linha_do_tempo()
	else:
		_observatorio()


func _seletor_de_entidade(atual: String, vazio: String, ao_mudar: Callable) -> OptionButton:
	var op := OptionButton.new()
	op.add_item(vazio)
	op.set_item_metadata(0, "")
	var i := 1
	for e in u.entidades_ativas():
		op.add_item(e["nome"])
		op.set_item_metadata(i, e["id"])
		if e["id"] == atual:
			op.select(i)
		i += 1
	op.item_selected.connect(func(k: int): ao_mudar.call(str(op.get_item_metadata(k))))
	return op


func _linha_do_tempo() -> void:
	var filtro := _seletor_de_entidade(_filtro_ent, "Todo o universo", func(e: String):
		_filtro_ent = e
		_montar_direita())
	var imp := CheckBox.new()
	imp.text = "Só o importante"
	imp.button_pressed = _so_importantes
	imp.toggled.connect(func(v: bool):
		_so_importantes = v
		_montar_direita())
	_dir.add_child(linha([filtro, imp]))
	var texto := Tema.texto_rico()
	texto.meta_clicked.connect(livro.navegar)
	_dir.add_child(texto)
	var fatos: Array = u.fatos.sobre(_filtro_ent) if _filtro_ent != "" else u.fatos.todos()
	fatos = fatos.filter(func(f):
		if not f["canon"]:
			return false
		if _so_importantes and (float(f["dados"].get("importancia", Simulador.IMPORTANCIA.get(f["dados"].get("acao", ""), 0.3))) < 0.35 or f["tipo"] in ["notícia", "rumor"]):
			return false
		return true)
	fatos.sort_custom(func(a, b):
		var oa := DataMundo.ordem(a["data"])
		var ob := DataMundo.ordem(b["data"])
		return oa > ob if oa != ob else int(a["seq"]) > int(b["seq"]))
	var s := ""
	var ano_atual := -999999999
	for f in fatos.slice(0, 400):
		var ano: int = int(f["data"]["ano"])
		if ano != ano_atual:
			ano_atual = ano
			s += "\n[font=%s][font_size=22]Ano %d[/font_size][/font]\n" % [Paginas.GOTICA, ano]
		var origem := ""
		match f["origem"].get("tipo", ""):
			BancoDeFatos.ORIGEM_CAPITULO:
				origem = " [color=#4A5A1E](escrito)[/color]"
			BancoDeFatos.ORIGEM_AUTOR:
				origem = " [color=#5A3A7A](autor)[/color]"
		s += "[color=#5A3A1A]dia %d[/color] — %s%s %s\n" % [int(f["data"]["dia"]), Paginas._e(f["descricao"]), origem, Paginas.link("fato:" + f["id"], "›")]
	if s == "":
		s = "[i]Nada ainda. Escreva, aceite fatos na margem ou avance o tempo.[/i]"
	texto.text = s


func _observatorio() -> void:
	var sel := _seletor_de_entidade(_obs_ent, "Escolha quem observar…", func(e: String):
		_obs_ent = e
		_montar_direita())
	var periodo := OptionButton.new()
	var periodos := [["Último ano", 360], ["Últimos 5 anos", 1800], ["Últimos 20 anos", 7200], ["Desde sempre", 0]]
	for p in periodos:
		periodo.add_item(p[0])
	for i in periodos.size():
		if periodos[i][1] == _obs_dias:
			periodo.select(i)
	periodo.item_selected.connect(func(i: int):
		_obs_dias = periodos[i][1]
		_montar_direita())
	_dir.add_child(linha([sel, periodo]))
	var texto := Tema.texto_rico()
	texto.meta_clicked.connect(livro.navegar)
	_dir.add_child(texto)
	texto.text = Observatorio.relatorio(u, _obs_ent, _obs_dias)
