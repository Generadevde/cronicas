extends TesteBase
## Parte 13: Modo Viver — encarnar um personagem e viver o mundo por dentro, com
## cena, diário, mapa local com névoa, ficha, relações, objetivos, pertences,
## notícias locais e ações em texto livre.
## Teste do plano: viver um ano como um morador comum de Varn e transformar a sessão
## em capítulo.


func _mundo(semente: int = 1313) -> Dictionary:
	var u := Universo.novo("Varn")
	u.extras["semente"] = semente
	u.definir_relogio(DataMundo.criar(412, 10))
	var planeta := u.criar_entidade("Aldra", "planeta")
	var varn := u.criar_entidade("Varn", "cidade", [], [{"chave": "população", "valor": "5000"}])
	var dunel := u.criar_entidade("Dunel", "vila", [], [{"chave": "população", "valor": "600"}])
	var kresk := u.criar_entidade("Kresk", "cidade", [], [{"chave": "população", "valor": "8000"}])
	Mapa.colocar(u, planeta, "", 10, 10)
	Mapa.colocar(u, varn, planeta, 10, 10)
	Mapa.colocar(u, dunel, planeta, 12, 11)
	Mapa.colocar(u, kresk, planeta, 30, 4)
	var lucas := _pessoa(u, "Lucas", 45, "gentil, calado e paciente", varn, "ferreiro")
	var marta := _pessoa(u, "Marta", 42, "alegre, carinhosa e curiosa", varn, "padeira")
	var irene := _pessoa(u, "Irene", 20, "alegre, curiosa e corajosa", varn, "tecelã")
	var velho := _pessoa(u, "Bruno", 70, "rabugento e orgulhoso", varn, "carpinteiro")
	var kai := _pessoa(u, "Kai", 30, "ambicioso e frio", kresk, "mercador")
	return {"u": u, "varn": varn, "dunel": dunel, "kresk": kresk, "lucas": lucas, "marta": marta, "irene": irene, "bruno": velho, "kai": kai}


func _pessoa(u: Universo, nome: String, idade: int, jeito: String, lugar: String, oficio: String) -> String:
	var e := u.criar_entidade(nome, "pessoa", [], [{"chave": "idade", "valor": "%d anos" % idade}, {"chave": "personalidade", "valor": jeito}, {"chave": "ofício", "valor": oficio}])
	u.estado(e)["local"] = lugar
	return e


func test_entende_o_que_voce_escreve() -> void:
	igual(Vivencia.intencao("vou até a forja"), "viajar", "ir a um lugar")
	igual(Vivencia.intencao("peço trabalho a Lucas"), "pedir_trabalho", "pedir trabalho")
	igual(Vivencia.intencao("trabalho na forja durante um mês"), "trabalhar", "trabalhar")
	igual(Vivencia.intencao("como um pão"), "comer", "comer")
	igual(Vivencia.intencao("construo uma casa perto do rio"), "construir", "construir")
	igual(Vivencia.intencao("pergunto a Marta o que ela sabe de Kai"), "conversar", "conversar")
	igual(Vivencia.intencao("passo o inverno em casa"), "esperar", "esperar")
	igual(Vivencia._duracao(TextUtil.normalizar("trabalho durante um mês")), 30, "um mês")
	igual(Vivencia._duracao(TextUtil.normalizar("treino por 3 semanas")), 21, "três semanas")
	igual(Vivencia._duracao(TextUtil.normalizar("passo o inverno")), 90, "o inverno")
	igual(Vivencia._clausulas("Vou até a forja e peço trabalho a Lucas. Depois volto para casa").size(), 3, "três ações numa frase")


