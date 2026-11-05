extends AbaLivro
## Aba "Jornal": o que o mundo fez enquanto você escrevia.
## Página esquerda: manchetes (o mais importante). Página direita: bilhetes curtos.
## Cada notícia pode ser lida (com as causas), virar capítulo ou ser desfeita.

var _todas := false


func montar(esq: VBoxContainer, dir: VBoxContainer, _dado: String) -> void:
	var desde := 0 if _todas else u.jornal_lido_ate()
	var itens := Observatorio.noticias(u, desde, 0.3)
	var manchetes: Array = itens.filter(func(f): return float(f["dados"].get("importancia", 0.3)) >= 0.55)
	var bilhetes: Array = itens.filter(func(f): return float(f["dados"].get("importancia", 0.3)) < 0.55)

	var cab := VBoxContainer.new()
	cab.add_child(Tema.titulo("A Gazeta de %s" % u.nome, 38))
	var sub := Tema.rotulo("%s · %s" % [DataMundo.texto(u.relogio), "todas as edições" if _todas else "notícias novas"], 16, Tema.F_FELL_IT, Tema.TINTA_SUAVE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cab.add_child(sub)
	cab.add_child(Tema.ornamento())
	esq.add_child(cab)

	var lista_m := VBoxContainer.new()
	lista_m.add_theme_constant_override("separation", 14)
	esq.add_child(rolagem(lista_m))
	if manchetes.is_empty():
		var vazio := Tema.rotulo("Nenhuma grande notícia. Avance o tempo do mundo (no alto da tela) ou escreva: o mundo responde.", 18, Tema.F_ITALICO, Tema.TINTA_SUAVE)
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista_m.add_child(vazio)
	for f in manchetes.slice(0, 30):
		lista_m.add_child(_noticia(f, true))

	var topo := HBoxContainer.new()
	var titulo := Tema.rotulo("Bilhetes", 26, Tema.F_FELL_IT)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	var b_lido := Tema.botao("Marcar tudo como lido")
	b_lido.pressed.connect(func():
		u.marcar_jornal_lido()
		livro.atualizar_cabecalho()
		livro.ir_para_aba("jornal"))
	topo.add_child(b_lido)
	var b_todas := Tema.botao("Ver as novas" if _todas else "Edições anteriores")
	b_todas.pressed.connect(func():
		_todas = not _todas
		Tema.limpar(esq)
		Tema.limpar(dir)
		montar(esq, dir, ""))
	topo.add_child(b_todas)
	dir.add_child(topo)
	var lista_b := VBoxContainer.new()
	lista_b.add_theme_constant_override("separation", 10)
	dir.add_child(rolagem(lista_b))
	if bilhetes.is_empty():
		lista_b.add_child(Tema.rotulo("Nenhum bilhete.", 17, Tema.F_ITALICO, Tema.TINTA_SUAVE))
	for f in bilhetes.slice(0, 60):
		lista_b.add_child(_noticia(f, false))


func _noticia(f: Dictionary, grande: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var onde := ""
	if f["lugar"] != "" and u.entidades.has(f["lugar"]):
		onde = " · " + u.entidade(f["lugar"])["nome"]
	v.add_child(Tema.rotulo("%s%s · %s" % [DataMundo.texto(f["data"]), onde, f["tipo"]], 14, Tema.F_VERSALETE, Tema.VERMELHO if grande else Tema.TINTA_SUAVE))
	var t := Tema.rotulo(f["descricao"], 24 if grande else 18, Tema.F_FELL if grande else null)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var ler := Tema.botao("Por quê?", "Ver as causas e consequências deste fato")
	ler.pressed.connect(func(): livro.navegar("fato:" + f["id"]))
	var escrever := Tema.botao("Escrever sobre isso", "Cria um capítulo com esta notícia como semente")
	escrever.pressed.connect(func(): _escrever_sobre(f))
	var desfazer := Tema.botao("Desfazer", "Isto (e o que isto causou) deixa de ter acontecido; fica guardado")
	desfazer.pressed.connect(func():
		livro.confirmar("Desfazer \"%s\"?\nTudo o que isto causou também deixa de valer. Os fatos continuam guardados." % f["descricao"], func():
			var n := u.desfazer_fato(f["id"])
			livro.avisar("%d fato(s) deixaram de valer." % n)
			livro.ir_para_aba("jornal")))
	v.add_child(linha([ler, escrever, desfazer]))
	return v


func _escrever_sobre(f: Dictionary) -> void:
	var lid := ""
	if u.livros.is_empty():
		lid = u.criar_livro("Crônicas soltas")
	else:
		lid = u.livros.back()["id"]
	var cid := u.criar_capitulo(lid, f["descricao"].left(60))
	u.atualizar_capitulo(cid, {"data": f["data"], "canon": false,
		"texto": "[Semente: %s]\n\n" % f["descricao"]})
	livro.ir_para_aba("escrever", cid)
