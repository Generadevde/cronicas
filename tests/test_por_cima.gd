extends TesteBase
## Escrever "por cima": números como se escreve, lugares e pessoas pelo nome, títulos
## ainda sem nome, o que está por vir, perguntas ao Livro, o laboratório de confronto
## e a tela única (página, margem, estante e painéis).

const PASTA := "user://teste_porcima_universos"
const LIXEIRA := "user://teste_porcima_lixeira"

var _nos: Array = []


func _novo() -> Dictionary:
	var u := Universo.novo("Por cima")
	u.extras["semente"] = 5
	var l := u.criar_livro("Saga")
	return {"u": u, "cap": u.criar_capitulo(l, "Livro I")}


func _escrever(u: Universo, cid: String, texto: String) -> Array:
	u.atualizar_capitulo(cid, {"texto": str(u.capitulo(cid)["texto"]) + texto + "\n"})
	return Escrita.processar(u, cid)


func _achar(u: Universo, nome: String) -> String:
	for e in u.entidades_ativas():
		if e["nome"] == nome:
			return e["id"]
	return ""


func _tipos(c: Dictionary) -> Array:
	return c["itens"].map(func(i): return i["tipo"])


func test_numeros_como_se_escreve() -> void:
	igual(LeitorMais.milhares("viviam 3.700 habitantes."), "viviam 3700 habitantes.", "ponto de milhar")
	igual(LeitorMais.por_extenso("tres mil e duzentos pescadores").strip_edges(), "3200 pescadores", "por extenso")
	igual(LeitorMais.por_extenso("um rei cruel").strip_edges(), "um rei cruel", "artigo não vira número")
	igual(Extrator.frases("Viviam 3.700 pessoas. Fim.").size(), 2, "3.700 não corta a frase")


func test_a_frase_de_austin() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	var c: Array = _escrever(u, m["cap"], "Na cidade de Austin viviam 3.700 habitantes até a chegada do imperador.")
	igual(c.size(), 1, "uma frase lida")
	var austin := _achar(u, "Austin")
	verdadeiro(austin != "", "Austin existe")
	igual(str(u.entidade(austin)["tipo"]), "cidade", "é uma cidade")
	verdadeiro(str(c[0]["itens"][1]["texto"]).begins_with("3700 habitantes em Austin"), "3.700 habitantes em Austin: " + str(c[0]["itens"][1]["texto"]))
	verdadeiro(_tipos(c[0]).has("pergunta"), "o Livro pergunta quem é o imperador")
	verdadeiro(_tipos(c[0]).has("por_vir"), "a chegada fica por vir")
	igual(LeitorMais.pendentes(u).size(), 1, "uma coisa por vir")
	# O imperador ganha nome: é a mesma pessoa, e ao chegar a pendência some.
	_escrever(u, m["cap"], "O imperador Valen chegou a Austin.")
	var valen := _achar(u, "Valen")
	verdadeiro(valen != "", "Valen existe")
	igual(_achar(u, "O Imperador"), "", "o título sem nome virou Valen")
	igual(str(u.estado(valen).get("local", "")), austin, "Valen está em Austin")
	igual(LeitorMais.pendentes(u).size(), 0, "nada mais por vir")


func test_o_mundo_traz_o_que_estava_por_vir() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "Na cidade de Austin viviam 500 habitantes até a chegada da rainha.")
	var p: Array = LeitorMais.pendentes(u)
	igual(p.size(), 1, "por vir")
	var fid := LeitorMais.cumprir(u, p[0])
	verdadeiro(u.fatos.existe(fid), "virou fato")
	verdadeiro(not u.fatos.obter(fid)["causas"].is_empty(), "com causa (a frase)")
	igual(LeitorMais.pendentes(u).size(), 0, "cumprido")


func test_pessoas_e_lugares_pelo_nome() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "John Black passou trezentos anos na Profundeza antes de entender que ninguém o tinha prendido.")
	var john := _achar(u, "John Black")
	verdadeiro(john != "", "John Black existe")
	verdadeiro(_achar(u, "Profundeza") != "", "a Profundeza existe")
	_escrever(u, m["cap"], "Kai Dunmar jurou vingança contra John Black.")
	verdadeiro(_achar(u, "Kai Dunmar") != "", "Kai existe")
	var antes := u.entidades_ativas().size()
	_escrever(u, m["cap"], "John seguiu para o norte.")
	igual(u.entidades_ativas().size(), antes, "John é John Black, não uma pessoa nova")
	_escrever(u, m["cap"], "Quando saiu, o mundo que ele conhecia já não existia.")
	igual(_achar(u, "Quando"), "", "'Quando' não é gente")


