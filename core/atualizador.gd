class_name AutoAtualizador
extends RefCounted
## Quando um fato é aceito, calcula as MUDANÇAS que ele causa no estado do mundo
## (vivo/morto, onde está, família, relações, emoções, objetivos), guarda essas
## mudanças dentro do próprio fato e as aplica. Assim o estado do mundo sempre pode
## ser reconstruído do zero relendo o banco de fatos — o banco é a verdade.
##
## Também propõe ECOS: reações que o mundo sugere e o autor aceita ou não.
## Ecos têm origem "simulacao" e sempre apontam para o fato que os causou.


## Calcula e aplica as mudanças de um fato recém-aceito. Devolve os ecos propostos.
static func aplicar(u: Universo, fid: String, gerar_ecos: bool = true) -> Array:
	var f := u.fatos.obter(fid)
	if f.is_empty() or not f["canon"]:
		return []
	var ops := mudancas_de(u, f)
	f["dados"]["mudancas"] = ops
	Mudancas.aplicar(u, ops, f)
	if not gerar_ecos:
		return []
	var ecos := ecos_de(u, f)
	for eco in ecos:
		u.propostas.append(eco)
	return ecos


## As mudanças diretas de cada tipo de ação (lista de operações).
static func mudancas_de(u: Universo, f: Dictionary) -> Array:
	var acao: String = f["dados"].get("acao", "")
	var s: Array = f["sujeitos"]
	var a: String = s[0] if s.size() > 0 else ""
	var b: String = s[1] if s.size() > 1 else ""
	var ops: Array = []
	match acao:
		"vitoria":
			ops.append({"op": "ferir", "quem": b, "descricao": "ferido em luta contra %s" % _n(u, a), "gravidade": 0.15})
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"raiva": 0.4, "respeito": 0.1}})
			ops.append({"op": "mudar", "quem": a, "chave": "reputacao", "delta": 1.0})
			ops.append({"op": "mudar", "quem": b, "chave": "reputacao", "delta": -0.5})
		"derrota":
			ops.append({"op": "ferir", "quem": a, "descricao": "ferido em luta contra %s" % _n(u, b), "gravidade": 0.15})
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"raiva": 0.4, "respeito": 0.1}})
			ops.append({"op": "mudar", "quem": b, "chave": "reputacao", "delta": 1.0})
		"luta":
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"raiva": 0.2}})
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"raiva": 0.2}})
		"morte_por":
			ops.append({"op": "morrer", "quem": b})
			ops.append({"op": "mudar", "quem": a, "chave": "reputacao", "delta": 1.0})
		"morte":
			ops.append({"op": "morrer", "quem": a})
		"ferimento":
			ops.append({"op": "ferir", "quem": b, "descricao": "ferido por %s" % _n(u, a), "gravidade": 0.3})
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"raiva": 0.5, "medo": 0.2}})
		"testemunho":
			ops.append({"op": "conhecer_capitulo", "quem": a, "cap": f["origem"].get("ref", "")})
		"filiacao":
			ops.append({"op": "familia", "pai": b, "filho": a})
		"paternidade":
			ops.append({"op": "familia", "pai": a, "filho": b})
		"casamento":
			ops.append({"op": "vinculo", "quem": a, "tipo": "conjuges", "outro": b})
			ops.append({"op": "vinculo", "quem": b, "tipo": "conjuges", "outro": a})
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"afeto": 0.6, "confianca": 0.4}})
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"afeto": 0.6, "confianca": 0.4}})
		"amor":
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"afeto": 0.7}})
		"odio":
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"raiva": 0.8, "afeto": -0.5}})
		"medo":
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"medo": 0.7}})
		"amizade":
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"afeto": 0.4, "confianca": 0.4}})
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"afeto": 0.4, "confianca": 0.4}})
		"traicao":
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"confianca": -0.8, "raiva": 0.6, "afeto": -0.4}})
		"ensino":
			ops.append({"op": "vinculo", "quem": a, "tipo": "discipulos", "outro": b})
			ops.append({"op": "vinculo", "quem": b, "tipo": "mestres", "outro": a})
			ops.append({"op": "relacao", "de": b, "para": a, "deltas": {"respeito": 0.5}})
		"aprendizado":
			ops.append({"op": "vinculo", "quem": a, "tipo": "mestres", "outro": b})
			ops.append({"op": "vinculo", "quem": b, "tipo": "discipulos", "outro": a})
			ops.append({"op": "relacao", "de": a, "para": b, "deltas": {"respeito": 0.5}})
		"chegada":
			ops.append({"op": "mover", "quem": a, "lugar": f["lugar"]})
		"nascimento":
			ops.append({"op": "nascer", "quem": a, "lugar": f["lugar"]})
	if acao.begins_with("eco_"):
		ops.append_array(_ops_de_eco(f["dados"].get("efeito", {})))
	# Quem estava num lugar durante uma cena passa a estar lá.
	if f["lugar"] != "" and acao in ["vitoria", "derrota", "luta", "ferimento", "morte_por", "testemunho", "amizade", "traicao"]:
		for e in s:
			ops.append({"op": "mover", "quem": e, "lugar": f["lugar"], "se_vivo": true})
	# Quem participou conhece o fato.
	for e in s:
		ops.append({"op": "conhecer", "quem": e})
	return ops


