class_name Informacao
extends RefCounted
## Notícias viajam: um acontecimento é conhecido na hora por quem estava lá,
## chega ao resto do lugar em poucos dias e a outros lugares depois de um tempo.
## Quem fica sabendo pode reagir (raiva, luto, vingança...).

const DIAS_MESMO_LUGAR := 3
const DIAS_OUTRO_LUGAR := 25
const IMPORTANCIA_MINIMA := 0.35
const IMPORTANCIA_PARA_VIAJAR := 0.5
const JANELA_DIAS := 360 * 3   ## notícias com mais de 3 anos param de circular


## Um passo de espalhamento. Devolve os ids dos fatos novos (chegadas de notícias e reações).
static func espalhar(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var hoje := DataMundo.ordem(u.relogio)
	var estado_noticias: Dictionary = u.extra("noticias", {})
	var por_lugar := {}
	for e in u.entidades_ativas():
		if not Estado.tem_mente(u, e["id"]) or not Estado.vivo(u, e["id"]):
			continue
		var l: String = u.estado(e["id"])["local"]
		if not por_lugar.has(l):
			por_lugar[l] = []
		por_lugar[l].append(e["id"])

	for f in u.fatos.todos():
		if not f["canon"] or f["tipo"] in ["notícia", "rumor"]:
			continue
		var imp: float = float(f["dados"].get("importancia", Simulador.IMPORTANCIA.get(f["dados"].get("acao", ""), 0.0)))
		if imp < IMPORTANCIA_MINIMA:
			continue
		var idade := hoje - DataMundo.ordem(f["data"])
		if idade < 0 or idade > JANELA_DIAS:
			continue
		var origem := _lugar_de_origem(u, f)
		var reg: Dictionary = estado_noticias.get(f["id"], {})
		if reg.is_empty():
			reg = {"lugares": {}}
			estado_noticias[f["id"]] = reg
		for lugar in por_lugar:
			if reg["lugares"].has(lugar):
				continue
			var atraso := DIAS_MESMO_LUGAR if lugar == origem else _atraso(u, origem, lugar)
			if lugar != origem and imp < IMPORTANCIA_PARA_VIAJAR:
				continue
			if idade < atraso:
				continue
			var quem: Array = por_lugar[lugar].filter(func(p): return not Estado.conhece(u, p, f["id"]))
			reg["lugares"][lugar] = true
			if quem.is_empty():
				continue
			var ops: Array = []
			for p in quem:
				ops.append({"op": "conhecer", "quem": p, "fato": f["id"]})
			var texto := ""
			if lugar == "":
				texto = "Rumores correram pelo mundo: %s" % f["descricao"]
			elif lugar == origem:
				texto = "A notícia correu por %s: %s" % [u.entidade(lugar).get("nome", "?"), f["descricao"]]
			else:
				texto = "A notícia chegou a %s: %s" % [u.entidade(lugar).get("nome", "?"), f["descricao"]]
			var nid := Simulador.registrar(u, {
				"tipo": "notícia" if lugar != "" else "rumor",
				"descricao": texto,
				"sujeitos": [],
				"lugar": lugar,
				"causas": [f["id"]],
				"dados": {"importancia": 0.12, "noticia_de": f["id"], "mudancas": ops},
			})
			if nid == "":
				continue
			novos.append(nid)
			for p in quem:
				var r := Reacoes.ao_saber(u, p, f, nid)
				if r != "":
					novos.append(r)
	return novos


static func _lugar_de_origem(u: Universo, f: Dictionary) -> String:
	if f["lugar"] != "":
		return f["lugar"]
	for s in f["sujeitos"]:
		var l: String = u.estado(s)["local"]
		if l != "":
			return l
	return ""


## Quantos dias a notícia leva de um lugar a outro (o mapa da Parte 4 refina isso).
static func _atraso(u: Universo, de: String, para: String) -> int:
	if de == para:
		return DIAS_MESMO_LUGAR
	var d := u.dias_de_viagem(de, para)
	if d >= 0:
		return d + DIAS_MESMO_LUGAR
	return DIAS_OUTRO_LUGAR


## Reconstrói quem já recebeu cada notícia a partir dos fatos de notícia.
static func reconstruir(u: Universo) -> void:
	var estado_noticias := {}
	for f in u.fatos.todos():
		if f["canon"] and f["tipo"] in ["notícia", "rumor"]:
			var de: String = f["dados"].get("noticia_de", "")
			if not estado_noticias.has(de):
				estado_noticias[de] = {"lugares": {}}
			estado_noticias[de]["lugares"][f["lugar"]] = true
	u.extras["noticias"] = estado_noticias
