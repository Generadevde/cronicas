extends AbaLivro
## Aba "Universo" (o Criador do Universo): leis, eras e lendas à esquerda;
## línguas, povos e espécies, planetas à direita. Tudo em texto livre; cada
## mudança vira fato.

var _lingua := ""


func montar(esq: VBoxContainer, dir: VBoxContainer, _dado: String) -> void:
	var e := VBoxContainer.new()
	esq.add_child(rolagem(e))
	var d := VBoxContainer.new()
	dir.add_child(rolagem(d))
	_eras(e)
	_poderes(e)
	_linguas(d)
	_povos_e_planetas(d)


func _dica(t: String) -> Label:
	var l := Tema.rotulo(t, 15, Tema.italico(), Tema.TINTA_SUAVE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _texto(dica: String, valor: String, altura: int = 70) -> TextEdit:
	var t := TextEdit.new()
	t.placeholder_text = dica
	t.text = valor
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.custom_minimum_size = Vector2(0, altura)
	return t


# ---------------------------------------------------------------- eras e lendas

func _eras(pai: VBoxContainer) -> void:
	pai.add_child(Tema.titulo("Eras", 30))
	var eras := Cosmos.eras(u)
	if eras.is_empty():
		pai.add_child(_dica("Nenhuma era ainda. Dê nome às épocas antigas do universo: Era das Cinzas, Era do Império…"))
	for era in eras:
		var fim := "hoje" if int(era["fim"]) < 0 else "ano %d" % int(era["fim"])
		var r := Tema.rotulo("%s · ano %d até %s" % [era["nome"], int(era["inicio"]), fim], 18, Tema.F_FELL)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tirar := Tema.botao("tirar")
		tirar.add_theme_font_size_override("font_size", Tema.px(15))
		tirar.pressed.connect(func():
			Cosmos.remover_era(u, era["fato"])
			livro.ir_para_aba("universo"))
		pai.add_child(linha([r, tirar]))
		if str(era["descricao"]) != "":
			pai.add_child(_dica(era["descricao"]))
	var nome := campo("Nome da era")
	var inicio := SpinBox.new()
	inicio.min_value = -1000000
	inicio.max_value = 1000000
	inicio.value = int(u.relogio["ano"]) - 100
	inicio.prefix = "de"
	var fim_s := SpinBox.new()
	fim_s.min_value = -1
	fim_s.max_value = 1000000
	fim_s.value = -1
	fim_s.prefix = "até"
	fim_s.tooltip_text = "-1 = ainda não terminou"
	pai.add_child(nome)
	var desc := campo("Como foi essa era (opcional)")
	pai.add_child(desc)
	var criar := Tema.botao("+ Criar era")
	criar.pressed.connect(func():
		if nome.text.strip_edges() == "":
			return
		Cosmos.criar_era(u, nome.text, int(inicio.value), int(fim_s.value), desc.text)
		livro.ir_para_aba("universo"))
	pai.add_child(linha([inicio, fim_s, criar]))

	pai.add_child(Tema.secao("Acontecimento antigo (vira lenda na linha do tempo)"))
	var ano := SpinBox.new()
	ano.min_value = -1000000
	ano.max_value = 1000000
	ano.value = int(u.relogio["ano"]) - 200
	ano.prefix = "Ano"
	var oque := campo("O que aconteceu? Ex.: o céu se partiu sobre Varn")
	var registrar := Tema.botao("Registrar")
	registrar.pressed.connect(func():
		if Cosmos.acontecimento_antigo(u, int(ano.value), oque.text) != "":
			livro.avisar("Lenda registrada no ano %d." % int(ano.value))
			oque.text = "")
	pai.add_child(linha([ano, oque]))
	pai.add_child(registrar)


# ---------------------------------------------------------------- poderes

func _poderes(pai: VBoxContainer) -> void:
	pai.add_child(Tema.ornamento())
	pai.add_child(Tema.titulo("Poderes", 30))
	pai.add_child(_dica("Um poder é qualquer entidade do tipo magia, dom, técnica, feitiço… Quem tem o poder é quem o cita na ficha (\"poderes: Chama Antiga\"). Na ficha do poder: \"força\" (quanto ajuda na luta), \"custo\" (ex.: envelhece um ano), \"limite\" (ex.: uma vez por mês) e \"efeitos permitidos\" (ex.: o outro fica ferido). Poderes que mexem com a realidade ou o destino viram pedido para você decidir."))
	var lista := u.entidades_ativas().filter(func(e): return Poderes.eh_poder(u, e["id"]))
	var s := ""
	for p in lista:
		var donos: Array = []
		for e in u.entidades_ativas():
			if Poderes.de(u, e["id"]).has(p["id"]):
				donos.append(Paginas.link("ent:" + e["id"], e["nome"]))
		s += "• %s · %s%s%s\n" % [Paginas.link("ent:" + p["id"], p["nome"]), Paginas._e(p["tipo"]),
			" · [i]narrativo[/i]" if Poderes.narrativo(u, p["id"]) else "",
			(" · de " + ", ".join(donos)) if not donos.is_empty() else " · [i]ninguém tem ainda[/i]"]
	var txt := Tema.texto_rico()
	txt.fit_content = true
	txt.scroll_active = false
	txt.meta_clicked.connect(livro.navegar)
	txt.text = s if s != "" else "[i]Nenhum poder ainda.[/i]"
	pai.add_child(txt)
	var novo := Tema.botao("+ Novo poder")
	novo.pressed.connect(func(): livro.ir_para_aba("criadores", "nova"))
	var shonen := Tema.botao("Sistema estilo shonen", "Cria um sistema de poder pronto: cresce treinando e lutando, e quem perde volta mais forte")
	shonen.pressed.connect(func():
		var sid := u.criar_entidade("Poder de Luta", "sistema de poder", [], [
			{"chave": "medida", "valor": "poder de luta (um número que pode chegar a milhares)"},
			{"chave": "como cresce", "valor": "treino, lutas e momentos de fúria"},
			{"chave": "transformações", "valor": "despertar: força dobrada por um tempo, com cansaço depois"}])
		Regras.criar(u, "Quem perde uma luta fica 5% mais forte.")
		Regras.criar(u, "Quem vence uma luta fica 3% mais forte.")
		Regras.criar(u, "Quem treina fica 1% mais forte.")
		livro.avisar("Sistema de poder criado, com três leis (veja a aba Leis).")
		livro.ir_para_aba("wiki", sid))
	pai.add_child(linha([novo, shonen]))


# ---------------------------------------------------------------- fauna e flora

var _terreno := "floresta"


func _fauna_e_flora(pai: VBoxContainer) -> void:
	pai.add_child(Tema.ornamento())
	pai.add_child(Tema.titulo("Fauna e flora", 28))
	pai.add_child(_dica("O que vive em cada terreno. Uma por linha, com o papel: planta, presa, predador ou rara (planta rara, que pode ser descoberta). Os números de cada uma são simulados em cada lugar."))
	var ids: Array = Mapa.TERRENOS.keys().filter(func(k): return k != "vazio")
	var op := OptionButton.new()
	for i in ids.size():
		op.add_item(Mapa.TERRENOS[ids[i]]["nome"])
		if ids[i] == _terreno:
			op.select(i)
	op.item_selected.connect(func(i: int):
		_terreno = ids[i]
		livro.ir_para_aba("universo"))
	pai.add_child(op)
	var caixa := _texto("ex.: cervos: presa", Natureza.texto_do_terreno(u, _terreno), 110)
	pai.add_child(caixa)
	var aplicar := CheckBox.new()
	aplicar.text = "Valer também para os lugares que já existem"
	aplicar.button_pressed = true
	var guardar := Tema.botao("Guardar")
	guardar.pressed.connect(func():
		Natureza.definir_terreno(u, _terreno, caixa.text, aplicar.button_pressed)
		livro.avisar("A vida de %s foi definida." % Mapa.TERRENOS[_terreno]["nome"]))
	pai.add_child(linha([guardar, aplicar]))


# ---------------------------------------------------------------- línguas

func _linguas(pai: VBoxContainer) -> void:
	pai.add_child(Tema.titulo("Línguas", 30))
	pai.add_child(_dica("Cada língua aprende o jeito dos nomes com os seus exemplos (os sons, os começos, os finais) e gera nomes novos no mesmo estilo. Um lugar usa a língua escrita no campo \"língua\" da ficha dele ou de onde ele fica."))
	var nomes := Linguas.nomes(u)
	if _lingua == "" or not nomes.has(_lingua):
		_lingua = nomes[0] if not nomes.is_empty() else Linguas.PADRAO
	var op := OptionButton.new()
	for i in nomes.size():
		op.add_item(nomes[i])
		if nomes[i] == _lingua:
			op.select(i)
	op.add_item("+ nova língua…")
	op.item_selected.connect(func(i: int):
		if i >= nomes.size():
			livro.pedir_texto("Nova língua", "Nome da língua (ex.: Élfico do Norte)", "", func(t: String):
				if t.strip_edges() != "":
					Linguas.definir(u, t, {})
					_lingua = t.strip_edges()
				livro.ir_para_aba("universo"))
			return
		_lingua = nomes[i]
		livro.ir_para_aba("universo"))
	pai.add_child(op)
	var dado: Dictionary = Linguas.todas(u).get(_lingua, {})
	var campos := {}
	for k in [["pessoas", "Nomes de pessoas"], ["lugares", "Nomes de lugares"], ["sobrenomes", "Sobrenomes"]]:
		pai.add_child(Tema.secao(k[1] + " (exemplos, separados por vírgula)"))
		var t := _texto("Ex.: Aelindra, Thalion, Elaria…", ", ".join(dado.get(k[0], [])), 46)
		campos[k[0]] = t
		pai.add_child(t)
	var amostra := Tema.rotulo("", 17, Tema.escrita(), Tema.TINTA)
	amostra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var salvar := Tema.botao("Guardar exemplos")
	salvar.pressed.connect(func():
		Linguas.definir(u, _lingua, {"pessoas": campos["pessoas"].text, "lugares": campos["lugares"].text, "sobrenomes": campos["sobrenomes"].text})
		livro.avisar("Língua %s guardada." % _lingua))
	var ouvir := Tema.botao("Ouvir nomes", "Gera alguns nomes nesta língua (não cria nada)")
	ouvir.pressed.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var p: Array = []
		for i in 5:
			p.append(Linguas.gerar(u, _lingua, "pessoas", rng) + " " + Linguas.gerar(u, _lingua, "sobrenomes", rng))
		var l: Array = []
		for i in 4:
			l.append(Linguas.gerar(u, _lingua, "lugares", rng))
		amostra.text = "Pessoas: %s\nLugares: %s" % [", ".join(p), ", ".join(l)])
	pai.add_child(linha([salvar, ouvir]))
	pai.add_child(amostra)


