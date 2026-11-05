class_name Pesquisa
extends RefCounted
## Pesquisa em tudo do universo: entidades (nome, apelidos, tipo, campos),
## capítulos (título e texto) e notas privadas.
## Sem acento, sem diferença de maiúsculas e tolerante a erros de digitação.


## Devolve resultados ordenados do mais relevante ao menos:
## [{tipo: "entidade"|"capitulo"|"nota", id, titulo, detalhe, pontos}]
static func buscar(universo: Universo, consulta: String, limite: int = 50) -> Array:
	var q := TextUtil.chave(consulta)
	if q.length() < 1:
		return []
	var palavras_q := TextUtil.palavras(q)
	var resultados: Array = []

	for e in universo.entidades_ativas():
		var pontos := 0
		var detalhe: String = e["tipo"]
		var nomes: Array = [e["nome"]]
		nomes.append_array(e["apelidos"])
		for n in nomes:
			pontos = maxi(pontos, _pontuar_nome(TextUtil.chave(str(n)), q, palavras_q))
		if pontos == 0 and TextUtil.chave(e["tipo"]).contains(q):
			pontos = 35
		if pontos == 0:
			for c in e["campos"]:
				var valor_n := TextUtil.normalizar(c["valor"])
				var pos := valor_n.find(q)
				if pos >= 0:
					pontos = 30
					detalhe = "%s: %s" % [c["chave"], TextUtil.trecho(c["valor"], pos, 40)]
					break
		if pontos > 0:
			resultados.append({"tipo": "entidade", "id": e["id"], "titulo": e["nome"],
				"detalhe": detalhe, "pontos": pontos})

	for l in universo.livros:
		for cid in l["capitulos"]:
			var cap: Dictionary = universo.capitulos[cid]
			var titulo_n := TextUtil.chave(cap["titulo"])
			var pontos := 0
			var detalhe: String = l["titulo"]
			if titulo_n == q:
				pontos = 70
			elif titulo_n.contains(q):
				pontos = 45
			var pos := TextUtil.normalizar(cap["texto"]).find(q)
			if pos >= 0:
				pontos = maxi(pontos, 25)
				detalhe = TextUtil.trecho(cap["texto"], pos)
			if pontos > 0:
				resultados.append({"tipo": "capitulo", "id": cid, "titulo": cap["titulo"],
					"detalhe": detalhe, "pontos": pontos})

	for n in universo.notas:
		var pontos := 0
		var detalhe := "nota do autor"
		if TextUtil.chave(n["titulo"]).contains(q):
			pontos = 40
		var pos := TextUtil.normalizar(n["texto"]).find(q)
		if pos >= 0:
			pontos = maxi(pontos, 20)
			detalhe = TextUtil.trecho(n["texto"], pos)
		if pontos > 0:
			resultados.append({"tipo": "nota", "id": n["id"], "titulo": n["titulo"],
				"detalhe": detalhe, "pontos": pontos})

	resultados.sort_custom(func(a, b):
		if a["pontos"] != b["pontos"]:
			return a["pontos"] > b["pontos"]
		return TextUtil.chave(a["titulo"]) < TextUtil.chave(b["titulo"]))
	return resultados.slice(0, limite)


static func _pontuar_nome(nome: String, q: String, palavras_q: PackedStringArray) -> int:
	if nome == q:
		return 100
	if nome.begins_with(q):
		return 85
	if nome.contains(q):
		return 65
	# Tolerância a erros: cada palavra da consulta precisa parecer com alguma palavra do nome.
	var palavras_nome := TextUtil.palavras(nome)
	if palavras_q.is_empty() or palavras_nome.is_empty():
		return 0
	for pq in palavras_q:
		var achou := false
		for pn in palavras_nome:
			if pn.begins_with(pq) and pq.length() >= 2:
				achou = true
				break
			if TextUtil.distancia(pq, pn) <= TextUtil.tolerancia(maxi(pq.length(), pn.length())):
				achou = true
				break
		if not achou:
			return 0
	return 50