func test_perguntas_regras_e_ordens() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "Na cidade de Austin viviam 200 habitantes.")
	var n := u.fatos.todos().size()
	var c: Array = _escrever(u, m["cap"], "Descreva a cidade de Austin.")
	igual(_tipos(c[0]), ["consulta"], "pergunta ao Livro")
	verdadeiro(str(c[0]["itens"][0]["texto"]).contains("Austin"), "o Livro responde com o que sabe")
	igual(u.fatos.todos().size(), n, "perguntar não muda o mundo")
	c = _escrever(u, m["cap"], "Não transforme uma hipótese em fato confirmado.")
	igual(_tipos(c[0]), ["regra"], "regra do Livro")
	igual(u.extra("regras_do_livro", []).size(), 1, "guardada")
	c = _escrever(u, m["cap"], "Crie um mercado no centro da cidade.")
	verdadeiro(_tipos(c[0]).has("lugar") or _tipos(c[0]).has("coisa"), "o mercado nasce")
	c = _escrever(u, m["cap"], "Uma névoa espessa cobriu o vale.")
	igual(_tipos(c[0]), ["acontecimento"], "o que acontece fica anotado como fato")
	# Apagar a linha desfaz o acontecimento.
	var cap := u.capitulo(m["cap"])
	u.atualizar_capitulo(m["cap"], {"texto": str(cap["texto"]).replace("Uma névoa espessa cobriu o vale.\n", "")})
	Escrita.processar(u, m["cap"])
	falso(u.fatos.todos().any(func(f): return f["canon"] and f["descricao"] == "Uma névoa espessa cobriu o vale."), "linha apagada, fato desfeito")


func test_confronto_nao_toca_na_historia() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "John Black passou trezentos anos na Profundeza.")
	_escrever(u, m["cap"], "Kai Dunmar jurou vingança contra John Black.")
	var john := _achar(u, "John Black")
	var kai := _achar(u, "Kai Dunmar")
	var fatos := u.fatos.todos().size()
	var e := Confronto.ensaiar(u, kai, john, {"surpresa": kai, "aliados": {kai: 12}, "semente": 3})
	verdadeiro(str(e["texto"]).contains("Kai Dunmar caiu sobre John Black"), "conta em palavras: " + str(e["texto"]))
	verdadeiro(e["porque"].size() >= 2, "com motivos")
	falso(str(e["texto"]).contains("%"), "sem porcentagem")
	igual(u.fatos.todos().size(), fatos, "nenhum fato novo")
	igual(u.extra("ensaios", []).size(), 1, "o ensaio fica guardado")
	# Quem não morre, não morre.
	var cs: Array = u.entidade(john)["campos"].duplicate(true)
	cs.append({"chave": "natureza", "valor": "imortal"})
	u.editar_entidade(john, {"campos": cs})
	for s in 30:
		var r := Confronto.ensaiar(u, kai, john, {"ate_a_morte": true, "aliados": {kai: 5000}, "semente": s})
		falso(r["perdedor"] == john and r["morte"], "John é imortal")


func test_temas_e_opcoes() -> void:
	Tema.carregar_preferencias()
	var antes := Tema.prefs.duplicate()
	Tema.salvar_preferencias({"tema": "escuro"})
	igual(Tema.PAPEL, Color(Tema.PALETAS["escuro"]["PAPEL"]), "papel escuro")
	Tema.salvar_preferencias({"tema": "claro"})
	igual(Tema.TINTA, Color(Tema.PALETAS["claro"]["TINTA"]), "tinta do tema claro")
	Tema.salvar_preferencias(antes)
	igual(Tema.PAPEL, Color(Tema.PALETAS[antes["tema"]]["PAPEL"]), "voltou")


