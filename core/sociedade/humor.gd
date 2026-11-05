class_name Humor
extends RefCounted
## O humor coletivo de cada povoado: raiva, medo, alegria e fé (0 a 1).
## Sobe e desce com a comida, as pestes, os impostos, a fama do governante e o
## que acontece. Raiva alta demais vira inquietação e depois REVOLTA; alegria alta
## vira festa; medo e fé juntos fazem surgir profetas. Números em extras["humor"],
## e só viram fato quando atravessam esses limites.

const BASE := {"raiva": 0.12, "medo": 0.12, "alegria": 0.35, "fe": 0.3}


static func de(u: Universo, lugar: String) -> Dictionary:
	var d: Dictionary = u.extra("humor", {})
	if not d.has(lugar):
		d[lugar] = {"raiva": BASE["raiva"], "medo": BASE["medo"], "alegria": BASE["alegria"], "fe": BASE["fe"], "semanas": 0, "alertas": {}}
	return d[lugar]


static func palavra(h: Dictionary) -> String:
	if float(h["raiva"]) >= 0.72:
		return "à beira da revolta"
	if float(h["raiva"]) >= 0.5:
		return "inquieto"
	if float(h["medo"]) >= 0.55:
		return "com medo"
	if float(h["alegria"]) >= 0.7:
		return "em festa"
	if float(h["alegria"]) <= 0.15:
		return "abatido"
	return "calmo"


static func _base(u: Universo, sid: String) -> Dictionary:
	var b := BASE.duplicate()
	if sid != "":
		b["raiva"] = float(b["raiva"]) + Sociedades.imposto(u, sid) * 1.2
		if Sociedades.tipo(u, sid) == "teocracia":
			b["fe"] = 0.6
	return b


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var dt := dias / 7.0
	var agora := DataMundo.ordem(u.relogio)
	var em_guerra := Guerras.lugares_em_guerra(u)
	for e in u.entidades_ativas():
		var lugar: String = e["id"]
		if Mapa.especie(u, lugar) != "povoado" or not Natureza.tem_natureza(u, lugar) or Motor.adormecido(u, lugar):
			continue
		var reg := Natureza.de(u, lugar)
		if float(reg["pop"]) <= 0:
			continue
		var h := de(u, lugar)
		var sid := Sociedades.de_lugar(u, lugar)
		var tipo := Sociedades.tipo(u, sid) if sid != "" else ""
		var b := _base(u, sid)
		var comida := float(reg["comida"])
		if comida < 0.55:
			h["raiva"] = float(h["raiva"]) + 0.05 * dt * (0.55 - comida) / 0.3
			h["medo"] = float(h["medo"]) + 0.02 * dt
			h["alegria"] = float(h["alegria"]) - 0.03 * dt
		elif comida > 1.05:
			h["alegria"] = float(h["alegria"]) + 0.02 * dt
		for ev in Natureza.eventos_ativos(u, lugar):
			match str(ev["tipo"]):
				"epidemia", "terremoto", "feras":
					h["medo"] = float(h["medo"]) + 0.04 * dt
				"seca", "praga", "enchente", "inverno":
					h["raiva"] = float(h["raiva"]) + 0.006 * dt
				"fartura":
					h["alegria"] = float(h["alegria"]) + 0.02 * dt
		# Guerra: medo na frente de batalha; raiva de quem ocupa.
		if em_guerra.has(lugar):
			h["medo"] = float(h["medo"]) + 0.04 * dt
			if u.estado(lugar).has("ocupado_por"):
				h["raiva"] = float(h["raiva"]) + 0.02 * dt
		if sid != "":
			var l := Sociedades.lider(u, sid)
			if l != "" and u.entidades.has(l):
				# A opinião sobre o governante muda devagar: recalcula uma vez por mês.
				if agora - int(h.get("op_quando", -999)) >= 28 or str(h.get("op_de", "")) != l:
					h["op_lider"] = Reputacao.opiniao(u, lugar, l)
					h["op_quando"] = agora
					h["op_de"] = l
				h["raiva"] = float(h["raiva"]) - float(h["op_lider"]) * 0.012 * dt
		# Volta aos poucos ao normal.
		for k in ["raiva", "medo", "alegria", "fe"]:
			h[k] = clampf(float(h[k]) + (float(b[k]) - float(h[k])) * 0.035 * dt, 0.0, 1.0)
		h["fe"] = clampf(float(h["fe"]) + float(h["medo"]) * 0.012 * dt, 0.0, 1.0)
		if tipo in ["colmeia", "maquina"]:
			h["raiva"] = minf(float(h["raiva"]), 0.3)  # não há dissidência
		novos.append_array(_limiares(u, lugar, sid, h, reg, rng, agora))
	return novos.filter(func(x): return x != "")


