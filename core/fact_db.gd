class_name BancoDeFatos
extends RefCounted
## O banco de fatos é a VERDADE do universo.
## Tudo o que acontece vira um fato com: o quê, quem, onde, quando,
## de onde veio (origem) e quais fatos o causaram (causas).
## A IA e a interface nunca são donas da verdade: só leem e escrevem aqui.

## Origens possíveis de um fato.
const ORIGEM_AUTOR := "autor"          ## você decidiu (raiz válida, não precisa de causa)
const ORIGEM_CAPITULO := "capitulo"    ## veio de um capítulo escrito (raiz válida)
const ORIGEM_SIMULACAO := "simulacao"  ## o mundo gerou: PRECISA ter causa
const ORIGEM_SISTEMA := "sistema"      ## manutenção interna (ex.: correções)

var _fatos: Dictionary = {}            ## id -> fato
var _consequencias: Dictionary = {}    ## id da causa -> Array de ids que ela causou
var _por_entidade: Dictionary = {}     ## id da entidade -> Array de ids de fatos
var _seq := 0
var _todos_cache: Array = []
var _todos_sujo := true


## Registra um fato e devolve o id dele.
## Campos aceitos: tipo, descricao, sujeitos, lugar, data, causas, origem, canon, dados.
## Causas que não existem são recusadas (devolve "").
func registrar(fato: Dictionary) -> String:
	var causas: Array = fato.get("causas", [])
	for c in causas:
		if not _fatos.has(c):
			push_warning("Fato recusado: causa inexistente '%s'" % c)
			return ""
	_seq += 1
	var id: String = fato.get("id", "")
	if id == "" or _fatos.has(id):
		id = Ids.novo("fato")
	var novo := {
		"id": id,
		"seq": _seq,
		"tipo": str(fato.get("tipo", "acontecimento")),
		"descricao": str(fato.get("descricao", "")),
		"sujeitos": Array(fato.get("sujeitos", [])).duplicate(),
		"lugar": str(fato.get("lugar", "")),
		"data": DataMundo.copiar(fato.get("data", DataMundo.criar())),
		"causas": causas.duplicate(),
		"origem": Dictionary(fato.get("origem", {"tipo": ORIGEM_AUTOR, "ref": ""})).duplicate(),
		"canon": bool(fato.get("canon", true)),
		"dados": Dictionary(fato.get("dados", {})).duplicate(true),
	}
	_fatos[id] = novo
	_todos_sujo = true
	_indexar(novo)
	return id


func obter(id: String) -> Dictionary:
	return _fatos.get(id, {})


func existe(id: String) -> bool:
	return _fatos.has(id)


func quantidade() -> int:
	return _fatos.size()


## Todos os fatos em ordem de registro.
func todos() -> Array:
	if _todos_sujo:
		_todos_cache = _fatos.values()
		_todos_cache.sort_custom(func(a, b): return a["seq"] < b["seq"])
		_todos_sujo = false
	return _todos_cache.duplicate()


## Fatos que envolvem uma entidade (como sujeito ou como lugar), em ordem.
func sobre(entidade_id: String) -> Array:
	var lista: Array = []
	for id in _por_entidade.get(entidade_id, []):
		lista.append(_fatos[id])
	return lista  # o índice já está na ordem de registro


## Ids dos fatos de uma entidade, na ordem de registro (sem copiar: só para ler).
func ids_sobre(entidade_id: String) -> Array:
	return _por_entidade.get(entidade_id, [])


## Fatos que este fato causou diretamente.
func consequencias(id: String) -> Array:
	var lista: Array = []
	for c in _consequencias.get(id, []):
		lista.append(_fatos[c])
	return lista


## Cadeia de causas (até 'profundidade' níveis), da mais próxima à mais distante.
func cadeia_de_causas(id: String, profundidade: int = 10) -> Array:
	var resultado: Array = []
	var vistos := {}
	var fila: Array = [[id, 0]]
	while not fila.is_empty():
		var item: Array = fila.pop_front()
		var fato: Dictionary = _fatos.get(item[0], {})
		if fato.is_empty() or item[1] >= profundidade:
			continue
		for c in fato["causas"]:
			if vistos.has(c) or not _fatos.has(c):
				continue
			vistos[c] = true
			resultado.append(_fatos[c])
			fila.append([c, item[1] + 1])
	return resultado


func _indexar(fato: Dictionary) -> void:
	for c in fato["causas"]:
		if not _consequencias.has(c):
			_consequencias[c] = []
		_consequencias[c].append(fato["id"])
	var envolvidos := {}
	for e in fato["sujeitos"]:
		envolvidos[e] = true
	if fato["lugar"] != "":
		envolvidos[fato["lugar"]] = true
	for e in envolvidos:
		if not _por_entidade.has(e):
			_por_entidade[e] = []
		var lista: Array = _por_entidade[e]
		if lista.is_empty() or lista.back() != fato["id"]:
			lista.append(fato["id"])


func para_dicionario() -> Dictionary:
	return {"seq": _seq, "fatos": todos()}


func carregar_dicionario(d: Dictionary) -> void:
	_fatos.clear()
	_consequencias.clear()
	_por_entidade.clear()
	_seq = int(d.get("seq", 0))
	for f in d.get("fatos", []):
		var fato: Dictionary = f
		fato["seq"] = int(fato.get("seq", 0))
		fato["data"] = DataMundo.copiar(fato.get("data", {}))
		_fatos[fato["id"]] = fato
	_todos_sujo = true
	# Indexa depois de carregar tudo (causas podem vir antes ou depois na lista).
	for fato in todos():
		_indexar(fato)


## Tira fatos do banco (só o gerenciador de memória usa, depois de guardá-los no arquivo).
func remover_varios(ids: Array) -> void:
	var sai := {}
	for id in ids:
		sai[id] = true
	for id in ids:
		var f: Dictionary = _fatos.get(id, {})
		if f.is_empty():
			continue
		for c in f["causas"]:
			if _consequencias.has(c):
				_consequencias[c] = Array(_consequencias[c]).filter(func(x): return not sai.has(x))
		var envolvidos: Array = Array(f["sujeitos"]) + ([f["lugar"]] if f["lugar"] != "" else [])
		for e in envolvidos:
			if _por_entidade.has(e):
				_por_entidade[e] = Array(_por_entidade[e]).filter(func(x): return not sai.has(x))
		_consequencias.erase(id)
		_fatos.erase(id)
	_todos_sujo = true


## Uso interno do auditor e dos testes: insere sem validar (para simular dados corrompidos).
func _inserir_cru(fato: Dictionary) -> void:
	_seq += 1
	fato["seq"] = _seq
	_fatos[fato["id"]] = fato
	_todos_sujo = true
	_indexar(fato)
