class_name Pactos
extends RefCounted
## Pactos com entidades. Qualquer entidade (deus, demônio, espírito, o próprio Autor…)
## com "o que oferece" na ficha pode oferecer pactos. É um mecanismo geral: cada
## universo decide quem oferece, o que oferece e o que cobra.
##
##  • A entidade procura quem tem um desejo forte e nenhuma saída (vingança contra
##    alguém muito mais forte, doença, uma guerra perdida, um luto).
##  • A mente da pessoa decide se aceita (desespero, ambição, prudência, o preço).
##  • O desejo é cumprido de verdade. O preço fica registrado — secreto: só você vê.
##  • O preço chega depois, no tempo da entidade ("em dez anos"), e quem paga é a
##    pessoa, a família, o primeiro filho ou a cidade. Só então o mundo descobre.
##  • Entidades ganham seguidores; as sociedades reagem (perseguem o culto ou
##    tentam usar a entidade).
## Tudo vira fato com causa; os pactos ficam no estado da entidade (por operações).

const CAMPOS_OFERTA := ["o que oferece", "oferece", "concede", "da em troca", "promete"]
const CAMPOS_PRECO := ["o que cobra", "cobra", "preco", "custo do pacto", "em troca"]


# ---------------------------------------------------------------- quem oferece

static func ofertantes(u: Universo) -> Array:
	return Sociedades._lembrar(u, "ofertantes", func():
		return u.entidades_ativas().filter(func(e): return Sociedades._campo(u, e["id"], CAMPOS_OFERTA) != "").map(func(e): return e["id"]))


static func oferta(u: Universo, ser: String) -> String:
	return Sociedades._campo(u, ser, CAMPOS_OFERTA)


static func preco_escrito(u: Universo, ser: String) -> String:
	var p := Sociedades._campo(u, ser, CAMPOS_PRECO)
	return "" if TextUtil.normalizar(p) in ["ainda nao se sabe", "?", "—", "-"] else p


## A entidade age por conta própria? ("vontade: dormir" a deixa quieta.)
static func ativo(u: Universo, ser: String) -> bool:
	var v := TextUtil.normalizar(Sociedades._campo(u, ser, ["vontade", "como age"]))
	return not (v.contains("dorm") or v.contains("nenhuma") or v.contains("nao age") or v.contains("so quando chamad"))


static func pactos_de(u: Universo, ser: String) -> Array:
	return u.estado(ser).get("pactos", [])


## Todos os pactos do universo: [{ser, ...pacto}]
static func todos(u: Universo) -> Array:
	var r: Array = []
	for e in u.entidades_ativas():
		for p in u.estado(e["id"]).get("pactos", []):
			var x: Dictionary = p.duplicate()
			x["ser"] = e["id"]
			r.append(x)
	return r


# ---------------------------------------------------------------- o preço

const POR_EXTENSO := {"um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8,
	"nove": 9, "dez": 10, "onze": 11, "doze": 12, "treze": 13, "quinze": 15, "vinte": 20, "trinta": 30, "cem": 100, "mil": 1000}


