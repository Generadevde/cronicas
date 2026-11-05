class_name Reacoes
extends RefCounted
## O que alguém sente quando fica sabendo de um acontecimento.
## Depende de quem foi atingido (família, amigos, inimigos) e da personalidade.


## Devolve o id do fato de reação, ou "" se a pessoa não liga para o acontecimento.
static func ao_saber(u: Universo, eid: String, f: Dictionary, causa: String) -> String:
	var acao: String = f["dados"].get("acao", "")
	var s: Array = f["sujeitos"]
	if s.has(eid) or s.size() == 0:
		return ""
	var a: String = s[0]
	var b: String = s[1] if s.size() > 1 else ""
	var t := Personalidade.tracos(u, eid)
	var nome: String = u.entidade(eid)["nome"]
	var ops: Array = []
	var texto := ""
	var imp := 0.4
	match acao:
		"vitoria", "derrota", "ferimento":
			var venc := a if acao != "derrota" else b
			var perd := b if acao != "derrota" else a
			var lig := _ligacao(u, eid, perd)
			if lig > 0.0 and venc != eid:
				var forca := clampf(0.3 + lig * 0.4 + float(t["rancor"]) * 0.3, 0.0, 1.0)
				ops.append({"op": "emocao", "quem": eid, "emocao": "raiva", "forca": forca, "alvo": venc})
				ops.append({"op": "relacao", "de": eid, "para": venc, "deltas": {"raiva": forca * 0.7}})
				texto = "%s soube o que %s fez com %s e ficou com raiva." % [nome, _n(u, venc), _n(u, perd)]
				if forca >= 0.75 and float(t["rancor"]) >= 0.55:
					ops.append({"op": "objetivo", "quem": eid, "tipo": "vingança", "alvo": venc, "forca": forca})
					texto = "%s soube o que %s fez com %s e jurou vingança." % [nome, _n(u, venc), _n(u, perd)]
					imp = 0.6
			elif _ligacao(u, eid, venc) > 0.0:
				ops.append({"op": "emocao", "quem": eid, "emocao": "orgulho", "forca": 0.4, "alvo": venc})
				texto = "%s se orgulhou da vitória de %s." % [nome, _n(u, venc)]
				imp = 0.2
		"morte_por":
			var lig := _ligacao(u, eid, b)
			if lig > 0.0 and a != eid:
				var forca := clampf(0.5 + lig * 0.4 + float(t["rancor"]) * 0.2, 0.0, 1.0)
				ops.append({"op": "emocao", "quem": eid, "emocao": "luto", "forca": clampf(lig, 0.3, 1.0), "alvo": b})
				ops.append({"op": "emocao", "quem": eid, "emocao": "odio", "forca": forca, "alvo": a})
				ops.append({"op": "relacao", "de": eid, "para": a, "deltas": {"raiva": forca, "afeto": -0.5}})
				texto = "%s soube da morte de %s pelas mãos de %s." % [nome, _n(u, b), _n(u, a)]
				if forca >= 0.6 and float(t["empatia"]) < 0.8:
					ops.append({"op": "objetivo", "quem": eid, "tipo": "vingança", "alvo": a, "forca": forca})
					texto = "%s soube da morte de %s pelas mãos de %s e jurou vingança." % [nome, _n(u, b), _n(u, a)]
				imp = 0.65
			elif Estado.valor_relacao(u, eid, b, "raiva") >= 0.5:
				ops.append({"op": "emocao", "quem": eid, "emocao": "alivio", "forca": 0.4, "alvo": b})
				texto = "%s sentiu alívio ao saber da morte de %s." % [nome, _n(u, b)]
				imp = 0.3
		"morte":
			var lig := _ligacao(u, eid, a)
			if lig > 0.0:
				ops.append({"op": "emocao", "quem": eid, "emocao": "luto", "forca": clampf(lig, 0.3, 1.0), "alvo": a})
				texto = "%s está de luto por %s." % [nome, _n(u, a)]
				imp = 0.45
		"casamento":
			for x in [a, b]:
				var outro: String = b if x == a else a
				if Estado.valor_relacao(u, eid, x, "afeto") >= 0.6 and not u.estado(eid)["familia"]["conjuges"].has(x) and not Estado.familia_proxima(u, eid).has(x):
					ops.append({"op": "emocao", "quem": eid, "emocao": "ciume", "forca": 0.6, "alvo": outro})
					ops.append({"op": "relacao", "de": eid, "para": outro, "deltas": {"raiva": 0.3}})
					texto = "%s ficou de coração partido com o casamento de %s." % [nome, _n(u, x)]
					imp = 0.45
					break
		"traicao":
			var lig := _ligacao(u, eid, b)
			if lig > 0.0:
				ops.append({"op": "relacao", "de": eid, "para": a, "deltas": {"confianca": -0.5, "raiva": 0.4}})
				texto = "%s não perdoa a traição de %s contra %s." % [nome, _n(u, a), _n(u, b)]
	if ops.is_empty():
		return ""
	ops.append({"op": "lembrar", "quem": eid, "peso": imp})
	return Simulador.registrar(u, {
		"tipo": "reação",
		"descricao": texto,
		"sujeitos": [eid] + s.filter(func(x): return x != eid),
		"causas": [causa],
		"dados": {"importancia": imp, "mudancas": ops},
	})


## Quanto 'eid' se importa com 'outro' (0 = nada; família e afeto contam).
static func _ligacao(u: Universo, eid: String, outro: String) -> float:
	if outro == "" or outro == eid:
		return 0.0
	var v := 0.0
	var fam: Dictionary = u.estado(eid)["familia"]
	if fam["pais"].has(outro) or fam["filhos"].has(outro) or fam["conjuges"].has(outro):
		v = 0.9
	elif Estado.familia_proxima(u, eid).has(outro):
		v = 0.7
	elif fam["mestres"].has(outro) or fam["discipulos"].has(outro):
		v = 0.6
	v = maxf(v, Estado.valor_relacao(u, eid, outro, "afeto"))
	return v if v >= 0.3 else 0.0


static func _n(u: Universo, eid: String) -> String:
	return u.entidade(eid).get("nome", "?")
