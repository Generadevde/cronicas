class_name Legado
extends RefCounted
## O legado das histórias: acontecimentos importantes deixam marcas na cultura.
##   uma guerra → feriado nacional ou dia de luto
##   um herói → personagem de uma canção
##   uma traição → provérbio popular
##   uma técnica → tradição de uma escola
##   um pacto esquecido → superstição
## Cada legado tem a origem registrada no banco de fatos, mesmo que o povo já não
## lembre a verdade. Legados mudam com o tempo: canções ganham versos, provérbios
## perdem o sentido original, dias de luto viram festa. E influenciam o presente
## (quem tem um herói cantado luta com mais moral; a superstição deixa o povo com medo).


static func de(u: Universo, lugar_ou_povo: String) -> Array:
	return u.estado(lugar_ou_povo).get("cultura", [])


static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	if str(op.get("op", "")) != "legado":
		return false
	var onde := str(op.get("onde", ""))
	if not u.entidades.has(onde):
		return true
	var c: Array = u.estado(onde).get("cultura", [])
	var x: Dictionary = op.get("legado", {}).duplicate(true)
	x["fato"] = fato.get("id", "")
	x["desde"] = DataMundo.ordem(fato.get("data", u.relogio))
	c.append(x)
	u.estado(onde)["cultura"] = c
	return true


static func _tem(u: Universo, onde: String, origem: String) -> bool:
	return de(u, onde).any(func(x): return str(x.get("origem", "")) == origem)


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("legado_ctrl", {"t": -999, "visto": 0})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < 90:
		return []
	ctrl["t"] = agora
	var novos: Array = []
	var todos := u.fatos.todos()
	var ate := int(ctrl["visto"])
	for i in range(todos.size() - 1, -1, -1):
		var f: Dictionary = todos[i]
		if int(f["seq"]) <= int(ctrl["visto"]):
			break
		ate = maxi(ate, int(f["seq"]))
		if not f["canon"]:
			continue
		novos.append(_marca(u, f, rng))
	ctrl["visto"] = ate
	return novos.filter(func(x): return x != "")


## O legado de um fato (se houver).
static func _marca(u: Universo, f: Dictionary, rng: RandomNumberGenerator) -> String:
	var tipo: String = f["tipo"]
	var onde := ""
	var leg := {}
	match tipo:
		"fim da guerra":
			var g := str(f["dados"].get("guerra", ""))
			var venc := str(f["dados"].get("vencedor", ""))
			var feitos: Array = []
			for lado in ["a", "b"]:
				for sid in Guerras.dados(u, g).get(lado, []):
					if _tem(u, sid, f["id"]):
						continue
					var ganhou: bool = sid == venc or (venc != "" and Guerras.lado_de(u, g, sid) == Guerras.lado_de(u, g, venc))
					leg = {"tipo": "feriado" if ganhou else "dia de luto", "nome": ("Dia da Vitória" if ganhou else "Dia de Luto por %s" % u.entidade(g)["nome"]),
						"texto": "lembra o fim da %s" % u.entidade(g)["nome"], "origem": f["id"]}
					feitos.append(_registrar(u, f, sid, leg))
			return feitos[0] if not feitos.is_empty() else ""
		"título":
			var h: String = f["sujeitos"][0]
			var sid2 := Sociedades.de_lugar(u, str(u.estado(h).get("local", "")))
			if sid2 != "" and not _tem(u, sid2, f["id"]) and rng.randf() < 0.7:
				var tit := str(f["dados"].get("titulo", ""))
				leg = {"tipo": "canção", "nome": "A Canção de %s" % u.entidade(h)["nome"].split(" ")[0], "texto": "canta %s, %s" % [u.entidade(h)["nome"], tit],
					"origem": f["id"], "versos": 1, "heroi": h}
				return _registrar(u, f, sid2, leg)
		"traição", "espião descoberto", "técnica roubada":
			var l := str(f["lugar"])
			if l != "" and not _tem(u, l, f["id"]) and rng.randf() < 0.5:
				var traidor: String = u.entidade(f["sujeitos"][0]).get("nome", "?")
				leg = {"tipo": "provérbio", "nome": "\"Quem confia em %s dorme com a porta aberta.\"" % traidor, "texto": "nasceu de: " + f["descricao"], "origem": f["id"]}
				return _registrar(u, f, l, leg)
		"escola fundada":
			var t := str(f["sujeitos"][2]) if f["sujeitos"].size() > 2 else ""
			var l2 := str(f["lugar"])
			if t != "" and l2 != "" and not _tem(u, l2, f["id"]):
				leg = {"tipo": "tradição", "nome": "A tradição %s" % Escolas._de(u.entidade(t)["nome"]), "texto": "os jovens de %s aprendem %s" % [u.entidade(l2)["nome"], u.entidade(t)["nome"]], "origem": f["id"]}
				return _registrar(u, f, l2, leg)
		"preço do pacto":
			var l3 := str(f["lugar"])
			if l3 != "" and not _tem(u, l3, f["id"]):
				var ser: String = f["sujeitos"][1] if f["sujeitos"].size() > 1 else ""
				leg = {"tipo": "superstição", "nome": "Não se diz o nome de %s depois do pôr do sol." % u.entidade(ser).get("nome", "certas coisas"), "texto": "dizem que traz azar", "origem": f["id"]}
				return _registrar(u, f, l3, leg)
	return ""


static func _registrar(u: Universo, f: Dictionary, onde: String, leg: Dictionary) -> String:
	return Simulador.registrar(u, {"tipo": "legado", "lugar": onde if Mapa.e_lugar(u, onde) else "", "sujeitos": [onde], "causas": [f["id"]],
		"descricao": "Em %s nasceu %s: %s (%s)." % [u.entidade(onde)["nome"], {"feriado": "um feriado", "dia de luto": "um dia de luto", "canção": "uma canção",
			"provérbio": "um provérbio", "tradição": "uma tradição", "superstição": "uma superstição"}.get(leg["tipo"], "um costume"), leg["nome"], leg["texto"]],
		"dados": {"importancia": 0.4, "mudancas": [{"op": "legado", "onde": onde, "legado": leg}]}})


## Como o legado está hoje (ele muda com o tempo; a verdade fica no fato).
static func como_esta(u: Universo, x: Dictionary) -> Dictionary:
	var anos := (DataMundo.ordem(u.relogio) - int(x.get("desde", DataMundo.ordem(u.relogio)))) / float(DataMundo.DIAS_POR_ANO)
	var r := x.duplicate()
	match str(x["tipo"]):
		"dia de luto":
			if anos >= 100:
				r["tipo"] = "festa"
				r["texto"] = "ninguém mais chora: virou dia de festa (%s)" % x["texto"]
		"canção":
			r["versos"] = 1 + int(anos / 10)
			if anos >= 30:
				r["texto"] = "%s — com %d versos que ninguém sabe quem acrescentou" % [x["texto"], r["versos"]]
		"provérbio":
			if anos >= 80:
				r["texto"] = "ninguém lembra de onde veio"
	return r


## Influência no presente: quantos heróis cantados um povo tem (moral na guerra).
static func cancoes_de(u: Universo, sid: String) -> int:
	return de(u, sid).filter(func(x): return x["tipo"] == "canção").size()
