extends TesteBase
## Parte 7: guerras e intervenção, tipos de força, batalhas em resumo, lutas em
## aberto, pós-guerra, lendas, títulos e nomes de batalhas.
## Teste do plano: Sokovia contra Bermudit com o exército de fantasmas.


func _mundo(semente: int = 7070) -> Dictionary:
	var u := Universo.novo("Terra Dupla")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(1200, 10))
	Cosmos.definir_leis(u, {"magia": 0.6, "tecnologia": 0.7})
	var planeta := u.criar_entidade("Areth", "planeta", [], [{"chave": "clima", "valor": "seco"}])
	var sok := u.criar_entidade("Sokovia", "república", [], [{"chave": "forma de governo", "valor": "república"},
		{"chave": "líder", "valor": "Dravek"}, {"chave": "território", "valor": "Sokov, Porto Leste"}])
	var ber := u.criar_entidade("Bermudit", "reino", [], [{"chave": "forma de governo", "valor": "monarquia"},
		{"chave": "líder", "valor": "Rei Azim"}, {"chave": "território", "valor": "Duna Alta, Oásis de Mir"}])
	var sokov := u.criar_entidade("Sokov", "cidade", [], [{"chave": "população", "valor": "40000"}])
	var porto := u.criar_entidade("Porto Leste", "cidade", [], [{"chave": "população", "valor": "12000"}])
	var duna := u.criar_entidade("Duna Alta", "cidade", [], [{"chave": "população", "valor": "15000"}])
	var mir := u.criar_entidade("Oásis de Mir", "vila", [], [{"chave": "população", "valor": "4000"}])
	Mapa.colocar(u, planeta, "", 20, 10)
	Mapa.colocar(u, sokov, planeta, 8, 8)
	Mapa.colocar(u, porto, planeta, 11, 12)
	Mapa.colocar(u, duna, planeta, 18, 9)
	Mapa.colocar(u, mir, planeta, 24, 12)
	# Deserto em volta de Bermudit (é onde os fantasmas vivem).
	for x in range(14, 30):
		for y in range(4, 18):
			Mapa.pintar(u, planeta, x, y, "deserto")
	var dravek := _pessoa(u, "Dravek Sorn", 50, "ambicioso, orgulhoso e frio", sokov)
	var azim := _pessoa(u, "Rei Azim", 58, "orgulhoso, desesperado e corajoso", duna)
	var general := _pessoa(u, "Ilsa Varga", 40, "prudente, curiosa e corajosa", sokov)
	var avioes := u.criar_entidade("Força Aérea de Sokovia", "força aérea", [], [{"chave": "tamanho", "valor": "20 mil aviões"},
		{"chave": "tipo de força", "valor": "aviões"}, {"chave": "pertence a", "valor": "Sokovia"}, {"chave": "comandante", "valor": "Ilsa Varga"},
		{"chave": "moral", "valor": "alta"}])
	var guarda := u.criar_entidade("Guarda de Bermudit", "exército", [], [{"chave": "tamanho", "valor": "6 mil"},
		{"chave": "tipo de força", "valor": "infantaria"}, {"chave": "pertence a", "valor": "Bermudit"}, {"chave": "moral", "valor": "boa"}])
	return {"u": u, "sok": sok, "ber": ber, "sokov": sokov, "duna": duna, "mir": mir, "dravek": dravek, "azim": azim,
		"general": general, "avioes": avioes, "guarda": guarda}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}])
	u.estado(e)["local"] = lugar
	return e