func test_tela_unica() -> void:
	var c := arvore.root.get_node_or_null("Cronica")
	if c == null:
		c = load("res://core/cronica.gd").new()
		c.name = "Cronica"
		arvore.root.add_child(c)
	c.biblioteca = Biblioteca.new(PASTA, LIXEIRA)
	var u: Universo = c.criar_universo("Zero", "")
	igual(u.entidades_ativas().size(), 0, "universo novo começa limpo")
	igual(u.livros.size(), 0, "sem livros de exemplo")
	var tela: Node = load("res://ui/tela/tela.tscn").instantiate()
	arvore.root.add_child(tela)
	_nos.append(tela)
	await arvore.process_frame
	verdadeiro(tela.cid != "", "abre um livro em branco para já escrever")
	igual(u.livros.size(), 1, "uma saga")
	tela._editor.text = "Na cidade de Austin viviam 3.700 habitantes até a chegada do imperador.\n"
	tela._editor.text_changed.emit()
	tela._ler_frases()
	await arvore.process_frame
	verdadeiro(tela._margem.get_child_count() >= 3, "a margem mostra o que entendeu, a pergunta e o aviso")
	# O mundo propõe; aceitar põe a linha na página, na tinta do mundo.
	tela._propor("Naquela noite, o povo de Austin fechou as portas.", [])
	verdadeiro(tela._proposta.get_child_count() == 1, "a proposta aparece")
	tela._aceitar_proposta(false)
	verdadeiro(str(u.capitulo(tela.cid)["texto"]).contains("fechou as portas"), "entrou na página")
	igual(tela._proposta.get_child_count(), 0, "a proposta some")
	var realce: RealceMundo = tela._editor.syntax_highlighter
	var ultima: int = tela._editor.get_line_count() - 2
	igual(realce._get_line_syntax_highlighting(ultima).get(0, {}).get("color", Color.BLACK), Tema.TINTA_MUNDO, "linha do mundo na tinta do mundo")
	igual(realce._get_line_syntax_highlighting(0).size(), 0, "linha do autor na tinta normal")
	# Todos os painéis montam.
	for p in tela.PAINEIS:
		for par in tela.PAINEIS[p]["abas"]:
			tela.abrir_painel(p, par[0])
			await arvore.process_frame
			verdadeiro(tela._painel.visible and tela._painel_esq.get_child_count() > 0, "painel %s/%s montou" % [p, par[0]])
	tela.fechar_painel()
	verdadeiro(tela._folha.visible, "voltou à página")
	# Passar o tempo e modo foco não quebram.
	tela._passar_tempo(30)
	tela._alternar_foco()
	falso(tela._barra.visible, "foco: só a página")
	tela._alternar_foco()
	# Trocar o tema remonta a tela no mesmo livro.
	var antes := Tema.prefs.duplicate()
	Tema.salvar_preferencias({"tema": "escuro"})
	tela.reconstruir()
	await arvore.process_frame
	verdadeiro(str(tela._editor.text).contains("Austin"), "o texto continua lá")
	Tema.salvar_preferencias(antes)
	# Exportar em texto.
	var pasta := PainelEstante.exportar(u, OS.get_user_data_dir() + "/teste_porcima_export")
	var arquivos := DirAccess.get_files_at(pasta)
	igual(arquivos.size(), 2, "dois arquivos por livro")
	for a in arquivos:
		var t := FileAccess.get_file_as_string(pasta + "/" + a)
		igual(t.contains("fechou as portas"), not a.contains("minhas"), "só as minhas linhas não leva as do mundo")
		DirAccess.remove_absolute(pasta + "/" + a)


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


## A IA local só traduz; o que ela inventa é cortado, e apagar a linha desfaz o que ela leu.
func test_ia_local_le_e_nao_inventa() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "O rei Odo chegou a Brasa.")
	_escrever(u, m["cap"], "Bren Valar passou a infância em Brasa.")
	var bren := _achar(u, "Bren Valar")
	var odo := _achar(u, "Odo")
	verdadeiro(bren != "" and odo != "", "Bren e Odo existem")
	var frase := "O velho rei Odo foi assassinado pelo próprio filho, Bren."
	var c: Array = _escrever(u, m["cap"], frase)
	igual(_tipos(c[0]), ["acontecimento"], "sem IA, a linha fica só anotada")
	var saida := "Aqui estão as frases:\n1. Bren matou Odo.\n- O rei Zarkon chegou a Marte.\n* Bren odeia Odo.\nNADA"
	var linhas := Interprete.limpar(u, saida, frase)
	igual(linhas, ["Bren matou Odo.", "Bren odeia Odo."], "tira marcadores e corta o que a IA inventou (Zarkon, Marte)")
	igual(Interprete.limpar(u, "Na cidade de Brasa viviam 900 habitantes.", frase), [], "número que a linha não diz é cortado")
	verdadeiro(Interprete.pedido(u, frase, "").contains("Não invente"), "o pedido proíbe inventar")
	var itens := Interprete.aplicar(u, m["cap"], frase, linhas)
	verdadeiro(itens.size() >= 1, "a leitura valeu no mundo")
	falso(Estado.vivo(u, odo), "Odo morreu")
	Escrita.processar(u, m["cap"])
	Extrator.analisar(u, m["cap"])
	falso(Estado.vivo(u, odo), "e continua morto depois de reler o livro")
	falso(str(u.capitulo(m["cap"])["texto"]).contains("Bren matou Odo"), "a frase da IA não entra no texto do autor")
	# Apagar a linha do autor desfaz o que a IA tinha lido dela.
	var cap := u.capitulo(m["cap"])
	u.atualizar_capitulo(m["cap"], {"texto": str(cap["texto"]).replace(frase + "\n", "")})
	Escrita.processar(u, m["cap"])
	verdadeiro(Estado.vivo(u, odo), "linha apagada: Odo volta a estar vivo")


