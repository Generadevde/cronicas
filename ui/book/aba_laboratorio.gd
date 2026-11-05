extends AbaLivro
## Aba "Laboratório": testar futuros sem perder a história, e cuidar da integridade.
##   Ramos — abrir possibilidades, deixá-las correr, comparar, escolher o canon;
##   Versões — fotos do mundo para voltar atrás;
##   Destinos — metas que o mundo tenta alcançar sem forçar;
##   Integridade — auditores, recuperação histórica e memória;
##   Trocar — exportar e importar universos (e páginas do WikidPad).

static var _modo := "ramos"
static var _comparacao: Array = []

var _dir: VBoxContainer


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	esq.add_child(Tema.secao("Laboratório e integridade"))
	for mm in [["ramos", "Ramos (e se…?)"], ["versoes", "Versões"], ["destinos", "Destinos do autor"], ["integridade", "Integridade"], ["trocar", "Importar e exportar"]]:
		var b := Tema.botao(mm[1])
		b.toggle_mode = true
		b.button_pressed = mm[0] == _modo
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_modo = mm[0]
			livro.ir_para_aba("laboratorio"))
		esq.add_child(b)
	var t := Tema.texto_rico()
	t.meta_clicked.connect(_meta)
	match _modo:
		"ramos":
			_controles_ramos()
			t.text = _ramos()
		"versoes":
			_controles_versoes()
			t.text = _versoes()
		"destinos":
			_controles_destinos()
			t.text = _destinos()
		"integridade":
			_controles_integridade()
			t.text = _integridade()
		"trocar":
			_controles_trocar()
			t.text = Paginas.cabecalho("Importar e exportar") + "[i]Exportar cria uma pasta com o universo inteiro (universo.json), uma página por entidade, as leis, a cronologia e os mapas em texto.\n\nImportar aceita um universo exportado (vira um universo novo na estante) ou uma pasta de textos — como as páginas do WikidPad: cada arquivo vira uma entidade; linhas \"chave: valor\" e atributos \"[chave: valor]\" viram campos.[/i]\n\nPasta de dados do programa: [b]%s[/b]" % OS.get_user_data_dir()
	_dir.add_child(t)


func _b() -> Biblioteca:
	return Cronica.biblioteca


func _meta(meta) -> void:
	var m := str(meta)
	if m.begins_with("canon:"):
		var rid := m.trim_prefix("canon:")
		livro.confirmar("Este ramo vira o canon? A história de agora fica guardada como uma versão.", func():
			var r := _b().carregar(rid)
			if r == null:
				return
			var novo := Laboratorio.tornar_canon(u, r, _b())
			Cronica._definir_universo(novo)
			livro.universo = novo
			livro.avisar("O ramo virou o canon.")
			livro.ir_para_aba("laboratorio"))
	elif m.begins_with("voltar:"):
		var arq := m.trim_prefix("voltar:")
		livro.confirmar("Voltar para esta versão? A situação de agora fica guardada como outra versão.", func():
			var novo := Versoes.voltar(_b(), u, arq)
			if novo != null:
				Cronica._definir_universo(novo)
				livro.universo = novo
				livro.atualizar_cabecalho()
				livro.ir_para_aba("laboratorio"))
	elif m.begins_with("restaurar:"):
		var n := Integridade.restaurar(u, m.trim_prefix("restaurar:"))
		livro.avisar("%d acontecimento(s) voltaram a valer." % n)
		livro.ir_para_aba("laboratorio")
	else:
		livro.navegar(meta)


# ---------------------------------------------------------------- ramos

func _controles_ramos() -> void:
	var abrir := Tema.botao_principal("Abrir um ramo…")
	abrir.pressed.connect(func():
		livro.pedir_texto("Abrir um ramo", "O que muda neste ramo (ex.: a general Varga dá um golpe no Reino de Varn)", "", func(t: String):
			if t.strip_edges() == "":
				return
			Cronica.salvar_agora()
			var r := Laboratorio.abrir_ramo(u, t.strip_edges().substr(0, 40))
			var o_que := Laboratorio.mudar(r, t)
			_b().salvar(r)
			livro.avisar("Ramo aberto. %s" % o_que)
			livro.ir_para_aba("laboratorio")))
	var botoes: Array = [abrir]
	for par in [["+1 ano", 360], ["+10 anos", 3600]]:
		var b := Tema.botao("Ramos " + par[0], "Cada ramo avança sozinho (o canon não muda)")
		b.pressed.connect(func():
			for item in Versoes.ramos(_b(), u.id):
				var r := _b().carregar(item["id"])
				if r != null:
					Simulador.avancar(r, par[1])
					_b().salvar(r)
			_comparacao = []
			livro.ir_para_aba("laboratorio"))
		botoes.append(b)
	var comp := Tema.botao("Comparar", "Quem governa, quem morreu, que guerras e lendas, em cada ramo")
	comp.pressed.connect(func():
		var rs: Array = []
		for item in Versoes.ramos(_b(), u.id):
			var r := _b().carregar(item["id"])
			if r != null:
				rs.append(r)
		_comparacao = Laboratorio.comparar(rs)
		livro.ir_para_aba("laboratorio"))
	botoes.append(comp)
	_dir.add_child(linha(botoes))


