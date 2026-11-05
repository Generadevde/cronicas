class_name Decisao
extends RefCounted
## Como cada mente escolhe o que fazer (modelo híbrido):
## 1. um catálogo fixo de ações possíveis (garante coerência);
## 2. cada ação recebe um peso pela personalidade, emoções, objetivos e relações;
## 3. um pouco de acaso (maior em quem é impulsivo);
## 4. raramente, uma emoção extrema faz alguém agir contra o próprio jeito (ruptura).
## A IA nunca decide: ela só daria voz ao que foi decidido aqui.


## Decide e executa a ação de uma mente neste passo. Devolve ids dos fatos gerados.
static func decidir(u: Universo, eid: String, rng: RandomNumberGenerator, indice: Dictionary) -> Array:
	var ctx := _contexto(u, eid, indice)
	var opcoes: Array = []
	for o in Estado.objetivos_ativos(u, eid):
		opcoes.append_array(_opcoes_do_objetivo(u, eid, o, ctx))
	opcoes.append_array(_opcoes_sociais(u, eid, ctx))
	opcoes.append_array(_opcoes_de_emocao(u, eid, ctx))
	opcoes.append({"acao": "rotina", "peso": 0.25})
	var t: Dictionary = ctx["tracos"]
	var ruido := 0.15 + float(t["impulsividade"]) * 0.35
	var melhor: Dictionary = {}
	var melhor_peso := -1.0
	for op in opcoes:
		var p: float = float(op["peso"]) + rng.randf() * ruido
		if p > melhor_peso:
			melhor_peso = p
			melhor = op
	# Ruptura: emoção extrema empurra a pessoa a agir contra o próprio jeito, uma vez.
	var extrema := _emocao_extrema(ctx)
	if not extrema.is_empty() and rng.randf() < 0.05 * float(extrema["forca_atual"]):
		var alvo: String = extrema["alvo"]
		if alvo != "" and ctx["perto"].has(alvo) and not u.estado(eid).get("rompeu", {}).has(alvo):
			melhor = {"acao": "ruptura", "alvo": alvo, "emocao": extrema}
	return _executar(u, eid, melhor, ctx, rng)


static func _contexto(u: Universo, eid: String, indice: Dictionary) -> Dictionary:
	var local: String = u.estado(eid)["local"]
	var perto: Array = Array(indice.get(local, [])).filter(func(x): return x != eid)
	return {
		"tracos": Personalidade.tracos(u, eid),
		"emocoes": Estado.emocoes_atuais(u, eid),
		"local": local,
		"perto": perto,
		"poder": Estado.poder(u, eid),
		"indice": indice,
	}


static func _emocao_extrema(ctx: Dictionary) -> Dictionary:
	for e in ctx["emocoes"]:
		if float(e["forca_atual"]) >= 0.85 and e["emocao"] in ["odio", "raiva", "humilhacao", "rancor", "desespero"]:
			return e
	return {}


# ---------------------------------------------------------------- objetivos