func test_ia_local_por_programa_externo() -> void:
	var falso_ollama := OS.get_environment("CRONICA_IA_FALSA")
	if falso_ollama == "" or not FileAccess.file_exists(falso_ollama):
		return
	var antes := IALocal.config()
	IALocal.salvar_config(falso_ollama, "teste", true)
	verdadeiro(IALocal.disponivel(), "IA configurada")
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "O rei Odo chegou a Brasa.")
	_escrever(u, m["cap"], "Bren Valar passou a infância em Brasa.")
	var linhas := Interprete.interpretar(u, "O velho rei Odo foi assassinado pelo próprio filho, Bren.", "")
	igual(linhas, ["Bren matou Odo.", "Bren odeia Odo."], "chama o programa e limpa a resposta")
	IALocal.salvar_config(str(antes.get("comando", "")), str(antes.get("modelo", "")), bool(antes.get("ligada", true)))


## O que se escreve livre tem consequência de verdade, e apagar a linha desfaz.
func test_consequencias_de_verdade() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "Na cidade de Austin viviam 400 habitantes.")
	_escrever(u, m["cap"], "O rei Odo chegou a Austin.")
	_escrever(u, m["cap"], "Bren Valar passou a infância em Austin.")
	_escrever(u, m["cap"], "Crie uma ponte.")
	var austin := _achar(u, "Austin")
	var odo := _achar(u, "Odo")
	var bren := _achar(u, "Bren Valar")
	var vivos := Ameacas._pessoas(u, austin).size()
	var c: Array = _escrever(u, m["cap"], "Uma peste terrível atingiu a cidade.")
	igual(_tipos(c[0]), ["consequencia"], "a peste tem consequência")
	verdadeiro(Ameacas._pessoas(u, austin).size() < vivos, "gente morreu de verdade")
	verdadeiro(Estado.vivo(u, odo) and Estado.vivo(u, bren), "quem o autor escreveu pelo nome não morre por acaso")
	falso(str(c[0]["itens"][0]["texto"]).contains("%"), "contado em palavras")
	# Apagar a linha traz todos de volta.
	var cap := u.capitulo(m["cap"])
	u.atualizar_capitulo(m["cap"], {"texto": str(cap["texto"]).replace("Uma peste terrível atingiu a cidade.\n", "")})
	Escrita.processar(u, m["cap"])
	igual(Ameacas._pessoas(u, austin).size(), vivos, "linha apagada: ninguém morreu")
	# A ponte cai.
	var ponte := ""
	for e in u.entidades_ativas():
		if e["tipo"] == "ponte":
			ponte = e["id"]
	verdadeiro(ponte != "", "a ponte existe")
	c = _escrever(u, m["cap"], "Uma enchente destruiu parte da ponte.")
	igual(str(u.estado(ponte).get("condicao", "")), "danificado", "a ponte ficou danificada")
	c = _escrever(u, m["cap"], "Dias depois, a ponte desabou.")
	igual(str(u.estado(ponte).get("condicao", "")), "em ruínas", "e depois caiu")
	# O trono muda de dono, e o antigo rei guarda raiva.
	c = _escrever(u, m["cap"], "Bren tomou o trono.")
	igual(u.valor_campo(bren, "cargo"), "governante de Austin", "Bren governa")
	verdadeiro(u.valor_campo(odo, "cargo").begins_with("antigo"), "Odo perdeu o cargo")
	verdadeiro(Estado.emocao_por(u, odo, bren, ["raiva"]) > 0.3, "e guarda raiva de Bren")
	# Adoecer e sarar.
	c = _escrever(u, m["cap"], "Odo adoeceu gravemente.")
	verdadeiro(Estado.saude_atual(u, odo) < 0.7, "Odo está mal")
	c = _escrever(u, m["cap"], "Odo se recuperou.")
	verdadeiro(Estado.saude_atual(u, odo) > 0.9, "Odo sarou")


