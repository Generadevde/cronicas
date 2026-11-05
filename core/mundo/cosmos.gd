class_name Cosmos
extends RefCounted
## O Criador do Universo: leis do universo, eras e acontecimentos antigos.
## Leis ficam em extras["leis"]; eras em extras["eras"]. Toda mudança vira fato.
## (As regras escritas em frases, que agem sozinhas, são da Parte 5.)


static func leis(u: Universo) -> Dictionary:
	var l: Dictionary = u.extra("leis", {})
	for k in {"magia": 0.5, "tecnologia": 0.3, "texto": "", "possivel": "", "impossivel": ""}.keys():
		if not l.has(k):
			l[k] = {"magia": 0.5, "tecnologia": 0.3, "texto": "", "possivel": "", "impossivel": ""}[k]
	return l


static func definir_leis(u: Universo, novas: Dictionary) -> void:
	var l := leis(u)
	var mudou: Array = []
	for k in novas:
		if l.get(k) != novas[k]:
			l[k] = novas[k]
			mudou.append(k)
	if mudou.is_empty():
		return
	var partes: Array = []
	if mudou.has("magia"):
		partes.append("magia: %s" % palavra_nivel(float(l["magia"])))
	if mudou.has("tecnologia"):
		partes.append("tecnologia: %s" % palavra_nivel(float(l["tecnologia"])))
	for k in ["texto", "possivel", "impossivel"]:
		if mudou.has(k):
			partes.append({"texto": "leis", "possivel": "o que é possível", "impossivel": "o que é impossível"}[k] + " reescrito")
	u.fatos.registrar({
		"tipo": "leis do universo",
		"descricao": "O autor mudou as leis do universo (%s)." % ", ".join(partes),
		"data": DataMundo.copiar(u.relogio),
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "leis"},
		"dados": {"importancia": 0.3, "leis": l.duplicate()},
	})
	u.marcar_mudanca()


static func palavra_nivel(v: float) -> String:
	if v < 0.05:
		return "nenhuma"
	if v < 0.3:
		return "rara"
	if v < 0.6:
		return "presente"
	if v < 0.85:
		return "comum"
	return "por toda parte"


# ---------------------------------------------------------------- eras

static func eras(u: Universo) -> Array:
	var e: Array = u.extra("eras", [])
	e.sort_custom(func(a, b): return int(a["inicio"]) < int(b["inicio"]))
	return e


## Cria uma era. 'fim' = -1 quando ainda não terminou (é a era atual).
static func criar_era(u: Universo, nome: String, inicio: int, fim: int = -1, descricao: String = "") -> String:
	nome = nome.strip_edges()
	if nome == "":
		return ""
	var fid := u.fatos.registrar({
		"tipo": "era",
		"descricao": "Começou a %s." % nome,
		"data": DataMundo.criar(inicio, 1),
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "eras"},
		"dados": {"importancia": 0.8, "era": nome, "texto": descricao},
	})
	u.extra("eras", []).append({"nome": nome, "inicio": inicio, "fim": fim, "descricao": descricao, "fato": fid})
	u.marcar_mudanca()
	return fid


static func remover_era(u: Universo, fid: String) -> void:
	var lista: Array = u.extra("eras", [])
	for i in range(lista.size() - 1, -1, -1):
		if lista[i]["fato"] == fid:
			lista.remove_at(i)
	u.desfazer_fato(fid)


## A era de um ano ({} se nenhuma).
static func era_de(u: Universo, ano: int) -> Dictionary:
	var achada := {}
	for e in eras(u):
		if int(e["inicio"]) <= ano and (int(e["fim"]) < 0 or ano <= int(e["fim"])):
			achada = e
	return achada


## Um acontecimento antigo escrito pelo autor (vira lenda na linha do tempo).
static func acontecimento_antigo(u: Universo, ano: int, texto: String, lugar: String = "") -> String:
	texto = texto.strip_edges()
	if texto == "":
		return ""
	var desc := texto.substr(0, 1).to_upper() + texto.substr(1)
	if not desc.ends_with("."):
		desc += "."
	var sujeitos: Array = []
	for m in Ligador.new(u).encontrar(texto):
		if not sujeitos.has(m["entidade"]):
			sujeitos.append(m["entidade"])
	var era := era_de(u, ano)
	var fid := u.fatos.registrar({
		"tipo": "lenda",
		"descricao": desc,
		"sujeitos": sujeitos,
		"lugar": lugar,
		"data": DataMundo.criar(ano, 1),
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "eras"},
		"dados": {"importancia": 0.6, "era": era.get("nome", "")},
	})
	u.marcar_mudanca()
	return fid
