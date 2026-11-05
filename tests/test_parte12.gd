extends TesteBase
## Parte 12: laboratório e integridade — ramos, destinos do autor, versões, auditores
## de causalidade, continuidade e conhecimento, recuperação histórica, gerenciador de
## memória, importação e exportação.
## Teste do plano: três futuros diferentes a partir da morte do rei, e o mundo coerente
## depois de 10 mil acontecimentos.

const PASTA := "user://teste_p12"


func _mundo(semente: int = 1212) -> Dictionary:
	var u := Universo.novo("Varn")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(412, 10))
	var planeta := u.criar_entidade("Aldra", "planeta")
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "5000"}])
	Mapa.colocar(u, planeta, "", 10, 10)
	Mapa.colocar(u, varn, planeta, 10, 10)
	var reino := u.criar_entidade("Reino de Varn", "reino", [], [{"chave": "forma de governo", "valor": "monarquia hereditária"}, {"chave": "território", "valor": "Varn"},
		{"chave": "líder", "valor": "Ostric"}, {"chave": "conselho", "valor": "Varga, Tobias"}])
	var rei := _pessoa(u, "Ostric", 80, "orgulhoso", varn)
	var principe := _pessoa(u, "Edric", 25, "calmo e leal", varn)
	var general := _pessoa(u, "Varga", 45, "ambiciosa, corajosa e fria", varn)
	var conselheiro := _pessoa(u, "Tobias", 50, "desesperado, ambicioso e medroso", varn)
	var mae := u.criar_entidade("Mãe das Cinzas", "demônio", [], [{"chave": "o que oferece", "valor": "poder"}, {"chave": "o que cobra", "valor": "a alma, em vinte anos"},
		{"chave": "vontade", "valor": "dormir até ser chamada"}])
	Simulador.registrar(u, {"tipo": "filiação", "descricao": "Edric é filho de Ostric.", "sujeitos": [principe, rei], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": [{"op": "familia", "pai": rei, "filho": principe}]}})
	return {"u": u, "varn": varn, "reino": reino, "rei": rei, "principe": principe, "general": general, "conselheiro": conselheiro, "mae": mae}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}])
	u.estado(e)["local"] = lugar
	return e


func test_tres_futuros_a_partir_da_morte_do_rei() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var fatos_canon := u.fatos.quantidade()
	var relogio_canon := u.relogio.duplicate()
	# Três ramos, cada um com uma mudança.
	var a := Laboratorio.abrir_ramo(u, "o príncipe assume")
	var b := Laboratorio.abrir_ramo(u, "o general dá um golpe")
	var c := Laboratorio.abrir_ramo(u, "o conselheiro faz um pacto")
	for r in [a, b, c]:
		verdadeiro(Laboratorio.eh_ramo(r) and r.id != u.id, "ramo separado")
		Laboratorio.mudar(r, "O rei Ostric morre.")
	verdadeiro(Laboratorio.mudar(a, "O príncipe Edric assume o trono do Reino de Varn.").contains("assumiu"), "A: o príncipe assume")
	var rb := Laboratorio.mudar(b, "A general Varga dá um golpe no Reino de Varn.")
	verdadeiro(rb.begins_with("Golpe"), "B: " + rb)
	verdadeiro(Laboratorio.mudar(c, "O conselheiro Tobias faz um pacto com a Mãe das Cinzas.").contains("Pacto"), "C: o pacto")
	# O canon não foi tocado.
	igual(u.fatos.quantidade(), fatos_canon, "o canon não ganhou nenhum fato")
	verdadeiro(Estado.vivo(u, m["rei"]), "no canon, o rei ainda vive")
	# Cada ramo avança sozinho.
	for r in [a, b, c]:
		Simulador.avancar(r, 5 * 360)
	igual(u.relogio, relogio_canon, "o canon não andou")
	var tabela := Laboratorio.comparar([a, b, c])
	igual(tabela.size(), 3, "três futuros lado a lado")
	var governos: Array = tabela.map(func(t): return str(t["governos"].get("Reino de Varn", "")))
	verdadeiro(governos[0].begins_with("Edric"), "A: governa Edric — " + governos[0])
	verdadeiro(governos[2].begins_with("Tobias"), "C: governa Tobias — " + governos[2])
	verdadeiro(governos[0] != governos[1] or governos[1] != governos[2], "os futuros são diferentes: " + " | ".join(governos))
	verdadeiro(tabela.all(func(t): return t["mortos"].has("Ostric")), "nos três, o rei morreu")
	verdadeiro(Pactos.todos(c).size() == 1 and Pactos.todos(a).is_empty(), "só no ramo C há pacto")
	# Trazer alguém de um ramo para outro; escolher um ramo como canon.
	var trazido := Laboratorio.trazer_entidade(c, a, m["mae"])
	igual(trazido, m["mae"], "quem já existe no outro ramo não é duplicado")
	var novo := Laboratorio.tornar_canon(u, b)
	igual(novo.id, u.id, "o ramo B virou o canon (mesmo universo)")
	falso(Estado.vivo(novo, m["rei"]), "no novo canon, o rei morreu")
	falso(Laboratorio.eh_ramo(novo), "e não é mais ramo")
	igual(Auditor.auditar(novo).size(), 0, "o novo canon é coerente")