func test_forcas_sao_lidas_da_ficha() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	verdadeiro(Forcas.eh_forca(u, m["avioes"]), "força aérea é força")
	falso(Sociedades.eh_sociedade(u, m["avioes"]), "e não é sociedade")
	igual(Forcas.tipo(u, m["avioes"]), "avioes", "tipo aviões")
	igual(Forcas.tamanho(u, m["avioes"]), 20000.0, "20 mil")
	igual(Forcas.lado(u, m["avioes"]), m["sok"], "de Sokovia")
	igual(Forcas.comandante(u, m["avioes"]), m["general"], "comandada por Ilsa")
	igual(Forcas.lado(u, m["guarda"]), m["ber"], "a guarda é de Bermudit")
	var inf := Forcas.inferir("exército de fantasmas do deserto")
	igual(inf["tipo"], "sobrenaturais", "fantasmas são sobrenaturais")
	verdadeiro(inf["fortes"].contains("imune a balas") and inf["fortes"].contains("invisível na areia"), "fortes sugeridos: " + inf["fortes"])
	verdadeiro(inf["fracos"].contains("luz do dia"), "fracos sugeridos: " + inf["fracos"])
	var regras := Forcas.ler_tracos("imune a balas e armas comuns, invisível na areia", true)
	igual(regras.size(), 2, "duas regras (a segunda parte continua a primeira)")
	verdadeiro(regras[0]["termos"].has("armas"), "armas comuns entra na imunidade")
	falso(Pendencias.listar(u).any(func(i): return i["tipo"] == "campo"), "campos de força têm efeito")


