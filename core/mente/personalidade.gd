class_name Personalidade
extends RefCounted
## Traços de personalidade (0 a 1) lidos do que o autor escreveu na ficha.
## Ninguém escolhe de lista: o programa procura pistas no texto livre
## ("rancoroso", "gentil", "esquentado"...). O que não aparece fica perto do
## meio, com uma pequena variação própria de cada personagem (sempre a mesma).

const TRACOS := ["coragem", "rancor", "ambicao", "empatia", "impulsividade", "curiosidade",
	"lealdade", "orgulho", "prudencia", "sociabilidade"]

const NOMES := {"coragem": "coragem", "rancor": "rancor", "ambicao": "ambição", "empatia": "empatia",
	"impulsividade": "impulsividade", "curiosidade": "curiosidade", "lealdade": "lealdade",
	"orgulho": "orgulho", "prudencia": "prudência", "sociabilidade": "sociabilidade"}

## Pistas no texto (início de palavra, sem acento) → efeito nos traços.
const PISTAS := {
	"corajos": {"coragem": 0.35}, "brav": {"coragem": 0.25}, "destemid": {"coragem": 0.4}, "ousad": {"coragem": 0.25, "impulsividade": 0.1},
	"heroic": {"coragem": 0.3, "empatia": 0.1}, "covard": {"coragem": -0.4}, "medros": {"coragem": -0.3}, "timid": {"coragem": -0.2, "sociabilidade": -0.2},
	"rancoros": {"rancor": 0.45}, "vingativ": {"rancor": 0.4}, "ressentid": {"rancor": 0.3}, "magoad": {"rancor": 0.15},
	"perdoa": {"rancor": -0.35, "empatia": 0.1}, "clement": {"rancor": -0.3, "empatia": 0.2},
	"ambicios": {"ambicao": 0.4}, "ganancios": {"ambicao": 0.4, "empatia": -0.15}, "humilde": {"ambicao": -0.25, "orgulho": -0.3},
	"gentil": {"empatia": 0.3}, "bondos": {"empatia": 0.35}, "compassiv": {"empatia": 0.35}, "carinhos": {"empatia": 0.3},
	"generos": {"empatia": 0.25}, "cruel": {"empatia": -0.45}, "frio": {"empatia": -0.2, "impulsividade": -0.2},
	"insensivel": {"empatia": -0.3}, "egoist": {"empatia": -0.3}, "sadic": {"empatia": -0.5},
	"impulsiv": {"impulsividade": 0.4, "prudencia": -0.2}, "esquentad": {"impulsividade": 0.4}, "explosiv": {"impulsividade": 0.4},
	"irritad": {"impulsividade": 0.25}, "precipit": {"impulsividade": 0.3, "prudencia": -0.2},
	"calm": {"impulsividade": -0.3}, "pacient": {"impulsividade": -0.3, "prudencia": 0.15}, "calculist": {"impulsividade": -0.3, "prudencia": 0.3},
	"curios": {"curiosidade": 0.4}, "estudios": {"curiosidade": 0.3}, "sabio": {"curiosidade": 0.25, "prudencia": 0.2}, "inventiv": {"curiosidade": 0.35},
	"leal": {"lealdade": 0.4}, "fiel": {"lealdade": 0.35}, "devot": {"lealdade": 0.3}, "traidor": {"lealdade": -0.45}, "traicoeir": {"lealdade": -0.45},
	"mentiros": {"lealdade": -0.25}, "falso": {"lealdade": -0.25},
	"orgulhos": {"orgulho": 0.4}, "arrogant": {"orgulho": 0.45, "empatia": -0.1}, "vaidos": {"orgulho": 0.3}, "soberb": {"orgulho": 0.4}, "modest": {"orgulho": -0.3},
	"prudent": {"prudencia": 0.4}, "cautelos": {"prudencia": 0.35}, "estrateg": {"prudencia": 0.3}, "imprudent": {"prudencia": -0.35},
	"social": {"sociabilidade": 0.3}, "extrovert": {"sociabilidade": 0.4}, "carismatic": {"sociabilidade": 0.4}, "alegre": {"sociabilidade": 0.3},
	"amigavel": {"sociabilidade": 0.3, "empatia": 0.1}, "solitari": {"sociabilidade": -0.35}, "reservad": {"sociabilidade": -0.25},
	"introvert": {"sociabilidade": -0.3}, "calad": {"sociabilidade": -0.2},
}


## Calcula os traços a partir da ficha. Sempre dá o mesmo resultado para a mesma ficha.
static func derivar(u: Universo, eid: String) -> Dictionary:
	var e := u.entidade(eid)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(eid + str(u.semente()))
	var t := {}
	for traco in TRACOS:
		t[traco] = clampf(0.5 + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	var texto := str(e.get("tipo", ""))
	for c in e.get("campos", []):
		texto += " " + str(c["valor"])
	for palavra in TextUtil.palavras(TextUtil.normalizar(texto)):
		for pista in PISTAS:
			if palavra.begins_with(pista):
				for k in PISTAS[pista]:
					t[k] = clampf(float(t[k]) + float(PISTAS[pista][k]), 0.0, 1.0)
	var autor: Dictionary = u.estado(eid).get("tracos_autor", {})
	for k in autor:
		t[k] = clampf(float(autor[k]), 0.0, 1.0)
	return t


## Traços atuais (os da ficha mais o que a vida mudou).
static var _cache_derivar: Dictionary = {}


static func tracos(u: Universo, eid: String) -> Dictionary:
	var e := u.entidade(eid)
	var chave := "%s|%s|%d|%d|%d" % [u.id, eid, hash(e.get("campos", [])), hash(e.get("tipo", "")), hash(u.estado(eid).get("tracos_autor", {}))]
	if not _cache_derivar.has(chave):
		if _cache_derivar.size() > 5000:
			_cache_derivar.clear()
		_cache_derivar[chave] = derivar(u, eid)
	var base: Dictionary = _cache_derivar[chave].duplicate()
	var vida: Dictionary = u.estado(eid)["tracos"]
	for k in vida:
		base[k] = clampf(float(base.get(k, 0.5)) + float(vida[k]) - 0.5, 0.0, 1.0)
	return base


## Descrição curta, para a wiki: "rancoroso, corajoso, pouco paciente".
static func resumo(t: Dictionary) -> String:
	var altos := {"coragem": "corajoso", "rancor": "rancoroso", "ambicao": "ambicioso", "empatia": "empático",
		"impulsividade": "impulsivo", "curiosidade": "curioso", "lealdade": "leal", "orgulho": "orgulhoso",
		"prudencia": "prudente", "sociabilidade": "sociável"}
	var baixos := {"coragem": "medroso", "rancor": "perdoa fácil", "ambicao": "sem ambição", "empatia": "frio",
		"impulsividade": "calmo", "curiosidade": "pouco curioso", "lealdade": "pouco leal", "orgulho": "humilde",
		"prudencia": "imprudente", "sociabilidade": "reservado"}
	var partes: Array = []
	for k in TRACOS:
		var v: float = float(t.get(k, 0.5))
		if v >= 0.72:
			partes.append(altos[k])
		elif v <= 0.28:
			partes.append(baixos[k])
	return ", ".join(partes) if not partes.is_empty() else "equilibrado"