func test_versoes_e_recuperacao() -> void:
	var m := _mundo(1313)
	var u: Universo = m["u"]
	var b := Biblioteca.new(PASTA, PASTA + "_lixo")
	b.salvar(u)
	var v := Versoes.salvar(b, u, "antes da morte do rei")
	verdadeiro(v != "", "versão salva")
	var morte := Simulador.registrar(u, {"tipo": "morte", "descricao": "Ostric morreu.", "sujeitos": [m["rei"]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"acao": "morte", "mudancas": [{"op": "morrer", "quem": m["rei"]}]}})
	Simulador.avancar(u, 30)
	falso(Estado.vivo(u, m["rei"]), "o rei morreu")
	var vs := Versoes.listar(b, u.id)
	igual(vs.size(), 1, "uma versão na lista")
	var volta := Versoes.voltar(b, u, vs[0]["arquivo"])
	verdadeiro(Estado.vivo(volta, m["rei"]), "voltando à versão, o rei vive")
	igual(Versoes.listar(b, u.id).size(), 2, "a situação de antes de voltar também ficou guardada")
	# Recuperação histórica: desfazer e restaurar.
	var n := u.desfazer_fato(morte)
	verdadeiro(n >= 1 and Estado.vivo(u, m["rei"]), "desfeita a morte, o rei vive")
	verdadeiro(Integridade.desfeitos(u).any(func(f): return f["id"] == morte), "a morte aparece entre os desfeitos")
	Integridade.restaurar(u, morte)
	falso(Estado.vivo(u, m["rei"]), "restaurada, o rei morre de novo")


func test_destinos_do_autor() -> void:
	var m := _mundo(1414)
	var u: Universo = m["u"]
	var kresk := u.criar_entidade("Kresk", "cidade", [], [{"chave": "população", "valor": "900"}])
	Mapa.colocar(u, kresk, u.entidade(m["varn"]).get("id", "") if false else Mapa.pai(u, m["varn"]), 13, 11)
	var lia := _pessoa(u, "Lia", 20, "curiosa", kresk)
	var d := Destinos.marcar(u, "Edric encontra Lia antes do ano 420.")
	igual(d.get("verbo", ""), "encontra", "entendeu o destino")
	igual(d.get("ate", 0), 420, "com prazo")
	var anos := 0
	while d["estado"] == "aberto" and anos < 8:
		Simulador.avancar(u, 360)
		anos += 1
	igual(d["estado"], "cumprido", "o mundo levou Edric até Lia, sem forçar")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "destino em curso"), "com pequenos empurrões (viraram fato)")
	verdadeiro(u.fatos.todos().any(func(f): return f["tipo"] == "destino cumprido" and not f["causas"].is_empty()), "o cumprimento tem causa real")


func test_auditores_e_memoria() -> void:
	var m := _mundo(1515)
	var u: Universo = m["u"]
	# Um segredo que alguém sabe sem poder saber (dado corrompido de propósito).
	var s := Simulador.registrar(u, {"tipo": "segredo", "descricao": "Ostric esconde um filho.", "sujeitos": [m["rei"]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"secreto": true, "mudancas": []}})
	u.estado(m["general"])["conhece"][s] = true
	var r := Integridade.auditar_tudo(u)
	verdadeiro(r["conhecimento"].any(func(x): return x["tipo"] == "sabe_segredo"), "o controle de conhecimento acha quem sabe o que não poderia")
	u.estado(m["general"])["conhece"].erase(s)
	# Alguém agindo depois de morto.
	Simulador.registrar(u, {"tipo": "morte", "descricao": "Varga morreu.", "sujeitos": [m["general"]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"acao": "morte", "mudancas": [{"op": "morrer", "quem": m["general"]}]}})
	u.fatos._inserir_cru({"id": "fato_x", "tipo": "luta", "descricao": "Varga venceu Edric.", "sujeitos": [m["general"], m["principe"]], "lugar": "", "data": DataMundo.copiar(u.relogio),
		"causas": [s], "origem": {"tipo": BancoDeFatos.ORIGEM_SIMULACAO, "ref": ""}, "canon": true, "dados": {"acao": "vitoria"}})
	verdadeiro(Integridade.continuidade(u).any(func(x): return x["tipo"] == "agiu_depois_de_morto"), "o auditor de continuidade acha quem age depois de morto")
	# Memória: notícias velhas vão para o arquivo, sem perder o que importa.
	var m2 := _mundo(1616)
	var u2: Universo = m2["u"]
	Simulador.avancar(u2, 3 * 360)
	var antes := Integridade.memoria(u2)
	u2.definir_relogio(DataMundo.criar(450, 10))
	var n := Integridade.arquivar(u2, 20)
	var depois := Integridade.memoria(u2)
	verdadeiro(n > 0, "notícias arquivadas (%d)" % n)
	igual(int(depois["fatos"]), int(antes["fatos"]) - n, "saíram do banco")
	igual(int(depois["arquivados"]), n, "e estão no arquivo (nada se perde)")
	igual(Auditor.auditar(u2).size(), 0, "o banco continua coerente")


