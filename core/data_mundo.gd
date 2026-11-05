class_name DataMundo
extends RefCounted
## Datas dentro do universo. Por enquanto: ano e dia do ano (1 a 360).
## O calendário próprio de cada universo (nomes de meses, eras) vem depois.

const DIAS_POR_ANO := 360


static func criar(ano: int = 1, dia: int = 1) -> Dictionary:
	return {"ano": ano, "dia": clampi(dia, 1, DIAS_POR_ANO)}


## Número único para comparar e ordenar datas.
static func ordem(data: Dictionary) -> int:
	return int(data.get("ano", 0)) * DIAS_POR_ANO + int(data.get("dia", 1))


static func texto(data: Dictionary) -> String:
	if data.is_empty():
		return "sem data"
	return "Ano %d, dia %d" % [int(data.get("ano", 0)), int(data.get("dia", 1))]


static func copiar(data: Dictionary) -> Dictionary:
	return criar(int(data.get("ano", 1)), int(data.get("dia", 1)))
