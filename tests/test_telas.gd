extends TesteBase
## Abre as telas de verdade (sem janela) e passa por todas as abas e links,
## para garantir que nada quebra ao montar.

const PASTA := "user://teste_telas_universos"
const LIXEIRA := "user://teste_telas_lixeira"

var _nos: Array = []


func _cronica() -> Node:
	var c := arvore.root.get_node_or_null("Cronica")
	if c == null:
		c = load("res://core/cronica.gd").new()
		c.name = "Cronica"
		arvore.root.add_child(c)
	c.biblioteca = Biblioteca.new(PASTA, LIXEIRA)
	return c


func _universo_exemplo(c: Node) -> Universo:
	var u: Universo = c.criar_universo("Aldra", "Fantasia de teste.")
	var daren := u.criar_entidade("Daren", "pessoa", ["o Rancoroso"], [{"chave": "medos", "valor": "ser fraco como Lucas"}])
	u.criar_entidade("Lucas", "pessoa", [], [{"chave": "ofício", "valor": "ferreiro em Varn"}])
	u.criar_entidade("Varn", "cidade")
	var l := u.criar_livro("A Vingança de Daren")
	var cap := u.criar_capitulo(l, "A Praça de Varn")
	u.atualizar_capitulo(cap, {"texto": "Kai enfrentou Lucas na praça de Varn. Daren viu tudo.", "marcado": true})
	u.criar_nota("Ideia", "Daren perdoa no fim?")
	u.editar_entidade(daren, {"campos": [{"chave": "medos", "valor": "ser fraco"}]})
	return u


func _abrir(caminho: String) -> Node:
	var cena: PackedScene = load(caminho)
	var no := cena.instantiate()
	arvore.root.add_child(no)
	_nos.append(no)
	return no


func test_livro_monta_todas_as_abas_e_links() -> void:
	var c := _cronica()
	var u := _universo_exemplo(c)
	var livro := _abrir("res://ui/book/book.tscn")
	await arvore.process_frame
	for a in livro.ABAS:
		livro.ir_para_aba(a["id"])
		await arvore.process_frame
		verdadeiro(livro._esq.get_child_count() > 0, "aba %s montou a página esquerda" % a["id"])
		verdadeiro(livro._dir.get_child_count() > 0, "aba %s montou a página direita" % a["id"])
	var ent: String = u.entidades_ativas()[0]["id"]
	for meta in ["ent:" + ent, "cap:" + u.capitulos.keys()[0], "fato:" + u.fatos.todos()[0]["id"], "nota:" + u.notas[0]["id"]]:
		livro.navegar(meta)
		await arvore.process_frame
	igual(livro.aba_atual, "notas", "último link abriu as notas")
	livro.ir_para_aba("pesquisa", "darn")
	await arvore.process_frame
	verdadeiro(livro._aba_obj._itens.size() > 0, "pesquisa rápida encontrou Daren com erro de digitação")


func test_criadores_salva_entidade_pelo_formulario() -> void:
	var c := _cronica()
	var u := _universo_exemplo(c)
	var livro := _abrir("res://ui/book/book.tscn")
	await arvore.process_frame
	livro.ir_para_aba("criadores", "nova")
	await arvore.process_frame
	var aba = livro._aba_obj
	aba._nome.text = "Gorm"
	aba._tipo.text = "dragão de gelo"
	aba._sugerir()
	aba._salvar()
	var gorm: Array = u.entidades_ativas().filter(func(e): return e["nome"] == "Gorm")
	igual(gorm.size(), 1, "Gorm foi criado")
	verdadeiro(gorm[0]["campos"].size() > 0, "campos sugeridos foram guardados")


func test_margem_mostra_e_aceita_propostas() -> void:
	var c := _cronica()
	var u := _universo_exemplo(c)
	var cid: String = u.capitulos.keys()[0]
	var livro := _abrir("res://ui/book/book.tscn")
	await arvore.process_frame
	livro.ir_para_aba("escrever", cid)
	await arvore.process_frame
	var aba = livro._aba_obj
	aba._trocar_modo("margem")
	var pendentes: Array = u.propostas_do_capitulo(cid).filter(func(p): return p["status"] == "pendente")
	verdadeiro(pendentes.size() > 0, "abrir o capítulo já analisou o texto")
	if pendentes.is_empty():
		return
	var antes := u.fatos.quantidade()
	aba._cartao_fato(pendentes[0])  # monta sem erro
	u.aceitar_proposta(pendentes[0]["id"])
	aba._trocar_modo("margem")
	verdadeiro(u.fatos.quantidade() > antes, "aceitar gerou fato")
	aba._trocar_modo("versoes")
	aba._trocar_modo("estante")
	verdadeiro(aba._arvore != null, "estante montada")


