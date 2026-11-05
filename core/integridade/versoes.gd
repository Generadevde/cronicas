class_name Versoes
extends RefCounted
## Versões do universo: fotos do mundo em momentos importantes, guardadas ao lado do
## universo (<pasta>/<id>/versoes/). Voltar a uma versão não apaga nada: a versão de
## agora vira mais uma foto antes da troca. Os ramos do laboratório também moram na
## estante, como universos com a marca de ramo.


static func _pasta(b: Biblioteca, uid: String) -> String:
	return "%s/%s/versoes" % [b.pasta, uid]


static func salvar(b: Biblioteca, u: Universo, nome: String) -> String:
	var p := _pasta(b, u.id)
	DirAccess.make_dir_recursive_absolute(p)
	var arq := "%d_%s.json" % [int(Time.get_unix_time_from_system() * 1000) % 1000000000000, Ids.novo("v").substr(2, 6)]
	var d := u.para_dicionario()
	d["versao"] = {"nome": nome, "data_do_mundo": DataMundo.texto(u.relogio), "fatos": u.fatos.quantidade(), "salva_em": Time.get_datetime_string_from_system()}
	var f := FileAccess.open(p + "/" + arq, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(d))
	f.close()
	return arq


## [{arquivo, nome, data_do_mundo, fatos, salva_em}], da mais nova para a mais antiga.
static func listar(b: Biblioteca, uid: String) -> Array:
	var r: Array = []
	var dir := DirAccess.open(_pasta(b, uid))
	if dir == null:
		return r
	for arq in dir.get_files():
		if not arq.ends_with(".json"):
			continue
		var d := Biblioteca._ler_json(_pasta(b, uid) + "/" + arq)
		var v: Dictionary = d.get("versao", {})
		r.append({"arquivo": arq, "nome": str(v.get("nome", arq)), "data_do_mundo": str(v.get("data_do_mundo", "")), "fatos": int(v.get("fatos", 0)), "salva_em": str(v.get("salva_em", ""))})
	r.sort_custom(func(a, b2): return a["arquivo"] > b2["arquivo"])
	return r


## Volta a uma versão: devolve o universo daquela foto (com o mesmo id). A situação de
## agora é guardada antes, como mais uma versão.
static func voltar(b: Biblioteca, atual: Universo, arquivo: String) -> Universo:
	var d := Biblioteca._ler_json(_pasta(b, atual.id) + "/" + arquivo)
	if d.is_empty():
		return null
	salvar(b, atual, "antes de voltar para \"%s\"" % str(d.get("versao", {}).get("nome", arquivo)))
	d.erase("versao")
	d["id"] = atual.id
	var u := Universo.de_dicionario(d)
	b.salvar(u)
	return u


## Ramos guardados na estante que nasceram deste universo (ou da mesma raiz).
static func ramos(b: Biblioteca, uid: String) -> Array:
	var r: Array = []
	for item in b.listar():
		var d := Biblioteca._ler_json("%s/%s/universo.json" % [b.pasta, item["id"]])
		var ramo: Dictionary = d.get("extras", {}).get("ramo", {})
		if not ramo.is_empty() and (str(ramo.get("raiz", "")) == uid or str(ramo.get("pai", "")) == uid):
			r.append({"id": item["id"], "nome": str(ramo.get("nome", "")), "pai": str(ramo.get("pai", "")), "desde": int(ramo.get("desde", 0))})
	return r
