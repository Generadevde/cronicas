class_name Fios
extends RefCounted
## Fios de história. O Crônica não obriga uma história a terminar: acompanha as
## possibilidades. Cada objetivo forte de alguém (uma vingança, um amor, uma ambição)
## é um fio, com estado (nascendo, crescendo, em tensão, perto do clímax, resolvido,
## abandonado) e caminhos possíveis. Os fios mudam com a simulação; quando um muda de
## rumo, vira notícia. Você pode puxar um fio (dar mais peso), deixá-lo correr ou
## cortá-lo. Fios abandonados ficam como pontas soltas que o mundo pode retomar.
##
## Arcos de personagem: quando alguém muda por dentro (da vingança para a dúvida),
## o arco é marcado como semente para você fechar.

const NOMES := {"vingança": "A vingança de %s", "afeto": "O amor de %s", "poder": "A ambição de %s", "forca": "A busca de %s por força",
	"saber": "A busca de %s por saber", "riqueza": "A fortuna de %s", "viagem": "A jornada de %s"}


static func _tipo(o: Dictionary) -> String:
	var t := TextUtil.normalizar(str(o["tipo"]))
	if t.begins_with("vingan"):
		return "vingança"
	return t


## Todos os fios (calculados a partir dos objetivos e do que aconteceu).
static func todos(u: Universo) -> Array:
	return Sociedades._lembrar(u, "fios|%d|%d" % [DataMundo.ordem(u.relogio), u.fatos.quantidade()], func(): return _calcular(u))


static func _calcular(u: Universo) -> Array:
	var lista: Array = []
	var guardados: Dictionary = u.extra("fios", {})
	for e in u.entidades_ativas():
		var eid: String = e["id"]
		if not Estado.tem_mente(u, eid):
			continue
		for o in u.estado(eid).get("objetivos", []):
			var t := _tipo(o)
			if not NOMES.has(t) or float(o["forca"]) < 0.4 and o["estado"] == "ativo":
				continue
			var id := "%s|%s|%s" % [eid, t, o["alvo"]]
			var g: Dictionary = guardados.get(id, {})
			lista.append({"id": id, "quem": eid, "alvo": str(o["alvo"]), "tipo": t, "tipo_obj": str(o["tipo"]), "forca": float(o["forca"]),
				"estado": estado(u, eid, o), "nome": NOMES[t] % e["nome"], "fato": str(o.get("fato", "")), "peso": str(g.get("peso", "solto"))})
	return lista


## O estado de um fio, a partir do objetivo, da vida de quem quer e do alvo.
static func estado(u: Universo, eid: String, o: Dictionary) -> String:
	if o["estado"] == "cumprido":
		return "resolvido"
	if o["estado"] != "ativo" or not Estado.vivo(u, eid):
		return "abandonado"
	var alvo := str(o["alvo"])
	if alvo != "" and u.entidades.has(alvo) and Estado.tem_mente(u, alvo) and not Estado.vivo(u, alvo):
		return "resolvido" if _tipo(o) == "vingança" else "abandonado"
	var dias := DataMundo.ordem(u.relogio) - DataMundo.ordem(o.get("desde", u.relogio))
	if float(o["forca"]) < 0.45:
		return "abandonado"
	if alvo != "" and u.entidades.has(alvo) and str(u.estado(alvo).get("local", "")) == str(u.estado(eid).get("local", "")) and float(o["forca"]) > 0.7:
		return "perto do clímax"
	if float(o.get("progresso", 0.0)) > 0.5 or (alvo != "" and Estado.valor_relacao(u, eid, alvo, "raiva") > 0.7):
		return "em tensão"
	if dias < 60:
		return "nascendo"
	return "crescendo"


## Os caminhos possíveis agora (o que pode acontecer com o fio).
static func caminhos(u: Universo, f: Dictionary) -> Array:
	var quem: String = u.entidade(f["quem"])["nome"]
	var alvo: String = u.entidade(f["alvo"]).get("nome", "") if f["alvo"] != "" else ""
	var r: Array = []
	match str(f["tipo"]):
		"vingança":
			r.append("%s pode abandonar a vingança (se apaixonar, perdoar, encontrar outro propósito)" % quem)
			if alvo != "":
				r.append("%s pode morrer antes do confronto, por outra mão" % alvo)
				r.append("o confronto entre %s e %s" % [quem, alvo])
			for p in u.estado(f["quem"])["familia"]["pais"]:
				if u.entidades.has(p) and Estado.vivo(u, p):
					r.append("%s pode revelar um segredo que muda tudo" % u.entidade(p)["nome"])
			r.append("a vingança pode virar guerra entre famílias")
		"afeto":
			r.append("o amor pode ser correspondido, ou não")
			r.append("alguém pode se pôr no caminho (ciúme, família, guerra)")
		"poder":
			r.append("%s pode tomar o poder (golpe, eleição, herança)" % quem)
			r.append("a ambição pode virar traição")
		_:
			r.append("%s pode conseguir o que quer — ou desistir" % quem)
	return r