func test_sokovia_contra_bermudit_com_fantasmas() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var g := Guerras.declarar(u, m["sok"], m["ber"], "ambição de Dravek")
	verdadeiro(g != "", "a guerra existe")
	verdadeiro(Guerras.eh_guerra(u, g), "a guerra é uma entidade")
	igual(Guerras.lado_de(u, g, m["sok"]), "a", "Sokovia ataca")
	igual(Guerras.frente(u, g), m["duna"], "a frente é Duna Alta (o lugar de Bermudit mais perto)")
	var p1 := Guerras.previsao(u, g)
	igual(p1["favorito"], m["sok"], "Sokovia é favorita")
	verdadeiro(float(p1["chance"]) > 0.9, "muito favorita: %s" % p1["texto"])
	verdadeiro(int(p1["semanas"]) <= 12, "Bermudit cai em semanas: %s" % p1["texto"])
	verdadeiro(p1["razoes"].any(func(r): return r.contains("não tem como atingir")), "o porquê: sem defesa aérea")

	# O autor intervém escrevendo.
	var r := Guerras.intervir(u, g, "livre", {"texto": "Desesperado, o rei de Bermudit fez um pacto com o Ser da Quinta Dimensão e recebeu um exército de fantasmas do deserto."})
	verdadeiro(r["texto"].begins_with("O mundo aceitou"), r["texto"])
	var ser := ""
	var fantasmas := ""
	for e in u.entidades_ativas():
		if e["nome"] == "Ser da Quinta Dimensão":
			ser = e["id"]
		if e["nome"].to_lower().contains("fantasmas"):
			fantasmas = e["id"]
	verdadeiro(ser != "", "o Ser da Quinta Dimensão virou entidade na wiki")
	verdadeiro(u.valor_campo(ser, "o que cobra") != "", "com seu preço (ainda escondido)")
	verdadeiro(fantasmas != "" and Forcas.eh_forca(u, fantasmas), "o exército de fantasmas virou força")
	igual(Forcas.lado(u, fantasmas), m["ber"], "do lado de Bermudit")
	igual(Forcas.tipo(u, fantasmas), "sobrenaturais", "sobrenatural")
	verdadeiro(Pecas.marcas(u, m["azim"]).any(func(x): return x.contains("pacto")), "o rei carrega o pacto")
	var pacto: Array = u.fatos.sobre(ser).filter(func(f): return f["tipo"] == "pacto")
	igual(pacto.size(), 1, "o pacto é fato")
	var nova: Array = u.fatos.sobre(fantasmas).filter(func(f): return f["tipo"] == "força nova")
	verdadeiro(not nova.is_empty() and nova[0]["causas"].has(pacto[0]["id"]), "os fantasmas vieram do pacto")

	# A guerra recalcula: imunes a balas, invisíveis na areia, somem de dia.
	var p2 := Guerras.previsao(u, g)
	verdadeiro(float(p2["chance"]) < float(p1["chance"]) - 0.3, "a previsão virou: %s" % p2["texto"])
	verdadeiro(p2["razoes"].any(func(x): return x.contains("imune a balas")), "por quê: imunes a balas")
	verdadeiro(p2["razoes"].any(func(x): return x.contains("areia")), "por quê: invisíveis na areia")
	var cond_dia := Forcas.condicoes(u, m["duna"], false)
	var cond_noite := Forcas.condicoes(u, m["duna"], true)
	verdadeiro(cond_dia.has("deserto"), "a frente é no deserto")
	var dia := float(Forcas.dano(u, fantasmas, [m["avioes"]], cond_dia)["dano"])
	var noite := float(Forcas.dano(u, fantasmas, [m["avioes"]], cond_noite)["dano"])
	verdadeiro(noite > dia * 2.0, "de noite os fantasmas são muito mais fortes")
	verdadeiro(Guerras._chance_de_noite(u, Guerras.forcas_do_lado(u, g, "a"), Guerras.forcas_do_lado(u, g, "b")) > 0.6, "Bermudit prefere lutar à noite")

	# A guerra corre até acabar.
	var dias := 0
	while Guerras.dados(u, g)["ativa"] and dias < 5 * 360:
		Simulador.avancar(u, 28)
		dias += 28
	falso(Guerras.dados(u, g)["ativa"], "a guerra acabou")
	var batalhas: Array = Guerras.dados(u, g)["batalhas"]
	verdadeiro(batalhas.size() >= 2, "houve batalhas (%d)" % batalhas.size())
	var nomes: Array = batalhas.map(func(b): return str(u.fatos.obter(b)["dados"].get("nome", "")))
	verdadeiro(nomes.all(func(n): return n != ""), "toda batalha tem nome")
	verdadeiro(nomes.any(func(n): return n.begins_with("A Noite dos Fantasmas do Deserto")), "A Noite dos Fantasmas do Deserto: " + ", ".join(nomes))
	# Cadeia de causas: cada batalha vem da anterior (ou da declaração).
	for b in batalhas:
		var f := u.fatos.obter(b)
		verdadeiro(not f["causas"].is_empty(), "batalha com causa")
	var fim: Array = u.fatos.sobre(g).filter(func(f): return f["tipo"] == "fim da guerra")
	igual(fim.size(), 1, "um fim de guerra")
	verdadeiro(fim[0]["descricao"].contains("Tratado"), "há tratado: " + fim[0]["descricao"])
	var cadeia := u.fatos.cadeia_de_causas(fim[0]["id"], 200)
	verdadeiro(cadeia.any(func(c): return c["tipo"] == "pacto"), "o fim da guerra remonta ao pacto")
	# Depois da guerra: rancor, veteranos.
	var venc := str(Guerras.dados(u, g)["vencedor"])
	verdadeiro(venc in ["a", "b", ""], "vencedor registrado")
	if venc != "":
		var perdeu: String = m["ber"] if venc == "a" else m["sok"]
		var ganhou: String = m["sok"] if venc == "a" else m["ber"]
		verdadeiro(Guerras.rancor(u, perdeu, ganhou) > 0.5, "o perdedor guarda rancor por gerações")
	verdadeiro(Pecas.marcas(u, m["general"]).any(func(x): return x.begins_with("veterano")) or not Estado.vivo(u, m["general"]), "a general virou veterana")
	# Tudo reconstruível: desfazer o pacto refaz o mundo sem os fantasmas.
	igual(Auditor.auditar(u).size(), 0, "auditor sem problemas: %s" % str(Auditor.auditar(u).slice(0, 3)))


