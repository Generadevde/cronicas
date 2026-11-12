class_name Interprete
extends RefCounted
## A IA local como intérprete: quando o Leitor só consegue anotar uma linha como
## acontecimento, a IA (pequena, no próprio computador) reescreve a linha em frases
## simples que o Leitor entende. Ela nunca decide nada: só traduz, o autor confere
## na margem, e o que ela inventar (nome ou número que não está na linha) é cortado.

const MODELOS := [
	"Existe uma cidade chamada NOME.",
	"Na cidade de NOME viviam 300 habitantes.",
	"O rei NOME chegou a LUGAR.",
	"NOME chegou a LUGAR.",
	"NOME matou OUTRO.",
	"NOME feriu OUTRO.",
	"NOME venceu OUTRO.",
	"NOME traiu OUTRO.",
	"NOME odeia OUTRO.",
	"NOME ama OUTRO.",
	"NOME casou com OUTRO.",
	"NOME salvou OUTRO.",
	"NOME ensinou OUTRO.",
	"NOME morreu.",
	"NOME adoeceu.",
	"NOME foi ferido.",
	"NOME se recuperou.",
	"NOME tomou o trono.",
	"Uma enchente atingiu LUGAR.",
	"Um incêndio terrível atingiu LUGAR.",
	"A ponte caiu.",
	"O rei de LUGAR estava doente.",
	"NOME a rainha de LUGAR estava chegando.",
	"O povo estava com medo.",
	"O povo estava com raiva.",
	"Seus moradores viviam da pesca.",
	"LUGAR estava em um grande deserto.",
	"O povo odeia NOME.",
	"O povo teme NOME.",
	"3 anos se passaram.",
	"À noite, lobos aparecem e atacam as pessoas.",
	"Neste mundo, quem mente perde a voz.",
]


static func pedido(u: Universo, frase: String, foco: String, antes: Array = []) -> String:
	var nomes: Array = []
	for e in u.entidades_ativas():
		if u.valor_campo(e["id"], "descrição") != "" and nomes.size() < 40:
			nomes.append(str(e["nome"]))
	var l: Array = []
	l.append("Você traduz a linha de um autor em frases simples que um programa entende.")
	l.append("Use SOMENTE os modelos abaixo, trocando as palavras em maiúsculas e os números pelos da linha. Pode trocar o tipo de lugar, o cargo, a criatura e a lei.")
	l.append("Não invente nomes, números nem acontecimentos que a linha não diz. Se nenhum modelo servir, responda só: NADA")
	l.append("Modelos:")
	for m in MODELOS:
		l.append("- " + m)
	if not nomes.is_empty():
		l.append("Nomes que já existem no universo: " + ", ".join(nomes) + ".")
	if foco != "" and not u.entidade(foco).is_empty():
		l.append("A história está em: %s." % str(u.entidade(foco)["nome"]))
	if not antes.is_empty():
		l.append("Linhas anteriores (só para saber de quem ou de onde se fala; não traduza estas):")
		for a in antes.slice(-3):
			l.append("  " + str(a).strip_edges())
		l.append("Troque \"ele\", \"ela\", \"seus\", \"lá\" pelo nome certo.")
	l.append("Linha do autor: \"%s\"" % frase.strip_edges())
	l.append("Responda com no máximo 3 frases, uma por linha, sem explicar.")
	return "\n".join(l)


## Limpa a resposta da IA: tira marcadores, corta o que ela inventou e o que repete a linha.
static func limpar(u: Universo, saida: String, frase: String) -> Array:
	var r: Array = []
	var permitido := TextUtil.normalizar(frase)
	var rx_nome := RegEx.new()
	rx_nome.compile("[A-ZÀ-Ý][\\wÀ-ÿ'-]+")
	var rx_num := RegEx.new()
	rx_num.compile("\\d+")
	var rx_ini := RegEx.new()
	rx_ini.compile("^[\\s\\-\\*•\\d\\.\\)]+")
	for linha in saida.split("\n", false):
		var t: String = rx_ini.sub(linha, "").strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
		if t.length() < 6 or t.length() > 160 or t.ends_with(":") or TextUtil.normalizar(t).begins_with("nada"):
			continue
		if not (t.ends_with(".") or t.ends_with("!")):
			t += "."
		if Escrita.chave(t) == Escrita.chave(frase):
			continue
		var inventou := false
		var palavras := rx_nome.search_all(t)
		for i in palavras.size():
			var w := palavras[i].get_string()
			if palavras[i].get_start() == 0 and (TextUtil.normalizar(w) in LeitorMais.INICIOS or TextUtil.normalizar(w) in ["a", "o", "neste"]):
				continue
			if not permitido.contains(TextUtil.normalizar(w)) and LeitorMais._existe(u, w) == "":
				inventou = true
		for m in rx_num.search_all(LeitorMais.milhares(t)):
			var n := m.get_string()
			if not LeitorMais.por_extenso(Leitor._limpo(LeitorMais.milhares(frase))).contains(" " + n + " "):
				inventou = true
		if inventou or r.has(t):
			continue
		r.append(t)
		if r.size() >= 3:
			break
	return r


