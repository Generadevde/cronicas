extends TesteBase
## Parte 10: viver o mundo por dentro — conversar com os personagens (como deus, como
## desconhecido, como outro personagem), acompanhar alguém de perto, ponto de vista,
## IA local só quando usada. Teste do plano: perguntar a Daren por que ele odeia Kai.


func _mundo() -> Dictionary:
	var u := Universo.novo("Aldra")
	u.extras["semente"] = 1010
	u.definir_relogio(DataMundo.criar(411, 100))
	var varn := u.criar_entidade("Varn", "cidade")
	var kresk := u.criar_entidade("Kresk", "cidade")
	var daren := u.criar_entidade("Daren", "pessoa", [], [{"chave": "idade", "valor": "19 anos"}, {"chave": "personalidade", "valor": "rancoroso e orgulhoso"},
		{"chave": "segredos", "valor": "sentiu vergonha do pai quando ele caiu na praça"}])
	var lucas := u.criar_entidade("Lucas", "pessoa", [], [{"chave": "idade", "valor": "45 anos"}, {"chave": "ofício", "valor": "ferreiro"}])
	var kai := u.criar_entidade("Kai", "pessoa", [], [{"chave": "idade", "valor": "30 anos"}, {"chave": "personalidade", "valor": "cruel"}])
	var mira := u.criar_entidade("Mira", "pessoa", [], [{"chave": "idade", "valor": "19 anos"}, {"chave": "personalidade", "valor": "gentil"}])
	for e in [daren, lucas, kai, mira]:
		u.estado(e)["local"] = varn
	var l := u.criar_livro("A Vingança de Daren")
	var cap := u.criar_capitulo(l, "A Praça de Varn")
	u.atualizar_capitulo(cap, {"texto": "Daren é filho de Lucas. Kai enfrentou Lucas na praça de Varn, e Lucas perdeu. Daren viu tudo.", "data": DataMundo.criar(411, 90)})
	for p in Extrator.analisar(u, cap):
		u.aceitar_proposta(p["id"])
	# Os ecos (o ódio de Daren) viram fato.
	for p in u.propostas.duplicate():
		if p["status"] == "eco":
			u.aceitar_proposta(p["id"])
	# Mira é a amiga em quem Daren confia.
	Simulador.registrar(u, {"tipo": "amizade", "descricao": "Daren e Mira cresceram juntos.", "sujeitos": [daren, mira], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"mudancas": [{"op": "relacao", "de": daren, "para": mira, "deltas": {"confianca": 0.9, "afeto": 0.8}}, {"op": "relacao", "de": mira, "para": daren, "deltas": {"afeto": 0.7}}]}})
	# Algo que Daren não sabe.
	var longe := Simulador.registrar(u, {"tipo": "segredo", "descricao": "Kai matou um mercador em Kresk.", "sujeitos": [kai], "lugar": kresk,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""}, "dados": {"importancia": 0.8, "mudancas": []}})
	return {"u": u, "varn": varn, "kresk": kresk, "daren": daren, "lucas": lucas, "kai": kai, "mira": mira, "cap": cap, "longe": longe}


func test_daren_por_que_odeia_kai() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	verdadeiro(Estado.valor_relacao(u, m["daren"], m["kai"], "raiva") > 0.2 or Estado.emocoes_atuais(u, m["daren"]).any(func(e): return e["alvo"] == m["kai"]), "Daren odeia Kai (pelos fatos)")
	# Como deus: seco, esconde.
	var c1 := Conversa.nova(u, m["daren"], "deus")
	var r1 := Conversa.perguntar(u, c1, "Por que você odeia o Kai?")
	igual(r1["intencao"], "odio", "entendeu a pergunta")
	falso(r1["texto"].to_lower().contains("vergonha"), "esconde a vergonha: " + r1["texto"])
	verdadeiro(r1["tom"] in ["seco", "reservado", "irritado"], "responde seco (%s): %s" % [r1["tom"], r1["texto"]])
	# Insistir como deus: irrita quem é orgulhoso, e continua sem contar.
	var r1b := Conversa.perguntar(u, c1, "Por que você odeia o Kai?")
	falso(r1b["texto"].to_lower().contains("vergonha"), "insistindo como deus, ainda esconde: " + r1b["texto"])
	# Como Mira, em quem confia, insistindo: abre-se.
	var c2 := Conversa.nova(u, m["daren"], "personagem", m["mira"])
	var r2 := Conversa.perguntar(u, c2, "Por que você odeia o Kai?")
	verdadeiro(r2["texto"].contains("Lucas") or r2["texto"].contains("pai"), "a Mira ele conta o que aconteceu: " + r2["texto"])
	var r3 := Conversa.perguntar(u, c2, "Por que você odeia o Kai, de verdade?")
	verdadeiro(r3["texto"].to_lower().contains("vergonha"), "insistindo, como alguém em quem confia, ele se abre: " + r3["texto"])
	igual(r3["tom"], "aberto", "tom aberto")
	# A confissão pode virar fato (passa pelos ecos).
	var props := Conversa.propostas(u, c2)
	igual(props.size(), 1, "uma confissão proposta")
	var fid := u.aceitar_proposta(props[0]["id"])
	verdadeiro(fid != "", "aceita, virou fato")
	verdadeiro(Estado.conhece(u, m["mira"], fid), "Mira sabe do que ouviu")
	verdadeiro(Pecas.marcas(u, m["daren"]).any(func(x): return x.begins_with("confessou")), "Daren confessou")
	# Avançar o tempo não aceita sozinho o que vem de conversa.
	Conversa.perguntar(u, c2, "Prometa que não vai matar o Kai.")
	Simulador.avancar(u, 7)
	verdadeiro(Conversa.propostas(u, c2).size() <= 1, "o que nasce da conversa espera você")


