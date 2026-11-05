class_name Viagens
extends RefCounted
## Viajar leva tempo. Quem parte fica "a caminho" (sem lugar) até chegar;
## a chegada vira fato, causada pela partida. Sem mapa, a ida é imediata.


## Operações para alguém ir de um lugar a outro (usadas pelas mentes e pela natureza).
static func ops_de_ida(u: Universo, eid: String, de: String, para: String) -> Array:
	var dias := u.dias_de_viagem(de, para)
	if dias <= 1:
		return [{"op": "mover", "quem": eid, "lugar": para}]
	return [{"op": "viajar", "quem": eid, "de": de, "para": para, "dias": dias}]


## Texto curto da duração ("uma viagem de 12 dias"), ou "" se for imediata.
static func duracao(u: Universo, de: String, para: String) -> String:
	var dias := u.dias_de_viagem(de, para)
	if dias <= 1:
		return ""
	if dias >= 60:
		return " (uma viagem de uns %d meses)" % roundi(dias / 30.0)
	return " (uma viagem de %d dias)" % dias


## Aplica a operação "viajar" (chamada pelo Universo via sistemas_de_mudanca).
static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	if str(op.get("op", "")) != "viajar":
		return false
	var quem := str(op.get("quem", ""))
	if not u.entidades.has(quem) or not Estado.vivo(u, quem):
		return true
	var s := u.estado(quem)
	var saida := DataMundo.ordem(fato.get("data", u.relogio))
	s["viagem"] = {"de": str(op.get("de", "")), "para": str(op.get("para", "")),
		"chega": saida + int(op.get("dias", 1)), "fato": fato.get("id", "")}
	s["local"] = ""
	s["local_desde"] = DataMundo.copiar(fato.get("data", u.relogio))
	return true


static func viajando(u: Universo, eid: String) -> bool:
	return not Dictionary(u.estado(eid).get("viagem", {})).is_empty()


## A cada passo: quem chegou ao destino.
static func passo(u: Universo, _dias: int, _rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for e in u.entidades_ativas():
		var s := u.estado(e["id"])
		var v: Dictionary = s.get("viagem", {})
		if v.is_empty() or int(v["chega"]) > agora:
			continue
		var para: String = v["para"]
		if not Estado.vivo(u, e["id"]):
			s.erase("viagem")
			continue
		var causas: Array = [v["fato"]] if u.fatos.existe(v["fato"]) else []
		var data := DataMundo.copiar(u.relogio)
		var fid := Simulador.registrar(u, {
			"tipo": "chegada",
			"descricao": "%s chegou a %s." % [e["nome"], u.entidade(para).get("nome", "?")],
			"sujeitos": [e["id"]],
			"lugar": para,
			"data": data,
			"causas": causas,
			"dados": {"acao": "chegada", "importancia": 0.25,
				"mudancas": [{"op": "mover", "quem": e["id"], "lugar": para}]},
		})
		if fid != "":
			novos.append(fid)
		else:
			s.erase("viagem")
	return novos
