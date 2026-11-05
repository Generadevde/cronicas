class_name Guerras
extends RefCounted
## Guerras: nascem da simulação (fome, vingança, fé, ambição de um líder, inimigos
## escritos na ficha) ou do autor (no capítulo ou no painel da guerra). Cada guerra
## é uma entidade (aparece na wiki) e tudo o que acontece nela vira fato com causa:
## a declaração, cada batalha (com nome), a ocupação de lugares, os refugiados, a
## morte de generais, o tratado e o que fica depois (rancor entre povos, veteranos,
## heróis com título, lugares com nome novo, lendas).
##
## O autor entra quando quiser, como deus ou como autor: reforços, traição, desastre,
## aliado inesperado, morte de um general, ou escrevendo ("o rei fez um pacto com o
## Ser da Quinta Dimensão e recebeu um exército de fantasmas do deserto"). A guerra
## recalcula sozinha: força, terreno, dia e noite, moral, suprimentos e as regras novas.

const CHANCE_DE_BATALHA := 0.55  ## por semana


# ---------------------------------------------------------------- consultas

static func eh_guerra(u: Universo, eid: String) -> bool:
	var e := u.entidade(eid)
	return not e.is_empty() and TextUtil.normalizar(e["tipo"]).begins_with("guerra")


static func dados(u: Universo, g: String) -> Dictionary:
	return u.estado(g).get("guerra", {})


static func todas(u: Universo) -> Array:
	var ents: Array = Sociedades._lembrar(u, "guerras", func(): return u.entidades_ativas().filter(func(e): return eh_guerra(u, e["id"])).map(func(e): return e["id"]))
	return ents.filter(func(g): return not dados(u, g).is_empty())


static func ativas(u: Universo) -> Array:
	return todas(u).filter(func(g): return dados(u, g).get("ativa", false))


static func lado_de(u: Universo, g: String, sid: String) -> String:
	var d := dados(u, g)
	if d.get("a", []).has(sid):
		return "a"
	if d.get("b", []).has(sid):
		return "b"
	return ""


static func em_guerra(u: Universo, a: String, b: String) -> String:
	for g in ativas(u):
		var la := lado_de(u, g, a)
		var lb := lado_de(u, g, b)
		if la != "" and lb != "" and la != lb:
			return g
	return ""


static func forcas_do_lado(u: Universo, g: String, lado: String) -> Array:
	var lista: Array = []
	for sid in dados(u, g).get(lado, []):
		lista.append_array(Forcas.da_sociedade(u, sid))
	return lista


static func tamanho_do_lado(u: Universo, g: String, lado: String) -> float:
	var t := 0.0
	for f in forcas_do_lado(u, g, lado):
		t += Forcas.tamanho(u, f)
	return t


static func _n(u: Universo, eid: String) -> String:
	return u.entidade(eid).get("nome", "?")


## A sociedade de alguém ou de algum lugar (para "Kai declarou guerra a Varn").
static func sociedade_de(u: Universo, eid: String) -> String:
	if eid == "" or not u.entidades.has(eid):
		return ""
	if Sociedades.eh_sociedade(u, eid):
		return eid
	if Mapa.e_lugar(u, eid):
		return Sociedades.de_lugar(u, eid)
	for sid in Sociedades.todas(u):
		if Sociedades.lider(u, sid) == eid:
			return sid
	return Sociedades.de_lugar(u, u.estado(eid).get("local", ""))


## Lugares (povoados) de uma sociedade que ainda não foram tomados pelo inimigo.
static func lugares_de(u: Universo, sid: String) -> Array:
	var lista: Array = []
	for l in Sociedades.territorio(u, sid):
		var esp := Mapa.especie(u, l)
		if esp in ["povoado", "regiao", "construcao"] and Sociedades.de_lugar(u, l) == sid:
			lista.append(l)
	if lista.is_empty():
		for b in Sociedades.territorio_base(u, sid):
			if Sociedades.de_lugar(u, b) == sid:
				lista.append(b)
	return lista


static func _sede(u: Universo, sid: String) -> String:
	var base := Sociedades.territorio_base(u, sid)
	for b in base:
		if Mapa.no_mapa(u, b) and Mapa.especie(u, b) == "povoado":
			return b
	for b in base:
		if Mapa.no_mapa(u, b):
			return b
	return base[0] if not base.is_empty() else ""


static func _distancia(u: Universo, de: String, para: String) -> int:
	if de == "" or para == "":
		return 9999
	var d := Mapa.dias_de_viagem(u, de, para)
	return d if d >= 0 else 9999


## Onde a próxima batalha acontece: o lugar do defensor mais perto do atacante.
static func frente(u: Universo, g: String) -> String:
	var d := dados(u, g)
	var origem := _sede(u, str(d["a"][0]))
	var melhor := ""
	var dist := 99999
	for sid in d.get("b", []):
		for l in lugares_de(u, sid):
			if Mapa.especie(u, l) != "povoado" and lugares_de(u, sid).any(func(x): return Mapa.especie(u, x) == "povoado"):
				continue
			var k := _distancia(u, origem, l)
			if k < dist or (k == dist and _n(u, l) < _n(u, melhor)):
				dist = k
				melhor = l
	return melhor


## Lugares em guerra agora (frentes e ocupados), para o mapa e o humor.
static func lugares_em_guerra(u: Universo) -> Dictionary:
	var r := {}
	for g in ativas(u):
		var f := frente(u, g)
		if f != "":
			r[f] = g
		for l in dados(u, g).get("ocupados", []):
			r[l] = g
	return r


# ---------------------------------------------------------------- operações (ficam nos fatos)

static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	match str(op.get("op", "")):
		"guerra_inicio":
			var g := str(op.get("guerra", ""))
			if not u.entidades.has(g):
				return true
			u.estado(g)["guerra"] = {"a": Array(op.get("a", [])).duplicate(), "b": Array(op.get("b", [])).duplicate(),
				"ativa": true, "inicio": DataMundo.ordem(fato.get("data", u.relogio)), "controle": 0.0, "batalhas": [],
				"mortos": {}, "ocupados": [], "vitorias": {"a": 0, "b": 0}, "declaracao": fato.get("id", ""),
				"inicial": op.get("inicial", {}), "motivo": str(op.get("motivo", "")), "vencedor": "", "fim": -1}
			return true
		"guerra_lado":
			var d := dados(u, str(op.get("guerra", "")))
			var lado := str(op.get("lado", "a"))
			if not d.is_empty() and not d[lado].has(op.get("sid", "")):
				d[lado].append(str(op["sid"]))
			return true
		"guerra_batalha":
			var d := dados(u, str(op.get("guerra", "")))
			if d.is_empty():
				return true
			d["batalhas"].append(fato.get("id", ""))
			d["controle"] = clampf(float(d["controle"]) + float(op.get("controle", 0.0)), -1.0, 1.0)
			var v := str(op.get("vencedor", ""))
			if v != "":
				d["vitorias"][v] = int(d["vitorias"].get(v, 0)) + 1
			var m: Dictionary = op.get("mortos", {})
			for sid in m:
				d["mortos"][sid] = float(d["mortos"].get(sid, 0.0)) + float(m[sid])
			return true
		"ocupar":
			var lugar := str(op.get("lugar", ""))
			if not u.entidades.has(lugar):
				return true
			var por := str(op.get("por", ""))
			if por == "":
				u.estado(lugar).erase("ocupado_por")
			else:
				u.estado(lugar)["ocupado_por"] = por
			var d := dados(u, str(op.get("guerra", "")))
			if not d.is_empty():
				if por == "":
					d["ocupados"].erase(lugar)
				elif not d["ocupados"].has(lugar):
					d["ocupados"].append(lugar)
			u.versao += 1
			return true
		"dono":
			var lugar := str(op.get("lugar", ""))
			if u.entidades.has(lugar):
				u.estado(lugar)["dono"] = str(op.get("sid", ""))
				u.estado(lugar).erase("ocupado_por")
				u.versao += 1
			return true
		"guerra_fim":
			var d := dados(u, str(op.get("guerra", "")))
			if not d.is_empty():
				d["ativa"] = false
				d["vencedor"] = str(op.get("vencedor", ""))
				d["fim"] = DataMundo.ordem(fato.get("data", u.relogio))
				d["tratado"] = fato.get("id", "")
				d["ocupados"] = []
			return true
		"rancor":
			for par in [[str(op.get("de", "")), str(op.get("para", "")), float(op.get("delta", 0.0))]]:
				if u.entidades.has(par[0]):
					var r: Dictionary = u.estado(par[0]).get("rancores", {})
					r[par[1]] = clampf(float(r.get(par[1], 0.0)) + float(par[2]), 0.0, 2.0)
					u.estado(par[0])["rancores"] = r
			return true
	return false