## Cada mudança de rumo vira notícia (uma vez por mudança).
static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("fios_ctrl", {"t": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < 28:
		return []
	ctrl["t"] = agora
	var guardados: Dictionary = u.extra("fios", {})
	var novos: Array = []
	for f in todos(u):
		var g: Dictionary = guardados.get(f["id"], {})
		var antes := str(g.get("estado", ""))
		g["estado"] = f["estado"]
		guardados[f["id"]] = g
		if antes == "" or antes == f["estado"] or f["estado"] in ["nascendo", "crescendo"]:
			continue
		var frase: Variant = {"em tensão": "a tensão cresce", "perto do clímax": "está perto do clímax", "resolvido": "chegou ao fim", "abandonado": "%s hesitou" % u.entidade(f["quem"])["nome"].split(" ")[0]}.get(f["estado"], f["estado"])
		var causa := _ultimo_fato(u, f["quem"])
		novos.append(Simulador.registrar(u, {"tipo": "fio de história", "descricao": "O fio \"%s\" mudou: %s." % [f["nome"], frase], "sujeitos": [f["quem"]] + ([f["alvo"]] if f["alvo"] != "" and u.entidades.has(f["alvo"]) else []),
			"causas": [causa], "origem": {"tipo": BancoDeFatos.ORIGEM_SISTEMA, "ref": "fios"}, "dados": {"importancia": 0.35, "fio": f["id"], "estado": f["estado"], "mudancas": []}}))
		# Arco: da vingança para a dúvida (ou outra mudança por dentro).
		if antes in ["em tensão", "perto do clímax", "crescendo"] and f["estado"] == "abandonado" and Estado.vivo(u, f["quem"]):
			var arcos: Array = u.extra("arcos", [])
			arcos.append({"quem": f["quem"], "de": f["nome"], "para": _o_que_sente_agora(u, f["quem"]), "fato": novos.back(), "fechado": false})
	# Pontas soltas: uma vingança abandonada pode voltar anos depois.
	for f in todos(u):
		if f["estado"] != "abandonado" or f["tipo"] != "vingança" or f["alvo"] == "" or not Estado.vivo(u, f["quem"]) or not Estado.vivo(u, f["alvo"]):
			continue
		if rng.randf() < 0.004 * dias:
			novos.append(Simulador.registrar(u, {"tipo": "ponta solta", "descricao": "Anos depois, a velha vingança de %s contra %s voltou a arder." % [u.entidade(f["quem"])["nome"], u.entidade(f["alvo"])["nome"]],
				"sujeitos": [f["quem"], f["alvo"]], "causas": [f["fato"]], "dados": {"importancia": 0.5, "mudancas": [
					{"op": "objetivo", "quem": f["quem"], "tipo": "vingança", "alvo": f["alvo"], "forca": 0.75}]}}))
	return novos.filter(func(x): return x != "")


static func _ultimo_fato(u: Universo, eid: String) -> String:
	var ids := u.fatos.ids_sobre(eid)
	for i in range(ids.size() - 1, -1, -1):
		if u.fatos.obter(ids[i])["canon"]:
			return ids[i]
	return Simulador.causa_de_presenca(u, eid)


static func _o_que_sente_agora(u: Universo, eid: String) -> String:
	var em := Estado.emocoes_atuais(u, eid)
	if em.is_empty():
		return "a calma"
	return Paginas.NOMES_EMOCAO.get(em[0]["emocao"], em[0]["emocao"])


static func arcos(u: Universo) -> Array:
	return u.extra("arcos", [])


## Você puxa um fio (mais força), deixa correr, ou corta (o objetivo é abandonado).
static func puxar(u: Universo, id: String) -> String:
	var f := _achar(u, id)
	if f.is_empty():
		return ""
	u.extra("fios", {})[id] = Dictionary(u.extra("fios", {}).get(id, {})).merged({"peso": "puxado"}, true)
	return Simulador.registrar(u, {"tipo": "fio puxado", "descricao": "O autor puxou o fio \"%s\"." % f["nome"], "sujeitos": [f["quem"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "fios"}, "dados": {"importancia": 0.2, "mudancas": [
			{"op": "objetivo_estado", "quem": f["quem"], "tipo": f["tipo_obj"], "alvo": f["alvo"], "forca": minf(1.0, float(f["forca"]) + 0.25)}]}})


static func cortar(u: Universo, id: String) -> String:
	var f := _achar(u, id)
	if f.is_empty():
		return ""
	u.extra("fios", {})[id] = Dictionary(u.extra("fios", {}).get(id, {})).merged({"peso": "cortado"}, true)
	return Simulador.registrar(u, {"tipo": "fio cortado", "descricao": "O autor cortou o fio \"%s\"." % f["nome"], "sujeitos": [f["quem"]],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "fios"}, "dados": {"importancia": 0.2, "mudancas": [
			{"op": "objetivo_estado", "quem": f["quem"], "tipo": f["tipo_obj"], "alvo": f["alvo"], "estado": "abandonado"}]}})


static func _achar(u: Universo, id: String) -> Dictionary:
	for f in todos(u):
		if f["id"] == id:
			return f
	return {}