## Lê o preço: {quem: pessoa|filho|familia|cidade, dias: quando, efeito: texto para as peças, resumo}
static func ler_preco(texto: String, rng_semente: int = 0) -> Dictionary:
	var t := " " + TextUtil.normalizar(texto) + " "
	var r := {"quem": "pessoa", "dias": -1, "efeito": "", "resumo": texto.strip_edges().trim_suffix(".")}
	# Quando.
	var rx := RegEx.new()
	rx.compile("(?:em|daqui a|depois de|apos|dentro de|ao fim de)\\s+(\\d+|[a-z]+)\\s+(anos?|mes(?:es)?|dias?|semanas?|decadas?|seculos?)")
	var m := rx.search(t)
	if m != null:
		var n := m.get_string(1)
		var v: float = float(n) if n.is_valid_int() else float(POR_EXTENSO.get(n, 7))
		var un := m.get_string(2)
		var mult := 360.0 if un.begins_with("ano") else (30.0 if un.begins_with("mes") else (7.0 if un.begins_with("semana") else (3600.0 if un.begins_with("decada") else (36000.0 if un.begins_with("seculo") else 1.0))))
		r["dias"] = int(v * mult)
	else:
		var h := absi(hash(texto) + rng_semente)
		r["dias"] = (3 + h % 8) * 360  # "um dia": entre 3 e 10 anos
	# Quem paga.
	if t.contains("primeiro filho") or t.contains("primogenit") or t.contains(" filho ") or t.contains(" filha ") or t.contains("filhos"):
		r["quem"] = "filho"
	elif t.contains("familia") or t.contains("linhagem") or t.contains("descendentes"):
		r["quem"] = "familia"
	elif t.contains("cidade") or t.contains(" povo ") or t.contains(" vila ") or t.contains(" reino ") or t.contains(" aldeia "):
		r["quem"] = "cidade"
	# O quê.
	if t.contains("sono") or t.contains("dormir") or t.contains("dorme") or t.contains("adormec"):
		r["efeito"] = "sono eterno"
	elif t.contains("juventude") or t.contains("anos de vida"):
		rx.compile("(\\d+|[a-z]+)\\s+anos de vida")
		var m2 := rx.search(t)
		var na := 20
		if m2 != null:
			na = int(m2.get_string(1)) if m2.get_string(1).is_valid_int() else int(POR_EXTENSO.get(m2.get_string(1), 20))
		r["efeito"] = "envelhece %d anos" % na
	elif t.contains(" alma") or t.contains(" vida ") or t.contains("a vida") or t.contains("morte") or t.contains(" sangue"):
		r["efeito"] = "morre"
	elif t.contains("memoria") or t.contains("lembranc"):
		r["efeito"] = "perde a memória"
	elif t.contains("olhos") or t.contains("visao"):
		r["efeito"] = "fica cego"
	elif t.contains(" voz"):
		r["efeito"] = "fica mudo"
	elif t.contains("servir") or t.contains("servo") or t.contains("obedienc") or t.contains("escrav"):
		r["efeito"] = "passa a ser servo"
	elif t.contains("colheita") or t.contains("lavoura"):
		r["efeito"] = "lavouras caem 80%"
		r["quem"] = "cidade"
	elif t.contains("peste") or t.contains("praga"):
		r["efeito"] = "peste"
		r["quem"] = "cidade"
	else:
		r["efeito"] = ""
	return r


# ---------------------------------------------------------------- o desejo

## O desejo mais forte e sem saída de alguém. {tipo, alvo, texto, desespero}
static func desejo(u: Universo, eid: String) -> Dictionary:
	if not Estado.vivo(u, eid):
		return {}
	var melhor := {}
	var dmax := 0.0
	for o in Estado.objetivos_ativos(u, eid):
		var tipo := TextUtil.normalizar(str(o["tipo"]))
		var alvo := str(o["alvo"])
		var d := 0.0
		var texto := ""
		if tipo.begins_with("vingan") and alvo != "" and Estado.vivo(u, alvo):
			var ch := Combate.chance(u, eid, alvo)
			d = clampf((1.0 - ch) * float(o["forca"]) * 1.2, 0.0, 1.0)
			texto = "vingança contra %s" % u.entidade(alvo)["nome"]
		elif tipo in ["forca", "poder"]:
			d = float(o["forca"]) * 0.5
			texto = "poder"
		elif tipo == "riqueza":
			d = float(o["forca"]) * 0.4
			texto = "riqueza"
		elif tipo == "afeto" and alvo != "" and Estado.valor_relacao(u, alvo, eid, "afeto") < 0.2:
			d = float(o["forca"]) * 0.5
			texto = "o amor de %s" % u.entidade(alvo)["nome"]
		if d > dmax:
			dmax = d
			melhor = {"tipo": "vinganca" if tipo.begins_with("vingan") else tipo, "alvo": alvo, "texto": texto, "desespero": d}
	# Doença ou ferida grave.
	if Estado.saude_atual(u, eid) < 0.35:
		var d2 := 0.85 - Estado.saude_atual(u, eid)
		if d2 > dmax:
			dmax = d2
			melhor = {"tipo": "cura", "alvo": eid, "texto": "ser curado", "desespero": d2}
	# Luto: trazer de volta quem morreu.
	for em in Estado.emocoes_atuais(u, eid):
		if str(em.get("emocao", "")) == "luto" and str(em.get("alvo", "")) != "" and not Estado.vivo(u, str(em["alvo"])):
			var d3 := Estado.forca_emocao(u, eid, em) * 0.9
			if d3 > dmax:
				dmax = d3
				melhor = {"tipo": "reviver", "alvo": str(em["alvo"]), "texto": "trazer %s de volta" % u.entidade(str(em["alvo"]))["nome"], "desespero": d3}
	# Um governante perdendo uma guerra.
	for sid in Sociedades.todas(u):
		if Sociedades.lider(u, sid) != eid:
			continue
		for g in Guerras.ativas(u):
			var lado := Guerras.lado_de(u, g, sid)
			if lado == "":
				continue
			var p := Guerras.previsao(u, g)
			var ch2 := float(p["chance"]) if lado == "a" else 1.0 - float(p["chance"])
			var d4 := (1.0 - ch2) * 0.95
			if d4 > dmax:
				dmax = d4
				melhor = {"tipo": "guerra", "alvo": g, "texto": "vencer a %s" % u.entidade(g)["nome"], "desespero": d4, "sociedade": sid}
	return melhor