func test_avancar_o_tempo_pela_tela() -> void:
	var c := _cronica()
	var u := _universo_exemplo(c)
	var livro := _abrir("res://ui/book/book.tscn")
	await arvore.process_frame
	livro.ir_para_aba("jornal")
	var antes := DataMundo.ordem(u.relogio)
	livro.avancar_tempo(360)
	await arvore.process_frame
	igual(DataMundo.ordem(u.relogio) - antes, 360, "um ano passou")
	livro.ir_para_aba("mundo")
	livro._aba_obj._modo = "observatorio"
	livro._aba_obj._obs_ent = u.entidades_ativas()[0]["id"]
	livro._aba_obj._montar_direita()
	livro.definir_ritmo(7)
	livro._passo_vivo()
	livro.definir_ritmo(0)
	verdadeiro(DataMundo.ordem(u.relogio) - antes == 367, "mundo vivo andou uma semana")


func test_menu_posiciona_botoes_sobre_a_arte() -> void:
	_cronica()
	var menu := _abrir("res://ui/menu/menu.tscn")
	await arvore.process_frame
	menu._posicionar()
	var b: Button = menu._botoes["continuar"]["botao"]
	var tela := Rect2(Vector2.ZERO, menu.size)
	verdadeiro(b.size.x > 0 and tela.encloses(Rect2(b.position, b.size)), "botão Continuar dentro da tela (%s em %s)" % [Rect2(b.position, b.size), menu.size])
	verdadeiro(b.position.x > menu.size.x * 0.5, "botão fica na página direita da arte")


func test_biblioteca_lista_universos() -> void:
	var c := _cronica()
	_universo_exemplo(c)
	c.salvar_agora()
	var tela := _abrir("res://ui/library/library.tscn")
	await arvore.process_frame
	verdadeiro(tela._lista.get_child_count() >= 1, "estante mostra o universo")


func limpar() -> void:
	for n in _nos:
		if is_instance_valid(n):
			n.queue_free()
	_nos.clear()
	for caminho in [PASTA, LIXEIRA]:
		_apagar_pasta(caminho)


func _apagar_pasta(caminho: String) -> void:
	if not DirAccess.dir_exists_absolute(caminho):
		return
	for sub in DirAccess.get_directories_at(caminho):
		_apagar_pasta(caminho + "/" + sub)
	for arq in DirAccess.get_files_at(caminho):
		DirAccess.remove_absolute(caminho + "/" + arq)
	DirAccess.remove_absolute(caminho)


func test_ajustes_de_leitura() -> void:
	var antes := Tema.prefs.duplicate()
	Tema.salvar_preferencias({"texto": "kalam", "escrita": "petit", "tamanho": 1.2})
	Tema.carregar_preferencias()
	igual(Tema.prefs["texto"], "kalam", "fonte do texto guardada")
	igual(Tema.prefs["escrita"], "petit", "fonte da escrita guardada")
	igual(Tema.px(20), 24, "tamanho com escala")
	verdadeiro(Tema.escrita() != null and Tema.italico() != null, "fontes carregam")
	verdadeiro(Tema.construir().default_font == Tema.corpo(), "tema usa a fonte escolhida")
	Tema.salvar_preferencias({"texto": "inexistente", "tamanho": 9.0})
	Tema.carregar_preferencias()
	igual(Tema.prefs["texto"], "garamond", "fonte desconhecida volta ao padrão")
	igual(Tema.prefs["tamanho"], 1.6, "tamanho limitado")
	# A janela monta e o livro se remonta depois de aplicar.
	var c := _cronica()
	_universo_exemplo(c)
	var livro := _abrir("res://ui/book/book.tscn")
	livro.ir_para_aba("escrever")
	var d := AjustesLeitura.abrir(livro, func(): pass)
	verdadeiro(d != null, "janela de ajustes abre")
	d.hide()
	Tema.salvar_preferencias(antes if not antes.is_empty() else Tema.PREFS_PADRAO)
	livro.abrir_ajustes_de_leitura()
	for w in livro.get_children():
		if w is ConfirmationDialog and w.title == "Ajustes de leitura":
			w.confirmed.emit()
	verdadeiro(livro.aba_atual == "escrever", "continua na aba")
	var timers := livro.get_children().filter(func(n): return n is Timer).size()
	igual(timers, 1, "remontar não duplica o relógio do mundo vivo")


