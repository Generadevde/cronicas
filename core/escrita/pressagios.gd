class_name Pressagios
extends RefCounted
## Avisos antes de momentos grandes: os personagens que o autor escreveu são livres
## (podem até morrer), mas o Livro avisa antes. Cada aviso tem um motivo, em palavras,
## e pode ser dispensado ("deixar seguir").

const RAIVAS := ["odio", "raiva", "rancor", "humilhacao"]


static func _do_autor(u: Universo, eid: String) -> bool:
	return u.valor_campo(eid, "descrição") != ""


static func _n(u: Universo, eid: String) -> String:
	return str(u.entidade(eid).get("nome", "?"))


## [{chave, texto, quem (o personagem em risco), outro}] — os mais graves primeiro.
static func listar(u: Universo, limite: int = 2) -> Array:
	var vistos: Dictionary = u.extra("pressagios_vistos", {})
	var r: Array = []
	var pessoas: Array = u.entidades_ativas().filter(func(e): return e["tipo"] == "pessoa" and Estado.vivo(u, e["id"]))
	var autores: Array = pessoas.filter(func(e): return _do_autor(u, e["id"]))
	for a in autores:
		var p: String = a["id"]
		var onde := str(u.estado(p).get("local", ""))
		if Estado.saude_atual(u, p) < 0.45:
			r.append({"chave": "saude:" + p, "peso": 3.0, "quem": p, "outro": "",
				"texto": "%s está muito mal e pode não resistir. Se a história precisa dele, escreva a cura; se não, o mundo segue." % _n(u, p)})
		for x in pessoas:
			var o: String = x["id"]
			if o == p:
				continue
			var raiva := maxf(Estado.emocao_por(u, o, p, RAIVAS), Estado.valor_relacao(u, o, p, "raiva"))
			var jurou: bool = raiva >= 0.7 or Estado.objetivos_ativos(u, o).any(func(ob): return str(ob["alvo"]) == p and str(ob["tipo"]) in ["vingar", "vinganca", "matar", "derrotar"])
			if raiva < 0.45 and not jurou:
				continue
			var onde_o := str(u.estado(o).get("local", ""))
			var viagem: Dictionary = u.estado(o).get("viagem", {})
			if onde != "" and onde_o == onde:
				r.append({"chave": "perto:%s:%s:%s" % [o, p, onde], "peso": 2.5, "quem": p, "outro": o,
					"texto": "%s e %s estão em %s. %s %s: os dois devem se cruzar em breve." % [_n(u, o), _n(u, p), _n(u, onde), _n(u, o),
						"jurou vingança" if jurou else "carrega raiva"]})
			elif onde != "" and str(viagem.get("para", "")) == onde:
				r.append({"chave": "caminho:%s:%s:%s" % [o, p, onde], "peso": 2.0, "quem": p, "outro": o,
					"texto": "%s está a caminho de %s, onde %s está. %s." % [_n(u, o), _n(u, onde), _n(u, p), "Jurou vingança" if jurou else "Não vai em paz"]})
			elif jurou and _do_autor(u, o):
				r.append({"chave": "jura:%s:%s" % [o, p], "peso": 1.0, "quem": p, "outro": o,
					"texto": "%s jurou vingança contra %s e ainda não desistiu. Um dia os dois se encontram." % [_n(u, o), _n(u, p)]})
	r = r.filter(func(x): return not vistos.has(x["chave"]))
	r.sort_custom(func(a, b): return float(a["peso"]) > float(b["peso"]))
	return r.slice(0, limite)


static func dispensar(u: Universo, chave: String) -> void:
	u.extra("pressagios_vistos", {})[chave] = true
	u.marcar_mudanca()
