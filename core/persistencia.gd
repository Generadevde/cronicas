class_name Persistencia
extends RefCounted
## Ajustes depois de carregar do JSON (o JSON guarda todo número como decimal).


static func normalizar_numeros(u: Universo) -> void:
	_datas(u.entidades)
	_datas(u.extras)
	_datas(u.propostas)
	u.relogio = DataMundo.copiar(u.relogio)


## Converte qualquer {ano, dia} encontrado (em qualquer profundidade) para inteiros.
static func _datas(v) -> void:
	if v is Dictionary:
		if v.has("ano") and v.has("dia") and v.size() <= 3:
			v["ano"] = int(v["ano"])
			v["dia"] = int(v["dia"])
		for k in v:
			_datas(v[k])
	elif v is Array:
		for x in v:
			_datas(x)
