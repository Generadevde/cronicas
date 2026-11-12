class_name Confronto
extends RefCounted
## Laboratório de confronto: põe dois lados para lutar e conta o que acontece,
## com o motivo em palavras. Nada daqui vira fato: é um ensaio, fora da história.
## Os ensaios ficam guardados em u.extra("ensaios") só para o autor reler.

const MAX_ENSAIOS := 30


static func _nome(u: Universo, eid: String) -> String:
	return str(u.entidade(eid).get("nome", "?"))


static func _imortal(u: Universo, eid: String) -> bool:
	for c in u.entidade(eid).get("campos", []):
		var t := TextUtil.normalizar(str(c["chave"]) + " " + str(c["valor"]))
		if t.contains("imortal") or t.contains("nao pode morrer") or t.contains("nao morre"):
			return true
	return false


## cond: {lugar, surpresa (id de quem ataca de surpresa), ate_a_morte, aliados: {id: n}, semente}
## Devolve {texto, porque: [frases], vencedor, perdedor, morte}.
static func ensaiar(u: Universo, a: String, b: String, cond: Dictionary = {}) -> Dictionary:
	if u.entidade(a).is_empty() or u.entidade(b).is_empty() or a == b:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cond.get("semente", Time.get_ticks_usec()))
	var na := _nome(u, a)
	var nb := _nome(u, b)
	var bonus := {a: 1.0, b: 1.0}
	var porque: Array = []
	var surpresa := str(cond.get("surpresa", ""))
	if surpresa in [a, b]:
		bonus[surpresa] *= 1.35
		porque.append("%s atacou de surpresa e teve o primeiro golpe." % _nome(u, surpresa))
	var aliados: Dictionary = cond.get("aliados", {})
	for x in [a, b]:
		var q := int(aliados.get(x, 0))
		if q > 0:
			bonus[x] *= 1.0 + 0.5 * sqrt(float(q))
			porque.append("%s não estava só: veio com aliados." % _nome(u, x))
	var lugar := str(cond.get("lugar", ""))
	if lugar != "":
		for x in [a, b]:
			if str(u.estado(x).get("local", "")) == lugar:
				bonus[x] *= 1.15
				porque.append("%s conhece o terreno." % _nome(u, x))
	var pa := Combate._forca_efetiva(u, a, b) * float(bonus[a])
	var pb := Combate._forca_efetiva(u, b, a) * float(bonus[b])
	var razao := pa / maxf(pb, 0.0001)
	if razao > 1.5:
		porque.append("%s é bem mais forte que %s." % [na, nb])
	elif razao < 0.67:
		porque.append("%s é bem mais forte que %s." % [nb, na])
	else:
		porque.append("As forças dos dois lados eram parecidas.")
	for par in [[a, b], [b, a]]:
		var x: String = par[0]
		if Estado.saude_atual(u, x) < 0.6:
			porque.append("%s já chegou ferido." % _nome(u, x))
		if maxf(Estado.emocao_por(u, x, par[1], ["odio", "raiva", "rancor", "humilhacao"]), Estado.valor_relacao(u, x, par[1], "raiva")) > 0.3:
			porque.append("%s carrega raiva de %s: a raiva dá força, mas tira o juízo." % [_nome(u, x), _nome(u, par[1])])
	var r := Combate.resolver(u, a, b, rng, bool(cond.get("ate_a_morte", false)), bonus)
	var venc: String = r["vencedor"]
	var perd: String = r["perdedor"]
	var cv: float = float(r["chance"]) if venc == a else 1.0 - float(r["chance"])
	var morte: bool = r["morte"]
	if morte and _imortal(u, perd):
		morte = false
		porque.append("%s não morre: está escrito na ficha." % _nome(u, perd))
	var onde := (" em " + _nome(u, lugar)) if lugar != "" else ""
	var frases: Array = []
	if surpresa in [a, b]:
		frases.append("%s caiu sobre %s sem aviso%s." % [_nome(u, surpresa), _nome(u, b if surpresa == a else a), onde])
	else:
		frases.append("%s e %s se encontraram%s." % [na, nb, onde])
	if cv > 0.8:
		frases.append("%s dominou do começo ao fim." % _nome(u, venc))
	elif cv > 0.6:
		frases.append("%s levou a melhor, mas não sem custo." % _nome(u, venc))
	elif cv > 0.4:
		frases.append("Ficou indeciso até o último instante; %s venceu por um fio." % _nome(u, venc))
	else:
		frases.append("Contra tudo o que se esperava, %s venceu." % _nome(u, venc))
		porque.append("A sorte pesou: nem sempre o mais forte vence.")
	if morte:
		frases.append("%s não saiu com vida." % _nome(u, perd))
	elif _imortal(u, perd):
		frases.append("%s caiu, mas não morre: levantou-se depois, derrotado." % _nome(u, perd))
	else:
		frases.append("%s recuou ferido." % _nome(u, perd))
	var e := {"a": a, "b": b, "texto": " ".join(frases), "porque": porque, "vencedor": venc, "perdedor": perd, "morte": morte,
		"resumo": "%s contra %s: %s" % [na, nb, frases[frases.size() - 1]]}
	var lista: Array = u.extra("ensaios", [])
	lista.push_front(e)
	while lista.size() > MAX_ENSAIOS:
		lista.pop_back()
	u.marcar_mudanca()
	return e
