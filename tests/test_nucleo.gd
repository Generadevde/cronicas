extends TesteBase
## Testes do banco de fatos, entidades, livros e auditor.


func test_universo_nasce_com_fato_de_origem() -> void:
	var u := Universo.novo("Aldra", "fantasia sombria")
	igual(u.fatos.quantidade(), 1, "um fato de origem")
	igual(u.fatos.todos()[0]["tipo"], "origem do universo", "tipo do primeiro fato")


func test_criar_entidade_gera_fato_com_sujeito() -> void:
	var u := Universo.novo("Aldra")
	var daren := u.criar_entidade("Daren", "pessoa", ["filho de Lucas"],
		[{"chave": "medos", "valor": "ser fraco como o pai"}])
	var sobre := u.fatos.sobre(daren)
	igual(sobre.size(), 1, "um fato sobre Daren")
	igual(sobre[0]["tipo"], "criação", "fato de criação")
	igual(u.valor_campo(daren, "Medos"), "ser fraco como o pai", "campo sem diferenciar maiúsculas")


func test_tipo_e_campos_sao_livres() -> void:
	var u := Universo.novo("Teste")
	var e := u.criar_entidade("Gorm", "dragão de gelo que fala com os mortos", [],
		[{"chave": "cor favorita da alma", "valor": "azul"}, {"chave": "", "valor": "ignorado"}])
	igual(u.entidade(e)["tipo"], "dragão de gelo que fala com os mortos", "tipo livre preservado")
	igual(u.entidade(e)["campos"].size(), 1, "campo sem nome é descartado")


func test_editar_entidade_registra_antes_e_depois() -> void:
	var u := Universo.novo("Aldra")
	var lucas := u.criar_entidade("Lucas", "pessoa", [], [{"chave": "ofício", "valor": "carpinteiro"}])
	u.editar_entidade(lucas, {"campos": [{"chave": "ofício", "valor": "ferreiro"}]})
	var ultimo: Dictionary = u.fatos.sobre(lucas).back()
	igual(ultimo["tipo"], "alteração", "fato de alteração")
	igual(ultimo["dados"]["antes"], "carpinteiro", "antes")
	igual(ultimo["dados"]["depois"], "ferreiro", "depois")
	var antes := u.fatos.quantidade()
	u.editar_entidade(lucas, {"campos": [{"chave": "ofício", "valor": "ferreiro"}]})
	igual(u.fatos.quantidade(), antes, "editar sem mudar nada não cria fato")


func test_remover_entidade_preserva_historia() -> void:
	var u := Universo.novo("Aldra")
	var kai := u.criar_entidade("Kai", "pessoa")
	u.remover_entidade(kai)
	verdadeiro(u.entidades.has(kai), "entidade continua no banco")
	falso(u.entidades_ativas().any(func(e): return e["id"] == kai), "some da lista ativa")
	igual(u.fatos.sobre(kai).back()["tipo"], "remoção", "remoção vira fato")
	u.restaurar_entidade(kai)
	verdadeiro(u.entidades_ativas().any(func(e): return e["id"] == kai), "volta ao restaurar")


func test_causas_e_consequencias() -> void:
	var u := Universo.novo("Aldra")
	var a := u.fatos.registrar({"descricao": "Seca no norte", "data": DataMundo.criar(409, 10)})
	var b := u.fatos.registrar({"descricao": "Fome em Varn", "data": DataMundo.criar(409, 90),
		"causas": [a], "origem": {"tipo": BancoDeFatos.ORIGEM_SIMULACAO}})
	var c := u.fatos.registrar({"descricao": "Revolta", "data": DataMundo.criar(410, 5),
		"causas": [b], "origem": {"tipo": BancoDeFatos.ORIGEM_SIMULACAO}})
	igual(u.fatos.consequencias(a).size(), 1, "seca causou a fome")
	var cadeia := u.fatos.cadeia_de_causas(c)
	igual(cadeia.size(), 2, "revolta vem de fome que vem de seca")
	igual(cadeia[1]["id"], a, "a seca é a causa mais distante")


func test_fato_com_causa_inexistente_e_recusado() -> void:
	var u := Universo.novo("Aldra")
	var antes := u.fatos.quantidade()
	var id := u.fatos.registrar({"descricao": "sem base", "causas": ["fato_naoexiste"]})
	igual(id, "", "registrar devolve vazio")
	igual(u.fatos.quantidade(), antes, "nada foi registrado")


func test_auditor_universo_saudavel() -> void:
	var u := Universo.novo("Aldra")
	var e := u.criar_entidade("Varn", "cidade")
	u.editar_entidade(e, {"nome": "Varn Velha"})
	igual(Auditor.auditar(u).size(), 0, "nenhum problema")