func _ramos() -> String:
	var s := Paginas.cabecalho("Ramos do universo", "possibilidades que não tocam o canon")
	var rs := Versoes.ramos(_b(), u.id)
	if rs.is_empty():
		return s + "[i]Nenhum ramo ainda. Abra um: escreva o que muda (\"o príncipe assume o trono\", \"o general dá um golpe\", \"o conselheiro faz um pacto com a Mãe das Cinzas\").[/i]"
	s += Paginas.secao("Árvore")
	s += "• [b]%s[/b] (o canon, %s)\n" % [Paginas._e(u.nome), DataMundo.texto(u.relogio)]
	for r in rs:
		s += "   └ %s — separou-se em %s · %s\n" % [Paginas._e(r["nome"]), DataMundo.texto(Paginas._data_de_ordem(int(r["desde"]))), Paginas.link("canon:" + r["id"], "tornar canon")]
	if not _comparacao.is_empty():
		s += Paginas.secao("Comparação")
		for t in _comparacao:
			s += "[b]%s[/b] (%s, %d acontecimentos)\n" % [Paginas._e(t["nome"]), t["data"], int(t["fatos"])]
			for soc in t["governos"]:
				s += "   governa %s: %s\n" % [soc, t["governos"][soc]]
			s += "   morreram: %s\n" % (", ".join(t["mortos"].slice(0, 8)) if not t["mortos"].is_empty() else "ninguém importante")
			if not t["guerras"].is_empty():
				s += "   guerras: %s\n" % "; ".join(t["guerras"].slice(0, 3))
			if not t["lendas"].is_empty():
				s += "   lendas e cultura: %s\n" % "; ".join(t["lendas"].slice(0, 3))
	return s


# ---------------------------------------------------------------- versões

func _controles_versoes() -> void:
	var salvar := Tema.botao_principal("Salvar uma versão…")
	salvar.pressed.connect(func():
		livro.pedir_texto("Salvar uma versão", "Nome (ex.: antes da guerra)", DataMundo.texto(u.relogio), func(t: String):
			Cronica.salvar_agora()
			Versoes.salvar(_b(), u, t.strip_edges() if t.strip_edges() != "" else DataMundo.texto(u.relogio))
			livro.ir_para_aba("laboratorio")))
	_dir.add_child(linha([salvar]))


func _versoes() -> String:
	var s := Paginas.cabecalho("Versões do universo", "fotos do mundo para voltar atrás")
	var vs := Versoes.listar(_b(), u.id)
	if vs.is_empty():
		return s + "[i]Nenhuma versão salva ainda.[/i]"
	for v in vs:
		s += "• [b]%s[/b] — mundo em %s, %d acontecimentos (salva em %s) · %s\n" % [Paginas._e(v["nome"]), v["data_do_mundo"], int(v["fatos"]), v["salva_em"], Paginas.link("voltar:" + v["arquivo"], "voltar para esta")]
	return s


# ---------------------------------------------------------------- destinos

func _controles_destinos() -> void:
	var campo_d := campo("Ex.: Daren encontra Kai antes do ano 420")
	campo_d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var marcar := Tema.botao_principal("Marcar destino")
	marcar.pressed.connect(func():
		var d := Destinos.marcar(u, campo_d.text)
		livro.avisar("Destino marcado." if not d.is_empty() else "Não entendi. Use: quem + encontra/mata/casa com/governa + quem, e \"antes do ano N\".")
		livro.ir_para_aba("laboratorio"))
	_dir.add_child(linha([campo_d, marcar]))


