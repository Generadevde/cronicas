class_name Conversa
extends RefCounted
## Conversar com os personagens. Ele responde com a própria voz, usando as memórias,
## emoções, relações e o que realmente sabe (os fatos que conhece). Pode mentir,
## esconder segredos, se irritar, desconfiar ou se abrir — conforme a personalidade
## e o que sente por quem pergunta. Você escolhe como falar: como deus, como um
## desconhecido ou como outro personagem.
##
## O que acontece na conversa pode virar fato (uma promessa, uma confissão, uma
## dúvida plantada): vira proposta, e você aceita ou não. A conversa pode virar cena
## (um capítulo em rascunho).
##
## Exemplo do plano: perguntar a Daren "por que você odeia o Kai?". Rancoroso e
## orgulhoso, ele responde seco, esconde que sentiu vergonha do pai, e só se abre se
## você insistir como alguém em quem ele confia.

const EMOCOES_DE_ODIO := ["odio", "raiva", "rancor", "humilhacao"]


# ---------------------------------------------------------------- conversas

static func conversas(u: Universo) -> Dictionary:
	return u.extra("conversas", {})


static func nova(u: Universo, eid: String, como: String = "deus", quem: String = "") -> String:
	var id := Ids.novo("cnv")
	conversas(u)[id] = {"id": id, "com": eid, "como": como, "quem": quem, "data": DataMundo.copiar(u.relogio), "falas": [], "insiste": {}, "fato": ""}
	return id


static func dados(u: Universo, cid: String) -> Dictionary:
	return conversas(u).get(cid, {})


## Faz uma pergunta. Devolve {texto, tom, propostas: [ids], intencao}.
static func perguntar(u: Universo, cid: String, pergunta: String) -> Dictionary:
	var c := dados(u, cid)
	if c.is_empty():
		return {}
	var eid: String = c["com"]
	c["falas"].append({"de": "voce", "texto": pergunta.strip_edges()})
	var r := responder(u, c, pergunta)
	r["texto"] = IALocal.voz(u, eid, pergunta, r["texto"], _o_que_sabe(u, eid).map(func(f): return f["descricao"]), r["tom"])
	c["falas"].append({"de": "personagem", "texto": r["texto"]})
	u.marcar_mudanca()
	return r


# ---------------------------------------------------------------- abertura e tom

## Quanto o personagem se abre com quem pergunta (0 a 1).
static func abertura(u: Universo, c: Dictionary, assunto: String) -> float:
	var eid: String = c["com"]
	var t := Personalidade.tracos(u, eid)
	var a := 0.0
	match str(c["como"]):
		"deus":
			var lugar := str(u.estado(eid).get("local", ""))
			var fe := float(Humor.de(u, lugar)["fe"]) if lugar != "" else 0.3
			a = 0.05 + 0.4 * fe + 0.15 * float(t["lealdade"]) + (0.3 if Autor.eh_arauto(u, eid) else 0.0)
		"personagem":
			var q := str(c["quem"])
			a = 0.6 * Estado.valor_relacao(u, eid, q, "confianca") + 0.4 * Estado.valor_relacao(u, eid, q, "afeto") - 0.4 * Estado.valor_relacao(u, eid, q, "raiva")
			if Estado.familia_proxima(u, eid).has(q):
				a += 0.15
		_:
			a = 0.1 + 0.3 * float(t["sociabilidade"]) - 0.2 * float(t["prudencia"])
	# Insistir ajuda (um pouco), mas irrita quem é orgulhoso.
	var n := int(c["insiste"].get(assunto, 0))
	a += 0.2 * n * (1.2 - float(t["orgulho"]))
	return clampf(a, 0.0, 1.0)


static func tom(u: Universo, eid: String, aberto: float, irritado: bool) -> String:
	var t := Personalidade.tracos(u, eid)
	if irritado:
		return "irritado"
	if aberto >= 0.65:
		return "aberto"
	if float(t["orgulho"]) > 0.6 or float(t["sociabilidade"]) < 0.35:
		return "seco"
	if float(t["empatia"]) > 0.6:
		return "gentil"
	return "reservado"


# ---------------------------------------------------------------- o que ele sabe