## A pessoa aceita? Desespero e ambição puxam; prudência, empatia (se a família paga) e lealdade seguram.
static func aceita(u: Universo, eid: String, d: Dictionary, preco: Dictionary) -> bool:
	var t := Personalidade.tracos(u, eid)
	var s := float(d.get("desespero", 0.0)) + 0.3 * float(t["ambicao"]) + 0.2 * float(t["impulsividade"]) + 0.1 * float(t["orgulho"])
	s -= 0.5 * float(t["prudencia"])
	if str(preco.get("quem", "pessoa")) in ["filho", "familia", "cidade"]:
		s -= 0.7 * float(t["empatia"])
	return s > 0.6


# ---------------------------------------------------------------- fazer o pacto

## O que acontece quando o desejo se cumpre. {ops, texto (o que o mundo vê)}
static func cumprimento(u: Universo, ser: String, eid: String, d: Dictionary, causa: String) -> Dictionary:
	var alvo := str(d.get("alvo", ""))
	var n: String = u.entidade(eid)["nome"]
	match str(d.get("tipo", "")):
		"vinganca":
			return {"ops": [{"op": "morrer", "quem": alvo}, {"op": "objetivo_estado", "quem": eid, "tipo": "vingança", "alvo": alvo, "estado": "cumprido"}],
				"texto": "%s morreu de repente, sem que ninguém soubesse explicar." % u.entidade(alvo)["nome"], "sujeitos": [alvo]}
		"cura":
			return {"ops": [{"op": "curar", "quem": eid, "quanto": 1.0}], "texto": "%s se curou de repente, contra todas as chances." % n, "sujeitos": [eid]}
		"reviver":
			return {"ops": [{"op": "reviver", "quem": alvo}], "texto": "%s voltou dos mortos." % u.entidade(alvo)["nome"], "sujeitos": [alvo, eid]}
		"guerra":
			var g := alvo
			var sid := str(d.get("sociedade", ""))
			var lado := Guerras.lado_de(u, g, sid)
			var outro: String = Guerras.dados(u, g)["b" if lado == "a" else "a"][0]
			var tam := maxf(1000.0, roundf(Guerras.tamanho_do_lado(u, g, Guerras.lado_de(u, g, outro)) * 0.6 / 100.0) * 100.0)
			var nome: Variant = Guerras._tropa_no_texto(oferta(u, ser))["nome"]
			if nome == "":
				nome = "Hoste de %s" % u.entidade(ser)["nome"]
			var f := Forcas.criar(u, nome, sid, tam, [causa], {"tipo": "sobrenaturais", "moral": "inabalável"})
			return {"ops": [], "texto": "%s recebeu %s (%s)." % [u.entidade(sid)["nome"], u.entidade(f)["nome"], Forcas.numero(tam)], "sujeitos": [sid, f]}
		"forca", "poder":
			return {"ops": [{"op": "mudar", "quem": eid, "chave": "poder", "delta": maxf(10.0, Estado.poder(u, eid) * 2.0)}],
				"texto": "%s ficou muito mais forte, de uma hora para outra." % n, "sujeitos": [eid]}
		"riqueza":
			return {"ops": [{"op": "marca", "quem": eid, "marca": "rico"}, {"op": "mudar", "quem": eid, "chave": "reputacao", "delta": 0.5}],
				"texto": "%s enriqueceu de repente." % n, "sujeitos": [eid]}
		"afeto":
			return {"ops": [{"op": "relacao", "de": alvo, "para": eid, "deltas": {"afeto": 0.9}}], "texto": "%s se apaixonou por %s." % [u.entidade(alvo)["nome"], n], "sujeitos": [alvo, eid]}
	return {"ops": [{"op": "marca", "quem": eid, "marca": "desejo realizado: " + str(d.get("texto", "?"))}], "texto": "O desejo de %s se realizou." % n, "sujeitos": [eid]}


