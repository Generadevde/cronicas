class_name Continuidade
extends RefCounted
## Confere se o texto combina com o que o mundo já sabe. Só AVISA: o autor decide
## se corrige o texto, se vira lenda/rascunho ou se muda o passado.

const PALAVRAS_DE_MEMORIA := ["lembr", "memoria", "tumulo", "tumba", "fantasma", "espirito", "falecid",
	"morto", "morta", "morreu", "luto", "saudade", "sonhou", "sonho", "enterr", "cadaver", "corpo de"]


## Avisos de um capítulo: [{tipo, mensagem, entidade}]
static func verificar_capitulo(u: Universo, cid: String) -> Array:
	var cap := u.capitulo(cid)
	if cap.is_empty() or not cap["canon"]:
		return []
	var avisos: Array = []
	var ja := {}
	var lig := Ligador.new(u)
	var data_cap := DataMundo.ordem(cap["data"])
	for frase in Extrator.frases(cap["texto"]):
		var norm := TextUtil.normalizar(frase)
		var memoria := PALAVRAS_DE_MEMORIA.any(func(p): return norm.contains(p))
		for m in lig.encontrar(frase):
			var eid: String = m["entidade"]
			var est := u.estado(eid)
			var nome: String = u.entidade(eid)["nome"]
			if not est["vivo"] and not est["morte"].is_empty() and not memoria:
				var fato_morte: Dictionary = u.fatos.obter(est["morte"].get("fato", ""))
				var mesmo_capitulo: bool = fato_morte.get("origem", {}).get("ref", "") == cid
				if DataMundo.ordem(est["morte"]["data"]) < data_cap and not mesmo_capitulo and not ja.has("morto" + eid):
					ja["morto" + eid] = true
					avisos.append({"tipo": "morto", "entidade": eid,
						"mensagem": "%s aparece aqui (%s), mas morreu em %s. Lembrança, fantasma ou erro?" % [
							nome, DataMundo.texto(cap["data"]), DataMundo.texto(est["morte"]["data"])]})
			if not est["nascimento"].is_empty() and DataMundo.ordem(est["nascimento"]) > data_cap and not ja.has("nasc" + eid):
				ja["nasc" + eid] = true
				avisos.append({"tipo": "antes_de_nascer", "entidade": eid,
					"mensagem": "%s aparece em %s, antes de nascer (%s)." % [nome, DataMundo.texto(cap["data"]), DataMundo.texto(est["nascimento"])]})
	# Mesmo personagem em dois lugares no mesmo dia (em capítulos diferentes).
	for f in u.fatos.todos():
		if f["origem"].get("ref", "") != cid or f["lugar"] == "":
			continue
		for outro in u.fatos.todos():
			if outro["id"] == f["id"] or outro["lugar"] == "" or outro["lugar"] == f["lugar"]:
				continue
			if DataMundo.ordem(outro["data"]) != DataMundo.ordem(f["data"]):
				continue
			for e in f["sujeitos"]:
				if outro["sujeitos"].has(e) and not ja.has("lugar" + e + outro["id"]):
					ja["lugar" + e + outro["id"]] = true
					avisos.append({"tipo": "dois_lugares", "entidade": e,
						"mensagem": "%s está em %s e em %s no mesmo dia (%s)." % [u.entidade(e)["nome"],
							u.entidade(f["lugar"]).get("nome", "?"), u.entidade(outro["lugar"]).get("nome", "?"), DataMundo.texto(f["data"])]})
	return avisos