## Os fatos que o personagem conhece (só esses ele pode contar), do mais recente.
static func _o_que_sabe(u: Universo, eid: String) -> Array:
	var r: Array = []
	for fid in u.estado(eid).get("conhece", {}).keys():
		var f := u.fatos.obter(fid)
		if not f.is_empty() and f["canon"] and not f["tipo"] in ["notícia", "rumor", "criação"]:
			r.append(f)
	r.sort_custom(func(a, b): return a["seq"] > b["seq"])
	return r


static func sabe(u: Universo, eid: String, fid: String) -> bool:
	return Estado.conhece(u, eid, fid)


## Pessoa citada na pergunta (que não seja o próprio personagem).
static func _alvo(u: Universo, eid: String, texto: String) -> String:
	for m in Ligador.new(u).encontrar(texto):
		if m["entidade"] != eid:
			return m["entidade"]
	return ""


static func _n(u: Universo, eid: String) -> String:
	return u.entidade(eid).get("nome", "?")


# ---------------------------------------------------------------- responder

static func responder(u: Universo, c: Dictionary, pergunta: String) -> Dictionary:
	var eid: String = c["com"]
	var n := " " + TextUtil.normalizar(pergunta) + " "
	for ch in ["?", "!", ".", ",", ";", ":"]:
		n = n.replace(ch, " ")
	while n.contains("  "):
		n = n.replace("  ", " ")
	var alvo := _alvo(u, eid, pergunta)
	var assunto := "geral"
	var intencao := "geral"
	if n.contains("prometa") or n.contains("promete") or n.contains("jure ") or n.contains("jura "):
		intencao = "promessa"
	elif (n.contains("por que") or n.contains("porque")) and alvo != "" and (n.contains("odeia") or n.contains("odio") or n.contains("raiva") or n.contains("detesta")):
		intencao = "odio"
	elif (n.contains("por que") or n.contains("porque")) and alvo != "" and (n.contains(" ama ") or n.contains("gosta") or n.contains("amor")):
		intencao = "afeto"
	elif (n.contains("por que") or n.contains("porque")) and alvo != "" and (n.contains("teme") or n.contains("medo")):
		intencao = "medo"
	elif alvo != "" and (n.contains(" voce matou ") or n.contains(" voce traiu ") or n.contains(" voce feriu ") or n.contains(" foi voce ")):
		intencao = "acusacao"
	elif alvo != "" and (n.contains(" nao matou ") or n.contains(" nao foi ") or n.contains(" e inocente") or n.contains(" mentiu")):
		intencao = "duvida"
	elif n.contains("segredo") or n.contains("esconde"):
		intencao = "segredo"
	elif n.contains(" quer ") or n.contains(" deseja ") or n.contains("objetivo") or n.contains("sonho"):
		intencao = "desejo"
	elif n.contains(" onde ") and (n.contains(" esta ") or n.contains(" mora ") or n.contains(" vive ")) and alvo == "":
		intencao = "onde"
	elif alvo != "" and (n.contains(" sabe ") or n.contains("aconteceu") or n.contains("ouviu")):
		intencao = "saber"
	elif alvo != "" and (n.contains(" acha ") or n.contains("quem e ") or n.contains("pensa de") or n.contains(" sente ")):
		intencao = "opiniao"
	assunto = intencao + ":" + alvo
	var aberto := abertura(u, c, assunto)
	var insistiu := int(c["insiste"].get(assunto, 0)) > 0
	c["insiste"][assunto] = int(c["insiste"].get(assunto, 0)) + 1
	c["insistiu"] = insistiu
	var t := Personalidade.tracos(u, eid)
	var r := {"texto": "", "tom": "", "propostas": [], "intencao": intencao, "abertura": aberto}
	var irritado := false
	match intencao:
		"odio", "medo", "afeto":
			r["texto"] = _motivo(u, c, eid, alvo, intencao, aberto, r)
			irritado = intencao == "odio" and aberto < 0.35 and float(t["orgulho"]) > 0.6 and int(c["insiste"][assunto]) > 1
		"acusacao":
			r["texto"] = _acusacao(u, c, eid, alvo, n, aberto, r)
		"duvida":
			r["texto"] = _duvida(u, c, eid, alvo, aberto, r)
		"segredo":
			r["texto"] = _segredo(u, c, eid, aberto, r)
		"promessa":
			r["texto"] = _promessa(u, c, eid, pergunta, aberto, r)
		"desejo":
			var obj := Estado.objetivos_ativos(u, eid)
			if obj.is_empty():
				r["texto"] = "Viver em paz. Só isso."
			elif aberto < 0.3 and float(t["prudencia"]) > 0.5:
				r["texto"] = "Isso é comigo."
			else:
				var o: Dictionary = obj[0]
				r["texto"] = "Quero %s." % _texto_objetivo(u, o)
		"onde":
			var l := str(u.estado(eid).get("local", ""))
			r["texto"] = ("Em %s." % _n(u, l)) if l != "" else "Longe de tudo."
		"saber":
			var fs: Array = _o_que_sabe(u, eid).filter(func(f): return f["sujeitos"].has(alvo) or f["lugar"] == alvo)
			if fs.is_empty():
				r["texto"] = "Não sei nada sobre %s." % _n(u, alvo)
			elif aberto < 0.2 and float(t["prudencia"]) > 0.6:
				r["texto"] = "Ouvi umas coisas. Não vou repetir."
			else:
				r["texto"] = "O que eu sei: %s" % fs[0]["descricao"] + ((" E também: " + fs[1]["descricao"]) if fs.size() > 1 and aberto >= 0.4 else "")
		"opiniao":
			r["texto"] = _opiniao(u, eid, alvo)
		_:
			r["texto"] = ["Não entendi o que você quer saber.", "Pergunte direito.", "Hm."][int(float(t["sociabilidade"]) * 2.9)] if float(t["sociabilidade"]) < 0.6 else "Do que você está falando? Me pergunte sobre alguém, sobre o que eu quero, sobre onde estou."
	r["tom"] = tom(u, eid, aberto, irritado)
	if irritado:
		r["texto"] = "Já disse que isso não é da sua conta. " + r["texto"]
	return r