func test_so_sabe_o_que_sabe() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var c := Conversa.nova(u, m["daren"], "personagem", m["mira"])
	var r := Conversa.perguntar(u, c, "O que você sabe sobre Kresk?")
	verdadeiro(not r["texto"].contains("mercador"), "Daren não sabe do que houve em Kresk: " + r["texto"])
	var r2 := Conversa.perguntar(u, c, "O que você quer?")
	verdadeiro(r2["texto"].contains("Kai"), "quer que Kai pague: " + r2["texto"])
	var r3 := Conversa.perguntar(u, c, "O que você acha da Mira?")
	verdadeiro(r3["texto"].contains("confio") or r3["texto"].contains("gosto"), "fala de Mira com afeto: " + r3["texto"])
	# O pedido à IA só leva o que ele sabe.
	var pedido := IALocal.montar_pedido(u, m["daren"], "o que houve?", "nada", Conversa._o_que_sabe(u, m["daren"]).map(func(f): return f["descricao"]), "seco")
	verdadeiro(pedido.contains("Lucas"), "o pedido à IA leva o que ele viveu")
	falso(pedido.contains("mercador"), "e não leva o que ele não sabe")
	falso(IALocal.disponivel(), "sem IA configurada, respostas montadas (a IA só carrega quando usada)")


func test_promessa_e_duvida() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var c := Conversa.nova(u, m["daren"], "personagem", m["mira"])
	Conversa.perguntar(u, c, "Prometa que não vai matar o Kai.")
	Conversa.perguntar(u, c, "Prometa que não vai matar o Kai.")
	var ps := Conversa.propostas(u, c)
	verdadeiro(ps.any(func(p): return p["acao"] == "promessa"), "Daren prometeu (para Mira, insistindo)")
	var c2 := Conversa.nova(u, m["daren"], "personagem", m["mira"])
	var r := Conversa.perguntar(u, c2, "O Kai não matou ninguém, ele é inocente.")
	verdadeiro(Conversa.propostas(u, c2).any(func(p): return p["acao"] == "duvida") or r["texto"].contains("acreditaria"), "uma dúvida plantada (ou desconfiança): " + r["texto"])
	var cena := Conversa.virar_cena(u, c)
	verdadeiro(u.capitulo(cena)["texto"].contains("Prometa"), "a conversa virou cena")
	falso(u.capitulo(cena)["canon"], "em rascunho")


func test_acompanhar_e_ponto_de_vista() -> void:
	var m := _mundo()
	var u: Universo = m["u"]
	var pv0 := Acompanhar.ponto_de_vista(u, m["daren"])
	verdadeiro(pv0.contains("não sabe") or pv0.contains("não chegou"), "o ponto de vista diz que há coisas que ele não sabe")
	var d := Acompanhar.seguir(u, m["daren"], 30, "dia")
	verdadeiro(not d.is_empty(), "o acompanhamento gera um diário (%d entradas)" % d.size())
	verdadeiro(d.any(func(x): return str(x["texto"]).begins_with("(")), "com o que ele pensa e sente")
	var cap := Acompanhar.salvar(u, m["daren"], d)
	falso(u.capitulo(cap)["canon"], "salvo como rascunho de capítulo")
	var pv := Acompanhar.ponto_de_vista(u, m["daren"])
	verdadeiro(pv.contains("Lucas"), "o ponto de vista mostra o que ele viveu")
	falso(pv.contains("O que viveu") == false, "seções do ponto de vista")
	falso(pv.contains("matou um mercador em Kresk.[/url]\n• ") and pv.find("O que viveu") < pv.find("mercador") and pv.find("mercador") < pv.find("O que ouviu"), "o que não sabe não aparece como vivido")