static func rancor(u: Universo, de: String, para: String) -> float:
	return float(u.estado(de).get("rancores", {}).get(para, 0.0))


# ---------------------------------------------------------------- declarar

## Nome da guerra pelo motivo.
static func _nome(u: Universo, a: String, b: String, motivo: String) -> String:
	var m := TextUtil.normalizar(motivo)
	var base := ""
	if m.contains("fome"):
		base = "Guerra da Fome"
	elif m.contains("fe") and (m.contains("religi") or m.contains("heres") or m.begins_with("fe")):
		base = "Guerra Santa de %s" % _n(u, a)
	elif m.contains("vinga") or m.contains("rancor") or m.contains("odio"):
		base = "Guerra da Vingança"
	elif m.contains("ambic") or m.contains("conquist"):
		base = "Conquista de %s" % _n(u, b)
	else:
		base = "Guerra de %s e %s" % [_n(u, a), _n(u, b)]
	var nome := base
	var i := 2
	while u.entidades_ativas().any(func(e): return e["nome"] == nome):
		nome = "%s (%s)" % [base, _ordinal(i)]
		i += 1
	return nome


static func _ordinal(i: int) -> String:
	return ["", "primeira", "segunda", "terceira", "quarta", "quinta", "sexta", "sétima", "oitava", "nona", "décima"][mini(i, 10)]


## Tamanho de um exército levantado às pressas pela população do território.
static func _levante(u: Universo, sid: String) -> float:
	var pop := 0.0
	for l in Sociedades.territorio(u, sid):
		if Natureza.tem_natureza(u, l):
			pop += float(Natureza.de(u, l)["pop"])
	return maxf(300.0, roundf(pop * 0.06 / 50.0) * 50.0) if pop > 0 else 2000.0


## As operações de uma declaração (cria a guerra, levanta exércitos, chama aliados).
## 'fid' é o fato que causa tudo (para as entidades novas terem causa).
static func ops_de_declaracao(u: Universo, a: String, b: String, fid: String, motivo: String = "", g: String = "") -> Array:
	if g == "":
		g = criar_guerra(u, a, b, motivo, [fid] if u.fatos.existe(fid) else [])
	if fid == "" or not u.fatos.existe(fid):
		fid = str(u.entidade(g).get("fato_criacao", ""))
	var ops: Array = []
	var lados := {"a": [a], "b": [b]}
	# Aliados: quem cita um dos lados como aliado (na ficha) entra junto.
	for sid in Sociedades.todas(u):
		if sid == a or sid == b or Forcas.eh_forca(u, sid):
			continue
		for par in [["a", a], ["b", b]]:
			if _aliados(u, sid, par[1]) and not _aliados(u, sid, a if par[0] == "b" else b):
				lados[par[0]].append(sid)
				break
	var inicial := {}
	for lado in ["a", "b"]:
		var t := 0.0
		for sid in lados[lado]:
			var fs := Forcas.da_sociedade(u, sid)
			if fs.is_empty() and sid == lados[lado][0]:
				var nova := Forcas.criar(u, "Exército de %s" % _n(u, sid), sid, _levante(u, sid), [fid] if u.fatos.existe(fid) else [],
					{"comandante": Sociedades.lider(u, sid) if Sociedades.lider(u, sid) != "" and u.entidades.has(Sociedades.lider(u, sid)) else ""})
				fs = [nova]
			for f in fs:
				t += Forcas.tamanho(u, f)
		inicial[lado] = t
	ops.append({"op": "guerra_inicio", "guerra": g, "a": lados["a"], "b": lados["b"], "inicial": inicial, "motivo": motivo})
	ops.append({"op": "rancor", "de": b, "para": a, "delta": 0.3})
	return ops


static func criar_guerra(u: Universo, a: String, b: String, motivo: String, causas: Array) -> String:
	return u.criar_entidade(_nome(u, a, b, motivo), "guerra", [], [
		{"chave": "lados", "valor": "%s contra %s" % [_n(u, a), _n(u, b)]},
		{"chave": "motivo", "valor": motivo if motivo != "" else "—"}], causas)


static func _aliados(u: Universo, sid: String, outro: String) -> bool:
	if u.estado(sid).get("aliados", []).has(outro):
		return true
	var txt := TextUtil.chave(Sociedades._campo(u, sid, ["aliad", "aliança", "alianca", "amigos"]))
	if txt != "" and txt.contains(TextUtil.chave(_n(u, outro))):
		return true
	var txt2 := TextUtil.chave(Sociedades._campo(u, outro, ["aliad", "aliança", "alianca", "amigos"]))
	return txt2 != "" and txt2.contains(TextUtil.chave(_n(u, sid)))