## Por que odeia (ou ama, ou teme) alguém: as emoções, as relações e os fatos que ele viveu.
static func _motivo(u: Universo, c: Dictionary, eid: String, alvo: String, intencao: String, aberto: float, r: Dictionary) -> String:
	var emocoes: Array = {"odio": EMOCOES_DE_ODIO, "medo": ["medo"], "afeto": ["amor", "gratidao"]}[intencao]
	var chave_rel: String = {"odio": "raiva", "medo": "medo", "afeto": "afeto"}[intencao]
	var sente := Estado.valor_relacao(u, eid, alvo, chave_rel)
	var causa := ""
	var humilhado := false
	for em in Estado.emocoes_atuais(u, eid):
		if em["alvo"] == alvo and emocoes.has(em["emocao"]):
			sente = maxf(sente, float(em["forca_atual"]))
			if causa == "" and u.fatos.existe(str(em.get("fato", ""))):
				causa = _raiz(u, eid, str(em["fato"]))
			if em["emocao"] == "humilhacao":
				humilhado = true
	# Sem emoção registrada: o fato mais forte entre os dois que ele conhece.
	if causa == "":
		for f in _o_que_sabe(u, eid):
			if f["sujeitos"].has(alvo) and f["dados"].get("acao", "") in ["vitoria", "morte_por", "traicao", "ferimento", "derrota", "amizade", "casamento", "amor"]:
				causa = f["id"]
				break
	var nome := _n(u, alvo)
	if sente < 0.15 and causa == "":
		return {"odio": "Odiar %s? Não odeio. Mal penso nele.", "medo": "Não tenho medo de %s.", "afeto": "Não sinto nada por %s."}[intencao] % nome
	var segredo := _vergonha(u, eid, alvo, causa)
	var t := Personalidade.tracos(u, eid)
	if aberto < 0.3:
		# Fechado: seco, e não conta nada.
		if intencao == "odio":
			return "%s sabe o que fez." % nome if float(t["orgulho"]) > 0.5 else "Prefiro não falar de %s." % nome
		return "Isso não é assunto para agora."
	var f := u.fatos.obter(causa) if causa != "" else {}
	var o_que := _primeira_pessoa(u, eid, f) if not f.is_empty() else ""
	# O que envergonha só sai com quem ele confia, e quando você insiste.
	if aberto < 0.65 or segredo == "" or not c.get("insistiu", false):
		# Conta o fato, mas esconde a vergonha.
		var txt := "Por causa do que aconteceu. %s" % _maiuscula(o_que) if o_que != "" else "Tenho meus motivos."
		if intencao == "odio" and float(t["rancor"]) > 0.6:
			txt += " E eu não esqueço."
		return txt
	# Aberto: conta também o que esconde — e isso pode virar uma confissão.
	var conf := "Vou te contar. %s Mas o que me consome é outra coisa: %s" % [_maiuscula(o_que), segredo]
	r["propostas"].append(_proposta(u, c, "confissao", "%s confessou %s: %s" % [_n(u, eid), _a_quem(u, c), segredo], [eid] + _interlocutor(c),
		[{"op": "marca", "quem": eid, "marca": "confessou: " + segredo}] + ([{"op": "relacao", "de": eid, "para": c["quem"], "deltas": {"confianca": 0.2}}] if c["como"] == "personagem" else [])))
	return conf