## Faz um pacto. Devolve o id do fato do pacto.
## 'preco' é texto livre (padrão: o que a entidade cobra); 'secreto' esconde o preço dos personagens.
static func fazer(u: Universo, ser: String, eid: String, d: Dictionary, preco: String = "", secreto: bool = true, causas: Array = [], pelo_autor: bool = false) -> String:
	if preco.strip_edges() == "":
		preco = preco_escrito(u, ser)
	var p := ler_preco(preco, hash(eid))
	var quando := DataMundo.ordem(u.relogio) + int(p["dias"])
	var fato := {"tipo": "pacto", "sujeitos": [eid, ser], "lugar": u.estado(eid).get("local", ""),
		"descricao": "%s fez um pacto com %s: %s, em troca de %s." % [u.entidade(eid)["nome"], u.entidade(ser)["nome"], str(d.get("texto", "um desejo")),
			p["resumo"] if p["resumo"] != "" else "um preço que ainda não disse"],
		"causas": causas,
		"dados": {"importancia": 0.9, "secreto": secreto, "pacto": {"ser": ser, "com": eid, "desejo": d, "preco": p, "quando": quando},
			"mudancas": [{"op": "pacto", "ser": ser, "com": eid, "quando": quando, "secreto": secreto},
				{"op": "marca", "quem": eid, "marca": "pacto com " + u.entidade(ser)["nome"]}, {"op": "conhecer", "quem": eid}, {"op": "conhecer", "quem": ser}]}}
	if pelo_autor:
		fato["origem"] = {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "pactos"}
	var fid := Simulador.registrar(u, fato)
	if fid == "":
		return ""
	# O desejo se cumpre de verdade (o mundo vê o efeito, não a causa).
	var c := cumprimento(u, ser, eid, d, fid)
	Simulador.registrar(u, {"tipo": "desejo cumprido", "descricao": c["texto"], "sujeitos": c["sujeitos"], "lugar": fato["lugar"], "causas": [fid],
		"dados": {"importancia": 0.75, "pacto_de": fid, "mudancas": c["ops"]}})
	return fid


static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	match str(op.get("op", "")):
		"pacto":
			var ser := str(op.get("ser", ""))
			if u.entidades.has(ser):
				var lista: Array = u.estado(ser).get("pactos", [])
				lista.append({"fato": fato.get("id", ""), "com": str(op.get("com", "")), "quando": int(op.get("quando", 0)),
					"cobrado": false, "secreto": bool(op.get("secreto", true))})
				u.estado(ser)["pactos"] = lista
			return true
		"pacto_cobrado":
			var ser2 := str(op.get("ser", ""))
			for p in u.estado(ser2).get("pactos", []):
				if p["fato"] == str(op.get("pacto", "")):
					p["cobrado"] = true
					p["revelado"] = true
			return true
	return false


# ---------------------------------------------------------------- o passo: cobrar, oferecer, seguidores