func test_exportar_e_importar() -> void:
	var m := _mundo(1717)
	var u: Universo = m["u"]
	var pasta := PASTA + "_export"
	var n := Troca.exportar(u, pasta)
	verdadeiro(n > 5, "exportou %d arquivos" % n)
	verdadeiro(FileAccess.file_exists(pasta + "/wiki/ostric.md"), "uma página por entidade")
	verdadeiro(FileAccess.get_file_as_string(pasta + "/cronologia.md").contains("Edric é filho de Ostric"), "a cronologia")
	verdadeiro(FileAccess.get_file_as_string(pasta + "/mapas.txt").contains("V = Varn"), "o mapa em texto")
	var imp := Troca.importar_universo(pasta)
	verdadeiro(imp != null and imp.id != u.id, "importado como universo novo")
	igual(imp.fatos.quantidade(), u.fatos.quantidade(), "com todos os fatos")
	# Uma pasta de textos (como o WikidPad).
	var wp := PASTA + "_wikidpad"
	DirAccess.make_dir_recursive_absolute(wp)
	var f := FileAccess.open(wp + "/DarenDeVarn.wiki", FileAccess.WRITE)
	f.store_string("[tipo: pessoa]\nidade: 19 anos\npersonalidade: rancoroso\nFilho de [[Lucas]], viu tudo na praça.\n")
	f.close()
	var f2 := FileAccess.open(wp + "/Lucas.txt", FileAccess.WRITE)
	f2.store_string("Lucas\n[tipo: pessoa]\nofício: ferreiro em Varn\n")
	f2.close()
	var novas := Troca.importar_textos(u, wp)
	igual(novas.size(), 2, "duas páginas viraram entidades")
	var daren := ""
	for e in u.entidades_ativas():
		if e["nome"] == "Daren De Varn":
			daren = e["id"]
	verdadeiro(daren != "", "o nome CamelCase virou \"Daren De Varn\"")
	igual(u.entidade(daren)["tipo"], "pessoa", "tipo pelo atributo [tipo: pessoa]")
	igual(u.valor_campo(daren, "idade"), "19 anos", "campos da ficha")
	verdadeiro(u.valor_campo(daren, "descrição").contains("Lucas"), "o resto vira descrição (sem os colchetes)")


func test_mundo_coerente_depois_de_10_mil_acontecimentos() -> void:
	var u := Universo.novo("Dez Mil")
	u.extras["semente"] = 10000
	var p := Povoador.gerar_planeta(u)
	Povoador.povoar(u, p)
	var anos := 0
	while u.fatos.quantidade() < 10000 and anos < 60:
		Simulador.avancar(u, 360)
		anos += 1
	verdadeiro(u.fatos.quantidade() >= 10000, "%d acontecimentos em %d anos" % [u.fatos.quantidade(), anos])
	var r := Integridade.auditar_tudo(u)
	igual(r["causalidade"].size(), 0, "causalidade: %s" % str(r["causalidade"].slice(0, 2)))
	igual(r["continuidade"].size(), 0, "continuidade: %s" % str(r["continuidade"].slice(0, 2)))
	igual(r["conhecimento"].size(), 0, "conhecimento: %s" % str(r["conhecimento"].slice(0, 2)))
	igual(r["simulacao"].size(), 0, "nada repetido: %s" % str(r["simulacao"].slice(0, 2)))
	# Reconstruir do zero dá o mesmo mundo.
	var vivos := Simulador._mentes(u).size()
	AutoAtualizador.reconstruir(u)
	igual(Simulador._mentes_calc(u).size(), vivos, "reconstruído do banco de fatos, o mundo é o mesmo")


func limpar() -> void:
	for p in [PASTA, PASTA + "_export", PASTA + "_wikidpad", PASTA + "_lixo"]:
		_apagar(p)


func _apagar(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for sub in d.get_directories():
		_apagar(p + "/" + sub)
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(p)