static func _ops_de_eco(efeito: Dictionary) -> Array:
	var quem: String = efeito.get("quem", "")
	var alvo: String = efeito.get("alvo", "")
	var forca: float = float(efeito.get("forca", 0.6))
	var emocao: String = str(efeito.get("emocao", ""))
	if quem == "":
		return []
	var ops: Array = [{"op": "emocao", "quem": quem, "emocao": emocao, "forca": forca, "alvo": alvo}]
	match emocao:
		"odio", "raiva", "rancor":
			ops.append({"op": "relacao", "de": quem, "para": alvo, "deltas": {"raiva": forca, "afeto": -forca * 0.5}})
		"humilhacao":
			ops.append({"op": "relacao", "de": quem, "para": alvo, "deltas": {"raiva": forca * 0.7}})
	if efeito.has("objetivo"):
		ops.append({"op": "objetivo", "quem": quem, "tipo": str(efeito["objetivo"]), "alvo": alvo, "forca": forca})
	elif emocao == "odio" and forca >= 0.8:
		ops.append({"op": "objetivo", "quem": quem, "tipo": "vingança", "alvo": alvo, "forca": forca})
	ops.append({"op": "lembrar", "quem": quem, "peso": forca})
	return ops


## Reações sugeridas (ainda não são fatos: o autor aceita, ajusta ou risca).
static func ecos_de(u: Universo, f: Dictionary) -> Array:
	var acao: String = f["dados"].get("acao", "")
	var s: Array = f["sujeitos"]
	var a: String = s[0] if s.size() > 0 else ""
	var b: String = s[1] if s.size() > 1 else ""
	var fid: String = f["id"]
	var ecos: Array = []
	match acao:
		"vitoria", "derrota":
			var vencedor := a if acao == "vitoria" else b
			var perdedor := b if acao == "vitoria" else a
			ecos.append(_eco(u, fid, [perdedor, vencedor], "%s sente humilhação e raiva de %s." % [_n(u, perdedor), _n(u, vencedor)],
				{"quem": perdedor, "emocao": "humilhacao", "alvo": vencedor, "forca": 0.6}))
			for parente in Estado.familia_proxima(u, perdedor):
				if parente == vencedor:
					continue
				if Estado.testemunhou_no_capitulo(u, parente, f):
					ecos.append(_eco(u, fid, [parente, vencedor], "%s viu a derrota de %s e passou a odiar %s." % [_n(u, parente), _n(u, perdedor), _n(u, vencedor)],
						{"quem": parente, "emocao": "odio", "alvo": vencedor, "forca": 0.85}))
				else:
					ecos.append(_eco(u, fid, [parente, vencedor], "Quando souber, %s ficará com raiva de %s pela derrota de %s." % [_n(u, parente), _n(u, vencedor), _n(u, perdedor)],
						{"quem": parente, "emocao": "raiva", "alvo": vencedor, "forca": 0.4}))
			for discipulo in u.estado(perdedor)["familia"]["discipulos"]:
				if discipulo != vencedor:
					ecos.append(_eco(u, fid, [discipulo, vencedor], "%s quer provar que o mestre %s não era fraco." % [_n(u, discipulo), _n(u, perdedor)],
						{"quem": discipulo, "emocao": "rivalidade", "alvo": vencedor, "forca": 0.5}))
		"morte_por":
			for parente in Estado.familia_proxima(u, b):
				if parente != a:
					ecos.append(_eco(u, fid, [parente, a], "%s está de luto por %s e jura vingança contra %s." % [_n(u, parente), _n(u, b), _n(u, a)],
						{"quem": parente, "emocao": "odio", "alvo": a, "forca": 0.9, "objetivo": "vingança"}))
			for amigo in _proximos_por_afeto(u, b):
				if amigo != a and not Estado.familia_proxima(u, b).has(amigo):
					ecos.append(_eco(u, fid, [amigo, a], "%s não perdoa %s pela morte de %s." % [_n(u, amigo), _n(u, a), _n(u, b)],
						{"quem": amigo, "emocao": "raiva", "alvo": a, "forca": 0.6}))
		"morte":
			for parente in Estado.familia_proxima(u, a):
				ecos.append(_eco(u, fid, [parente], "%s está de luto por %s." % [_n(u, parente), _n(u, a)],
					{"quem": parente, "emocao": "luto", "alvo": a, "forca": 0.8}))
		"traicao":
			ecos.append(_eco(u, fid, [b, a], "%s nunca mais vai confiar em %s." % [_n(u, b), _n(u, a)],
				{"quem": b, "emocao": "rancor", "alvo": a, "forca": 0.7}))
		"ferimento":
			ecos.append(_eco(u, fid, [b, a], "%s passou a temer e odiar %s." % [_n(u, b), _n(u, a)],
				{"quem": b, "emocao": "medo", "alvo": a, "forca": 0.5}))
		"amor":
			if Estado.valor_relacao(u, b, a, "afeto") > 0.3:
				ecos.append(_eco(u, fid, [a, b], "O amor de %s por %s é correspondido." % [_n(u, a), _n(u, b)],
					{"quem": b, "emocao": "amor", "alvo": a, "forca": 0.6}))
	return ecos.filter(func(x): return not x.is_empty())