static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for ser in ofertantes(u):
		for p in pactos_de(u, ser):
			if not p["cobrado"] and int(p["quando"]) <= agora:
				novos.append_array(cobrar(u, ser, p, rng))
	var ctrl: Dictionary = u.extra("pactos_ctrl", {"mes": -999, "ano": -999})
	if agora - int(ctrl["mes"]) >= 7:
		ctrl["mes"] = agora
		for ser in ofertantes(u):
			if ativo(u, ser) and Estado.vivo(u, ser):
				novos.append_array(_procurar(u, ser, rng))
	if agora - int(ctrl["ano"]) >= DataMundo.DIAS_POR_ANO:
		ctrl["ano"] = agora
		for ser in ofertantes(u):
			novos.append_array(_seguidores(u, ser, rng))
	return novos.filter(func(x): return x != "")


## A entidade procura alguém desesperado.
static func _procurar(u: Universo, ser: String, rng: RandomNumberGenerator) -> Array:
	var ja := {}
	for p in pactos_de(u, ser):
		ja[p["com"]] = true
	var onde := _onde_age(u, ser)
	var melhor := ""
	var dm := {}
	for eid in Simulador._mentes(u):
		if eid == ser or ja.has(eid) or u.estado(eid).has("recusou_" + ser):
			continue
		if not onde.is_empty() and not onde.has(u.estado(eid).get("local", "")):
			continue
		var d := desejo(u, eid)
		if d.is_empty() or float(d["desespero"]) < 0.55:
			continue
		if dm.is_empty() or float(d["desespero"]) > float(dm["desespero"]):
			dm = d
			melhor = eid
	# Quanto mais sem saída, mais depressa a entidade aparece.
	if melhor == "" or rng.randf() > 0.25 + 0.6 * (float(dm["desespero"]) - 0.55) / 0.45:
		return []
	var preco := ler_preco(preco_escrito(u, ser), hash(melhor))
	var causa := _causa_do_desespero(u, melhor, dm)
	var oferta_f := Simulador.registrar(u, {"tipo": "oferta de pacto", "sujeitos": [melhor, ser], "lugar": u.estado(melhor).get("local", ""),
		"descricao": "%s ofereceu um pacto a %s: %s." % [u.entidade(ser)["nome"], u.entidade(melhor)["nome"], dm["texto"]],
		"causas": [causa] if causa != "" else [], "dados": {"importancia": 0.6, "secreto": true, "mudancas": [{"op": "conhecer", "quem": melhor}]}})
	if aceita(u, melhor, dm, preco):
		return [oferta_f, fazer(u, ser, melhor, dm, "", true, [oferta_f])]
	return [oferta_f, Simulador.registrar(u, {"tipo": "pacto recusado", "sujeitos": [melhor, ser], "causas": [oferta_f],
		"descricao": "%s recusou o pacto de %s." % [u.entidade(melhor)["nome"], u.entidade(ser)["nome"]],
		"dados": {"importancia": 0.4, "secreto": true, "mudancas": [{"op": "definir", "quem": melhor, "chave": "recusou_" + ser, "valor": true}]}})]


## Onde a entidade age (campo "onde age", "lugar", "templo"); vazio = em qualquer lugar.
static func _onde_age(u: Universo, ser: String) -> Array:
	var txt := Sociedades._campo(u, ser, ["onde age", "onde vive", "lugar", "templo", "morada", "santuario"])
	var r: Array = []
	if txt == "":
		return r
	for m in Ligador.new(u).encontrar(txt):
		if Mapa.e_lugar(u, m["entidade"]):
			r.append(m["entidade"])
			r.append_array(Mapa.descendentes(u, m["entidade"]))
	return r


static func _causa_do_desespero(u: Universo, eid: String, d: Dictionary) -> String:
	if str(d.get("tipo", "")) == "vinganca":
		for o in Estado.objetivos_ativos(u, eid):
			if o["alvo"] == d["alvo"] and u.fatos.existe(str(o.get("fato", ""))):
				return str(o["fato"])
	if str(d.get("tipo", "")) == "guerra":
		return Guerras._ultimo_fato(u, str(d["alvo"]))
	return Simulador.causa_de_presenca(u, eid)