func test_ocupacao_muda_quem_manda() -> void:
	var m := _mundo(7171)
	var u: Universo = m["u"]
	var g := Guerras.declarar(u, m["sok"], m["ber"], "")
	var dias := 0
	while Guerras.dados(u, g)["ativa"] and dias < 2 * 360:
		Simulador.avancar(u, 14)
		dias += 14
	falso(Guerras.dados(u, g)["ativa"], "sem fantasmas, Bermudit cai")
	igual(Guerras.dados(u, g)["vencedor"], "a", "Sokovia venceu")
	verdadeiro(dias <= 200, "caiu em semanas (%d dias)" % dias)
	igual(Sociedades.de_lugar(u, m["duna"]), m["sok"], "Duna Alta agora é de Sokovia")
	verdadeiro(Sociedades.territorio(u, m["sok"]).has(m["duna"]), "no território de Sokovia")
	falso(Sociedades.territorio(u, m["ber"]).has(m["duna"]), "e fora do de Bermudit")
	var oc: Array = u.fatos.sobre(m["duna"]).filter(func(f): return f["tipo"] == "ocupação")
	verdadeiro(not oc.is_empty(), "a ocupação virou fato")
	verdadeiro(u.fatos.cadeia_de_causas(oc[0]["id"], 50).any(func(c): return c["tipo"] == "declaração de guerra"), "a ocupação remonta à declaração")
	# Desfazer a declaração devolve tudo.
	var decl: String = Guerras.dados(u, g)["declaracao"]
	u.desfazer_fato(decl)
	igual(Sociedades.de_lugar(u, m["duna"]), m["ber"], "desfeita a guerra, Duna Alta volta a Bermudit")
	verdadeiro(Guerras.ativas(u).is_empty(), "nenhuma guerra ativa")


func test_intervencoes_do_painel() -> void:
	var m := _mundo(7272)
	var u: Universo = m["u"]
	var g := Guerras.declarar(u, m["sok"], m["ber"], "")
	var antes := Forcas.tamanho(u, m["guarda"])
	Guerras.intervir(u, g, "reforcos", {"sid": m["ber"], "tamanho": 4000})
	igual(Forcas.tamanho(u, m["guarda"]), antes + 4000.0, "reforços somam")
	var aliado := u.criar_entidade("Tribo do Vento", "tribo", [], [{"chave": "forma de governo", "valor": "tribo"}])
	Guerras.intervir(u, g, "aliado", {"sid": aliado, "lado": "b"})
	igual(Guerras.lado_de(u, g, aliado), "b", "aliado inesperado do lado de Bermudit")
	verdadeiro(not Forcas.da_sociedade(u, aliado).is_empty(), "o aliado levantou um exército")
	Guerras.intervir(u, g, "morte_general", {"quem": m["general"]})
	falso(Estado.vivo(u, m["general"]), "a general morreu")
	verdadeiro(Forcas.moral(u, m["avioes"]) < 0.8, "a moral caiu")
	Guerras.intervir(u, g, "traicao", {"forca": m["avioes"]})
	igual(Forcas.lado(u, m["avioes"]), m["ber"], "a força aérea traiu e mudou de lado")
	var p := Guerras.previsao(u, g)
	igual(p["favorito"], m["ber"], "agora Bermudit é favorito: " + p["texto"])
	Guerras.intervir(u, g, "paz", {})
	falso(Guerras.dados(u, g)["ativa"], "paz pelo autor")
	verdadeiro(u.fatos.sobre(g).filter(func(f): return f["origem"]["tipo"] == BancoDeFatos.ORIGEM_AUTOR).size() >= 4, "intervenções são fatos do autor")
	var nada := Guerras.intervir(u, Guerras.declarar(u, m["sok"], m["ber"], ""), "livre", {"texto": "Um silêncio estranho caiu sobre todos."})
	verdadeiro(nada["texto"].contains("Ainda sem efeito") or nada["texto"].contains("não sei"), "o que não entende vira pendência: " + nada["texto"])


