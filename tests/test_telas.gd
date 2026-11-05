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