func _destinos() -> String:
	var s := Paginas.cabecalho("Destinos do autor", "o mundo tenta, sem forçar")
	var ds := Destinos.todos(u)
	if ds.is_empty():
		return s + "[i]Nenhum destino marcado.[/i]"
	for d in ds:
		s += "• %s — [b]%s[/b]\n" % [Paginas._e(d["texto"]), {"aberto": "em curso", "cumprido": "cumprido", "falhou": "não se cumpriu"}.get(d["estado"], d["estado"])]
	return s


# ---------------------------------------------------------------- integridade

func _controles_integridade() -> void:
	var arq := Tema.botao("Arquivar notícias antigas", "Notícias miúdas com mais de 20 anos vão para o arquivo do universo (nada se perde)")
	arq.pressed.connect(func():
		var n := Integridade.arquivar(u, 20, "%s/%s/arquivo" % [_b().pasta, u.id])
		livro.avisar("%d notícias arquivadas." % n)
		livro.ir_para_aba("laboratorio"))
	_dir.add_child(linha([arq]))


func _integridade() -> String:
	var s := Paginas.cabecalho("Integridade", "o que mantém o mundo coerente")
	var r := Integridade.auditar_tudo(u)
	var nomes := {"causalidade": "Auditor de causalidade", "continuidade": "Auditor de continuidade", "conhecimento": "Controle de conhecimento", "simulacao": "Controle de simulação"}
	for k in nomes:
		var lista: Array = r[k]
		s += "[b]%s:[/b] %s\n" % [nomes[k], "[color=#3F6A3A]tudo certo[/color]" if lista.is_empty() else "[color=#7A2418]%d problema(s)[/color]" % lista.size()]
		for p in lista.slice(0, 5):
			s += "   • %s%s\n" % [Paginas._e(str(p["mensagem"])), (" " + Paginas.link("fato:" + str(p["fato"]), "(fato)")) if str(p.get("fato", "")) != "" else ""]
	var mem := Integridade.memoria(u)
	s += Paginas.secao("Memória")
	s += "%d acontecimentos, %d entidades, cerca de %s KB · %d arquivados\n" % [int(mem["fatos"]), int(mem["entidades"]), Paginas._numero(float(mem["bytes"]) / 1024.0), int(mem["arquivados"])]
	var tipos: Array = mem["por_tipo"].keys()
	tipos.sort_custom(func(a, b): return int(mem["por_tipo"][a]) > int(mem["por_tipo"][b]))
	s += "[color=#5A3A1A]%s[/color]\n" % ", ".join(tipos.slice(0, 8).map(func(t): return "%s: %d" % [t, int(mem["por_tipo"][t])]))
	var desf := Integridade.desfeitos(u)
	s += Paginas.secao("Recuperação histórica (desfeitos)")
	if desf.is_empty():
		s += "[i]Nada desfeito.[/i]\n"
	for f in desf.slice(0, 15):
		s += "• %s — %s · %s\n" % [DataMundo.texto(f["data"]), Paginas._e(f["descricao"]), Paginas.link("restaurar:" + f["id"], "restaurar")]
	return s


# ---------------------------------------------------------------- trocar

func _controles_trocar() -> void:
	var exp := Tema.botao_principal("Exportar este universo")
	exp.pressed.connect(func():
		var pasta := "user://exportacoes/%s_%s" % [Troca._nome_arquivo(u.nome), Time.get_datetime_string_from_system().replace(":", "-")]
		var n := Troca.exportar(u, pasta)
		livro.avisar("%d arquivos em %s" % [n, ProjectSettings.globalize_path(pasta)]))
	var imp := Tema.botao("Importar universo…")
	imp.pressed.connect(func():
		livro.pedir_texto("Importar universo", "Caminho da pasta exportada (ou do universo.json)", "", func(t: String):
			var novo := Troca.importar_universo(t.strip_edges())
			if novo == null:
				livro.avisar("Não achei um universo nesse caminho.")
				return
			_b().salvar(novo)
			livro.avisar("\"%s\" está na estante." % novo.nome)))
	var txt := Tema.botao("Importar páginas (WikidPad, .txt, .md)…")
	txt.pressed.connect(func():
		livro.pedir_texto("Importar páginas", "Caminho da pasta com as páginas", "", func(t: String):
			var novas := Troca.importar_textos(u, t.strip_edges())
			livro.avisar("%d entidades criadas a partir das páginas." % novas.size())
			livro.ir_para_aba("wiki", novas[0] if not novas.is_empty() else "")))
	_dir.add_child(linha([exp, imp, txt]))