func test_guerra_escrita_no_capitulo() -> void:
	var m := _mundo(7373)
	var u: Universo = m["u"]
	var livro := u.criar_livro("Crônicas")
	var c := u.criar_capitulo(livro, "A Declaração")
	u.atualizar_capitulo(c, {"texto": "Na primavera, Sokovia declarou guerra a Bermudit.", "data": DataMundo.criar(1200, 10)})
	var props := Extrator.analisar(u, c)
	var gp: Array = props.filter(func(p): return p["acao"] == "guerra")
	igual(gp.size(), 1, "propôs a guerra")
	igual(gp[0]["sujeitos"], [m["sok"], m["ber"]], "Sokovia contra Bermudit")
	var fid := u.aceitar_proposta(gp[0]["id"])
	var g := Guerras.em_guerra(u, m["sok"], m["ber"])
	verdadeiro(g != "", "aceitar cria a guerra")
	verdadeiro(u.fatos.obter(fid)["dados"].get("guerra", "") == g, "o fato do capítulo aponta para a guerra")
	u.desfazer_proposta(gp[0]["id"])
	igual(Guerras.em_guerra(u, m["sok"], m["ber"]), "", "desfazer acaba com a guerra")


func test_luta_em_aberto() -> void:
	var u := Universo.novo("Duelo")
	u.extras["semente"] = 99
	u.definir_relogio(DataMundo.criar(300, 10))
	var black := u.criar_entidade("Jhon Black", "pessoa", [], [{"chave": "idade", "valor": "35 anos"}, {"chave": "personalidade", "valor": "teimoso e corajoso"},
		{"chave": "fraquezas", "valor": "uma ferida antiga no ombro"}])
	var sirius := u.criar_entidade("Sirius Dal", "pessoa", [], [{"chave": "idade", "valor": "30 anos"}, {"chave": "personalidade", "valor": "prudente, curioso e frio"}])
	var livro := u.criar_livro("Livro")
	var c := u.criar_capitulo(livro, "O Duelo")
	u.atualizar_capitulo(c, {"texto": "Jhon Black tinha a força de 98 mil. Sirius Dal tinha força de 70 mil. Eles lutaram por 10 dias; apenas um ficou em pé.",
		"data": DataMundo.criar(300, 10)})
	var props := Extrator.analisar(u, c)
	var lutas: Array = props.filter(func(p): return p["acao"] == "luta")
	igual(lutas.size(), 1, "a luta foi proposta (\"eles\" = os dois)")
	verdadeiro(lutas[0]["sujeitos"].has(black) and lutas[0]["sujeitos"].has(sirius), "entre Black e Sirius")
	falso(props.any(func(p): return p["acao"] in ["vitoria", "morte", "morte_por"]), "o programa não decide no meio do texto")
	var lf := u.aceitar_proposta(lutas[0]["id"])
	igual(Lutas.forca(u, black, c), 98000.0, "força de Black lida do texto")
	igual(Lutas.forca(u, sirius, c), 70000.0, "força de Sirius lida do texto")
	Simulador.avancar(u, 7, {"aceitar_ecos": false})
	var ecos: Array = u.propostas.filter(func(p): return p["status"] == "eco" and p.has("luta"))
	igual(ecos.size(), 1, "o resultado chegou como eco")
	var e: Dictionary = ecos[0]
	igual(e["capitulo"], c, "na margem do capítulo")
	igual(e["causa"], lf, "causado pela luta")
	igual(int(e["luta"]["dias"]), 10, "10 dias de luta")
	verdadeiro(e["luta"]["ate_o_fim"], "apenas um ficou em pé")
	# A chance de Black começa em 58% (98 mil contra 70 mil), menos a ferida que Sirius explora.
	var chance_black: float = e["luta"]["chance"] if e["sujeitos"][0] == black else 1.0 - float(e["luta"]["chance"])
	verdadeiro(chance_black > 0.35 and chance_black < 0.62, "chance de Black: %.2f" % chance_black)
	verdadeiro(e["luta"]["fatores"].any(func(x): return str(x[2]).contains("ferida antiga")), "a ferida antiga pesa")
	# Trocar o vencedor.
	var antes: String = e["sujeitos"][0]
	var novo := Lutas.trocar_vencedor(u, e["id"])
	igual(novo["sujeitos"][1], antes, "vencedor trocado")
	verdadeiro(novo["descricao"].contains("decisão do autor"), novo["descricao"])
	var fv := u.aceitar_proposta(novo["id"])
	var venc: String = novo["sujeitos"][0]
	var perd: String = novo["sujeitos"][1]
	verdadeiro(u.fatos.obter(fv)["causas"].has(lf), "o resultado remonta à luta")
	verdadeiro(not Estado.vivo(u, perd) or Estado.saude_atual(u, perd) < 0.7, "o perdedor morreu ou ficou muito ferido")
	verdadeiro(float(u.estado(venc)["reputacao"]) > 0, "o vencedor ganhou fama")
	verdadeiro(Lendas.titulo(u, venc) != "", "e um título: " + Lendas.nome_com_titulo(u, venc))
	# Não decide de novo.
	Simulador.avancar(u, 14)
	igual(u.propostas.filter(func(p): return p.has("luta")).size(), 2, "a luta não é recalculada")
	# Lenda: décadas depois, os dez dias viram mais.
	u.definir_relogio(DataMundo.criar(340, 10))
	var v := Lendas.versao(u, u.fatos.obter(fv))
	verdadeiro(v["lenda"] != "" and not v["lenda"].contains(" 10 dias"), "a lenda cresceu: " + v["lenda"])
	igual(v["verdade"], u.fatos.obter(fv)["descricao"], "a verdade fica guardada")


