class_name Reputacao
extends RefCounted
## Reputação relativa: não existe um juízo universal. Cada grupo (uma sociedade ou
## um lugar) julga alguém pelo que SABE que essa pessoa fez e pelos SEUS valores
## (campos "admiram" e "desprezam" da sociedade). O mesmo general pode ser herói
## para uns e carniceiro para outros. A verdade continua no banco de fatos.

## Atos: peso comum (o que quase todo mundo acha) e as palavras que a cultura pode admirar ou desprezar.
const ATOS := {
	"vitoria": [0.25, ["forca", "coragem", "guerra", "vitoria", "honra", "luta", "combate"]],
	"morte_por": [-0.45, ["guerra", "sangue", "violencia", "forca", "vinganca"]],
	"traicao": [-0.7, ["astucia", "traicao", "ambicao"]],
	"ensino": [0.2, ["sabedoria", "conhecimento", "ensino", "tradicao"]],
	"casamento": [0.08, ["familia", "amor", "tradicao"]],
	"perdão": [0.3, ["piedade", "perdao", "misericordia", "paz"]],
	"fuga": [-0.2, ["covardia", "prudencia"]],
	"usar_poder": [0.0, ["magia", "poder", "feiticaria"]],
	"golpe vitorioso": [-0.3, ["ambicao", "poder", "astucia", "forca"]],
	"golpe fracassado": [-0.4, ["ambicao", "traicao"]],
	"queda do governo": [0.3, ["liberdade", "coragem", "revolucao", "povo"]],
	"revolta esmagada": [-0.2, ["ordem", "forca", "lei"]],
	"sucessão": [0.1, ["tradicao", "lealdade", "familia"]],
	"vingança cumprida": [0.0, ["vinganca", "honra"]],
	"profeta": [0.2, ["fe", "religiao", "deus", "profecia"]],
	"heresia": [-0.4, ["heresia", "liberdade"]],
	"aprendizado": [0.1, ["sabedoria", "conhecimento", "disciplina"]],
}

static var _cache: Dictionary = {}


## Opinião (-1 a 1) do grupo sobre alguém. 0 = indiferente ou não sabe.
static func opiniao(u: Universo, grupo: String, alvo: String) -> float:
	var r := detalhe(u, grupo, alvo)
	return float(r["valor"])


## {valor, conhecidos, mortes}: quantos atos o grupo conhece e quantas mortes.
static func detalhe(u: Universo, grupo: String, alvo: String) -> Dictionary:
	var chave := "%s|%d|%d|%s|%s" % [u.id, u.versao, u.fatos.quantidade(), grupo, alvo]
	if _cache.has(chave):
		return _cache[chave]
	if _cache.size() > 20000:
		_cache.clear()
	var r := _calcular(u, grupo, alvo)
	_cache[chave] = r
	return r


static func _valores(u: Universo, grupo: String) -> Dictionary:
	var sid := grupo if Sociedades.eh_sociedade(u, grupo) else Sociedades.de_lugar(u, grupo)
	var adm := TextUtil.normalizar(Sociedades._campo(u, grupo, ["admir", "valor", "honram"]) + " " + (Sociedades._campo(u, sid, ["admir", "valor", "honram"]) if sid != "" else ""))
	var desp := TextUtil.normalizar(Sociedades._campo(u, grupo, ["desprez", "tabu", "odeiam", "condenam"]) + " " + (Sociedades._campo(u, sid, ["desprez", "tabu", "odeiam", "condenam"]) if sid != "" else ""))
	return {"admira": adm, "despreza": desp}


static func _lugares_do_grupo(u: Universo, grupo: String) -> Array:
	if Sociedades.eh_sociedade(u, grupo):
		return Sociedades.territorio(u, grupo)
	return [grupo] + Mapa.descendentes(u, grupo)


static func _calcular(u: Universo, grupo: String, alvo: String) -> Dictionary:
	var lugares := _lugares_do_grupo(u, grupo)
	var val := _valores(u, grupo)
	var noticias: Dictionary = u.extra("noticias", {})
	var soma := 0.0
	var conhecidos := 0
	var mortes := 0
	var agora := DataMundo.ordem(u.relogio)
	for fid in u.fatos.ids_sobre(alvo):
		var f := u.fatos.obter(fid)
		if not f["canon"]:
			continue
		var acao := str(f["dados"].get("acao", ""))
		var chave := acao if ATOS.has(acao) else str(f["tipo"])
		if not ATOS.has(chave):
			continue
		# Quem fez: o primeiro sujeito (nas quedas e revoltas, quem as liderou).
		var autor: String = f["sujeitos"][0] if not f["sujeitos"].is_empty() else ""
		if chave in ["queda do governo", "golpe vitorioso", "golpe fracassado", "sucessão", "heresia"] and f["sujeitos"].size() > 1:
			autor = f["sujeitos"][1]
		if chave == "revolta esmagada" and f["sujeitos"].size() > 2:
			autor = f["sujeitos"][2]
		if autor != alvo:
			continue
		# O grupo sabe? Aconteceu no território dele, ou a notícia chegou lá.
		var sabe: bool = lugares.has(f["lugar"])
		if not sabe:
			var reg: Dictionary = noticias.get(fid, {})
			for l in reg.get("lugares", {}):
				if lugares.has(l):
					sabe = true
					break
		if not sabe:
			continue
		conhecidos += 1
		if chave == "morte_por":
			mortes += 1
		var def: Array = ATOS[chave]
		var v := float(def[0])
		for w in def[1]:
			if val["admira"].contains(w):
				v += 0.5
				break
		for w in def[1]:
			if val["despreza"].contains(w):
				v -= 0.6
				break
		var anos := maxf(0.0, (agora - DataMundo.ordem(f["data"])) / 360.0)
		soma += v / (1.0 + anos / 15.0)
	var r := {"valor": tanh(soma * 0.8) if conhecidos > 0 else 0.0, "conhecidos": conhecidos, "mortes": mortes}
	return r


static func palavra(r: Dictionary) -> String:
	if int(r["conhecidos"]) == 0:
		return "desconhecido"
	var v := float(r["valor"])
	if v >= 0.5:
		return "herói"
	if v >= 0.2:
		return "bem visto"
	if v <= -0.5:
		return "carniceiro" if int(r["mortes"]) >= 2 else "odiado"
	if v <= -0.2:
		return "mal visto"
	return "indiferente"


## Como cada grupo vê alguém: [{grupo, palavra, valor}] (só os que sabem algo).
static func por_grupo(u: Universo, alvo: String) -> Array:
	var lista: Array = []
	var grupos: Array = Sociedades.todas(u)
	for e in u.entidades_ativas():
		if Mapa.especie(u, e["id"]) == "povoado" and not grupos.has(e["id"]):
			grupos.append(e["id"])
	for g in grupos:
		var r := detalhe(u, g, alvo)
		if int(r["conhecidos"]) > 0:
			lista.append({"grupo": g, "palavra": palavra(r), "valor": float(r["valor"])})
	lista.sort_custom(func(a, b): return absf(a["valor"]) > absf(b["valor"]))
	return lista