## O acontecimento por trás de uma reação ("passou a odiar Kai" → "Kai venceu Lucas").
static func _raiz(u: Universo, eid: String, fid: String) -> String:
	var f := u.fatos.obter(fid)
	for i in 4:
		var reacao: bool = str(f["dados"].get("acao", "")).begins_with("eco_") or f["tipo"] in ["reação", "derrota amarga"] or f["sujeitos"].size() > 0 and f["sujeitos"][0] == eid and f["origem"]["tipo"] == BancoDeFatos.ORIGEM_SIMULACAO
		if not reacao or f["causas"].is_empty():
			break
		var prox := u.fatos.obter(str(f["causas"][0]))
		if prox.is_empty():
			break
		f = prox
	return f["id"]


const VERBOS_1P := {"sentiu": "senti", "teve": "tive", "foi": "fui", "fez": "fiz", "matou": "matei", "mentiu": "menti", "traiu": "traí", "roubou": "roubei",
	"viu": "vi", "ama": "amo", "odeia": "odeio", "tem": "tenho", "é": "sou", "quer": "quero", "esconde": "escondo", "perdeu": "perdi", "fugiu": "fugi",
	"deixou": "deixei", "abandonou": "abandonei", "chorou": "chorei", "nunca": "nunca", "jurou": "jurei", "sabe": "sei"}


## "sentiu vergonha do pai" → "senti vergonha do pai".
static func _eu(texto: String) -> String:
	var t := texto.strip_edges()
	var p := t.split(" ", false)
	if p.is_empty():
		return t
	var w := str(p[0]).to_lower()
	if VERBOS_1P.has(w):
		p[0] = VERBOS_1P[w]
	return " ".join(p)


