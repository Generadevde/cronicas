class_name Ids
extends RefCounted
## Gera identificadores únicos e legíveis, como "ent_k3x9q2m1".

const _ALFABETO := "abcdefghijkmnopqrstuvwxyz23456789"


static func novo(prefixo: String) -> String:
	var s := ""
	for i in 8:
		s += _ALFABETO[randi() % _ALFABETO.length()]
	return "%s_%s" % [prefixo, s]