func test_viver_um_ano_em_varn() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var inicio := DataMundo.ordem(u.relogio)
	# Um morador comum, nascido em Varn, filho de Marta, sem ofício.
	var tomas := Vivencia.criar(u, {"nome": "Tomas", "lugar": m["varn"], "idade": 18, "jeito": "curioso, gentil e teimoso",
		"origem": "filho da padeira", "familia": "filho de Marta", "dinheiro": "6 moedas", "pertences": "uma faca, uma capa"})
	verdadeiro(tomas != "", "o personagem nasceu")
	igual(Vivencia.encarnado(u), tomas, "você vive Tomas")
	verdadeiro(u.estado(tomas)["familia"]["pais"].has(m["marta"]), "filho de Marta")
	igual(int(Vivencia.dinheiro(u, tomas)), 6, "seis moedas no bolso")
	verdadeiro(Vivencia.bens(u, tomas)["itens"].has("faca"), "a faca é dele")
	var cena := Vivencia.cena(u, tomas)
	verdadeiro(cena.contains("Estou em Varn") and cena.contains("Lucas"), "a cena: onde está e quem está por perto — " + cena)
	# Só conhece a vizinhança: Kresk fica na névoa.
	var con := Vivencia.conhecidos(u, tomas)
	verdadeiro(con.has(m["varn"]) and con.has(m["dunel"]), "conhece Varn e Dunel")
	falso(con.has(m["kresk"]), "não conhece Kresk")
	var r := Vivencia.agir(u, "Vou para Kresk")
	falso(r["ok"], "não sabe o caminho: " + r["texto"])
	# Pedir trabalho na forja (insistir pode ser preciso).
	var tentativas := 0
	while Vivencia._patrao(u, tomas) != m["lucas"] and tentativas < 6:
		r = Vivencia.agir(u, "Vou até a forja e peço trabalho a Lucas")
		tentativas += 1
	igual(Vivencia._patrao(u, tomas), m["lucas"], "Lucas aceitou depois de %d tentativa(s)" % tentativas)
	verdadeiro(diario_tem(u, "Pedi trabalho a Lucas"), "o diário guarda o pedido")
	# Um ano de vida: trabalho, conversa, compras, exploração, um plano e uma obra.
	r = Vivencia.agir(u, "Quero ser mestre ferreiro")
	verdadeiro(Estado.objetivos_ativos(u, tomas).size() > 0, "o plano virou objetivo")
	var mes := 0
	var construiu := ""
	var descobriu := false
	while DataMundo.ordem(Vivencia._agora(u, Vivencia.sessao(u))) < inicio + 360 and Estado.vivo(u, tomas):
		Vivencia.agir(u, "Trabalho na forja durante um mês")
		Vivencia.agir(u, "Converso com Marta")
		Vivencia.agir(u, "Compro pão. Como")
		if mes == 2:
			Vivencia.agir(u, "Pergunto a Lucas: o que você quer?")
		if mes == 3 and not descobriu:
			var e := Vivencia.agir(u, "Exploro os arredores")
			descobriu = e["texto"].begins_with("Explorando")
		if mes == 5:
			Vivencia.agir(u, "Converso com Irene. Dou a capa a Irene")
		if mes >= 6 and construiu == "" and Vivencia.dinheiro(u, tomas) >= 30:
			var c := Vivencia.agir(u, "Construo uma cabana perto do rio")
			for fid in c["fatos"]:
				if u.fatos.existe(fid) and u.fatos.obter(fid)["tipo"] == "construção":
					construiu = u.fatos.obter(fid)["sujeitos"][1]
		Vivencia.agir(u, "Durmo")
		mes += 1
	var s := Vivencia.sessao(u)
	verdadeiro(DataMundo.ordem(Vivencia._agora(u, s)) >= inicio + 360, "um ano se passou (%s)" % DataMundo.texto(Vivencia._agora(u, s)))
	verdadeiro(Estado.vivo(u, tomas), "Tomas viveu o ano")
	verdadeiro(Vivencia.habilidade(u, tomas, "ferreiro") >= 0.15, "aprendeu o ofício: %s" % Vivencia._nivel(Vivencia.habilidade(u, tomas, "ferreiro")))
	verdadeiro(Estado.valor_relacao(u, m["lucas"], tomas, "confianca") > 0.3, "Lucas confia nele (%.2f)" % Estado.valor_relacao(u, m["lucas"], tomas, "confianca"))
	verdadeiro(construiu != "" and u.entidades.has(construiu), "construiu a cabana (com %d moedas)" % int(Vivencia.dinheiro(u, tomas)))
	if construiu != "":
		igual(u.valor_campo(construiu, "dono"), "Tomas", "a cabana é dele, com página")
		verdadeiro(Mapa.no_mapa(u, construiu), "e está no mapa")
	verdadeiro(Vivencia.bens(u, m["irene"])["itens"].has("capa"), "a capa agora é de Irene")
	verdadeiro(str(u.estado(tomas)["local"]) == m["varn"], "ninguém mudou Tomas de lugar além de você")
	# O resto do mundo seguiu simulando em volta.
	var do_mundo := u.fatos.todos().filter(func(f): return DataMundo.ordem(f["data"]) > inicio and not f["dados"].get("vivido", false) and not f["sujeitos"].has(tomas))
	verdadeiro(do_mundo.size() > 10, "o mundo seguiu (%d acontecimentos sem Tomas)" % do_mundo.size())
	verdadeiro(s["diario"].size() >= 30, "o diário tem %d entradas" % s["diario"].size())
	# Ficha, relações, notícias.
	var f := Vivencia.ficha(u, tomas)
	verdadeiro(f["habilidades"].size() > 0 and float(f["dinheiro"]) >= 0.0, "a ficha: %s" % str(f["habilidades"]))
	verdadeiro(Vivencia.relacoes(u, tomas).any(func(x): return x["id"] == m["lucas"]), "Lucas está nas relações")
	# Tudo coerente.
	var aud := Integridade.auditar_tudo(u)
	igual(Integridade.total(aud), 0, "o mundo continua coerente: %s" % str(aud))
	# A sessão vira capítulo.
	var cap := Vivencia.virar_capitulo(u, "Um ano em Varn")
	verdadeiro(cap != "", "virou capítulo")
	var c := u.capitulo(cap)
	igual(u.livro(c["livro"])["titulo"], "Vidas", "no livro Vidas")
	verdadeiro(str(c["texto"]).contains("Pedi trabalho a Lucas") and str(c["texto"]).contains("Trabalhei um mês"), "em primeira pessoa")
	verdadeiro(str(c["texto"]).contains(DataMundo.texto(DataMundo.criar(412, 10))), "com as datas")
	igual(Extrator.analisar(u, cap).size(), 0, "o capítulo não é reanalisado (os fatos já existem)")
	var cap3 := Vivencia.virar_capitulo(u, "Em terceira pessoa", "terceira")
	verdadeiro(str(u.capitulo(cap3)["texto"]).contains("Tomas pediu trabalho a Lucas"), "e em terceira pessoa")