static func _maiuscula(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


## O que o personagem esconde sobre o assunto: o campo "segredos" ou uma humilhação.
static func _vergonha(u: Universo, eid: String, alvo: String, causa: String) -> String:
	var s := Sociedades._campo(u, eid, ["segredo", "segredos", "vergonha", "esconde"])
	if s != "":
		return _eu(s).trim_suffix(".") + "."
	for em in Estado.emocoes_atuais(u, eid):
		if em["emocao"] in ["humilhacao", "culpa", "vergonha"]:
			return "eu senti %s, e ainda sinto." % {"humilhacao": "humilhação", "culpa": "culpa", "vergonha": "vergonha"}[em["emocao"]]
	return ""


## Um fato contado em primeira pessoa ("Kai venceu Lucas" → "Kai venceu meu pai, Lucas").
static func _primeira_pessoa(u: Universo, eid: String, f: Dictionary) -> String:
	var t: String = f["descricao"]
	var fam: Dictionary = u.estado(eid)["familia"]
	for p in fam["pais"]:
		t = t.replace(_n(u, p), "meu pai %s" % _n(u, p))
	for s in fam["filhos"]:
		t = t.replace(_n(u, s), "meu filho %s" % _n(u, s))
	t = t.replace(_n(u, eid), "eu")
	# Ele estava lá? ("Daren viu tudo")
	var viu := false
	for g in u.fatos.sobre(eid):
		if g["canon"] and g["dados"].get("acao", "") == "testemunho" and g["origem"].get("ref", "") == f["origem"].get("ref", "~"):
			viu = true
	if viu and not f["sujeitos"].has(eid):
		t += " Eu vi tudo."
	return t.replace(", em", " em").replace(",.", ".")


static func _acusacao(u: Universo, c: Dictionary, eid: String, alvo: String, n: String, aberto: float, r: Dictionary) -> String:
	var acao := "morte_por" if n.contains("matou") else ("traicao" if n.contains("traiu") else "ferimento")
	var fez := ""
	for f in u.fatos.sobre(eid):
		if f["canon"] and f["dados"].get("acao", "") == acao and f["sujeitos"].size() > 1 and f["sujeitos"][0] == eid and f["sujeitos"][1] == alvo:
			fez = f["id"]
	var t := Personalidade.tracos(u, eid)
	if fez == "":
		return "Não. Quem disse isso mentiu."
	# Fez. Mente se não confia e não é honesto; confessa se confia.
	if aberto < 0.5 and float(t["empatia"]) < 0.6:
		return "Eu? Nunca. Procure outro culpado."
	r["propostas"].append(_proposta(u, c, "confissao", "%s confessou %s: %s" % [_n(u, eid), _a_quem(u, c), u.fatos.obter(fez)["descricao"]], [eid] + _interlocutor(c),
		[{"op": "emocao", "quem": eid, "emocao": "culpa", "forca": 0.5, "alvo": alvo}]))
	return "...Fui eu. %s" % ("E faria de novo." if float(t["rancor"]) > 0.6 else "Não passa um dia sem que eu pense nisso.")


static func _duvida(u: Universo, c: Dictionary, eid: String, alvo: String, aberto: float, r: Dictionary) -> String:
	var raiva := Estado.valor_relacao(u, eid, alvo, "raiva")
	if aberto < 0.45:
		return "E por que eu acreditaria em você?"
	r["propostas"].append(_proposta(u, c, "duvida", "%s começou a duvidar do que pensava sobre %s." % [_n(u, eid), _n(u, alvo)], [eid, alvo] + _interlocutor(c),
		[{"op": "relacao", "de": eid, "para": alvo, "deltas": {"raiva": -0.25}}, {"op": "esfriar_emocao", "quem": eid, "emocao": "odio", "alvo": alvo, "quanto": 0.25}]))
	return "Não pode ser... Se for verdade, eu %s." % ("odiei a pessoa errada" if raiva > 0.4 else "preciso pensar")


static func _segredo(u: Universo, c: Dictionary, eid: String, aberto: float, r: Dictionary) -> String:
	var s := _vergonha(u, eid, "", "")
	if s == "":
		return "Não tenho segredos. Não que valham a pena."
	if aberto < 0.6:
		return "Todo mundo esconde alguma coisa. Eu também."
	r["propostas"].append(_proposta(u, c, "confissao", "%s contou um segredo %s: %s" % [_n(u, eid), _a_quem(u, c), s], [eid] + _interlocutor(c),
		[{"op": "marca", "quem": eid, "marca": "confessou: " + s}]))
	return "Só a você: %s" % s


static func _promessa(u: Universo, c: Dictionary, eid: String, pergunta: String, aberto: float, r: Dictionary) -> String:
	var n := TextUtil.normalizar(pergunta)
	var i := n.find("que ")
	var o_que := pergunta.substr(i + 4).strip_edges().trim_suffix(".").trim_suffix("?") if i >= 0 else pergunta.strip_edges()
	o_que = o_que.replace("vai ", "vou ").replace("não vai", "não vou").replace("voce", "eu").replace("você", "eu")
	var t := Personalidade.tracos(u, eid)
	var alvo := _alvo(u, eid, pergunta)
	if aberto < 0.45 or (alvo != "" and Estado.valor_relacao(u, eid, alvo, "raiva") > 0.6 and float(t["rancor"]) > 0.7 and aberto < 0.75):
		return "Não prometo nada."
	var ops: Array = [{"op": "marca", "quem": eid, "marca": "prometeu: " + o_que}]
	var nn := TextUtil.normalizar(o_que)
	if alvo != "" and nn.contains("nao") and (nn.contains("mat") or nn.contains("vingar") or nn.contains("machucar") or nn.contains("ferir")):
		ops.append({"op": "objetivo_estado", "quem": eid, "tipo": "vingança", "alvo": alvo, "forca": 0.2})
	r["propostas"].append(_proposta(u, c, "promessa", "%s prometeu %s: %s." % [_n(u, eid), _a_quem(u, c), o_que], [eid] + _interlocutor(c), ops))
	return "Prometo. %s" % o_que.substr(0, 1).to_upper() + o_que.substr(1) + "."


static func _opiniao(u: Universo, eid: String, alvo: String) -> String:
	var nome := _n(u, alvo)
	if not u.estado(eid)["relacoes"].has(alvo):
		return "Não conheço %s." % nome if Sugestoes.categoria(u.entidade(alvo).get("tipo", "")) == "pessoa" else "%s? Sei pouco." % nome
	var rel: Dictionary = u.estado(eid)["relacoes"][alvo]
	var partes: Array = []
	if float(rel["afeto"]) >= 0.4:
		partes.append("gosto de %s" % nome)
	if float(rel["confianca"]) >= 0.4:
		partes.append("confio")
	if float(rel["respeito"]) >= 0.4:
		partes.append("respeito")
	if float(rel["medo"]) >= 0.4:
		partes.append("tenho medo")
	if float(rel["raiva"]) >= 0.4:
		partes.append("não suporto %s" % nome)
	if partes.is_empty():
		return "%s? Nem bem nem mal." % nome
	var txt := ", ".join(partes)
	return txt.substr(0, 1).to_upper() + txt.substr(1) + "."


static func _texto_objetivo(u: Universo, o: Dictionary) -> String:
	var alvo := str(o.get("alvo", ""))
	match TextUtil.normalizar(str(o["tipo"])):
		"vinganca":
			return "ver %s pagar pelo que fez" % _n(u, alvo)
		"forca":
			return "ficar mais forte"
		"saber":
			return "aprender o que ninguém sabe"
		"riqueza":
			return "ser rico"
		"afeto":
			return ("proteger %s" % _n(u, alvo)) if alvo != "" else "uma família"
		"poder":
			return ("o poder de %s" % _n(u, alvo)) if alvo != "" else "mandar"
		"viagem":
			return "ver o mundo"
	return "o que me cabe"


# ---------------------------------------------------------------- propostas e cenas

static func _interlocutor(c: Dictionary) -> Array:
	return [c["quem"]] if c["como"] == "personagem" and str(c["quem"]) != "" else []


static func _a_quem(u: Universo, c: Dictionary) -> String:
	match str(c["como"]):
		"deus":
			return "aos deuses"
		"personagem":
			return "a " + _n(u, c["quem"])
	return "a um desconhecido"


## O fato da conversa (criado na primeira proposta): é a causa do que ela gerar.
static func _fato(u: Universo, c: Dictionary) -> String:
	if u.fatos.existe(str(c["fato"])):
		return c["fato"]
	var como: Variant = {"deus": "como deus", "personagem": "como " + _n(u, c["quem"]), "desconhecido": "como um desconhecido"}.get(c["como"], "")
	c["fato"] = Simulador.registrar(u, {"tipo": "conversa", "descricao": "Uma conversa com %s (%s)." % [_n(u, c["com"]), como],
		"sujeitos": [c["com"]] + _interlocutor(c), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "conversa"},
		"dados": {"importancia": 0.2, "secreto": true, "conversa": c["id"], "mudancas": []}})
	return c["fato"]