func test_auditor_detecta_problemas() -> void:
	var u := Universo.novo("Aldra")
	# Ciclo: x causa y, y causa x (só é possível com dados corrompidos).
	u.fatos._inserir_cru(_fato_cru("fato_x", ["fato_y"], DataMundo.criar(1, 1)))
	u.fatos._inserir_cru(_fato_cru("fato_y", ["fato_x"], DataMundo.criar(1, 1)))
	# Fato da simulação sem causa.
	var solto := _fato_cru("fato_solto", [], DataMundo.criar(1, 1))
	solto["origem"] = {"tipo": BancoDeFatos.ORIGEM_SIMULACAO}
	u.fatos._inserir_cru(solto)
	# Causa que acontece depois do efeito.
	u.fatos._inserir_cru(_fato_cru("fato_depois", [], DataMundo.criar(500, 1)))
	u.fatos._inserir_cru(_fato_cru("fato_antes", ["fato_depois"], DataMundo.criar(10, 1)))
	# Entidade inexistente e causa inexistente.
	var fantasma := _fato_cru("fato_fantasma", ["fato_sumiu"], DataMundo.criar(1, 1))
	fantasma["sujeitos"] = ["ent_naoexiste"]
	u.fatos._inserir_cru(fantasma)

	var tipos := {}
	for p in Auditor.auditar(u):
		tipos[p["tipo"]] = true
	for esperado in ["ciclo", "sem_origem", "causa_depois_do_efeito", "entidade_inexistente", "causa_inexistente"]:
		verdadeiro(tipos.has(esperado), "auditor devia detectar: " + esperado)


func test_livros_capitulos_e_marcadores() -> void:
	var u := Universo.novo("Aldra")
	var l := u.criar_livro("A Vingança de Daren")
	var c1 := u.criar_capitulo(l, "A Praça de Varn")
	var c2 := u.criar_capitulo(l, "O Mestre")
	u.atualizar_capitulo(c2, {"marcado": true, "data": DataMundo.criar(412, 40), "canon": false})
	igual(u.capitulos_marcados().size(), 1, "um marcador")
	igual(u.capitulo(c2)["data"]["ano"], 412, "data do capítulo")
	u.mover_capitulo(c2, -1)
	igual(u.livro(l)["capitulos"][0], c2, "capítulo movido para cima")
	u.atualizar_capitulo(c1, {"texto": "Kai venceu."})
	u.apagar_capitulo(c1)
	falso(u.capitulos.has(c1), "capítulo apagado")
	igual(u.notas.size(), 1, "texto apagado foi guardado nas notas")


func test_salvar_e_carregar_dicionario_preserva_tudo() -> void:
	var u := Universo.novo("Aldra", "mundo de teste")
	var d := u.criar_entidade("Daren", "pessoa", ["o Rancoroso"], [{"chave": "medos", "valor": "fraqueza"}])
	var l := u.criar_livro("Livro I")
	var c := u.criar_capitulo(l, "Cap 1")
	u.atualizar_capitulo(c, {"texto": "Daren viu tudo.", "data": DataMundo.criar(411, 200)})
	u.criar_nota("Ideia", "Daren perdoa no final?")
	var json := JSON.stringify(u.para_dicionario())
	var v := Universo.de_dicionario(JSON.parse_string(json))
	igual(v.nome, "Aldra", "nome")
	igual(v.entidade(d)["apelidos"], ["o Rancoroso"], "apelidos")
	igual(v.capitulo(c)["data"]["ano"], 411, "ano do capítulo volta como inteiro")
	igual(v.fatos.quantidade(), u.fatos.quantidade(), "mesma quantidade de fatos")
	igual(v.fatos.sobre(d).size(), u.fatos.sobre(d).size(), "índice de fatos reconstruído")
	igual(v.notas[0]["texto"], "Daren perdoa no final?", "nota privada")
	igual(Auditor.auditar(v).size(), 0, "universo carregado continua íntegro")


func test_sugestoes_sao_so_sugestoes() -> void:
	verdadeiro(Sugestoes.campos_para("pessoa").has("medos"), "pessoa sugere medos")
	verdadeiro(Sugestoes.campos_para("Cidade flutuante").has("população"), "cidade sugere população")
	var mista := Sugestoes.campos_para("mago dragão")
	verdadeiro(mista.has("medos") and mista.has("habitat"), "tipo misto combina sugestões")
	verdadeiro(Sugestoes.campos_para("xyzzy qualquer coisa").size() > 0, "tipo desconhecido ainda sugere algo")


func _fato_cru(id: String, causas: Array, data: Dictionary) -> Dictionary:
	return {"id": id, "tipo": "teste", "descricao": id, "sujeitos": [], "lugar": "",
		"data": data, "causas": causas, "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR},
		"canon": true, "dados": {}}