static func _opcoes_do_objetivo(u: Universo, eid: String, o: Dictionary, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx["tracos"]
	var forca: float = float(o["forca"])
	if o["tipo"] == "vingança":
		var alvo: String = o["alvo"]
		if alvo == "" or not u.entidades.has(alvo):
			return []
		if not Estado.vivo(u, alvo):
			return [{"acao": "vinganca_sem_alvo", "objetivo": o, "peso": 2.0}]
		var raiva := Estado.emocao_por(u, eid, alvo, ["odio", "raiva", "rancor", "humilhacao"])
		var desejo := forca * (0.5 + float(t["rancor"]) * 0.6) * (0.4 + raiva)
		# Perdão: quem é empático, com a raiva esfriada, pode desistir.
		if raiva < 0.2 and float(t["empatia"]) >= 0.6:
			return [{"acao": "perdoar", "objetivo": o, "peso": 0.4 + float(t["empatia"]) * 0.6 - float(t["rancor"]) * 0.5}]
		var meu_poder: float = ctx["poder"]
		var poder_alvo := Estado.poder(u, alvo)
		var pronto := meu_poder >= poder_alvo * (0.75 + float(t["prudencia"]) * 0.5) or float(t["impulsividade"]) >= 0.8
		var local_alvo: String = u.estado(alvo)["local"]
		if pronto:
			if ctx["perto"].has(alvo):
				return [{"acao": "confrontar", "objetivo": o, "alvo": alvo, "peso": desejo * 1.4}]
			if local_alvo != "" and local_alvo != ctx["local"]:
				return [{"acao": "viajar_atras", "objetivo": o, "alvo": alvo, "lugar": local_alvo, "peso": desejo * 1.1}]
			return [{"acao": "procurar", "objetivo": o, "alvo": alvo, "peso": desejo * 0.8}]
		var mestres: Array = u.estado(eid)["familia"]["mestres"].filter(func(m): return Estado.vivo(u, m))
		if mestres.is_empty():
			var candidato := _melhor_mestre(u, eid, ctx)
			if candidato != "":
				return [{"acao": "pedir_mestre", "objetivo": o, "alvo": candidato, "peso": desejo * 1.2}]
		return [{"acao": "treinar", "objetivo": o, "mestre": mestres[0] if not mestres.is_empty() else "", "peso": desejo}]
	# Objetivos livres escritos pelo autor ou nascidos na simulação.
	var cat := Objetivos.categoria(o["tipo"])
	var peso := forca * (0.45 + float(t["ambicao"]) * 0.5)
	return [{"acao": "dedicar", "objetivo": o, "categoria": cat, "peso": peso}]


## Alguém mais forte, por perto ou famoso, que possa ensinar.
static func _melhor_mestre(u: Universo, eid: String, ctx: Dictionary) -> String:
	var melhor := ""
	var melhor_v := float(ctx["poder"]) * 1.3
	for outro in ctx["perto"]:
		var p := Estado.poder(u, outro)
		if p > melhor_v and Estado.valor_relacao(u, eid, outro, "raiva") < 0.3:
			melhor_v = p
			melhor = outro
	return melhor


# ---------------------------------------------------------------- relações

static func _opcoes_sociais(u: Universo, eid: String, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx["tracos"]
	var lista: Array = []
	for outro in ctx["perto"]:
		var afeto := Estado.valor_relacao(u, eid, outro, "afeto")
		var raiva := Estado.valor_relacao(u, eid, outro, "raiva")
		var medo := Estado.valor_relacao(u, eid, outro, "medo")
		if medo >= 0.5 and float(t["coragem"]) < 0.5:
			lista.append({"acao": "fugir", "alvo": outro, "peso": medo * (1.0 - float(t["coragem"]))})
			continue
		if raiva >= 0.4:
			continue
		var afinidade := afinidade(u, eid, outro)
		var peso := (0.15 + float(t["sociabilidade"]) * 0.35) * (0.5 + afinidade) * (1.0 - absf(afeto - 0.4))
		lista.append({"acao": "conviver", "alvo": outro, "peso": peso})
		var dele := Estado.valor_relacao(u, outro, eid, "afeto")
		var casados: bool = not u.estado(eid)["familia"]["conjuges"].is_empty() or not u.estado(outro)["familia"]["conjuges"].is_empty()
		var parentes := Estado.familia_proxima(u, eid).has(outro)
		var amor_meu := Estado.emocao_por(u, eid, outro, ["amor"])
		var amor_dele := Estado.emocao_por(u, outro, eid, ["amor"])
		if amor_meu >= 0.5 and amor_dele >= 0.5 and not casados and not parentes and _adulto(u, eid) and _adulto(u, outro):
			lista.append({"acao": "casar", "alvo": outro, "peso": 0.3 + amor_meu * 0.4})
	return lista


## Afinidade (0 a 1): gostos e valores parecidos aproximam; desgostos em comum também.
static func afinidade(u: Universo, a: String, b: String) -> float:
	var pa := _palavras_de(u, a, ["gost", "valor", "hobby", "paix"])
	var pb := _palavras_de(u, b, ["gost", "valor", "hobby", "paix"])
	var da := _palavras_de(u, a, ["desgost", "odeia", "detesta"])
	var db := _palavras_de(u, b, ["desgost", "odeia", "detesta"])
	var comum := 0
	for w in pa:
		if pb.has(w):
			comum += 1
	for w in da:
		if db.has(w):
			comum += 1
	for w in pa:
		if db.has(w):
			comum -= 1
	var ta := Personalidade.tracos(u, a)
	var tb := Personalidade.tracos(u, b)
	var dif := 0.0
	for k in ["empatia", "lealdade", "sociabilidade", "curiosidade"]:
		dif += absf(float(ta[k]) - float(tb[k]))
	return clampf(0.35 + comum * 0.15 + (0.5 - dif / 4.0) * 0.5, 0.0, 1.0)


static func _palavras_de(u: Universo, eid: String, chaves: Array) -> Array:
	var lista: Array = []
	for c in u.entidade(eid).get("campos", []):
		var k := TextUtil.normalizar(str(c["chave"]))
		if chaves.any(func(x): return k.begins_with(x)):
			for w in TextUtil.palavras(TextUtil.normalizar(str(c["valor"]))):
				if w.length() > 3:
					lista.append(w)
	return lista


## Paixão não nasce de toda amizade: precisa de atração (um sorteio fixo para cada par),
## e quem já ama alguém ou é casado não se apaixona por outro tão fácil.
static func _pode_se_apaixonar(u: Universo, a: String, b: String) -> bool:
	if Estado.familia_proxima(u, a).has(b) or not _adulto(u, a) or not _adulto(u, b):
		return false
	if not u.estado(a)["familia"]["conjuges"].is_empty():
		return false
	for e in Estado.emocoes_atuais(u, a):
		if e["emocao"] == "amor" and e["alvo"] != b and float(e["forca_atual"]) >= 0.3:
			return false
	var par := [a, b]
	par.sort()
	return abs(hash("atracao" + par[0] + par[1] + str(u.semente()))) % 100 < 30


static func _adulto(u: Universo, eid: String) -> bool:
	var i := Estado.idade(u, eid)
	return i < 0 or i >= 16


# ---------------------------------------------------------------- emoções

static func _opcoes_de_emocao(u: Universo, eid: String, ctx: Dictionary) -> Array:
	var lista: Array = []
	for e in ctx["emocoes"]:
		if e["emocao"] == "luto" and float(e["forca_atual"]) >= 0.4 and not _ja_anotou(u, eid, "luto", e["alvo"]):
			lista.append({"acao": "luto", "alvo": e["alvo"], "peso": float(e["forca_atual"]) * 0.9})
	return lista


static func _ja_anotou(u: Universo, eid: String, tipo: String, alvo: String) -> bool:
	for f in u.fatos.sobre(eid):
		if f["dados"].get("rotina", "") == tipo and f["sujeitos"].has(alvo):
			return true
	return false


# ---------------------------------------------------------------- executar

static func _executar(u: Universo, eid: String, op: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var nome: String = u.entidade(eid)["nome"]
	var t: Dictionary = ctx["tracos"]
	var o: Dictionary = op.get("objetivo", {})
	var causa: String = o.get("fato", "")
	var causas: Array = [causa] if u.fatos.existe(causa) else []
	match str(op.get("acao", "")):
		"treinar":
			var mestre: String = op.get("mestre", "")
			var ganho := 0.02 + float(t["ambicao"]) * 0.01 + (0.03 if mestre != "" else 0.0)
			ganho *= Estado.poder(u, eid)
			var texto := "%s treinou %s." % [nome, ("com " + _n(u, mestre)) if mestre != "" else "por conta própria"]
			return _fato(u, "treino", texto, [eid] + ([mestre] if mestre != "" else []), causas, 0.08,
				[{"op": "mudar", "quem": eid, "chave": "poder", "delta": ganho},
				 {"op": "objetivo_estado", "quem": eid, "tipo": o["tipo"], "alvo": o["alvo"], "progresso": 0.01}])
		"pedir_mestre":
			var m: String = op["alvo"]
			var tm := Personalidade.tracos(u, m)
			var aceita := rng.randf() < 0.35 + float(tm["empatia"]) * 0.4 + afinidade(u, eid, m) * 0.3
			if not aceita:
				return _fato(u, "pedido recusado", "%s pediu para ser discípulo de %s, que recusou." % [nome, _n(u, m)], [eid, m], causas, 0.3,
					[{"op": "relacao", "de": eid, "para": m, "deltas": {"respeito": 0.1}}])
			return _fato(u, "aprendizado", "%s tornou-se discípulo de %s." % [nome, _n(u, m)], [eid, m], causas, 0.5,
				[{"op": "vinculo", "quem": eid, "tipo": "mestres", "outro": m},
				 {"op": "vinculo", "quem": m, "tipo": "discipulos", "outro": eid},
				 {"op": "relacao", "de": eid, "para": m, "deltas": {"respeito": 0.4, "confianca": 0.2}},
				 {"op": "relacao", "de": m, "para": eid, "deltas": {"afeto": 0.2}}])
		"viajar_atras":
			var lugar: String = op["lugar"]
			return _fato(u, "viagem", "%s partiu para %s atrás de %s%s." % [nome, _n(u, lugar), _n(u, op["alvo"]), Viagens.duracao(u, ctx["local"], lugar)], [eid, op["alvo"]], causas, 0.45,
				Viagens.ops_de_ida(u, eid, ctx["local"], lugar), lugar)
		"procurar":
			return _fato(u, "busca", "%s procura notícias de onde está %s." % [nome, _n(u, op["alvo"])], [eid, op["alvo"]], causas, 0.15,
				[{"op": "objetivo_estado", "quem": eid, "tipo": o["tipo"], "alvo": o["alvo"], "progresso": 0.02}])
		"confrontar":
			return _confronto(u, eid, op["alvo"], causas, o, rng, false)
		"ruptura":
			var alvo: String = op["alvo"]
			var ids := _fato(u, "ruptura", "%s perdeu o controle diante de %s." % [nome, _n(u, alvo)], [eid, alvo], [op["emocao"]["fato"]] if u.fatos.existe(op["emocao"]["fato"]) else [], 0.55,
				[{"op": "definir", "quem": eid, "chave": "rompeu", "valor": {alvo: true}},
				 {"op": "traco", "quem": eid, "traco": "impulsividade", "delta": 0.05}])
			if ids.is_empty():
				return []
			ids.append_array(_confronto(u, eid, alvo, ids, {}, rng, false))
			return ids
		"perdoar":
			return _fato(u, "perdão", "%s desistiu da vingança contra %s." % [nome, _n(u, o["alvo"])], [eid, o["alvo"]], causas, 0.6,
				[{"op": "objetivo_estado", "quem": eid, "tipo": o["tipo"], "alvo": o["alvo"], "estado": "abandonado"},
				 {"op": "esfriar_emocao", "quem": eid, "emocao": "", "alvo": o["alvo"], "quanto": 0.5},
				 {"op": "traco", "quem": eid, "traco": "rancor", "delta": -0.05}])
		"vinganca_sem_alvo":
			return _fato(u, "vingança sem alvo", "%s ficou sem a vingança: %s já está morto." % [nome, _n(u, o["alvo"])], [eid, o["alvo"]], causas, 0.4,
				[{"op": "objetivo_estado", "quem": eid, "tipo": o["tipo"], "alvo": o["alvo"], "estado": "sem alvo"}])
		"dedicar":
			return _dedicar(u, eid, op, causas, rng)
		"conviver":
			if rng.randf() > 0.3:
				return []  # nem todo encontro muda alguma coisa
			var outro: String = op["alvo"]
			var antes := Estado.valor_relacao(u, eid, outro, "afeto")
			var ganho := 0.06 + afinidade(u, eid, outro) * 0.08
			var ops := [{"op": "relacao", "de": eid, "para": outro, "deltas": {"afeto": ganho, "confianca": ganho * 0.6}},
				{"op": "relacao", "de": outro, "para": eid, "deltas": {"afeto": ganho * 0.8, "confianca": ganho * 0.5}}]
			if antes < 0.4 and antes + ganho >= 0.4:
				return _fato(u, "amizade", "%s e %s ficaram amigos." % [nome, _n(u, outro)], [eid, outro], [Simulador.causa_de_presenca(u, eid)], 0.35, ops)
			if antes < 0.6 and antes + ganho >= 0.6 and Estado.valor_relacao(u, outro, eid, "afeto") >= 0.5 and _pode_se_apaixonar(u, eid, outro):
				return _fato(u, "amor", "%s se apaixonou por %s." % [nome, _n(u, outro)], [eid, outro], [Simulador.causa_de_presenca(u, eid)], 0.45,
					ops + [{"op": "emocao", "quem": eid, "emocao": "amor", "forca": 0.7, "alvo": outro}])
			# Convívio comum muda a relação sem virar manchete, mas precisa ficar registrado.
			return _fato(u, "convívio", "%s passou tempo com %s." % [nome, _n(u, outro)], [eid, outro], [Simulador.causa_de_presenca(u, eid)], 0.03, ops)
		"casar":
			if rng.randf() > 0.12:
				return []  # casamento é decisão que leva tempo
			var outro: String = op["alvo"]
			var fid := Simulador.registrar(u, {"tipo": "casamento", "descricao": "%s e %s se casaram." % [nome, _n(u, outro)],
				"sujeitos": [eid, outro], "lugar": ctx["local"], "causas": [Simulador.causa_de_presenca(u, eid)],
				"dados": {"acao": "casamento", "importancia": 0.7}})
			return [fid] if fid != "" else []
		"fugir":
			var destino := _outro_lugar(u, ctx["local"], rng)
			if destino == "":
				return []
			return _fato(u, "fuga", "%s fugiu para %s com medo de %s%s." % [nome, _n(u, destino), _n(u, op["alvo"]), Viagens.duracao(u, ctx["local"], destino)], [eid, op["alvo"]], [Simulador.causa_de_presenca(u, eid)], 0.4,
				Viagens.ops_de_ida(u, eid, ctx["local"], destino), destino)
		"luto":
			return _fato(u, "luto", "%s está recolhido, de luto por %s." % [nome, _n(u, op["alvo"])], [eid, op["alvo"]], [_fato_da_emocao(u, eid, "luto", op["alvo"])], 0.2,
				[], "", {"rotina": "luto"})
	return []


## Objetivo livre: o tipo de esforço depende do que o autor escreveu.
static func _dedicar(u: Universo, eid: String, op: Dictionary, causas: Array, rng: RandomNumberGenerator) -> Array:
	var o: Dictionary = op["objetivo"]
	var nome: String = u.entidade(eid)["nome"]
	var t := Personalidade.tracos(u, eid)
	# Grandes objetivos levam anos: uns 2 a 4 anos de dedicação semanal.
	var avanco := 0.004 + float(t["ambicao"]) * 0.006 + rng.randf() * 0.004
	var ops: Array = [{"op": "objetivo_estado", "quem": eid, "tipo": o["tipo"], "alvo": o["alvo"], "progresso": avanco}]
	var verbo := {"forca": "treinou pensando em", "saber": "estudou para", "riqueza": "trabalhou duro para",
		"afeto": "cuidou dos seus, pensando em", "viagem": "planejou a jornada para", "poder": "fez alianças para",
		"generico": "se dedicou a"}
	if op["categoria"] == "forca":
		ops.append({"op": "mudar", "quem": eid, "chave": "poder", "delta": 0.02 * Estado.poder(u, eid)})
	if float(o["progresso"]) + avanco >= 1.0:
		ops.append({"op": "objetivo_estado", "quem": eid, "tipo": o["tipo"], "alvo": o["alvo"], "estado": "concluido"})
		ops.append({"op": "emocao", "quem": eid, "emocao": "orgulho", "forca": 0.7, "alvo": ""})
		ops.append({"op": "mudar", "quem": eid, "chave": "reputacao", "delta": 1.0})
		return _fato(u, "conquista", "%s conseguiu: %s." % [nome, o["tipo"]], [eid], causas, 0.7, ops)
	var marcos := [0.25, 0.5, 0.75]
	for m in marcos:
		if float(o["progresso"]) < m and float(o["progresso"]) + avanco >= m:
			return _fato(u, "progresso", "%s está mais perto de: %s." % [nome, o["tipo"]], [eid], causas, 0.25, ops)
	return _fato(u, "esforço", "%s %s %s." % [nome, verbo.get(op["categoria"], "se dedicou a"), o["tipo"]], [eid], causas, 0.04, ops)


## Luta entre duas mentes. Resultado vira fato de vitória (ou morte) com as consequências.
static func _confronto(u: Universo, eid: String, alvo: String, causas: Array, o: Dictionary, rng: RandomNumberGenerator, ate_a_morte: bool) -> Array:
	var r := Combate.resolver(u, eid, alvo, rng, ate_a_morte)
	var venc: String = r["vencedor"]
	var perd: String = r["perdedor"]
	var lugar: String = u.estado(eid)["local"]
	var ids: Array = []
	var desc := "%s enfrentou %s, e %s venceu." % [_n(u, eid), _n(u, alvo), _n(u, venc)]
	var acao := "vitoria"
	if r["morte"]:
		desc = "%s enfrentou %s, e %s matou %s." % [_n(u, eid), _n(u, alvo), _n(u, venc), _n(u, perd)]
		acao = "morte_por"
	var fid := Simulador.registrar(u, {"tipo": "luta", "descricao": desc, "sujeitos": [venc, perd], "lugar": lugar,
		"causas": causas, "dados": {"acao": acao, "importancia": 1.0 if r["morte"] else 0.8, "chance": r["chance"]}})
	if fid == "":
		return []
	ids.append(fid)
	if not o.is_empty() and o["tipo"] == "vingança":
		if venc == eid:
			ids.append_array(_fato(u, "vingança cumprida", "%s cumpriu a vingança contra %s." % [_n(u, eid), _n(u, alvo)], [eid, alvo], [fid], 0.7,
				[{"op": "objetivo_estado", "quem": eid, "tipo": "vingança", "alvo": alvo, "estado": "concluido"},
				 {"op": "esfriar_emocao", "quem": eid, "emocao": "", "alvo": alvo, "quanto": 0.6},
				 {"op": "emocao", "quem": eid, "emocao": "vazio" if rng.randf() < 0.4 else "alivio", "forca": 0.5, "alvo": alvo}]))
		elif Estado.vivo(u, eid):
			ids.append_array(_fato(u, "derrota amarga", "%s perdeu para %s, e a vingança ficou mais amarga." % [_n(u, eid), _n(u, alvo)], [eid, alvo], [fid], 0.4,
				[{"op": "objetivo_estado", "quem": eid, "tipo": "vingança", "alvo": alvo, "forca": minf(1.0, float(o["forca"]) + 0.15)},
				 {"op": "emocao", "quem": eid, "emocao": "humilhacao", "forca": 0.7, "alvo": alvo}]))
	return ids


static func _fato(u: Universo, tipo: String, descricao: String, sujeitos: Array, causas: Array, importancia: float,
		ops: Array, lugar: String = "", extra: Dictionary = {}) -> Array:
	var dados := {"importancia": importancia, "mudancas": ops}
	dados.merge(extra)
	var fid := Simulador.registrar(u, {"tipo": tipo, "descricao": descricao, "sujeitos": sujeitos.filter(func(x): return x != ""),
		"lugar": lugar, "causas": causas.filter(func(c): return u.fatos.existe(c)), "dados": dados})
	return [fid] if fid != "" else []


static func _fato_da_emocao(u: Universo, eid: String, emocao: String, alvo: String) -> String:
	for e in u.estado(eid)["emocoes"]:
		if e["emocao"] == emocao and e["alvo"] == alvo and u.fatos.existe(e["fato"]):
			return e["fato"]
	return Simulador.causa_de_presenca(u, eid)


static func _outro_lugar(u: Universo, atual: String, rng: RandomNumberGenerator) -> String:
	var lugares := Simulador.lugares(u).filter(func(l): return l != atual)
	# Foge para onde dá para morar (não para um planeta ou uma região inteira).
	var habitaveis := lugares.filter(func(l): return not Mapa.especie(u, l) in ["planeta", "cosmico", "regiao"])
	if not habitaveis.is_empty():
		lugares = habitaveis
	if lugares.is_empty():
		return ""
	return lugares[rng.randi() % lugares.size()]


static func _n(u: Universo, eid: String) -> String:
	return u.entidade(eid).get("nome", "?")
