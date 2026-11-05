class_name Sugestoes
extends RefCounted
## Sugestões de campos para fichas. São SÓ sugestões: o tipo da entidade e os
## campos são sempre texto livre, e você pode apagar, renomear ou criar qualquer campo.

const _GRUPOS := [
	{
		"palavras": ["pessoa", "personagem", "humano", "heroi", "vilao", "mago", "guerreiro",
			"rei", "rainha", "principe", "princesa", "soldado", "crianca", "elfo", "anao"],
		"campos": ["aparência", "idade", "personalidade", "medos", "fraquezas", "desejos",
			"ambições", "gostos", "desgostos", "valores", "habilidades", "segredos", "história"],
	},
	{
		"palavras": ["lugar", "cidade", "vila", "reino", "planeta", "continente", "regiao",
			"floresta", "montanha", "ruina", "castelo", "templo", "ilha", "mundo", "bairro",
			"aldeia", "porto", "torre", "fortaleza", "capital", "povoado", "lago", "caverna", "deserto",
			"pantano", "estalagem", "taverna", "provincia", "condado", "galaxia", "estrela"],
		"campos": ["descrição", "clima", "população", "quem governa", "recursos", "perigos",
			"lendas", "história"],
	},
	{
		"palavras": ["magia", "poder", "feitico", "tecnica", "habilidade", "dom", "maldicao",
			"bencao", "ritual"],
		"campos": ["efeito", "custo", "limite", "alcance", "duração", "quem pode usar",
			"como se aprende", "riscos", "origem"],
	},
	{
		"palavras": ["objeto", "arma", "artefato", "item", "reliquia", "espada", "livro",
			"nave", "maquina", "joia"],
		"campos": ["descrição", "quem fez", "poder", "raridade", "dono atual", "história"],
	},
	{
		"palavras": ["faccao", "nacao", "guilda", "ordem", "seita", "familia",
			"cla", "imperio", "republica", "igreja", "escola", "empresa", "associacao"],
		"campos": ["forma de governo", "líder", "objetivos", "aliados", "inimigos", "riqueza",
			"força", "leis", "história"],
	},
	{
		"palavras": ["criatura", "monstro", "animal", "raca", "especie", "povo", "dragao",
			"besta", "planta", "fera"],
		"campos": ["aparência", "tamanho", "habitat", "comportamento", "inteligência",
			"perigo", "expectativa de vida", "cultura"],
	},
	{
		"palavras": ["entidade", "deus", "deusa", "divindade", "demonio", "espirito", "ser"],
		"campos": ["natureza", "vontade", "como age no mundo", "o que oferece", "o que cobra",
			"seguidores"],
	},
	{
		"palavras": ["exercito", "frota", "legiao", "tropa", "batalhao", "horda", "esquadra", "esquadrilha", "armada", "milicia",
			"regimento", "cavalaria", "infantaria", "hoste"],
		"campos": ["tamanho", "tipo de força", "pertence a", "comandante", "moral", "pontos fortes", "fraquezas"],
	},
]


const _NOMES := ["pessoa", "lugar", "poder", "objeto", "faccao", "criatura", "entidade", "forca"]


## Categoria aproximada de um tipo livre, só para as heurísticas internas
## (ex.: saber que "cidade flutuante" é um lugar). Nunca é mostrada como campo fixo.
## Devolve "" quando não reconhece.
static var _cache_categoria: Dictionary = {}


static func categoria(tipo: String) -> String:
	if _cache_categoria.has(tipo):
		return _cache_categoria[tipo]
	var c := _categoria(tipo)
	if _cache_categoria.size() > 2000:
		_cache_categoria.clear()
	_cache_categoria[tipo] = c
	return c


static func _categoria(tipo: String) -> String:
	var palavras := TextUtil.palavras(TextUtil.normalizar(tipo))
	# Primeiro, casamento exato; depois, aproximado.
	for exato in [true, false]:
		for p in palavras:
			for i in _GRUPOS.size():
				for chave in _GRUPOS[i]["palavras"]:
					if p == chave or (not exato and ((p.length() > 3 and p.begins_with(chave)) or TextUtil.distancia(p, chave) <= TextUtil.tolerancia(chave.length()))):
						return _NOMES[i]
	return ""


## Sugere campos para um tipo escrito livremente. Pode combinar grupos
## ("mago dragão" sugere campos de pessoa e de criatura).
static func campos_para(tipo: String) -> Array:
	var palavras := TextUtil.palavras(TextUtil.normalizar(tipo))
	var sugeridos: Array = []
	for g in _GRUPOS:
		var casou := false
		for p in palavras:
			for chave in g["palavras"]:
				if p == chave or (p.length() > 3 and p.begins_with(chave)) or TextUtil.distancia(p, chave) <= TextUtil.tolerancia(chave.length()):
					casou = true
					break
			if casou:
				break
		if casou:
			for c in g["campos"]:
				if not sugeridos.has(c):
					sugeridos.append(c)
	if sugeridos.is_empty():
		sugeridos = ["descrição", "origem", "história"]
	return sugeridos