## O Livro avisa antes de momentos grandes com quem o autor escreveu.
func test_avisos_antes_de_momentos_grandes() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	u.extras["escrita_sem_tempo"] = true
	_escrever(u, m["cap"], "Na cidade de Austin viviam 100 habitantes.")
	_escrever(u, m["cap"], "John Black chegou a Austin.")
	igual(Pressagios.listar(u).size(), 0, "nada de grande ainda")
	_escrever(u, m["cap"], "Kai Dunmar jurou vingança contra John Black.")
	var avisos := Pressagios.listar(u)
	igual(avisos.size(), 1, "um aviso")
	verdadeiro(str(avisos[0]["texto"]).contains("Kai Dunmar") and str(avisos[0]["texto"]).contains("John Black"), "diz quem e por quê: " + str(avisos[0]["texto"]))
	Pressagios.dispensar(u, str(avisos[0]["chave"]))
	igual(Pressagios.listar(u).size(), 0, "deixar seguir: o aviso some")
	_escrever(u, m["cap"], "John Black adoeceu gravemente.")
	verdadeiro(Pressagios.listar(u).any(func(a): return str(a["chave"]).begins_with("saude:")), "avisa que John pode não resistir")


## O começo que o autor escreveu de verdade: a cidade não troca de nome e o povo vive de algo.
func test_kreven_no_deserto() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "Existia uma cidade chamada Kreven.")
	var kreven := _achar(u, "Kreven")
	verdadeiro(kreven != "", "Kreven existe")
	var c: Array = _escrever(u, m["cap"], "Kreven estava em um grande deserto.")
	verdadeiro(_achar(u, "Deserto de Kreven") != "", "o deserto leva o nome da cidade: " + str(c[0]["itens"]))
	igual(str(u.capitulo(m["cap"]).get("foco", "")), kreven, "a história continua em Kreven")
	c = _escrever(u, m["cap"], "Seus moradores, vivam da caça e de mineração.")
	igual(u.valor_campo(kreven, "vive de"), "caça e mineração", "Kreven vive de caça e mineração")
	verdadeiro(Ameacas._pessoas(u, kreven).size() > 0, "e agora tem moradores")
	falso(_tipos(c[0]).has("acontecimento"), "não fica só anotado")


## O começo de "Inverno Desert", como o autor escreveu.
func test_inverno_desert() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "Existia uma cidade chamada Kreven.")
	_escrever(u, m["cap"], "Kreven estava em um grande deserto.")
	_escrever(u, m["cap"], "Seus moradores, vivam da caça e de mineração.")
	var kreven := _achar(u, "Kreven")
	var c: Array = _escrever(u, m["cap"], "O rei de Kreven estava doente.")
	var rei := _achar(u, "O Rei")
	verdadeiro(rei != "", "o rei existe, ainda sem nome")
	igual(u.valor_campo(rei, "cargo"), "rei de Kreven", "é o rei de Kreven")
	verdadeiro(Estado.saude_atual(u, rei) < 0.9, "e está doente de verdade")
	c = _escrever(u, m["cap"], "O povo sabia disso, e estavam com medo.")
	igual(_tipos(c[0]), ["consequencia"], "o povo com medo: " + str(c[0]["itens"]))
	c = _escrever(u, m["cap"], "Leptuna a rainha do inverno estava chegando.")
	var leptuna := _achar(u, "Leptuna")
	verdadeiro(leptuna != "", "Leptuna existe")
	igual(u.valor_campo(leptuna, "cargo"), "rainha do inverno", "é a rainha do inverno")
	igual(_achar(u, "A Rainha"), "", "o Livro não pergunta quem é a rainha")
	verdadeiro(LeitorMais.pendentes(u).any(func(p): return str(p["quem"]) == leptuna), "a chegada dela está por vir")
	c = _escrever(u, m["cap"], "E apenas Gregorio R. Tunt poderia salvá-los.")
	igual(c.size(), 1, "a inicial R. não corta a frase")
	verdadeiro(_achar(u, "Gregorio R. Tunt") != "", "Gregorio R. Tunt existe")
	igual(_achar(u, "Tunt"), "", "e não um 'Tunt' solto")
	igual(DataMundo.ordem(u.relogio), DataMundo.ordem(DataMundo.criar(1, 1)), "só descrição: o tempo não andou")
	igual(str(u.capitulo(m["cap"]).get("foco", "")), kreven, "a história continua em Kreven")