func test_luta_em_misterio() -> void:
	var u := Universo.novo("Mistério")
	u.extras["semente"] = 5
	var a := u.criar_entidade("Kai", "pessoa", [], [{"chave": "força", "valor": "50"}])
	var b := u.criar_entidade("Lucas", "pessoa", [], [{"chave": "força", "valor": "50"}])
	var livro := u.criar_livro("L")
	var c := u.criar_capitulo(livro, "C")
	u.atualizar_capitulo(c, {"texto": "Kai enfrentou Lucas na beira do rio."})
	var lut: Array = Extrator.analisar(u, c).filter(func(p): return p["acao"] == "luta")
	u.aceitar_proposta(lut[0]["id"])
	Simulador.avancar(u, 7, {"aceitar_ecos": false})
	var eco: Dictionary = u.propostas.filter(func(p): return p.has("luta"))[0]
	Lutas.manter_misterio(u, eco["id"])
	Simulador.avancar(u, 30)
	verdadeiro(Estado.vivo(u, a) and Estado.vivo(u, b), "ninguém morreu: é mistério")
	igual(u.propostas.filter(func(p): return p.has("luta")).size(), 1, "e não é recalculada")


func test_guerra_nasce_da_simulacao() -> void:
	var m := _mundo(7474)
	var u: Universo = m["u"]
	# Ódio do líder de Sokovia pelo rei, inimigos na ficha.
	u.editar_entidade(m["sok"], {"campos": u.entidade(m["sok"])["campos"] + [{"chave": "inimigos", "valor": "Bermudit"}]})
	Simulador.registrar(u, {"tipo": "ódio", "descricao": "Dravek passou a odiar o Rei Azim.", "sujeitos": [m["dravek"], m["azim"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"acao": "odio"}})
	var mot := Guerras.motivo(u, m["sok"], m["ber"])
	verdadeiro(float(mot["forca"]) > 0.7, "motivo forte: %.2f (%s)" % [mot["forca"], mot["texto"]])
	var dias := 0
	while Guerras.todas(u).is_empty() and dias < 6 * 360:
		Simulador.avancar(u, 28)
		dias += 28
	verdadeiro(not Guerras.todas(u).is_empty(), "a simulação declarou a guerra")
	var g: String = Guerras.todas(u)[0]
	var decl := u.fatos.obter(Guerras.dados(u, g)["declaracao"])
	igual(decl["origem"]["tipo"], BancoDeFatos.ORIGEM_SIMULACAO, "declarada pela simulação")
	verdadeiro(not decl["causas"].is_empty(), "com causa: " + str(decl["causas"]))


func test_mundo_povoado_nao_quebra() -> void:
	var u := Universo.novo("Paz")
	u.extras["semente"] = 31
	var p := Povoador.gerar_planeta(u, "Velha Terra")
	Povoador.povoar(u, p)
	Simulador.avancar(u, 3 * 360)
	igual(Auditor.auditar(u).size(), 0, "auditor limpo depois de 3 anos")