func test_mapa_pela_tela() -> void:
	var c := _cronica()
	var u := _universo_exemplo(c)
	var planeta := Povoador.gerar_planeta(u)
	var livro := _abrir("res://ui/book/book.tscn")
	await arvore.process_frame
	livro.ir_para_aba("mapa", planeta)
	await arvore.process_frame
	igual(livro.get_meta("mapa_sel"), planeta, "o planeta ficou escolhido no cosmos")
	# Entrar no planeta: dois cliques seguidos.
	var aba = livro._aba_obj
	var pos := Mapa.posicao(u, planeta)
	aba._clicou(int(pos["x"]), int(pos["y"]), planeta)
	livro._aba_obj._clicou(int(pos["x"]), int(pos["y"]), planeta)
	await arvore.process_frame
	igual(livro.get_meta("mapa_lugar"), planeta, "entrou no planeta")
	verdadeiro(livro._aba_obj._mapa.lugar == planeta, "o mapa mostra o planeta")
	# Escrever no mapa.
	livro.set_meta("mapa_modo", "escrever")
	livro.ir_para_aba("mapa")
	var livres := Mapa.celulas_livres(u, planeta, ["campo", "planicie", "floresta", "colina", "montanha", "deserto"])
	var cel: Vector2i = livres[0]
	livro._aba_obj._clicou(cel.x, cel.y, "")
	var dialogo: ConfirmationDialog = null
	for n in livro.get_children():
		if n is ConfirmationDialog and n.visible:
			dialogo = n
	verdadeiro(dialogo != null, "pediu o texto")
	if dialogo != null:
		var campo: LineEdit = dialogo.get_children().filter(func(x): return x is LineEdit)[0]
		campo.text = "uma casa na montanha"
		dialogo.confirmed.emit()
		dialogo.hide()
	await arvore.process_frame
	var casa := Mapa.em(u, planeta, cel.x, cel.y)
	verdadeiro(casa != "" and u.entidade(casa)["tipo"] == "casa", "a casa apareceu no mapa")
	# Pintar arrastando vira um fato só.
	livro.set_meta("mapa_modo", "pintar")
	livro.ir_para_aba("mapa")
	var antes := u.fatos.quantidade()
	livro._aba_obj._clicou(1, 1, "")
	livro._aba_obj._arrastou(2, 1)
	livro._aba_obj._arrastou(3, 1)
	livro._aba_obj._soltou()
	igual(u.fatos.quantidade(), antes + 1, "uma sessão de pintura, um fato")
	# Intervir aqui, pela página do lugar.
	livro.set_meta("mapa_modo", "ver")
	livro.set_meta("mapa_sel", casa)
	livro.ir_para_aba("mapa")
	await arvore.process_frame
	verdadeiro(MapaTexto.descricao_curta(u, casa).begins_with(u.entidade(casa)["nome"]), "passar o mouse mostra o lugar")
	livro.ir_para_aba("universo")
	await arvore.process_frame
	verdadeiro(livro._esq.get_child_count() > 0, "aba Universo montou")


func test_aba_leis_mostra_o_que_falta() -> void:
	var c := _cronica()
	var u := _universo_exemplo(c)
	var kai := u.criar_entidade("Kai", "pessoa", [], [{"chave": "segredos", "valor": "matou o irmão"}])
	Regras.criar(u, "Quem usa magia envelhece um ano por feitiço.")
	var livro := _abrir("res://ui/book/book.tscn")
	await arvore.process_frame
	livro.ir_para_aba("leis")
	await arvore.process_frame
	verdadeiro(livro._fitas["leis"]["botao"].text.begins_with("Leis ("), "a fita mostra quantas coisas estão sem efeito")
	var item: Dictionary = Pendencias.listar(u).filter(func(i): return i["tipo"] == "campo" and i["chave"] == "segredos")[0]
	Pendencias.definir(u, item, "fica desconfiado")
	livro.atualizar_cabecalho()
	livro.ir_para_aba("leis")
	await arvore.process_frame
	verdadeiro(Regras.todas(u).size() == 2, "a definição virou lei")
	verdadeiro(u.fatos.sobre(kai).any(func(f): return f["tipo"] == "efeito de lei"), "e já valeu para Kai")
