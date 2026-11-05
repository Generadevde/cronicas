class_name Lutas
extends RefCounted
## Lutas com resultado em aberto. Você escreve a luta sem dizer quem venceu:
##   "Jhon Black tinha a força de 98 mil. Sirius Dal tinha força de 70 mil.
##    Eles lutaram por 10 dias; apenas um ficou em pé."
## O programa registra a luta como pendente e não decide no meio do texto. Ao
## avançar o tempo, calcula: força (98 mil contra 70 mil dá cerca de 58% para Black),
## resistência nos dias de luta, fraquezas (uma ferida antiga), poderes, terreno,
## aliados por perto e um pouco de sorte. O resultado chega como eco na margem
## do capítulo: você aceita, troca o vencedor ou mantém em mistério.

const ATE_O_FIM := ["apenas um", "so um", "somente um", "ate a morte", "ate o fim", "ficou de pe", "ficou em pe", "sobreviveu", "um deles caiu", "so restou um"]


## Lutas pendentes (fatos de luta escritos em capítulos, ainda sem resultado).
static func pendentes(u: Universo) -> Array:
	var feitas: Dictionary = u.extra("lutas", {})
	var lista: Array = []
	for f in u.fatos.todos():
		if f["canon"] and f["dados"].get("acao", "") == "luta" and f["origem"]["tipo"] == BancoDeFatos.ORIGEM_CAPITULO and not feitas.has(f["id"]):
			lista.append(f)
	return lista


## No passo do relógio: cada luta pendente vira um resultado proposto (eco).
static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("lutas_ctrl", {"seq": 0})
	var feitas: Dictionary = u.extra("lutas", {})
	var todos := u.fatos.todos()
	var ate := int(ctrl["seq"])
	for i in range(todos.size() - 1, -1, -1):
		var f: Dictionary = todos[i]
		if int(f["seq"]) <= int(ctrl["seq"]):
			break
		ate = maxi(ate, int(f["seq"]))
		if not f["canon"] or f["dados"].get("acao", "") != "luta" or f["origem"]["tipo"] != BancoDeFatos.ORIGEM_CAPITULO or feitas.has(f["id"]):
			continue
		var s: Array = f["sujeitos"]
		if s.size() < 2 or not Estado.vivo(u, s[0]) or not Estado.vivo(u, s[1]):
			continue
		var eco := resolver(u, f, rng)
		if not eco.is_empty():
			u.propostas.append(eco)
			feitas[f["id"]] = eco["id"]
	ctrl["seq"] = ate
	return []


## Força de alguém para a luta: a ficha, ou o que o capítulo disse ("tinha a força de 98 mil").
static func forca(u: Universo, eid: String, cap: String) -> float:
	var n := Combate.poder_da_ficha(u, eid)
	if n <= 1.0 and cap != "":
		n = maxf(n, _forca_no_texto(u, eid, u.capitulo(cap).get("texto", "")))
	var s := u.estado(eid)
	n = (n + float(s.get("poder", 0.0))) * Corpo.fator_idade(u, eid)
	return maxf(n, 0.01)


static func _forca_no_texto(u: Universo, eid: String, texto: String) -> float:
	var nomes: Array = [TextUtil.normalizar(u.entidade(eid)["nome"]), TextUtil.normalizar(u.entidade(eid)["nome"].split(" ")[0])]
	for a in u.entidade(eid).get("apelidos", []):
		nomes.append(TextUtil.normalizar(a))
	for frase in Extrator.frases(texto):
		var n := TextUtil.normalizar(frase)
		if not nomes.any(func(x): return x != "" and n.contains(x)):
			continue
		for chave in ["forca de", "forca", "poder de", "poder", "nivel de", "nivel"]:
			var i := n.find(chave)
			if i >= 0:
				var v := Combate.ler_numero(n.substr(i + chave.length()))
				if v > 0:
					return v
	return 0.0