## A IA como leitora principal: completa sem repetir o que o Livro já entendeu, e dá para desfazer.
func test_ia_completa_sem_repetir() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	_escrever(u, m["cap"], "O rei Odo chegou a Brasa.")
	_escrever(u, m["cap"], "Bren Valar passou a infância em Brasa.")
	var odo := _achar(u, "Odo")
	var bren := _achar(u, "Bren Valar")
	var c: Array = _escrever(u, m["cap"], "Bren matou Odo.")
	verdadeiro(_tipos(c[0]).has("acao"), "o Livro entendeu sozinho")
	var mortes := u.fatos.todos().filter(func(f): return f["canon"] and f["dados"].get("acao", "") == "morte_por").size()
	var itens := Interprete.aplicar(u, m["cap"], "Bren matou Odo.", ["Bren matou Odo.", "Bren odeia Odo."], _tipos(c[0]))
	igual(u.fatos.todos().filter(func(f): return f["canon"] and f["dados"].get("acao", "") == "morte_por").size(), mortes, "a IA não mata Odo duas vezes")
	# Numa linha que o Livro só anotou, a IA vale na hora e dá para desfazer.
	var c2: Array = _escrever(u, m["cap"], "Desde então o rapaz guardava rancor do velho.")
	var medo := Estado.valor_relacao(u, bren, odo, "medo")
	itens = Interprete.aplicar(u, m["cap"], "Desde então o rapaz guardava rancor do velho.", ["Bren teme Odo."], _tipos(c2[0]))
	verdadeiro(itens.size() >= 1 and Estado.valor_relacao(u, bren, odo, "medo") > medo, "a leitura da IA valeu: %s" % str(itens))
	verdadeiro(Interprete.desfazer(u, m["cap"], "Desde então o rapaz guardava rancor do velho.") > 0, "e foi desfeita")
	igual(Estado.valor_relacao(u, bren, odo, "medo"), medo, "o medo voltou ao que era")
	verdadeiro(Interprete.pedido(u, "Ele fugiu.", "", ["Bren matou Odo."]).contains("Bren matou Odo."), "o pedido leva as linhas anteriores, para os pronomes")


## O mapa mostra só o que foi escrito.
func test_mapa_so_com_o_que_foi_escrito() -> void:
	var m := _novo()
	var u: Universo = m["u"]
	u.extras["escrita_por_cima"] = true
	_escrever(u, m["cap"], "Existia uma cidade chamada Kreven.")
	_escrever(u, m["cap"], "Kreven estava em um grande deserto.")
	var kreven := _achar(u, "Kreven")
	var mundo := Mapa.pai(u, kreven)
	var p: Dictionary = Mapa.posicao(u, kreven)
	igual(Mapa.terreno_em(u, mundo, int(p["x"]), int(p["y"])), "deserto", "Kreven está no deserto")
	igual(Mapa.terreno_em(u, mundo, clampi(int(p["x"]) + 3, 0, Mapa.COLS - 1), int(p["y"])), "deserto", "e o deserto é grande")
	var visto := LeitorMais.escrito_no_mapa(u, mundo)
	verdadeiro(visto.has(Vector2i(int(p["x"]), int(p["y"]))), "o mapa mostra Kreven")
	verdadeiro(visto.size() < Mapa.COLS * Mapa.LINHAS / 3, "e não o mundo inteiro (%d células)" % visto.size())
	var d: Dictionary = Mapa.posicao(u, _achar(u, "Deserto de Kreven"))
	verdadeiro(absi(int(d["x"]) - int(p["x"])) <= 1 and absi(int(d["y"]) - int(p["y"])) <= 1, "o deserto fica marcado ao lado da cidade")


## O que a IA deduz de linhas anteriores não vale sozinho: pede o sim do autor.
func test_ia_so_vale_sozinha_com_nomes_da_linha() -> void:
	var partes := Interprete.separar("O velho rei Odo foi assassinado pelo próprio filho, Bren.", ["Bren matou Odo.", "O povo estava com medo."])
	igual(partes[0], ["Bren matou Odo.", "O povo estava com medo."], "nomes da própria linha: vale na hora")
	partes = Interprete.separar("Ele passou a infância em Kreven.", ["Bren matou Odo.", "O povo estava com medo."])
	igual(partes[1], ["Bren matou Odo."], "nome que não está na linha: pede confirmação")