## Chegou a hora: a entidade cobra o preço.
static func cobrar(u: Universo, ser: String, p: Dictionary, rng: RandomNumberGenerator) -> Array:
	var f := u.fatos.obter(str(p["fato"]))
	if f.is_empty() or not f["canon"]:
		return []
	var info: Dictionary = f["dados"].get("pacto", {})
	var preco: Dictionary = info.get("preco", ler_preco(""))
	var eid := str(p["com"])
	var quem: Array = []
	var lugar := str(u.estado(eid).get("local", ""))
	match str(preco.get("quem", "pessoa")):
		"pessoa":
			quem = [eid] if Estado.vivo(u, eid) else Estado.familia_proxima(u, eid).filter(func(x): return Estado.vivo(u, x)).slice(0, 1)
		"filho":
			var filhos: Array = u.estado(eid)["familia"]["filhos"].filter(func(x): return Estado.vivo(u, x))
			quem = filhos.slice(0, 1) if not filhos.is_empty() else ([eid] if Estado.vivo(u, eid) else [])
		"familia":
			quem = Estado.familia_proxima(u, eid).filter(func(x): return Estado.vivo(u, x))
			if Estado.vivo(u, eid):
				quem.append(eid)
		"cidade":
			quem = [lugar] if lugar != "" else [eid]
	var anos := int(roundf((DataMundo.ordem(u.relogio) - DataMundo.ordem(f["data"])) / float(DataMundo.DIAS_POR_ANO)))
	var efeito := str(preco.get("efeito", ""))
	var ops: Array = [{"op": "pacto_cobrado", "ser": ser, "pacto": f["id"]}]
	var o_que := ""
	if efeito == "sono eterno" and lugar != "":
		ops.append({"op": "adormecer", "lugar": lugar})
		o_que = "%s caiu num sono eterno" % u.entidade(lugar)["nome"]
	elif efeito != "":
		for alvo in quem:
			var ctx := {"sujeito": alvo, "outro": eid, "lugar": alvo if Mapa.e_lugar(u, alvo) else lugar}
			for e in Pecas.ler(u, efeito):
				if Mapa.e_lugar(u, alvo) and str(e.get("alvo", "")) == "sujeito":
					e["alvo"] = "todos_no_lugar" if not str(e.get("peca", "")) in ["evento", "natureza"] else "lugar"
					e["lugar_alvo"] = alvo
				if str(e.get("peca", "")) == "marca" and str(e.get("marca", "")).ends_with("servo"):
					e["marca"] = "servo de " + u.entidade(ser)["nome"]
				ops.append_array(Pecas.operacoes(u, e, ctx))
		# "a alma do primeiro filho, em dez anos" → "a alma do primeiro filho"
		var o_preco := str(preco.get("resumo", efeito))
		var rxp := RegEx.new()
		rxp.compile(",?\\s*(em|daqui a|depois de|após|apos|dentro de|ao fim de)\\s+\\S+\\s+\\S+\\s*$")
		o_preco = rxp.sub(o_preco, "").strip_edges()
		o_que = "%s pagou com %s" % [", ".join(quem.map(func(x): return u.entidade(x)["nome"])) if not quem.is_empty() else "ninguém", o_preco]
	else:
		# Preço não escrito: vira pendência para você dizer o que foi.
		o_que = "o preço ainda não tem efeito: diga em \"Ainda sem efeito\" o que aconteceu"
	for alvo in quem:
		if Estado.tem_mente(u, alvo):
			ops.append({"op": "emocao", "quem": alvo, "emocao": "medo", "forca": 0.6, "alvo": ser})
	var texto := "Chegou a hora: %s cobrou o preço do pacto que %s fez há %d ano%s — %s." % [u.entidade(ser)["nome"], u.entidade(eid)["nome"], anos, "" if anos == 1 else "s", o_que]
	var fid := Simulador.registrar(u, {"tipo": "preço do pacto", "descricao": texto, "sujeitos": [eid, ser] + quem.filter(func(x): return x != eid),
		"lugar": lugar, "causas": [f["id"]], "dados": {"importancia": 0.95, "revela_pacto": f["id"], "sem_efeito": efeito == "",
			"texto": "preço do pacto com " + u.entidade(ser)["nome"], "mudancas": ops}})
	return [fid]