static func _limiares(u: Universo, lugar: String, sid: String, h: Dictionary, reg: Dictionary, rng: RandomNumberGenerator, agora: int) -> Array:
	var novos: Array = []
	var al: Dictionary = h["alertas"]
	var nome: String = u.entidade(lugar)["nome"]
	var l := Sociedades.lider(u, sid) if sid != "" else ""
	var causa_fome := str(reg.get("alertas", {}).get("fome_fato", ""))
	if causa_fome == "" or not u.fatos.existe(causa_fome):
		causa_fome = Natureza._ultimo_fato_natural(u, lugar)
	# Inquietação.
	if float(h["raiva"]) >= 0.5 and not al.get("inquieto", false):
		al["inquieto"] = true
		var fid := _fato(u, lugar, "inquietação", "Há inquietação em %s%s." % [nome, (" contra " + u.entidade(l)["nome"]) if l != "" else ""], 0.55, [causa_fome], [l])
		al["inquieto_fato"] = fid
		novos.append(fid)
	elif float(h["raiva"]) < 0.35 and al.get("inquieto", false):
		al.erase("inquieto")
	# Revolta: raiva muito alta por semanas (e não logo depois de outra).
	if float(h["raiva"]) >= 0.72:
		h["semanas"] = int(h["semanas"]) + 1
	else:
		h["semanas"] = 0
	if int(h["semanas"]) >= 3 and agora - int(al.get("ultima_revolta", -99999)) > 180:
		al["ultima_revolta"] = agora
		h["semanas"] = 0
		var r := Sociedades.revolta(u, sid, lugar, str(al.get("inquieto_fato", causa_fome)), float(h["raiva"]), rng)
		novos.append_array(r["fatos"])
		if r["venceu"]:
			h["raiva"] = 0.25
			h["alegria"] = clampf(float(h["alegria"]) + 0.25, 0.0, 1.0)
		else:
			h["raiva"] = 0.45
			h["medo"] = 0.7
	# Festa.
	if float(h["alegria"]) >= 0.75 and not al.get("festa", false):
		al["festa"] = true
		novos.append(_fato(u, lugar, "festa", "%s está em festa." % nome, 0.3, [Natureza._ultimo_fato_natural(u, lugar)], []))
	elif float(h["alegria"]) < 0.5:
		al.erase("festa")
	# Profeta: medo e fé altos fazem alguém começar a pregar.
	if float(h["fe"]) >= 0.55 and float(h["medo"]) >= 0.45 and rng.randf() < 0.01 and not al.get("profeta", false):
		var gente := Natureza._mentes_em(u, lugar).filter(func(m): return not Pecas.marcas(u, m).has("profeta"))
		if not gente.is_empty():
			gente.sort_custom(func(a, b): return Personalidade.tracos(u, a)["curiosidade"] + Personalidade.tracos(u, a)["orgulho"] > Personalidade.tracos(u, b)["curiosidade"] + Personalidade.tracos(u, b)["orgulho"])
			var p: String = gente[0]
			al["profeta"] = true
			var fe_txt := Sociedades._campo(u, sid, ["religi", "fe", "crenc", "deus"]) if sid != "" else ""
			var ops: Array = [{"op": "marca", "quem": p, "marca": "profeta"}, {"op": "mudar", "quem": p, "chave": "reputacao", "delta": 0.5}]
			for m in gente.slice(1):
				if rng.randf() < 0.3:
					ops.append({"op": "marca", "quem": m, "marca": "seguidor de " + u.entidade(p)["nome"]})
			var texto := "%s começou a pregar em %s que o sofrimento é um sinal%s." % [u.entidade(p)["nome"], nome, (" (" + fe_txt + ")") if fe_txt != "" else ""]
			var pf := _fato(u, lugar, "profeta", texto, 0.6, [causa_fome], [p], ops)
			novos.append(pf)
			# Numa teocracia, um profeta de fora é heresia.
			if sid != "" and Sociedades.tipo(u, sid) == "teocracia" and rng.randf() < 0.6:
				novos.append(_fato(u, lugar, "heresia", "%s foi declarado herege por %s." % [u.entidade(p)["nome"], u.entidade(sid)["nome"]], 0.6, [pf], [p],
					[{"op": "marca", "quem": p, "marca": "herege"}] + ([{"op": "relacao", "de": l, "para": p, "deltas": {"raiva": 0.6}}] if l != "" else [])))
	return novos


static func _fato(u: Universo, lugar: String, tipo: String, texto: String, imp: float, causas: Array, sujeitos: Array, ops: Array = []) -> String:
	var cs: Array = causas.filter(func(c): return c != "" and u.fatos.existe(c))
	if cs.is_empty():
		var fc: String = u.entidade(lugar).get("fato_criacao", "")
		if u.fatos.existe(fc):
			cs = [fc]
	return Simulador.registrar(u, {
		"tipo": tipo, "descricao": texto, "sujeitos": [lugar] + sujeitos.filter(func(x): return x != "" and x != lugar), "lugar": lugar,
		"causas": cs, "dados": {"importancia": imp, "humor": true, "mudancas": ops},
	})