## Declara uma guerra. Devolve o id da guerra ("" se não deu).
static func declarar(u: Universo, a: String, b: String, motivo: String = "", causas: Array = [], origem: String = "") -> String:
	if a == "" or b == "" or a == b or em_guerra(u, a, b) != "":
		return ""
	var autor := causas.is_empty()
	var texto := "%s declarou guerra a %s%s." % [_n(u, a), _n(u, b), (" (" + motivo + ")") if motivo != "" else ""]
	# A guerra (entidade) nasce do mesmo motivo; as mudanças vão no fato da declaração.
	var g := criar_guerra(u, a, b, motivo, causas)
	var ops := ops_de_declaracao(u, a, b, "", motivo, g)
	var fato := {"tipo": "declaração de guerra", "descricao": texto, "sujeitos": [g, a, b],
		"causas": causas, "dados": {"importancia": 1.0, "guerra": g, "guerra_motivo": motivo, "mudancas": ops}}
	if autor:
		fato["origem"] = {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": origem if origem != "" else "guerras"}
	var fid := Simulador.registrar(u, fato)
	if fid == "":
		return ""
	for sid in dados(u, g)["a"].slice(1) + dados(u, g)["b"].slice(1):
		var lado := lado_de(u, g, sid)
		_fato_guerra(u, g, "aliança na guerra", "%s entrou na %s ao lado de %s." % [_n(u, sid), _n(u, g), _n(u, dados(u, g)[lado][0])], 0.6, [fid], [], [sid])
	u.marcar_mudanca()
	return g


static func _fato_guerra(u: Universo, g: String, tipo: String, texto: String, imp: float, causas: Array, ops: Array, sujeitos: Array = [], lugar: String = "", extra: Dictionary = {}) -> String:
	var cs: Array = causas.filter(func(c): return c != "" and u.fatos.existe(c))
	if cs.is_empty():
		cs = [str(dados(u, g).get("declaracao", u.entidade(g).get("fato_criacao", "")))]
	var dd := {"importancia": imp, "guerra": g, "mudancas": ops}
	dd.merge(extra)
	return Simulador.registrar(u, {"tipo": tipo, "descricao": texto, "sujeitos": [g] + sujeitos.filter(func(x): return x != "" and x != g),
		"lugar": lugar, "causas": cs, "dados": dd})


## O que soma ao lado além das forças: lendas (heróis invocados), espiões infiltrados
## no inimigo e, para quem defende, as muralhas da cidade.
static func _extra(u: Universo, g: String, lado: String, lugar: String) -> float:
	var d := dados(u, g)
	var outro := "b" if lado == "a" else "a"
	var x := Lendas.inspiracao(u, d[lado], d[outro])
	x *= 1.0 + 0.05 * mini(3, Intriga.espioes_em(u, str(d[lado][0]), str(d[outro][0])))
	if lado == "b" and lugar != "" and Cidades.muralha(u, lugar):
		x *= 1.35
	return x


# ---------------------------------------------------------------- previsão

## Quem deve vencer e por quê. {favorito, chance (do lado a), semanas, texto, razoes, r}
static func previsao(u: Universo, g: String) -> Dictionary:
	var d := dados(u, g)
	if d.is_empty():
		return {}
	var A := forcas_do_lado(u, g, "a")
	var B := forcas_do_lado(u, g, "b")
	var fr := frente(u, g)
	var razoes: Array = []
	var rs: Array = []
	for noite in [false, true]:
		var cond := Forcas.condicoes(u, fr, noite) if fr != "" else ["noite" if noite else "dia"]
		var pa := Forcas.poder_do_lado(u, A, B, cond, _extra(u, g, "a", fr))
		var pb := Forcas.poder_do_lado(u, B, A, cond, _extra(u, g, "b", fr))
		var tot := float(pa["dano"]) + float(pb["dano"])
		rs.append(0.5 if tot <= 0 else float(pa["dano"]) / tot)
		for x in pa["razoes"] + pb["razoes"]:
			if not razoes.has(x):
				razoes.append(x)
	var noite_p := _chance_de_noite(u, A, B)
	var r := float(rs[0]) * (1.0 - noite_p) + float(rs[1]) * noite_p
	var ta := tamanho_do_lado(u, g, "a")
	var tb := tamanho_do_lado(u, g, "b")
	razoes.push_front("%s: %s · %s: %s" % [_n(u, d["a"][0]), _composicao(u, A), _n(u, d["b"][0]), _composicao(u, B)])
	if absf(rs[0] - rs[1]) > 0.25:
		razoes.append("De dia, %s leva vantagem; de noite, %s." % [_n(u, d["a"][0]) if rs[0] > rs[1] else _n(u, d["b"][0]), _n(u, d["a"][0]) if rs[1] > rs[0] else _n(u, d["b"][0])])
	var chance := 1.0 / (1.0 + exp(-(r - 0.5) / 0.045))
	var semanas := 0
	var texto := ""
	var ini: Dictionary = d.get("inicial", {})
	if absf(r - 0.5) < 0.04:
		texto = "Guerra equilibrada: ninguém sabe quem vence."
		semanas = -1
	elif r > 0.5:
		var fl := 0.08 + 0.5 * (r - 0.5)
		var frac := tb / maxf(1.0, float(ini.get("b", tb)))
		var nb := log(0.15 / maxf(0.16, frac)) / log(1.0 - fl) if frac > 0.15 else 0.0
		var nc := (0.85 - float(d["controle"])) / (0.1 + 0.25 * (r - 0.5))
		semanas = int(ceil(maxf(1.0, minf(nb, nc)) / CHANCE_DE_BATALHA))
		texto = "%s é favorito (%d%%): %s deve cair em cerca de %s." % [_n(u, d["a"][0]), int(roundf(chance * 100)), _n(u, d["b"][0]), _tempo(semanas)]
	else:
		var fl2 := 0.08 + 0.5 * (0.5 - r)
		var frac2 := ta / maxf(1.0, float(ini.get("a", ta)))
		var na := log(0.2 / maxf(0.21, frac2)) / log(1.0 - fl2) if frac2 > 0.2 else 0.0
		var nc2 := (float(d["controle"]) + 0.4) / (0.08 + 0.2 * (0.5 - r))
		semanas = int(ceil(maxf(1.0, minf(na, nc2)) / CHANCE_DE_BATALHA))
		texto = "%s deve resistir (%d%%): %s deve desistir em cerca de %s." % [_n(u, d["b"][0]), int(roundf((1.0 - chance) * 100)), _n(u, d["a"][0]), _tempo(semanas)]
	return {"favorito": d["a"][0] if r >= 0.5 else d["b"][0], "chance": chance, "semanas": semanas, "texto": texto, "razoes": razoes, "r": r}


static func _tempo(semanas: int) -> String:
	if semanas <= 1:
		return "uma semana"
	if semanas < 9:
		return "%d semanas" % semanas
	if semanas < 52:
		return "%d meses" % int(roundf(semanas / 4.3))
	return "%d anos" % maxi(1, int(roundf(semanas / 52.0)))


static func _composicao(u: Universo, forcas: Array) -> String:
	if forcas.is_empty():
		return "nada"
	var por_tipo := {}
	for f in forcas:
		var t := Forcas.nome_tipo(u, f)
		por_tipo[t] = float(por_tipo.get(t, 0.0)) + Forcas.tamanho(u, f)
	var partes: Array = []
	for t in por_tipo:
		partes.append("%s (%s)" % [Forcas.numero(por_tipo[t]), t])
	return ", ".join(partes)


## Quem prefere lutar de noite (fantasmas que somem de dia, forças que são fortes no escuro).
static func _chance_de_noite(u: Universo, A: Array, B: Array) -> float:
	var p := 0.5
	for par in [[A, 0.3], [B, 0.2]]:
		for f in par[0]:
			var quer := 0
			for r in Forcas.ler_tracos(Forcas.pontos_fortes(u, f), true):
				if r["tipo"] == "forte_em":
					if r["termos"].has("noite"):
						quer += 1
					if r["termos"].has("dia"):
						quer -= 1
			for r in Forcas.ler_tracos(Forcas.fraquezas(u, f), false):
				if r["tipo"] == "fraco_em":
					if r["termos"].has("dia"):
						quer += 1
					if r["termos"].has("noite"):
						quer -= 1
			p += signf(quer) * float(par[1])
	return clampf(p, 0.05, 0.95)


# ---------------------------------------------------------------- a semana da guerra

static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for g in ativas(u):
		novos.append_array(_semana(u, g, dias, rng))
	var ctrl: Dictionary = u.extra("guerras_ctrl", {"ultimo": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["ultimo"]) >= 28:
		ctrl["ultimo"] = agora
		novos.append_array(_talvez_declarar(u, rng))
	return novos.filter(func(x): return x != "")


static func _semana(u: Universo, g: String, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var d := dados(u, g)
	var A := forcas_do_lado(u, g, "a")
	var B := forcas_do_lado(u, g, "b")
	var ultimo := _ultimo_fato(u, g)
	# Fim por falta de exército, de moral ou de território.
	var fim := _deve_acabar(u, g, A, B)
	if fim != "x":
		novos.append_array(terminar(u, g, fim, ultimo))
		return novos
	if rng.randf() > CHANCE_DE_BATALHA * dias / 7.0:
		# Sem batalha: o atacante gasta suprimentos longe de casa.
		return novos
	novos.append(batalha(u, g, rng))
	return novos


static func _ultimo_fato(u: Universo, g: String) -> String:
	var d := dados(u, g)
	var bs: Array = d.get("batalhas", [])
	for i in range(bs.size() - 1, -1, -1):
		if u.fatos.obter(bs[i]).get("canon", false):
			return bs[i]
	var ids := u.fatos.ids_sobre(g)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and f["tipo"] != "criação":
			return f["id"]
	return str(d.get("declaracao", ""))


## "a" (atacante vence), "b" (defensor vence), "" (empate) ou "x" (continua).
static func _deve_acabar(u: Universo, g: String, A: Array, B: Array) -> String:
	var d := dados(u, g)
	var ini: Dictionary = d.get("inicial", {})
	var ta := tamanho_do_lado(u, g, "a")
	var tb := tamanho_do_lado(u, g, "b")
	if tb <= 0.15 * maxf(1.0, float(ini.get("b", tb))) or B.is_empty() or float(d["controle"]) >= 0.85:
		return "a"
	# O defensor tinha terras e perdeu todas.
	if frente(u, g) == "" and not d["ocupados"].is_empty():
		return "a"
	if ta <= 0.2 * maxf(1.0, float(ini.get("a", ta))) or A.is_empty() or float(d["controle"]) <= -0.4:
		return "b"
	if _moral_media(u, B) < 0.18:
		return "a"
	if _moral_media(u, A) < 0.18:
		return "b"
	# Anos de impasse cansam os dois lados.
	if DataMundo.ordem(u.relogio) - int(d["inicio"]) > 3 * DataMundo.DIAS_POR_ANO and absf(float(d["controle"])) < 0.3:
		return ""
	return "x"


static func _moral_media(u: Universo, fs: Array) -> float:
	if fs.is_empty():
		return 0.0
	var t := 0.0
	var n := 0.0
	for f in fs:
		t += Forcas.moral(u, f) * Forcas.tamanho(u, f)
		n += Forcas.tamanho(u, f)
	return t / maxf(1.0, n)


## Uma batalha, resolvida em resumo. Devolve o id do fato.
static func batalha(u: Universo, g: String, rng: RandomNumberGenerator) -> String:
	var d := dados(u, g)
	var A := forcas_do_lado(u, g, "a")
	var B := forcas_do_lado(u, g, "b")
	var lugar := frente(u, g)
	var noite := rng.randf() < _chance_de_noite(u, A, B)
	var cond := Forcas.condicoes(u, lugar, noite) if lugar != "" else ["noite" if noite else "dia"]
	var pa := Forcas.poder_do_lado(u, A, B, cond, _extra(u, g, "a", lugar))
	var pb := Forcas.poder_do_lado(u, B, A, cond, _extra(u, g, "b", lugar))
	if Cidades.muralha(u, lugar):
		pb["razoes"].append("as muralhas de %s" % _n(u, lugar))
	var tot := float(pa["dano"]) + float(pb["dano"])
	var r := 0.5 if tot <= 0 else float(pa["dano"]) / tot
	var rr := clampf(r + rng.randfn(0.0, 0.07), 0.01, 0.99)
	var venc := "a" if rr > 0.5 else "b"
	var margem := absf(rr - 0.5) * 2.0
	var perdedoras := B if venc == "a" else A
	var vencedoras := A if venc == "a" else B
	var fl := 0.08 + 0.25 * margem
	var fw := 0.02 + 0.08 * (1.0 - margem)
	var ops: Array = []
	var mortos := {}
	for par in [[perdedoras, fl, -0.1], [vencedoras, fw, 0.04]]:
		for f in par[0]:
			var perda := roundf(Forcas.tamanho(u, f) * float(par[1]) * rng.randf_range(0.7, 1.3))
			ops.append({"op": "mudar", "quem": f, "chave": "baixas", "delta": perda})
			ops.append({"op": "mudar", "quem": f, "chave": "moral_delta", "delta": float(par[2])})
			var s := Forcas.lado(u, f)
			mortos[s] = float(mortos.get(s, 0.0)) + perda
	for f in A:
		ops.append({"op": "mudar", "quem": f, "chave": "suprimentos_delta", "delta": -0.03})
	var controle := (0.1 + 0.25 * (rr - 0.5)) if venc == "a" else -(0.08 + 0.2 * (0.5 - rr))
	ops.append({"op": "guerra_batalha", "guerra": g, "vencedor": venc, "mortos": mortos, "controle": controle})
	var sid_v: String = d[venc][0]
	var sid_p: String = d["b" if venc == "a" else "a"][0]
	# Generais: o do lado que perdeu pode morrer.
	var envolvidos: Array = []
	var mortes_txt: Array = []
	for f in A + B:
		var c := Forcas.comandante(u, f)
		if c == "" or not Estado.vivo(u, c) or envolvidos.has(c):
			continue
		envolvidos.append(c)
		var risco := 0.1 if perdedoras.has(f) else 0.02
		if rng.randf() < risco:
			ops.append({"op": "morrer", "quem": c})
			ops.append({"op": "mudar", "quem": f, "chave": "moral_delta", "delta": -0.15})
			mortes_txt.append(_n(u, c))
	# Quem mora onde a batalha acontece sofre também.
	if lugar != "":
		for m in Natureza._mentes_em(u, lugar):
			if envolvidos.has(m):
				continue
			var x := rng.randf()
			if x < 0.04:
				ops.append({"op": "morrer", "quem": m})
				mortes_txt.append(_n(u, m))
			elif x < 0.14:
				ops.append({"op": "ferir", "quem": m, "descricao": "ferido na batalha", "gravidade": 0.3})
			envolvidos.append(m)
	# Ocupação: o atacante toma o lugar quando vence com folga.
	var ocupou := false
	if venc == "a" and rr > 0.6 and lugar != "":
		ops.append({"op": "ocupar", "lugar": lugar, "por": sid_v, "guerra": g})
		ocupou = true
	var libertou := ""
	if venc == "b" and float(d["controle"]) + controle < 0.0 and not d["ocupados"].is_empty():
		libertou = d["ocupados"].back()
		ops.append({"op": "ocupar", "lugar": libertou, "por": "", "guerra": g})
	# Herói: o comandante do lado vencedor (ou alguém valente do lugar).
	var heroi := _heroi(u, vencedoras, lugar, sid_v, rng)
	if heroi != "":
		ops.append({"op": "mudar", "quem": heroi, "chave": "reputacao", "delta": 0.8})
		ops.append({"op": "relacao", "de": Sociedades.lider(u, sid_p), "para": heroi, "deltas": {"raiva": 0.3, "medo": 0.2}})
	var total_mortos := 0.0
	for s in mortos:
		total_mortos += float(mortos[s])
	var engajados := 0.0
	for f in A + B:
		engajados += Forcas.tamanho(u, f)
	var info := {"lugar": lugar, "noite": noite, "cond": cond, "mortos": total_mortos, "engajados": engajados,
		"forcas": A + B, "vencedor_tipo": Forcas.tipo(u, vencedoras[0]) if not vencedoras.is_empty() else "", "guerra": g}
	var nome := Lendas.nome_da_batalha(u, info)
	var texto := "%s: %s venceu %s" % [nome, _quem_venceu(u, vencedoras, sid_v), _n(u, sid_p)]
	texto += " (%s mortos)" % Forcas.numero(total_mortos)
	if not mortes_txt.is_empty():
		texto += "; morreu %s" % ", ".join(mortes_txt) if mortes_txt.size() == 1 else "; morreram %s" % ", ".join(mortes_txt)
	texto += "."
	var razoes: Array = (pa["razoes"] if venc == "a" else pb["razoes"]).slice(0, 3)
	var lugar_novo := Lendas.nome_de_lugar(u, lugar, total_mortos, engajados, rng)
	if lugar_novo != "":
		ops.append({"op": "definir", "quem": lugar, "chave": "nome_de_guerra", "valor": lugar_novo})
	var fid := _fato_guerra(u, g, "batalha", texto, 0.8, [_ultimo_fato(u, g)], ops, [sid_v, sid_p, heroi] + envolvidos.slice(0, 4), lugar,
		{"batalha": true, "nome": nome, "vencedor": sid_v, "perdedor": sid_p, "noite": noite, "condicoes": cond, "razoes": razoes,
		 "mortos": total_mortos, "heroi": heroi, "chance": r})
	if fid == "":
		return ""
	if heroi != "":
		Lendas.dar_titulo_de_batalha(u, heroi, g, fid, venc)
	if ocupou:
		var dest := ""
		for l in lugares_de(u, sid_p):
			if l != lugar:
				dest = l
				break
		var reg := Natureza.de(u, lugar) if Natureza.tem_natureza(u, lugar) else {}
		if not reg.is_empty() and float(reg["pop"]) > 0:
			var foge := float(reg["pop"]) * 0.15
			reg["pop"] = float(reg["pop"]) - foge
			if dest != "" and Natureza.tem_natureza(u, dest):
				Natureza.de(u, dest)["pop"] = float(Natureza.de(u, dest)["pop"]) + foge
		_fato_guerra(u, g, "ocupação", "%s ocupou %s%s." % [_n(u, sid_v), _n(u, lugar),
			(" — refugiados fogem para %s" % _n(u, dest)) if dest != "" else ""], 0.7, [fid], [], [sid_v, sid_p, lugar], lugar)
	if libertou != "":
		_fato_guerra(u, g, "libertação", "%s retomou %s." % [_n(u, sid_v), _n(u, libertou)], 0.65, [fid], [], [sid_v, libertou], libertou)
	return fid


static func _quem_venceu(u: Universo, forcas: Array, sid: String) -> String:
	if forcas.is_empty():
		return _n(u, sid)
	var maior: String = forcas[0]
	for f in forcas:
		if Forcas.tamanho(u, f) * float(Forcas.TIPOS[Forcas.tipo(u, f)]["poder"]) > Forcas.tamanho(u, maior) * float(Forcas.TIPOS[Forcas.tipo(u, maior)]["poder"]):
			maior = f
	return "%s (%s)" % [_n(u, sid), _n(u, maior)] if _n(u, maior).find(_n(u, sid)) < 0 else _n(u, maior)


static func _heroi(u: Universo, vencedoras: Array, lugar: String, sid: String, rng: RandomNumberGenerator) -> String:
	var candidatos: Array = []
	for f in vencedoras:
		var c := Forcas.comandante(u, f)
		if c != "" and Estado.vivo(u, c):
			candidatos.append(c)
	if lugar != "":
		for m in Natureza._mentes_em(u, lugar):
			if Sociedades.de_lugar(u, u.estado(m)["local"]) == sid or Sociedades.membros(u, sid).has(m):
				candidatos.append(m)
	if candidatos.is_empty():
		return ""
	candidatos.sort_custom(func(x, y): return float(Personalidade.tracos(u, x)["coragem"]) > float(Personalidade.tracos(u, y)["coragem"]))
	return candidatos[0] if rng.randf() < 0.7 else candidatos[rng.randi() % candidatos.size()]


# ---------------------------------------------------------------- fim da guerra

## Termina a guerra. vencedor: "a", "b" ou "" (paz sem vencedor). Devolve os fatos.
static func terminar(u: Universo, g: String, vencedor: String, causa: String, pelo_autor: bool = false) -> Array:
	var d := dados(u, g)
	if d.is_empty() or not d["ativa"]:
		return []
	var novos: Array = []
	var a: String = d["a"][0]
	var b: String = d["b"][0]
	var ops: Array = [{"op": "guerra_fim", "guerra": g, "vencedor": vencedor}]
	var ganhou := a if vencedor == "a" else (b if vencedor == "b" else "")
	var perdeu := b if vencedor == "a" else (a if vencedor == "b" else "")
	var tomados: Array = []
	for l in d["ocupados"]:
		if vencedor == "a":
			ops.append({"op": "dono", "lugar": l, "sid": a})
			tomados.append(l)
		else:
			ops.append({"op": "ocupar", "lugar": l, "por": "", "guerra": g})
	# Ódio entre povos por gerações.
	if perdeu != "":
		ops.append({"op": "rancor", "de": perdeu, "para": ganhou, "delta": 0.7})
		ops.append({"op": "rancor", "de": ganhou, "para": perdeu, "delta": 0.2})
	else:
		ops.append({"op": "rancor", "de": a, "para": b, "delta": 0.3})
		ops.append({"op": "rancor", "de": b, "para": a, "delta": 0.3})
	# Veteranos: quem comandou ou viveu as batalhas leva a guerra consigo.
	var veteranos: Array = []
	for fid in d["batalhas"]:
		for s in u.fatos.obter(fid).get("sujeitos", []):
			if Estado.tem_mente(u, s) and Estado.vivo(u, s) and not veteranos.has(s):
				veteranos.append(s)
	for f in forcas_do_lado(u, g, "a") + forcas_do_lado(u, g, "b"):
		var c := Forcas.comandante(u, f)
		if c != "" and Estado.vivo(u, c) and not veteranos.has(c):
			veteranos.append(c)
	for v in veteranos:
		ops.append({"op": "marca", "quem": v, "marca": "veterano da " + _n(u, g)})
		ops.append({"op": "emocao", "quem": v, "emocao": "medo", "forca": 0.3})
	var lugar_tratado := _sede(u, b)
	var nome_tratado := "Tratado de %s" % (_n(u, lugar_tratado) if lugar_tratado != "" else _n(u, perdeu if perdeu != "" else b))
	var texto := ""
	if vencedor == "":
		texto = "Fim da %s: pelo %s, %s e %s fizeram as pazes sem vencedor." % [_n(u, g), nome_tratado, _n(u, a), _n(u, b)]
	elif vencedor == "b":
		texto = "Fim da %s: %s resistiu. Pelo %s, %s recuou e desistiu da guerra." % [_n(u, g), _n(u, ganhou), nome_tratado, _n(u, perdeu)]
	else:
		texto = "Fim da %s: %s venceu. Pelo %s, %s se rendeu" % [_n(u, g), _n(u, ganhou), nome_tratado, _n(u, perdeu)]
		if not tomados.is_empty():
			texto += " e entregou %s" % ", ".join(tomados.map(func(l): return _n(u, l)))
		texto += "."
	var fato := {"tipo": "fim da guerra", "descricao": texto, "sujeitos": [g, a, b], "lugar": lugar_tratado,
		"dados": {"importancia": 0.95, "guerra": g, "tratado": nome_tratado, "vencedor": ganhou, "mudancas": ops}}
	if pelo_autor:
		fato["origem"] = {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "guerras"}
		fato["causas"] = []
	else:
		fato["causas"] = [causa] if u.fatos.existe(causa) else [str(d["declaracao"])]
	var fid := Simulador.registrar(u, fato)
	novos.append(fid)
	novos.append_array(Lendas.titulos_da_guerra(u, g, fid))
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = hash(fid)
	novos.append(Intriga.tratado_mal_traduzido(u, fid, rng_t))
	var dur := DataMundo.ordem(u.relogio) - int(d["inicio"])
	if dur >= 2 * DataMundo.DIAS_POR_ANO:
		u.estado(g)["nome_lendario"] = "A Guerra dos %s Anos" % Lendas.extenso(int(roundf(dur / float(DataMundo.DIAS_POR_ANO))))
	return novos


# ---------------------------------------------------------------- a simulação declara guerras

## Uma vez por mês: alguma sociedade tem motivo e coragem para atacar outra?
static func _talvez_declarar(u: Universo, rng: RandomNumberGenerator) -> Array:
	var socs: Array = Sociedades.todas(u).filter(func(s): return not Forcas.eh_forca(u, s) and not Sociedades.tipo(u, s) in ["corporacao", "ordem", "anarquia"])
	if socs.size() < 2:
		return []
	for a in socs:
		for b in socs:
			if a == b or em_guerra(u, a, b) != "" or _aliados(u, a, b):
				continue
			var m := motivo(u, a, b)
			if float(m["forca"]) < 0.7:
				continue
			if rng.randf() < clampf((float(m["forca"]) - 0.7) * 0.2, 0.0, 0.3):
				var g := declarar(u, a, b, m["texto"], m["causas"])
				if g != "":
					return [dados(u, g)["declaracao"]]
	return []


## Por que A atacaria B? {forca, texto, causas}
static func motivo(u: Universo, a: String, b: String) -> Dictionary:
	var acc := {"forca": 0.0, "melhor": 0.0, "texto": "", "causas": []}
	var add := func(v: float, t: String, c: String) -> void:
		acc["forca"] = float(acc["forca"]) + v
		if v > float(acc["melhor"]) and u.fatos.existe(c):
			acc["melhor"] = v
			acc["texto"] = t
			acc["causas"] = [c]
	var la := Sociedades.lider(u, a)
	var lb := Sociedades.lider(u, b)
	# Inimigos escritos na ficha.
	var inim := TextUtil.chave(Sociedades._campo(u, a, ["inimig", "rival"]))
	if inim != "" and inim.contains(TextUtil.chave(_n(u, b))):
		add.call(0.55, "inimigos de longa data", str(u.entidade(a).get("fato_criacao", "")))
	# Rancor de guerras passadas.
	var rc := rancor(u, a, b)
	if rc > 0.0:
		add.call(rc * 0.6, "vingança", _ultimo_tratado(u, a, b))
	# Ódio entre os governantes.
	if la != "" and lb != "" and u.entidades.has(la) and u.entidades.has(lb):
		var raiva := Estado.valor_relacao(u, la, lb, "raiva")
		if raiva >= 0.5:
			add.call(raiva * 0.6, "o ódio de %s por %s" % [_n(u, la), _n(u, lb)], _fato_entre(u, la, lb))
		var amb := float(Personalidade.tracos(u, la)["ambicao"])
		if amb > 0.75:
			add.call((amb - 0.75) * 1.2, "ambição de %s" % _n(u, la), str(u.entidade(la).get("fato_criacao", "")))
	# Fome em casa, fartura no vizinho.
	var fome_c: String = _comida(u, a)["fome"]
	if fome_c != "" and _comida(u, b)["fartura"]:
		add.call(0.45, "fome", fome_c)
	# Fé: teocracia contra quem crê em outra coisa.
	if Sociedades.tipo(u, a) == "teocracia":
		var fa := TextUtil.chave(Sociedades._campo(u, a, ["religi", "fe", "crenc", "deus"]))
		var fb := TextUtil.chave(Sociedades._campo(u, b, ["religi", "fe", "crenc", "deus"]))
		if fa != "" and fb != "" and fa != fb:
			add.call(0.35, "fé", str(u.entidade(a).get("fato_criacao", "")))
	# Distância: longe demais, ninguém marcha (a não ser por ódio antigo).
	var forca := float(acc["forca"])
	if forca < 0.7:
		return {"forca": forca, "texto": acc["texto"], "causas": acc["causas"]}
	var dist := _distancia(u, _sede(u, a), _sede(u, b))
	if dist > 60 and dist < 9999:
		forca *= 0.3
	# Ninguém ataca quem é muito mais forte.
	var pa := 0.0
	var pb := 0.0
	for f in Forcas.da_sociedade(u, a):
		pa += Forcas.tamanho(u, f) * float(Forcas.TIPOS[Forcas.tipo(u, f)]["poder"])
	for f in Forcas.da_sociedade(u, b):
		pb += Forcas.tamanho(u, f) * float(Forcas.TIPOS[Forcas.tipo(u, f)]["poder"])
	if pa == 0.0:
		pa = _levante(u, a)
	if pb == 0.0:
		pb = _levante(u, b)
	if pa < pb * 0.8:
		forca *= 0.4
	if Array(acc["causas"]).is_empty():
		forca = 0.0
	return {"forca": forca, "texto": acc["texto"], "causas": acc["causas"]}


## Fome e fartura no território (guardado por uma semana).
static func _comida(u: Universo, sid: String) -> Dictionary:
	return Sociedades._lembrar(u, "comida|%s|%d" % [sid, DataMundo.ordem(u.relogio) / 7], func():
		var r := {"fome": "", "fartura": false}
		for l in Sociedades.territorio(u, sid):
			if not Natureza.tem_natureza(u, l):
				continue
			var c := float(Natureza.de(u, l)["comida"])
			if c < 0.5 and r["fome"] == "":
				r["fome"] = str(Natureza.de(u, l)["alertas"].get("fome_fato", ""))
			if c > 0.95:
				r["fartura"] = true
		return r)


static func _ultimo_tratado(u: Universo, a: String, b: String) -> String:
	var ids := u.fatos.ids_sobre(a)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and f["tipo"] == "fim da guerra" and f["sujeitos"].has(b):
			return f["id"]
	return ""


static func _fato_entre(u: Universo, x: String, y: String) -> String:
	var ids := u.fatos.ids_sobre(x)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and f["sujeitos"].has(y):
			return f["id"]
	return str(u.entidade(x).get("fato_criacao", ""))


# ---------------------------------------------------------------- o autor intervém

## Intervenções do painel. 'tipo': reforcos, traicao, desastre, aliado, morte_general, livre, paz.
## Devolve {fatos: [...], texto: "o que o mundo entendeu"}.
static func intervir(u: Universo, g: String, tipo: String, p: Dictionary) -> Dictionary:
	var d := dados(u, g)
	if d.is_empty():
		return {"fatos": [], "texto": "Esta guerra não existe."}
	var origem := {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "guerras"}
	var fatos: Array = []
	var texto := ""
	match tipo:
		"reforcos":
			var sid := str(p.get("sid", d["a"][0]))
			var tam := float(p.get("tamanho", 1000))
			var nome := str(p.get("nome", ""))
			if nome != "":
				var nova := Forcas.criar(u, nome, sid, tam)
				fatos.append(_autor(u, g, "reforços", "Reforços para %s: %s (%s)." % [_n(u, sid), nome, Forcas.numero(tam)], [], [sid, nova]))
			else:
				var fs := Forcas.da_sociedade(u, sid)
				if fs.is_empty():
					var nova2 := Forcas.criar(u, "Exército de %s" % _n(u, sid), sid, tam)
					fs = [nova2]
				fatos.append(_autor(u, g, "reforços", "Chegaram reforços para %s: %s soldados." % [_n(u, sid), Forcas.numero(tam)],
					[{"op": "mudar", "quem": fs[0], "chave": "reforcos", "delta": tam}, {"op": "mudar", "quem": fs[0], "chave": "moral_delta", "delta": 0.1}], [sid, fs[0]]))
			texto = "Reforços enviados."
		"traicao":
			var f := str(p.get("forca", ""))
			if f == "" or not u.entidades.has(f):
				return {"fatos": [], "texto": "Escolha a força que trai."}
			var de := Forcas.lado(u, f)
			var lado := lado_de(u, g, de)
			var para: String = d["b" if lado == "a" else "a"][0]
			var c := Forcas.comandante(u, f)
			var ops: Array = [{"op": "definir", "quem": f, "chave": "lado", "valor": para}]
			if c != "":
				ops.append({"op": "relacao", "de": Sociedades.lider(u, de), "para": c, "deltas": {"raiva": 0.9, "confianca": -1.0}})
				ops.append({"op": "marca", "quem": c, "marca": "traidor de " + _n(u, de)})
			fatos.append(_autor(u, g, "traição", "%s traiu %s e passou para o lado de %s." % [_n(u, c) if c != "" else _n(u, f), _n(u, de), _n(u, para)], ops, [de, para, f, c]))
			texto = "A traição muda os lados."
		"desastre":
			var fr := frente(u, g)
			if fr == "":
				return {"fatos": [], "texto": "Esta guerra não tem frente no mapa."}
			var r := Natureza.intervir(u, fr, str(p.get("texto", "tempestade")))
			if r.has("fato"):
				fatos.append(r["fato"])
				var ops2: Array = []
				for f2 in forcas_do_lado(u, g, "a"):
					ops2.append({"op": "mudar", "quem": f2, "chave": "suprimentos_delta", "delta": -0.3})
				fatos.append(_autor(u, g, "desastre na guerra", "%s atingiu os exércitos em %s." % [str(p.get("texto", "Um desastre")).capitalize(), _n(u, fr)], ops2, [fr], fr, [r["fato"]]))
			texto = "Desastre em %s." % _n(u, fr)
		"aliado":
			var sid2 := str(p.get("sid", ""))
			var lado2 := str(p.get("lado", "b"))
			if sid2 == "" or lado_de(u, g, sid2) != "":
				return {"fatos": [], "texto": "Essa sociedade já está na guerra."}
			var ops3: Array = [{"op": "guerra_lado", "guerra": g, "sid": sid2, "lado": lado2}]
			if Forcas.da_sociedade(u, sid2).is_empty():
				Forcas.criar(u, "Exército de %s" % _n(u, sid2), sid2, _levante(u, sid2))
			fatos.append(_autor(u, g, "aliado inesperado", "%s entrou na guerra ao lado de %s." % [_n(u, sid2), _n(u, d[lado2][0])], ops3, [sid2, d[lado2][0]]))
			texto = "Um aliado entrou na guerra."
		"morte_general":
			var quem := str(p.get("quem", ""))
			if quem == "" or not Estado.vivo(u, quem):
				return {"fatos": [], "texto": "Escolha um general vivo."}
			var ops4: Array = [{"op": "morrer", "quem": quem}]
			for f3 in Forcas.todas(u):
				if Forcas.comandante(u, f3) == quem:
					ops4.append({"op": "mudar", "quem": f3, "chave": "moral_delta", "delta": -0.25})
			fatos.append(_autor(u, g, "morte de um general", "%s morreu%s." % [_n(u, quem), (", " + str(p["como"])) if str(p.get("como", "")) != "" else ""], ops4, [quem]))
			texto = "O general morreu."
		"livre":
			return ler_intervencao(u, g, str(p.get("texto", "")))
		"paz":
			fatos.append_array(terminar(u, g, str(p.get("vencedor", "")), "", true))
			texto = "A guerra acabou."
	u.marcar_mudanca()
	return {"fatos": fatos.filter(func(x): return x != ""), "texto": texto}


static func _autor(u: Universo, g: String, tipo: String, texto: String, ops: Array, sujeitos: Array, lugar: String = "", causas: Array = []) -> String:
	return Simulador.registrar(u, {"tipo": tipo, "descricao": texto, "sujeitos": [g] + sujeitos.filter(func(x): return x != "" and x != g),
		"lugar": lugar, "causas": causas, "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "guerras"},
		"dados": {"importancia": 0.8, "guerra": g, "intervencao": true, "mudancas": ops}})


const PALAVRAS_DE_TROPA := ["exercito", "legiao", "horda", "frota", "esquadra", "esquadrilha", "tropa", "tropas", "batalhao", "regimento", "armada", "hoste", "enxame", "bando"]


## Lê uma intervenção escrita: pactos com seres, forças que chegam, ou um acontecimento
## natural na frente. O que não entender vai para "Ainda sem efeito".
static func ler_intervencao(u: Universo, g: String, texto: String) -> Dictionary:
	var d := dados(u, g)
	var fatos: Array = []
	var entendeu: Array = []
	var norm := TextUtil.normalizar(texto)
	var lig := Ligador.new(u)
	var mencoes := lig.encontrar(texto)
	# Quem recebe: a sociedade citada (ou a de quem foi citado), a mais perto da tropa.
	var pos_tropa := -1
	for w in PALAVRAS_DE_TROPA:
		var i := norm.find(w)
		if i >= 0 and (pos_tropa < 0 or i < pos_tropa):
			pos_tropa = i
	var lado_sid := ""
	var quem := ""
	for m in mencoes:
		var s := sociedade_de(u, m["entidade"])
		if s != "" and lado_de(u, g, s) != "" and (pos_tropa < 0 or m["inicio"] < pos_tropa or lado_sid == ""):
			lado_sid = s
		if Estado.tem_mente(u, m["entidade"]) and quem == "":
			quem = m["entidade"]
	# "o rei de Bermudit" → o governante.
	if quem == "" and lado_sid != "" and (norm.contains("o rei") or norm.contains("a rainha") or norm.contains("o imperador") or norm.contains("o lider") or norm.contains("o governante")):
		quem = Sociedades.lider(u, lado_sid)
	var causa_pacto := ""
	# Pacto com um ser.
	var ip := norm.find("pacto com")
	if ip >= 0:
		var nome_ser := _nome_depois(texto, ip + "pacto com".length())
		if nome_ser != "":
			var ser := ""
			for m in lig.encontrar(nome_ser):
				ser = m["entidade"]
			if ser == "":
				ser = u.criar_entidade(nome_ser, "entidade", [], [
					{"chave": "natureza", "valor": "ser que faz pactos"},
					{"chave": "o que oferece", "valor": _trecho_recebido(texto)},
					{"chave": "o que cobra", "valor": "ainda não se sabe"}])
			var ops: Array = []
			if quem != "":
				ops.append({"op": "marca", "quem": quem, "marca": "pacto com " + _n(u, ser)})
			causa_pacto = _autor(u, g, "pacto", "%s fez um pacto com %s." % [_n(u, quem) if quem != "" else _n(u, lado_sid), _n(u, ser)], ops, [quem, ser, lado_sid])
			u.fatos.obter(causa_pacto)["dados"]["pacto"] = {"ser": ser, "com": quem, "preco": ""}
			fatos.append(causa_pacto)
			entendeu.append("pacto com %s (o preço fica para a Parte 8)" % _n(u, ser))
	# Uma força que chega.
	var tropa := _tropa_no_texto(texto)
	if tropa["nome"] != "":
		if lado_sid == "":
			return {"fatos": fatos, "texto": "Entendi a tropa, mas não de que lado ela é. Cite o reino (ex.: \"Bermudit recebeu…\")."}
		var outro: String = d["b" if lado_de(u, g, lado_sid) == "a" else "a"][0]
		var tam: float = tropa["tamanho"]
		if tam <= 0:
			var deles := tamanho_do_lado(u, g, lado_de(u, g, outro))
			tam = maxf(1000.0, roundf(deles * 0.5 / 100.0) * 100.0)
		var nova := Forcas.criar(u, tropa["nome"], lado_sid, tam, [], {"moral": "inabalável" if Forcas.inferir(tropa["nome"])["tipo"] == "sobrenaturais" else "alta"})
		var f2 := _autor(u, g, "força nova", "%s recebeu %s (%s)." % [_n(u, lado_sid), tropa["nome"], Forcas.numero(tam)], [], [lado_sid, nova, quem], "", [causa_pacto] if causa_pacto != "" else [])
		fatos.append(f2)
		var inf := Forcas.inferir(tropa["nome"])
		entendeu.append("%s virou força militar de %s: %s%s%s" % [tropa["nome"], _n(u, lado_sid), Forcas.TIPOS[inf["tipo"]]["nome"],
			(" · fortes: " + inf["fortes"]) if inf["fortes"] != "" else "", (" · fracos: " + inf["fracos"]) if inf["fracos"] != "" else ""])
	if entendeu.is_empty():
		# Talvez seja natureza na frente de batalha (tempestade, peste…).
		var fr := frente(u, g)
		if fr != "":
			var r := Natureza.intervir(u, fr, texto)
			if str(r.get("fato", "")) != "":
				fatos.append(r["fato"])
			if Array(r.get("entendidos", [])).is_empty() and Array(r.get("leis", [])).is_empty():
				return {"fatos": fatos, "texto": "Registrei em %s, mas não sei o que isso muda: ficou em \"Ainda sem efeito\" (aba Leis)." % _n(u, fr)}
			return {"fatos": fatos, "texto": "Aconteceu em %s (a frente de batalha): %s." % [_n(u, fr), ", ".join(r.get("entendidos", []) + r.get("leis", []))]}
		var fx := _autor(u, g, "intervenção", texto.strip_edges(), [], [lado_sid])
		u.fatos.obter(fx)["dados"]["sem_efeito"] = true
		u.fatos.obter(fx)["dados"]["texto"] = texto.strip_edges()
		return {"fatos": [fx], "texto": "Registrei, mas não sei o que isso muda: ficou em \"Ainda sem efeito\" (aba Leis)."}
	u.marcar_mudanca()
	return {"fatos": fatos, "texto": "O mundo aceitou: " + "; ".join(entendeu) + "."}


## Nome próprio depois de uma posição ("pacto com o Ser da Quinta Dimensão e recebeu…").
static func _nome_depois(texto: String, pos_norm: int) -> String:
	# As posições do texto normalizado batem com as do original (mesmo tamanho).
	var resto := texto.substr(pos_norm).strip_edges()
	var palavras := resto.split(" ", false)
	var saida: Array = []
	var i := 0
	while i < palavras.size():
		var w: String = palavras[i]
		var limpa := w.rstrip(".,;:!?")
		if saida.is_empty() and limpa.to_lower() in ["o", "a", "os", "as", "um", "uma"]:
			i += 1
			continue
		var maiuscula := limpa != "" and limpa[0] == limpa[0].to_upper() and limpa[0] != limpa[0].to_lower()
		if maiuscula or (not saida.is_empty() and limpa.to_lower() in ["da", "de", "do", "das", "dos"] and i + 1 < palavras.size()):
			saida.append(limpa)
			if limpa != w:
				break
		else:
			break
		i += 1
	while not saida.is_empty() and str(saida.back()).to_lower() in ["da", "de", "do", "das", "dos"]:
		saida.pop_back()
	return " ".join(saida)


static func _trecho_recebido(texto: String) -> String:
	var n := TextUtil.normalizar(texto)
	for v in ["recebeu", "ganhou", "obteve", "em troca de"]:
		var i := n.find(v)
		if i >= 0:
			return texto.substr(i + v.length()).strip_edges().trim_suffix(".")
	return "—"


## "um exército de fantasmas do deserto", "20 mil aviões", "uma frota de 300 navios".
static func _tropa_no_texto(texto: String) -> Dictionary:
	var n := TextUtil.normalizar(texto)
	for w in PALAVRAS_DE_TROPA:
		var i := n.find(w + " de ")
		if i < 0:
			continue
		var fim: int = i + w.length() + 4
		var j: int = fim
		while j < n.length() and not n[j] in [".", ",", ";", "!", "?"] and not n.substr(j).begins_with(" e ") and not n.substr(j).begins_with(" que ") and not n.substr(j).begins_with(" para "):
			j += 1
		var nome := texto.substr(i, j - i).strip_edges()
		var tam := Combate.ler_numero(n.substr(fim, j - fim))
		return {"nome": nome.substr(0, 1).to_upper() + nome.substr(1), "tamanho": tam}
	# "20 mil aviões", "300 navios".
	var re := RegEx.new()
	re.compile("(\\d[\\d.,]*\\s*(mil|milhoes|milhao|bilhoes)?)\\s+([a-z-]+)")
	for m in re.search_all(n):
		var w := m.get_string(3)
		for t in Forcas.TIPOS:
			if Forcas.TIPOS[t]["palavras"].has(w) or Forcas.TIPOS[t]["palavras"].has(w.trim_suffix("s")):
				var nome2 := texto.substr(m.get_start(), m.get_end() - m.get_start()).strip_edges()
				return {"nome": nome2.substr(0, 1).to_upper() + nome2.substr(1), "tamanho": Combate.ler_numero(m.get_string(1))}
	return {"nome": "", "tamanho": 0.0}