## Seguidores e a reação das sociedades.
static func _seguidores(u: Universo, ser: String, rng: RandomNumberGenerator) -> Array:
	var cumpridos: Array = pactos_de(u, ser)
	if cumpridos.is_empty():
		return []
	var novos: Array = []
	var marca: Variant = "seguidor de " + u.entidade(ser)["nome"]
	var lugares := {}
	for p in cumpridos:
		var l := str(u.estado(str(p["com"])).get("local", ""))
		if l != "":
			lugares[l] = p["fato"]
	for l in lugares:
		var h := Humor.de(u, l)
		var gente: Array = Natureza._mentes_em(u, l).filter(func(m): return not Pecas.marcas(u, m).has(marca) and m != ser)
		var ops: Array = []
		for m in gente:
			var t := Personalidade.tracos(u, m)
			if rng.randf() < 0.15 * (float(h["fe"]) + float(h["medo"])) * (0.5 + float(t["ambicao"])):
				ops.append({"op": "marca", "quem": m, "marca": marca})
		if not ops.is_empty():
			novos.append(Simulador.registrar(u, {"tipo": "seguidores", "lugar": l, "sujeitos": [ser, l] + ops.map(func(o): return o["quem"]),
				"descricao": "Em %s, %d pessoa%s passou a seguir %s." % [u.entidade(l)["nome"], ops.size(), "" if ops.size() == 1 else "s", u.entidade(ser)["nome"]],
				"causas": [lugares[l]], "dados": {"importancia": 0.5, "mudancas": ops}}))
			# A sociedade reage: persegue o culto ou tenta usar a entidade.
			var sid := Sociedades.de_lugar(u, l)
			if sid != "" and not u.estado(sid).has("reagiu_" + ser):
				novos.append(_reacao(u, sid, ser, l, novos.back(), rng))
	return novos


static func _reacao(u: Universo, sid: String, ser: String, lugar: String, causa: String, rng: RandomNumberGenerator) -> String:
	var lider := Sociedades.lider(u, sid)
	var t := Personalidade.tracos(u, lider) if lider != "" else {"ambicao": 0.5, "prudencia": 0.5, "empatia": 0.5}
	var desp := TextUtil.normalizar(Sociedades._campo(u, sid, ["desprez", "tabu", "condenam"]))
	var persegue: bool = Sociedades.tipo(u, sid) == "teocracia" or desp.contains("pacto") or desp.contains("demon") or desp.contains("magia") \
		or float(t["prudencia"]) > float(t["ambicao"])
	var ops: Array = [{"op": "definir", "quem": sid, "chave": "reagiu_" + ser, "valor": "persegue" if persegue else "usa"}]
	var texto := ""
	if persegue:
		var marca: Variant = "seguidor de " + u.entidade(ser)["nome"]
		for e in u.entidades_ativas():
			if Pecas.marcas(u, e["id"]).has(marca) and Sociedades.membros(u, sid).has(e["id"]):
				ops.append({"op": "marca", "quem": e["id"], "marca": "perseguido"})
		texto = "%s proibiu o culto a %s e passou a perseguir seus seguidores." % [u.entidade(sid)["nome"], u.entidade(ser)["nome"]]
	else:
		texto = "%s quer usar o poder de %s%s." % [u.entidade(sid)["nome"], u.entidade(ser)["nome"], (": " + u.entidade(lider)["nome"] + " vai procurá-lo") if lider != "" else ""]
		if lider != "":
			ops.append({"op": "objetivo", "quem": lider, "tipo": "poder", "alvo": ser, "forca": 0.7})
	return Simulador.registrar(u, {"tipo": "reação ao culto", "descricao": texto, "sujeitos": [sid, ser], "lugar": lugar, "causas": [causa],
		"dados": {"importancia": 0.6, "mudancas": ops}})