## Pergunta à IA (bloqueia: chame de uma Thread). Devolve as frases já limpas.
static func interpretar(u: Universo, frase: String, foco: String) -> Array:
	var saida := IALocal.gerar(pedido(u, frase, foco), 80)
	return limpar(u, saida, frase) if saida != "" else []


## O autor aceitou a leitura da IA: as frases valem como se ele as tivesse escrito,
## presas à linha original (apagar a linha desfaz tudo). Devolve os itens entendidos.
static func aplicar(u: Universo, cid: String, frase: String, linhas: Array, ja: Array = []) -> Array:
	var cap: Dictionary = u.capitulos.get(cid, {})
	if cap.is_empty():
		return []
	var itens: Array = []
	var raizes: Array = []
	var sem_tempo: bool = u.extras.get("escrita_sem_tempo", false)
	u.extras["escrita_sem_tempo"] = true
	for l in linhas:
		# A frase entra no texto só para ser lida (as ações são achadas no capítulo) e sai em seguida.
		var texto_antes := str(cap["texto"])
		cap["texto"] = texto_antes + "\n" + str(l) + "\n"
		var c := Escrita.processar_frase(u, cid, str(l))
		cap["texto"] = texto_antes
		cap["feed"].pop_back()
		var bons: Array = c["itens"].filter(func(i): return str(i["tipo"]) != "acontecimento" and str(i["tipo"]) != "consulta")
		var raiz := str(c.get("raiz", ""))
		# O Livro já tinha entendido a ação ou a consequência desta linha: a IA não repete.
		var repete: bool = (ja.has("acao") or ja.has("consequencia")) and bons.all(func(i): return str(i["tipo"]) in ["acao", "consequencia"])
		if bons.is_empty() or repete:
			for it in bons:
				if str(it["tipo"]) == "acao":
					u.desfazer_fato(str(it["id"]))
			if raiz != "":
				Leitor.desfazer(u, raiz)
			continue
		if raiz != "":
			raizes.append(raiz)
		for it in bons:
			if str(it["tipo"]) == "acao":
				raizes.append(str(it["id"]))
		itens.append_array(bons)
	u.extras["escrita_sem_tempo"] = sem_tempo
	if not raizes.is_empty():
		var mapa: Dictionary = cap.get("ia", {})
		mapa[Escrita.chave(frase)] = mapa.get(Escrita.chave(frase), []) + raizes
		cap["ia"] = mapa
	u.marcar_mudanca()
	return itens


## Desfaz o que a IA leu de uma linha (a linha do autor continua como estava).
static func desfazer(u: Universo, cid: String, frase: String) -> int:
	var cap: Dictionary = u.capitulos.get(cid, {})
	var k := Escrita.chave(frase)
	var n := 0
	for ri in cap.get("ia", {}).get(k, []):
		if u.fatos.existe(str(ri)) and u.fatos.obter(str(ri))["canon"]:
			n += Leitor.desfazer(u, str(ri)) if u.fatos.obter(str(ri))["dados"].get("leitura", false) else u.desfazer_fato(str(ri))
	cap.get("ia", {}).erase(k)
	u.marcar_mudanca()
	return n


## Separa as frases da IA em [seguras, duvidosas]: é segura a que só usa nomes que estão na própria linha do autor.
## As outras (a IA deduziu de quem se fala pelas linhas anteriores) pedem o sim do autor antes de valer.
static func separar(frase: String, linhas: Array) -> Array:
	var permitido := TextUtil.normalizar(frase)
	var rx := RegEx.new()
	rx.compile("[A-ZÀ-Ý][\\wÀ-ÿ'-]+")
	var seguras: Array = []
	var duvidosas: Array = []
	for l in linhas:
		var ok := true
		for m in rx.search_all(str(l)):
			var w := TextUtil.normalizar(m.get_string())
			if m.get_start() == 0 and (w in LeitorMais.INICIOS or w in ["a", "o", "neste"]):
				continue
			if not permitido.contains(w):
				ok = false
		if ok:
			seguras.append(l)
		else:
			duvidosas.append(l)
	return [seguras, duvidosas]
