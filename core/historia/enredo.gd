class_name Enredo
extends RefCounted
## O que dá forma às histórias, além dos fios:
##  • Ganchos que voltam: promessas, profecias e objetos apresentados ficam marcados,
##    e o mundo tende a trazê-los de volta (a pistola de um tiro só não fica esquecida).
##  • Segredos e mistérios: quem sabe, quem suspeita, e o momento da revelação.
##  • Boatos: notícias que viajam longe chegam distorcidas.
##  • Sementes de histórias: o próprio mundo sugere histórias curtas a partir do que
##    está acontecendo nele (personagens, lugar e conflito reais).


# ---------------------------------------------------------------- ganchos

static func ganchos(u: Universo) -> Array:
	var r: Array = []
	for f in u.fatos.todos():
		if not f["canon"]:
			continue
		if f["tipo"] in ["promessa", "revelação"] or str(f["dados"].get("acao", "")) == "promessa":
			var tipo := "promessa" if f["tipo"] == "promessa" or str(f["dados"].get("acao", "")) == "promessa" else str(f["dados"].get("revelacao", {}).get("tipo", "visao"))
			r.append({"fato": f["id"], "tipo": tipo, "texto": f["descricao"], "voltou": u.extra("ganchos", {}).has(f["id"])})
	for e in u.entidades_ativas():
		if Sugestoes.categoria(e["tipo"]) == "objeto" and u.indice().has(e["id"]):
			r.append({"fato": str(e.get("fato_criacao", "")), "tipo": "objeto", "texto": e["nome"], "objeto": e["id"], "voltou": u.extra("ganchos", {}).has(e["id"])})
	return r


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("enredo_ctrl", {"t": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < 90:
		return []
	ctrl["t"] = agora
	var novos: Array = []
	var feitos: Dictionary = u.extra("ganchos", {})
	for g in ganchos(u):
		if g["voltou"]:
			continue
		var f := u.fatos.obter(str(g["fato"]))
		var anos := (agora - DataMundo.ordem(f.get("data", u.relogio))) / float(DataMundo.DIAS_POR_ANO)
		if anos < 1.0 or rng.randf() > 0.12 * Diretor.fator(u, "gancho"):
			continue
		match str(g["tipo"]):
			"promessa":
				var quem: String = f["sujeitos"][0]
				if Estado.vivo(u, quem):
					feitos[g["fato"]] = true
					novos.append(Simulador.registrar(u, {"tipo": "promessa à prova", "sujeitos": f["sujeitos"], "causas": [f["id"]],
						"descricao": "A promessa de %s foi posta à prova: %s" % [u.entidade(quem)["nome"], f["descricao"]],
						"dados": {"importancia": 0.55, "mudancas": [{"op": "emocao", "quem": quem, "emocao": "culpa", "forca": 0.4, "alvo": ""}]}}))
			"profecia":
				var cumpriu := _profecia_cumprida(u, f)
				if cumpriu != "":
					feitos[g["fato"]] = true
					novos.append(Simulador.registrar(u, {"tipo": "profecia cumprida", "sujeitos": f["sujeitos"], "causas": [f["id"], cumpriu],
						"descricao": "A profecia se cumpriu: %s" % u.fatos.obter(cumpriu)["descricao"], "dados": {"importancia": 0.75, "mudancas": []}}))
			"objeto":
				var obj := str(g.get("objeto", ""))
				var dono := _alguem_perto(u, obj)
				if dono != "":
					feitos[obj] = true
					novos.append(Simulador.registrar(u, {"tipo": "o objeto volta", "sujeitos": [dono, obj], "causas": [str(u.entidade(obj).get("fato_criacao", ""))],
						"descricao": "%s encontrou %s, esquecido havia muito tempo." % [u.entidade(dono)["nome"], u.entidade(obj)["nome"]],
						"dados": {"importancia": 0.5, "mudancas": [{"op": "marca", "quem": dono, "marca": "tem " + u.entidade(obj)["nome"]}]}}))
	novos.append_array(_segredos(u, rng))
	return novos.filter(func(x): return x != "")


## Uma profecia se cumpre quando acontece algo que bate com as palavras dela.
static func _profecia_cumprida(u: Universo, f: Dictionary) -> String:
	var texto := TextUtil.normalizar(str(f["dados"].get("revelacao", {}).get("texto", f["descricao"])))
	var lig := Ligador.new(u)
	var citados: Array = lig.encontrar(str(f["dados"].get("revelacao", {}).get("texto", ""))).map(func(m): return m["entidade"])
	var verbos := {"cair": ["queda do governo", "ocupação", "fim da guerra", "declínio"], "morrer": ["morte"], "guerra": ["declaração de guerra"],
		"fome": ["fome"], "peste": ["peste"], "rei": ["sucessão", "queda do governo"]}
	var tipos: Array = []
	for v in verbos:
		if texto.contains(v.substr(0, 4)):
			tipos.append_array(verbos[v])
	if tipos.is_empty() or citados.is_empty():
		return ""
	for g in u.fatos.todos():
		if g["canon"] and g["seq"] > f["seq"] and tipos.has(g["tipo"]) and (citados.has(g["lugar"]) or g["sujeitos"].any(func(s): return citados.has(s))):
			return g["id"]
	return ""


static func _alguem_perto(u: Universo, obj: String) -> String:
	var lugar := ""
	for m in Ligador.new(u).encontrar(" ".join(u.entidade(obj)["campos"].map(func(c): return str(c["valor"])))):
		if Mapa.e_lugar(u, m["entidade"]):
			lugar = m["entidade"]
	var gente := Natureza._mentes_em(u, lugar) if lugar != "" else Simulador._mentes(u)
	gente = gente.filter(func(x): return float(Personalidade.tracos(u, x)["curiosidade"]) > 0.5)
	return gente[0] if not gente.is_empty() else ""


# ---------------------------------------------------------------- segredos

## Segredos: fatos secretos, quem sabe e quem suspeita.
static func segredos(u: Universo) -> Array:
	var r: Array = []
	for f in u.fatos.todos():
		if not f["canon"] or not f["dados"].get("secreto", false) or f["tipo"] in ["conversa", "oferta de pacto"]:
			continue
		var sabem: Array = []
		var suspeitam: Array = []
		for e in u.entidades_ativas():
			if Estado.conhece(u, e["id"], f["id"]):
				sabem.append(e["id"])
			elif Pecas.marcas(u, e["id"]).has("suspeita de " + f["id"]):
				suspeitam.append(e["id"])
		r.append({"fato": f["id"], "texto": f["descricao"], "sabem": sabem, "suspeitam": suspeitam, "revelar_em": int(f["dados"].get("revelar_em", -1))})
	return r


## Você marca quando um segredo vem à tona.
static func revelar_em(u: Universo, fid: String, data: Dictionary) -> void:
	u.fatos.obter(fid)["dados"]["revelar_em"] = DataMundo.ordem(data)
	u.marcar_mudanca()


static func _segredos(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for s in segredos(u):
		var f := u.fatos.obter(s["fato"])
		# A hora da revelação chegou.
		if int(s["revelar_em"]) > 0 and agora >= int(s["revelar_em"]):
			f["dados"]["revelar_em"] = -1
			novos.append(Simulador.registrar(u, {"tipo": "segredo revelado", "sujeitos": f["sujeitos"], "lugar": f["lugar"], "causas": [f["id"]],
				"descricao": "Veio à tona: %s" % f["descricao"], "dados": {"importancia": 0.8, "mudancas": []}}))
			continue
		# Gente curiosa e próxima dos envolvidos começa a suspeitar.
		for sj in f["sujeitos"]:
			if not u.entidades.has(sj) or not Estado.tem_mente(u, sj):
				continue
			for m in Natureza._mentes_em(u, str(u.estado(sj).get("local", ""))):
				if m == sj or Estado.conhece(u, m, f["id"]) or Pecas.marcas(u, m).has("suspeita de " + f["id"]):
					continue
				var t := Personalidade.tracos(u, m)
				if float(t["curiosidade"]) > 0.6 and Estado.valor_relacao(u, m, sj, "afeto") + Estado.valor_relacao(u, m, sj, "raiva") > 0.4 and rng.randf() < 0.08:
					novos.append(Simulador.registrar(u, {"tipo": "suspeita", "sujeitos": [m, sj], "causas": [f["id"]],
						"descricao": "%s começou a desconfiar de %s." % [u.entidade(m)["nome"], u.entidade(sj)["nome"]],
						"dados": {"importancia": 0.3, "secreto": true, "mudancas": [{"op": "marca", "quem": m, "marca": "suspeita de " + f["id"]}]}}))
	return novos


# ---------------------------------------------------------------- boatos

## Um boato: a notícia distorcida (números crescem, uma vitória vira morte, um nome some).
static func distorcer(texto: String, rng: RandomNumberGenerator) -> String:
	var t := texto
	var rx := RegEx.new()
	rx.compile("(\\d+)")
	for m in rx.search_all(texto):
		t = t.replace(m.get_string(1), str(int(m.get_string(1)) * (2 + rng.randi() % 3)))
	if rng.randf() < 0.5:
		t = t.replace("venceu", "matou").replace("feriu", "matou").replace("perdeu", "fugiu de")
	if rng.randf() < 0.4:
		t = t.replace(" mil", " milhares").replace("doença", "praga mortal").replace("seca", "maldição")
	return t


# ---------------------------------------------------------------- sementes

## Uma semente de história a partir do que está acontecendo (personagens, lugar e conflito reais).
## Filtros: lugar, pessoa. Devolve {titulo, resumo, personagens, gancho} ou {}.
static func semente(u: Universo, rng: RandomNumberGenerator, filtro_lugar: String = "", filtro_pessoa: String = "") -> Dictionary:
	var ideias: Array = []
	var mentes := Simulador._mentes(u)
	var por_lugar := {}
	for x in mentes:
		var lx := str(u.estado(x)["local"])
		por_lugar[lx] = Array(por_lugar.get(lx, [])) + [x]
	var ok_lugar := func(l: String) -> bool:
		return filtro_lugar == "" or l == filtro_lugar or Mapa.ancestrais(u, l).has(filtro_lugar)
	var ok_pessoa := func(lista: Array) -> bool:
		return filtro_pessoa == "" or lista.has(filtro_pessoa)
	# 1) Um ferido do inimigo e alguém de bom coração.
	for g in Guerras.ativas(u):
		for m in mentes:
			var l := str(u.estado(m)["local"])
			var minha := Sociedades.de_lugar(u, l)
			if Estado.saude_atual(u, m) < 0.7 and minha != "" and Guerras.lado_de(u, g, minha) != "":
				for o in por_lugar.get(l, []):
					if o != m and float(Personalidade.tracos(u, o)["empatia"]) > 0.6 and ok_lugar.call(l) and ok_pessoa.call([m, o]):
						ideias.append({"titulo": "O inimigo na minha casa", "personagens": [o, m],
							"resumo": "%s, de %s, esconde %s, ferido, em plena %s." % [u.entidade(o)["nome"], u.entidade(l)["nome"], u.entidade(m)["nome"], u.entidade(g)["nome"]],
							"gancho": "Se descobrirem, os dois morrem."})
	# 2) Amor entre povos que se odeiam.
	for m in mentes:
		for o in u.estado(m)["relacoes"]:
			if not u.entidades.has(o) or Estado.valor_relacao(u, m, o, "afeto") < 0.5:
				continue
			var sa := Sociedades.de_lugar(u, str(u.estado(m)["local"]))
			var sb := Sociedades.de_lugar(u, str(u.estado(o).get("local", "")))
			if sa != "" and sb != "" and sa != sb and (Guerras.rancor(u, sa, sb) >= 0.3 or Guerras.em_guerra(u, sa, sb) != "") and ok_pessoa.call([m, o]):
				ideias.append({"titulo": "Do outro lado do rio", "personagens": [m, o],
					"resumo": "%s ama %s, mas %s e %s não se perdoam." % [u.entidade(m)["nome"], u.entidade(o)["nome"], u.entidade(sa)["nome"], u.entidade(sb)["nome"]],
					"gancho": "Um dos dois vai ter de escolher."})
	# 3) A vingança e o alvo no mesmo lugar.
	for f in Fios.todos(u):
		if f["tipo"] == "vingança" and f["estado"] in ["em tensão", "perto do clímax"] and ok_pessoa.call([f["quem"], f["alvo"]]) and ok_lugar.call(str(u.estado(f["quem"])["local"])):
			ideias.append({"titulo": "O dia do acerto", "personagens": [f["quem"], f["alvo"]],
				"resumo": "%s finalmente está perto de %s." % [u.entidade(f["quem"])["nome"], u.entidade(f["alvo"])["nome"]],
				"gancho": "Mas e se a vingança custar mais do que ele imagina?"})
	# 4) Um segredo e alguém que suspeita.
	for s in segredos(u):
		if not s["suspeitam"].is_empty() and ok_pessoa.call(s["sabem"] + s["suspeitam"]):
			var q: String = s["suspeitam"][0]
			ideias.append({"titulo": "O que ninguém conta", "personagens": [q] + s["sabem"].slice(0, 1),
				"resumo": "%s desconfia de algo: %s" % [u.entidade(q)["nome"], s["texto"]], "gancho": "A verdade está mais perto do que parece."})
	# 5) Um profeta e um governante que não acredita.
	for m in mentes:
		if Pecas.marcas(u, m).has("profeta"):
			var sid := Sociedades.de_lugar(u, str(u.estado(m)["local"]))
			var l2 := Sociedades.lider(u, sid) if sid != "" else ""
			if l2 != "" and ok_pessoa.call([m, l2]):
				ideias.append({"titulo": "A voz no deserto", "personagens": [m, l2],
					"resumo": "%s prega o fim dos tempos, e %s quer silenciá-lo." % [u.entidade(m)["nome"], u.entidade(l2)["nome"]], "gancho": "E se o profeta tiver razão?"})
	if ideias.is_empty():
		return {}
	return ideias[rng.randi() % ideias.size()]
