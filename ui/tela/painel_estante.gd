class_name PainelEstante
extends RefCounted
## Estante do universo: sagas e, dentro delas, os livros. Abrir, criar, renomear,
## apagar (o texto vai para as notas) e exportar em texto.


static func montar(tela, pai: VBoxContainer) -> void:
	var u: Universo = tela.universo
	pai.add_theme_constant_override("separation", 10)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	var nome := Tema.rotulo(u.nome, 24, Tema.F_FELL, Tema.TINTA)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(nome)
	var nova := Tema.botao("Nova saga", "Uma saga junta vários livros")
	nova.pressed.connect(func(): tela.pedir_texto("Nova saga", "nome da saga", "Saga %d" % (u.livros.size() + 1), func(t: String):
		if t.strip_edges() != "":
			u.criar_livro(t)
			tela.abrir_painel("estante")))
	topo.add_child(nova)
	var exp := Tema.botao("Exportar em texto", "Salva os livros como arquivos de texto na sua pasta de Documentos")
	exp.pressed.connect(func():
		var pasta := exportar(u)
		tela.avisar("Exportado em: " + pasta)
		OS.shell_open(pasta))
	topo.add_child(exp)
	var trocar := Tema.botao("Outro universo", "Voltar à estante de universos")
	trocar.pressed.connect(func(): Cronica.ir_para("biblioteca"))
	topo.add_child(trocar)
	pai.add_child(topo)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 14)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rol := ScrollContainer.new()
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rol.add_child(lista)
	pai.add_child(rol)
	for saga in u.livros:
		var sid := str(saga["id"])
		var cab := HBoxContainer.new()
		cab.add_theme_constant_override("separation", 10)
		var t := Tema.rotulo(str(saga["titulo"]), 22, Tema.F_VERSALETE, Tema.VERMELHO)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cab.add_child(t)
		var novo := Tema.botao("Novo livro")
		novo.pressed.connect(func(): tela.pedir_texto("Novo livro", "título do livro", "Livro %d" % (saga["capitulos"].size() + 1), func(tt: String):
			if tt.strip_edges() != "":
				tela.abrir_livro(u.criar_capitulo(sid, tt))))
		cab.add_child(novo)
		var ren := Tema.botao("Renomear")
		ren.pressed.connect(func(): tela.pedir_texto("Renomear saga", "nome", str(saga["titulo"]), func(tt: String):
			u.renomear_livro(sid, tt)
			tela.abrir_painel("estante")))
		cab.add_child(ren)
		lista.add_child(cab)
		if saga["capitulos"].is_empty():
			lista.add_child(Tema.rotulo("   (nenhum livro ainda)", 17, Tema.italico(), Tema.TINTA_SUAVE))
		for c in saga["capitulos"]:
			var id := str(c)
			var cap := u.capitulo(id)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var abrir := LinkButton.new()
			abrir.text = "%s%s" % [str(cap["titulo"]) if str(cap["titulo"]) != "" else "(sem título)", "   ← aberto" if id == tela.cid else ""]
			abrir.add_theme_font_override("font", Tema.F_FELL)
			abrir.add_theme_font_size_override("font_size", Tema.px(21))
			abrir.add_theme_color_override("font_color", Tema.TINTA)
			abrir.pressed.connect(func(): tela.abrir_livro(id))
			h.add_child(abrir)
			var palavras := str(cap["texto"]).split(" ", false).size()
			var info := Tema.rotulo("%d palavras · %s" % [palavras, DataMundo.texto(cap["data"])], 15, Tema.italico(), Tema.TINTA_SUAVE)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(info)
			var apagar := Tema.botao("Apagar", "O texto vai para as notas; nada se perde")
			apagar.pressed.connect(func(): tela.confirmar("Apagar o livro \"%s\"? O texto vai para as notas." % str(cap["titulo"]), func():
				u.apagar_capitulo(id)
				if id == tela.cid:
					tela.cid = ""
					tela._abrir_onde_parou()
				tela.abrir_painel("estante")))
			h.add_child(apagar)
			lista.add_child(h)


## Escreve cada livro em dois arquivos: tudo, e só as linhas do autor. Devolve a pasta.
static func exportar(u: Universo, base: String = "") -> String:
	if base == "":
		base = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if base == "":
			base = OS.get_user_data_dir()
	var pasta := "%s/Cronica/%s" % [base, _arquivo(u.nome)]
	DirAccess.make_dir_recursive_absolute(pasta)
	for saga in u.livros:
		for c in saga["capitulos"]:
			var cap := u.capitulo(str(c))
			var nome := "%s - %s" % [_arquivo(str(saga["titulo"])), _arquivo(str(cap["titulo"]))]
			var texto := str(cap["texto"])
			_escrever("%s/%s.txt" % [pasta, nome], "%s\n%s\n\n%s" % [str(cap["titulo"]), str(saga["titulo"]), texto])
			var lidas: Dictionary = cap.get("lidas", {})
			var minhas: Array = []
			for linha in texto.split("\n"):
				var frases := Escrita.frases_prontas(linha + "\n")
				var do_mundo: bool = not frases.is_empty() and frases.all(func(f): return str(lidas.get(Escrita.chave(f), "")) == "mundo")
				if not do_mundo:
					minhas.append(linha)
			_escrever("%s/%s (só as minhas linhas).txt" % [pasta, nome], "%s\n%s\n\n%s" % [str(cap["titulo"]), str(saga["titulo"]), "\n".join(minhas)])
	return pasta


static func _arquivo(nome: String) -> String:
	var t := nome.strip_edges()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		t = t.replace(ch, "-")
	return t if t != "" else "sem nome"


static func _escrever(caminho: String, texto: String) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f != null:
		f.store_string(texto)
		f.close()