static func _proposta(u: Universo, c: Dictionary, acao: String, descricao: String, sujeitos: Array, ops: Array) -> String:
	var p := {"id": Ids.novo("prp"), "capitulo": "", "frase": "", "acao": acao, "sujeitos": sujeitos, "lugar": u.estado(c["com"]).get("local", ""),
		"status": "eco", "descricao": descricao, "causa": _fato(u, c), "efeito": {}, "ops_extra": ops, "conversa": c["id"],
		"assinatura": "conversa|%s|%s" % [c["id"], descricao]}
	u.propostas.append(p)
	return p["id"]


static func propostas(u: Universo, cid: String) -> Array:
	return u.propostas.filter(func(p): return str(p.get("conversa", "")) == cid and p["status"] == "eco")


## A conversa vira cena: um capítulo em rascunho (não muda o mundo até você marcar canon).
static func virar_cena(u: Universo, cid: String) -> String:
	var c := dados(u, cid)
	if c.is_empty():
		return ""
	var livro := ""
	for l in u.livros:
		if l["titulo"] == "Cenas":
			livro = l["id"]
	if livro == "":
		livro = u.criar_livro("Cenas")
	var cap := u.criar_capitulo(livro, "Conversa com %s" % _n(u, c["com"]))
	var linhas: Array = []
	for f in c["falas"]:
		linhas.append("— %s" % f["texto"] if f["de"] == "voce" else "— %s, disse %s." % [str(f["texto"]).trim_suffix("."), _n(u, c["com"])])
	u.atualizar_capitulo(cap, {"texto": "\n\n".join(linhas), "canon": false, "data": DataMundo.copiar(c["data"])})
	return cap