static func _proximos_por_afeto(u: Universo, eid: String) -> Array:
	var lista: Array = []
	for outro in u.entidades:
		if outro != eid and Estado.valor_relacao(u, outro, eid, "afeto") >= 0.4:
			lista.append(outro)
	return lista


static func _n(u: Universo, eid: String) -> String:
	return u.entidade(eid).get("nome", "?")


static func _eco(u: Universo, causa: String, sujeitos: Array, descricao: String, efeito: Dictionary) -> Dictionary:
	# Só quem tem mente reage, e só os vivos.
	var quem: String = efeito.get("quem", "")
	if quem == "" or not Estado.tem_mente(u, quem) or not Estado.vivo(u, quem):
		return {}
	return {
		"id": Ids.novo("prp"), "capitulo": u.fatos.obter(causa)["origem"].get("ref", ""),
		"frase": "", "acao": "eco_" + str(efeito.get("emocao", "reacao")), "sujeitos": sujeitos, "lugar": "",
		"status": "eco", "descricao": descricao, "causa": causa, "efeito": efeito,
		"assinatura": "eco|%s|%s" % [causa, descricao],
	}


## Recalcula todo o estado do mundo relendo o banco de fatos, na ordem.
## Usado ao desfazer um fato, ao mudar o passado e para conferir a integridade.
## Preserva só o que o AUTOR definiu à mão (ex.: "tem mente", traços).
static func reconstruir(u: Universo) -> void:
	for e in u.entidades.values():
		var autor := {}
		if e.has("sim"):
			for k in Estado.CHAVES_DO_AUTOR:
				if e["sim"].has(k):
					autor[k] = e["sim"][k]
		e["sim"] = autor.duplicate(true)
		Estado.garantir(e)
	var fatos := u.fatos.todos()
	fatos.sort_custom(func(x, y):
		var ox := DataMundo.ordem(x["data"])
		var oy := DataMundo.ordem(y["data"])
		if ox != oy:
			return ox < oy
		return x["seq"] < y["seq"])
	for f in fatos:
		if f["canon"]:
			Mudancas.aplicar(u, f["dados"].get("mudancas", []), f)
	Informacao.reconstruir(u)
