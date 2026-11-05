class_name Cidades
extends RefCounted
## Construções e ruínas. Cidades crescem (aldeia → vila → cidade → metrópole) ou
## minguam; muralhas sobem quando a guerra ameaça (e ajudam quem defende); templos
## caem quando a fé morre; lugares sem ninguém viram ruínas, que guardam o que restou
## das eras passadas e viram lugar de aventura (e de redescobertas).

const PORTES := [[0.0, "ruínas"], [1.0, "aldeia"], [800.0, "vila"], [5000.0, "cidade"], [40000.0, "metrópole"]]


static func porte_de(pop: float) -> String:
	var r := "ruínas"
	for p in PORTES:
		if pop >= float(p[0]):
			r = p[1]
	return r


static func porte(u: Universo, lugar: String) -> String:
	return str(u.estado(lugar).get("porte", ""))


static func em_ruinas(u: Universo, lugar: String) -> bool:
	return lugar != "" and u.entidades.has(lugar) and u.estado(lugar).get("ruina", false)


static func muralha(u: Universo, lugar: String) -> bool:
	return lugar != "" and u.entidades.has(lugar) and u.estado(lugar).get("muralha", false)


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("cidades_ctrl", {"ano": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["ano"]) < 90:
		return []
	ctrl["ano"] = agora
	var novos: Array = []
	var guerra := Guerras.lugares_em_guerra(u)
	for e in u.entidades_ativas():
		var l: String = e["id"]
		if Mapa.especie(u, l) != "povoado" or not Natureza.tem_natureza(u, l) or Motor.adormecido(u, l):
			continue
		var reg := Natureza.de(u, l)
		var pop := float(reg["pop"])
		var antes := porte(u, l)
		var agora_p := porte_de(pop)
		if antes == "":
			u.estado(l)["porte"] = agora_p  # o porte inicial não é notícia
			if agora_p == "ruínas":
				u.estado(l)["ruina"] = true
			continue
		if agora_p != antes:
			var cresceu := PORTES.map(func(p): return p[1]).find(agora_p) > PORTES.map(func(p): return p[1]).find(antes)
			var ops: Array = [{"op": "definir", "quem": l, "chave": "porte", "valor": agora_p}]
			var texto := ""
			if agora_p == "ruínas":
				ops.append({"op": "definir", "quem": l, "chave": "ruina", "valor": true})
				texto = "%s ficou deserta e virou ruínas." % e["nome"]
			elif antes == "ruínas":
				ops.append({"op": "definir", "quem": l, "chave": "ruina", "valor": false})
				texto = "Gente voltou a morar nas ruínas de %s." % e["nome"]
			else:
				texto = ("%s cresceu e virou %s." if cresceu else "%s minguou e virou %s.") % [e["nome"], agora_p]
			novos.append(Simulador.registrar(u, {"tipo": "crescimento" if cresceu else "declínio", "lugar": l, "sujeitos": [l],
				"causas": [Natureza._ultimo_fato_natural(u, l)], "descricao": texto,
				"dados": {"importancia": 0.5 if agora_p in ["cidade", "metrópole", "ruínas"] else 0.3, "mudancas": ops}}))
		# Muralhas: a guerra chega perto e a cidade tem gente para erguê-las.
		if not muralha(u, l) and pop >= 800 and guerra.has(l) == false:
			for g in Guerras.ativas(u):
				var sid := Sociedades.de_lugar(u, l)
				if sid != "" and Guerras.lado_de(u, g, sid) != "" and rng.randf() < 0.35:
					novos.append(Simulador.registrar(u, {"tipo": "construção", "lugar": l, "sujeitos": [l, sid, g], "causas": [str(Guerras.dados(u, g)["declaracao"])],
						"descricao": "%s ergueu muralhas em volta de %s." % [u.entidade(sid)["nome"], e["nome"]],
						"dados": {"importancia": 0.45, "mudancas": [{"op": "definir", "quem": l, "chave": "muralha", "valor": true}]}}))
					break
	return novos.filter(func(x): return x != "")


## Um templo que cai (a religião morreu) vira ruína com nome.
static func templo_em_ruinas(u: Universo, religiao: String, lugar: String, causa: String) -> String:
	var nome := "Ruínas do Templo %s" % ("de " + u.entidade(religiao)["nome"])
	var r := u.criar_entidade(nome, "ruína", [], [{"chave": "descrição", "valor": "o que restou do templo de uma fé esquecida"},
		{"chave": "fica em", "valor": u.entidade(lugar).get("nome", "")}], [causa] if u.fatos.existe(causa) else [])
	u.estado(r)["ruina"] = true
	return r