# ---------------------------------------------------------------- povos, espécies e planetas

func _povos_e_planetas(pai: VBoxContainer) -> void:
	pai.add_child(Tema.ornamento())
	pai.add_child(Tema.titulo("Povos e espécies", 28))
	var povos := u.entidades_ativas().filter(func(e): return Sugestoes.categoria(e["tipo"]) == "criatura")
	if povos.is_empty():
		pai.add_child(_dica("Nenhum ainda. Crie em Criadores (tipo livre: \"povo\", \"raça\", \"espécie\", \"fera\"…). Uma espécie com \"habitat\" na ficha (ex.: \"florestas de Varn\") passa a viver na natureza desse lugar."))
	else:
		var lista := Tema.texto_rico()
		lista.fit_content = true
		lista.scroll_active = false
		lista.meta_clicked.connect(livro.navegar)
		var s := ""
		for e in povos:
			var mente := "pensante" if Estado.tem_mente(u, e["id"]) else "natureza"
			s += "• %s · %s · [i]%s[/i]\n" % [Paginas.link("ent:" + e["id"], e["nome"]), Paginas._e(e["tipo"]), mente]
		lista.text = s
		pai.add_child(lista)
	var novo := Tema.botao("+ Novo povo ou espécie")
	novo.pressed.connect(func(): livro.ir_para_aba("criadores", "nova"))
	pai.add_child(novo)

	_fauna_e_flora(pai)
	pai.add_child(Tema.titulo("Planetas e mundos", 28))
	var mundos := u.entidades_ativas().filter(func(e): return Mapa.especie(u, e["id"]) in ["planeta", "cosmico"])
	var txt := Tema.texto_rico()
	txt.fit_content = true
	txt.scroll_active = false
	txt.meta_clicked.connect(livro.navegar)
	var s2 := ""
	for e in mundos:
		var regioes := Mapa.filhos(u, e["id"]).size()
		s2 += "• %s · %s · %s · %d lugares dentro\n" % [Paginas.link("ent:" + e["id"], e["nome"]), Paginas._e(e["tipo"]),
			Paginas._e(u.valor_campo(e["id"], "clima")) if u.valor_campo(e["id"], "clima") != "" else "clima livre", regioes]
	txt.text = s2 if s2 != "" else "[i]Nenhum planeta ainda.[/i]"
	pai.add_child(txt)
	var gerar := Tema.botao_principal("Gerar planeta")
	gerar.pressed.connect(func():
		var p := Povoador.gerar_planeta(u)
		livro.avisar("Nasceu o planeta %s." % u.entidade(p)["nome"])
		livro.set_meta("mapa_lugar", p)
		livro.set_meta("mapa_sel", "")
		livro.ir_para_aba("mapa"))
	var ver := Tema.botao("Ver no mapa")
	ver.pressed.connect(func(): livro.ir_para_aba("mapa"))
	pai.add_child(linha([gerar, ver]))
