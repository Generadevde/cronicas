class_name Combate
extends RefCounted
## Lutas no nível da história (não golpe a golpe): força, saúde, coragem,
## a raiva do momento e um pouco de sorte decidem quem fica em pé.

const CHAVES_DE_PODER := ["forca", "poder", "nivel", "ki", "mana", "energia", "potencia", "ataque"]


## Lê um número de poder da ficha: um campo como "força: 98 mil", "poder: 70000", "nível 40".
## Sem nada escrito, todo mundo começa com 1.
static func poder_da_ficha(u: Universo, eid: String) -> float:
	for c in u.entidade(eid).get("campos", []):
		var chave := TextUtil.normalizar(str(c["chave"]))
		if not CHAVES_DE_PODER.any(func(k): return chave.contains(k)):
			continue
		var n := ler_numero(str(c["valor"]))
		if n > 0:
			return n
	return 1.0


## "98 mil" → 98000; "1,5 milhão" → 1500000; "70.000" → 70000; "40" → 40.
static func ler_numero(texto: String) -> float:
	var t := TextUtil.normalizar(texto)
	var numero := ""
	var achou := false
	var i := 0
	while i < t.length():
		var c: String = t[i]
		if c >= "0" and c <= "9":
			numero += c
			achou = true
		elif achou and (c == "," or c == "."):
			# "70.000" (milhar) ou "1,5" (decimal)
			var resto := t.substr(i + 1, 3)
			if c == "." and resto.length() == 3 and resto.is_valid_int():
				pass
			else:
				numero += "."
		elif achou:
			break
		i += 1
	if not achou:
		return 0.0
	var v := numero.to_float()
	var depois := t.substr(i).strip_edges()
	if depois.begins_with("mil") and not depois.begins_with("milh"):
		v *= 1000.0
	elif depois.begins_with("milh"):
		v *= 1000000.0
	elif depois.begins_with("bilh"):
		v *= 1000000000.0
	return v


## Chance de A vencer B (0 a 1).
static func chance(u: Universo, a: String, b: String, bonus: Dictionary = {}) -> float:
	var pa := _forca_efetiva(u, a, b) * float(bonus.get(a, 1.0))
	var pb := _forca_efetiva(u, b, a) * float(bonus.get(b, 1.0))
	var ka := pow(pa, 1.6)
	var kb := pow(pb, 1.6)
	return ka / (ka + kb)


static func _forca_efetiva(u: Universo, eid: String, contra: String) -> float:
	var t := Personalidade.tracos(u, eid)
	var p := Estado.poder(u, eid)
	p *= 0.4 + 0.6 * Estado.saude_atual(u, eid)
	p *= 0.85 + 0.3 * float(t.get("coragem", 0.5))
	# Raiva dá força, mas a imprudência cobra.
	var raiva := Estado.emocao_por(u, eid, contra, ["odio", "raiva", "rancor", "humilhacao"])
	p *= 1.0 + raiva * 0.25 * (1.2 - float(t.get("prudencia", 0.5)))
	return maxf(p, 0.001)


## Resolve uma luta. Devolve {vencedor, perdedor, morte: bool, chance, gravidade}.
## 'ate_a_morte' aumenta muito a chance de alguém morrer.
static func resolver(u: Universo, a: String, b: String, rng: RandomNumberGenerator, ate_a_morte: bool = false, bonus: Dictionary = {}) -> Dictionary:
	var ca := chance(u, a, b, bonus)
	var a_vence := rng.randf() < ca
	var venc := a if a_vence else b
	var perd := b if a_vence else a
	var tv := Personalidade.tracos(u, venc)
	var odio := Estado.emocao_por(u, venc, perd, ["odio", "rancor"])
	var risco := 0.04 + (1.0 - float(tv.get("empatia", 0.5))) * 0.18 + odio * 0.25
	if ate_a_morte:
		risco += 0.45
	if Estado.saude_atual(u, perd) < 0.35:
		risco += 0.15
	var morte := rng.randf() < clampf(risco, 0.0, 0.95)
	var margem := absf((ca if a_vence else 1.0 - ca) - 0.5)
	return {"vencedor": venc, "perdedor": perd, "morte": morte, "chance": ca,
		"gravidade": clampf(0.25 + (0.5 - margem) * 0.6, 0.15, 0.6)}