func test_quem_voce_vive_nao_age_sozinho() -> void:
	var m := _mundo(77)
	var u: Universo = m["u"]
	Simulador.registrar(u, {"tipo": "ódio", "descricao": "Irene quer ir embora para Kresk.", "sujeitos": [m["irene"], m["kresk"]], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": [{"op": "objetivo", "quem": m["irene"], "tipo": "viagem", "alvo": m["kresk"], "forca": 0.9}]}})
	Vivencia.comecar(u, m["irene"], "terceira")
	var antes := u.fatos.quantidade()
	Simulador.avancar(u, 120)
	var dela := u.fatos.todos().slice(antes).filter(func(f): return f["sujeitos"].size() > 0 and f["sujeitos"][0] == m["irene"] and f["origem"]["tipo"] == BancoDeFatos.ORIGEM_SIMULACAO and f["tipo"] in ["viagem", "chegada", "amizade", "conversa", "partida"])
	igual(dela.size(), 0, "Irene não decide nada sozinha enquanto você a vive")
	verdadeiro(Vivencia.cena(u, m["irene"]).contains("Irene está em Varn"), "a cena em terceira pessoa")
	# Atacar alguém: a outra mente reage, e quem viu também.
	var r := Vivencia.agir(u, "Ataco Bruno")
	verdadeiro(r["ok"], r["texto"])
	verdadeiro(Estado.valor_relacao(u, m["bruno"], m["irene"], "raiva") > 0.3, "Bruno ficou com raiva")
	verdadeiro(Estado.valor_relacao(u, m["lucas"], m["irene"], "medo") > 0.0 or Estado.valor_relacao(u, m["lucas"], m["irene"], "raiva") > 0.0, "quem viu mudou o que sente")
	# Sem dinheiro, não compra.
	falso(Vivencia.agir(u, "Compro um cavalo")["ok"], "um cavalo custa mais do que ela tem")
	# Parar devolve a mente.
	Vivencia.parar(u)
	igual(Vivencia.encarnado(u), "", "parou de viver")
	falso(Vivencia.sessao(u, m["irene"]).is_empty(), "a sessão fica guardada")
	igual(Auditor.auditar(u).size(), 0, "tudo com causa")


func diario_tem(u: Universo, trecho: String) -> bool:
	return Vivencia.diario(u).any(func(x): return str(x["eu"]).contains(trecho))