## Calcula o resultado. Devolve a proposta (eco) com o vencedor e o porquê.
static func resolver(u: Universo, f: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var a: String = f["sujeitos"][0]
	var b: String = f["sujeitos"][1]
	var cap: String = f["origem"].get("ref", "")
	var frase := TextUtil.normalizar(str(f["dados"].get("frase", "")))
	var texto_cap := TextUtil.normalizar(u.capitulo(cap).get("texto", ""))
	var dias := _dias(frase if frase.contains("dia") else texto_cap)
	# A frase da luta e o que vem logo depois ("Eles lutaram por 10 dias; apenas um ficou em pé.").
	var pos := texto_cap.find(frase) if frase != "" else -1
	var trecho := texto_cap.substr(pos, frase.length() + 90) if pos >= 0 else frase
	var ate_o_fim := ATE_O_FIM.any(func(w): return trecho.contains(w))
	var fa := forca(u, a, cap)
	var fb := forca(u, b, cap)
	var chance := fa / (fa + fb)  # 98 mil contra 70 mil → 58%
	var fatores: Array = []  # [quem favorece, peso, texto]
	# Resistência: em lutas longas, quem aguenta mais leva vantagem.
	if dias >= 3:
		var va := _vigor(u, a)
		var vb := _vigor(u, b)
		var d := (va - vb) * 0.12 * minf(float(dias), 30.0) / 10.0
		chance += d
		if absf(d) > 0.02:
			fatores.append([a if d > 0 else b, absf(d), "aguentando melhor os %d dias de luta" % dias])
	# Fraquezas: uma ferida antiga, um ponto fraco escrito na ficha.
	for par in [[a, b, 1.0], [b, a, -1.0]]:
		var fraco := _fraqueza(u, par[0])
		if fraco != "":
			var t := Personalidade.tracos(u, par[1])
			var explora := 0.03 + 0.06 * (float(t["prudencia"]) + float(t["curiosidade"])) / 2.0
			chance -= explora * float(par[2])
			fatores.append([par[1], explora, "explorando %s de %s" % [fraco, _curto(u, par[0])]])
	# Poderes (sem gastar: a luta é resumida).
	for par in [[a, 1.0], [b, -1.0]]:
		var melhor := 1.0
		var qual := ""
		for pid in Poderes.de(u, par[0]):
			if Poderes.pode_usar(u, par[0], pid) and Poderes.bonus(u, pid) > melhor:
				melhor = Poderes.bonus(u, pid)
				qual = pid
		if qual != "":
			var d2 := (melhor - 1.0) * 0.12
			chance += d2 * float(par[1])
			fatores.append([par[0], d2, "com %s" % u.entidade(qual)["nome"]])
	# Terreno: quem é do lugar conhece o chão.
	var lugar: String = f.get("lugar", "")
	if lugar != "":
		for par in [[a, 1.0], [b, -1.0]]:
			if Sociedades.de_lugar(u, lugar) != "" and Sociedades.membros(u, Sociedades.de_lugar(u, lugar)).has(par[0]):
				chance += 0.03 * float(par[1])
				fatores.append([par[0], 0.03, "lutando em casa"])
	# Aliados por perto.
	for par in [[a, 1.0], [b, -1.0]]:
		var n := 0
		for m in Natureza._mentes_em(u, u.estado(par[0]).get("local", "")):
			if m != a and m != b and Estado.valor_relacao(u, m, par[0], "afeto") >= 0.5:
				n += 1
		if n > 0:
			chance += minf(0.06, 0.02 * n) * float(par[1])
			fatores.append([par[0], minf(0.06, 0.02 * n), "com amigos por perto"])
	chance = clampf(chance, 0.03, 0.97)
	var a_vence := rng.randf() < chance
	var venc := a if a_vence else b
	var perd := b if a_vence else a
	var chance_v := chance if a_vence else 1.0 - chance
	return montar_eco(u, f, venc, perd, chance_v, dias, ate_o_fim, fatores, rng, fa if a_vence else fb, fb if a_vence else fa)


## Monta a proposta de resultado (também usada para trocar o vencedor).
static func montar_eco(u: Universo, f: Dictionary, venc: String, perd: String, chance_v: float, dias: int, ate_o_fim: bool, fatores: Array,
		rng: RandomNumberGenerator, forca_v: float, forca_p: float, do_autor: bool = false) -> Dictionary:
	var nv: String = u.entidade(venc)["nome"]
	var np: String = u.entidade(perd)["nome"]
	var cp := _curto(u, perd)
	# O porquê: o fator que mais ajudou o vencedor.
	var porque := ""
	var melhor := 0.0
	for x in fatores:
		if x[0] == venc and float(x[1]) > melhor:
			melhor = float(x[1])
			porque = x[2]
	var texto := "%s venceu %s" % [nv, np]
	if do_autor:
		texto += " (decisão do autor)"
	elif chance_v < 0.5:
		texto += ", contra as chances" + ((", " + porque) if porque != "" else "")
	elif porque != "":
		texto += ", " + porque
	var ops: Array = []
	var morte := false
	var destino := ""
	var x := rng.randf()
	if ate_o_fim:
		morte = x < 0.6
		destino = "e só ele ficou em pé" if morte else "e %s, caído, foi deixado para trás" % cp
	elif x < 0.12:
		morte = true
		destino = "e %s não sobreviveu" % cp
	elif x < 0.4:
		destino = "e %s fugiu" % cp
		ops.append({"op": "marca", "quem": perd, "marca": "fugiu de " + nv})
	else:
		destino = "e %s ficou marcado pela derrota" % cp
		ops.append({"op": "marca", "quem": perd, "marca": "marcado pela derrota"})
	if morte:
		ops.append({"op": "morrer", "quem": perd})
	else:
		ops.append({"op": "ferir", "quem": perd, "descricao": "ferido na luta contra %s" % nv, "gravidade": 0.45 if ate_o_fim else 0.3})
	texto += ", " + destino + "."
	# A família do perdedor guarda rancor; o vencedor ganha fama e talvez um título.
	for p in Estado.familia_proxima(u, perd):
		if p != venc:
			ops.append({"op": "relacao", "de": p, "para": venc, "deltas": {"raiva": 0.5}})
	ops.append({"op": "mudar", "quem": venc, "chave": "reputacao", "delta": 0.5 + (0.5 if chance_v < 0.5 else 0.0)})
	var tit := Lendas.titulo_de_luta(chance_v, dias, morte, forca_v, forca_p)
	if tit != "" and Lendas.titulo(u, venc) == "":
		ops.append({"op": "definir", "quem": venc, "chave": "titulo", "valor": tit})
		texto += " Passou a ser chamado de %s, %s." % [nv.split(" ")[0], tit]
	return {
		"id": Ids.novo("prp"), "capitulo": f["origem"].get("ref", ""), "frase": "", "acao": "vitoria",
		"sujeitos": [venc, perd], "lugar": f.get("lugar", ""), "status": "eco", "descricao": texto,
		"causa": f["id"], "efeito": {}, "ops_extra": ops,
		"luta": {"chance": chance_v, "dias": dias, "ate_o_fim": ate_o_fim, "fatores": fatores, "forca_v": forca_v, "forca_p": forca_p},
		"assinatura": "luta|%s|%s" % [f["id"], venc],
	}


## O autor troca o vencedor: a proposta é refeita com os papéis invertidos.
static func trocar_vencedor(u: Universo, pid: String) -> Dictionary:
	var p := u.proposta(pid)
	if p.is_empty() or not p.has("luta"):
		return {}
	var f := u.fatos.obter(p["causa"])
	var l: Dictionary = p["luta"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pid)
	var novo := montar_eco(u, f, p["sujeitos"][1], p["sujeitos"][0], 1.0 - float(l["chance"]), int(l["dias"]), bool(l["ate_o_fim"]), l["fatores"],
		rng, float(l["forca_p"]), float(l["forca_v"]), true)
	p["status"] = "riscada"
	u.propostas.append(novo)
	u.extra("lutas", {})[p["causa"]] = novo["id"]
	u.marcar_mudanca()
	return novo


## O autor prefere o mistério: ninguém fica sabendo quem venceu (e o mundo não recalcula).
static func manter_misterio(u: Universo, pid: String) -> void:
	var p := u.proposta(pid)
	if p.is_empty():
		return
	p["status"] = "misterio"
	var f := u.fatos.obter(p.get("causa", ""))
	if not f.is_empty():
		f["dados"]["misterio"] = true
	u.marcar_mudanca()


## "Jhon Black" → "Black"; "Kai" → "Kai".
static func _curto(u: Universo, eid: String) -> String:
	var partes: PackedStringArray = str(u.entidade(eid).get("nome", "?")).split(" ", false)
	return partes[partes.size() - 1] if partes.size() > 0 else "?"


static func _dias(t: String) -> int:
	var i := t.find(" dias")
	if i < 0:
		i = t.find(" dia")
	if i < 0:
		return 1
	var antes := t.substr(maxi(0, i - 12), mini(12, i)).strip_edges()
	var partes := antes.split(" ")
	var ultimo: String = partes[partes.size() - 1] if partes.size() > 0 else ""
	var v := Combate.ler_numero(ultimo)
	if v <= 0:
		var por_extenso := {"dois": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8, "nove": 9, "dez": 10, "onze": 11, "doze": 12,
			"quinze": 15, "vinte": 20, "trinta": 30, "cem": 100, "um": 1}
		v = float(por_extenso.get(ultimo, 1))
	return maxi(1, int(v))


## Vigor para lutas longas: saúde, idade e coragem.
static func _vigor(u: Universo, eid: String) -> float:
	var t := Personalidade.tracos(u, eid)
	return Estado.saude_atual(u, eid) * clampf(Corpo.fator_idade(u, eid), 0.3, 1.2) * (0.8 + 0.4 * float(t["coragem"]))


## A fraqueza que um adversário pode explorar: ficha ("fraquezas", "ponto fraco") ou ferida antiga.
static func _fraqueza(u: Universo, eid: String) -> String:
	var txt := Sociedades._campo(u, eid, ["fraquez", "ponto fraco", "pontos fracos", "ferida"])
	if txt != "":
		var n := TextUtil.normalizar(txt)
		if n.contains("ferida") or n.contains("cicatriz") or n.contains("joelho") or n.contains("ombro"):
			return "a ferida antiga"
		return "o ponto fraco (%s)" % txt.split(",")[0].strip_edges()
	for fer in u.estado(eid).get("ferimentos", []):
		if float(fer.get("gravidade", 0.0)) >= 0.25:
			return "a ferida antiga"
	if not Corpo.cicatrizes(u, eid).is_empty():
		return "a ferida antiga"
	return ""
