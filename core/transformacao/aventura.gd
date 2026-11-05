class_name Aventura
extends RefCounted
## Ecologia de monstros e torneios.
##  • Monstros: caçar demais de um lado faz as feras surgirem do outro. Caçadores
##    baixam os predadores onde moram; os que sobram migram para o vizinho, que passa
##    a sofrer ataques. Quem enfrenta as feras pode virar caçador de monstros.
##  • Torneios: uma vez por ano, cada sociedade com lutadores bastantes faz um torneio;
##    rivais nascem na final, campeões ganham fama, e quem vence três vezes vira lenda.


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var ctrl: Dictionary = u.extra("torneios_ctrl", {"t": -999, "caca": -999})
	var agora := DataMundo.ordem(u.relogio)
	# A caça pesa aos poucos: confere uma vez por mês.
	if agora - int(ctrl.get("caca", -999)) >= 28:
		novos.append_array(_caca(u, mini(28, agora - int(ctrl.get("caca", agora - 28))), rng))
		ctrl["caca"] = agora
	if agora - int(ctrl["t"]) >= DataMundo.DIAS_POR_ANO:
		ctrl["t"] = agora
		for sid in Sociedades.todas(u):
			if rng.randf() < 0.35:  # nem todo ano há torneio
				novos.append(torneio(u, sid, rng))
	return novos.filter(func(x): return x != "")


static func _cacadores(u: Universo, lugar: String) -> Array:
	return Natureza._mentes_em(u, lugar).filter(func(m):
		var of := TextUtil.normalizar(u.valor_campo(m, "ofício") + " " + u.valor_campo(m, "profissão"))
		return of.contains("cacador") or Pecas.marcas(u, m).has("caçador de monstros"))


static func _caca(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	# Onde há caçadores (uma passada pelas mentes, não por lugar).
	var por_lugar := {}
	for m in Simulador._mentes(u):
		var of := TextUtil.normalizar(u.valor_campo(m, "ofício") + " " + u.valor_campo(m, "profissão"))
		if of.contains("cacador") or Pecas.marcas(u, m).has("caçador de monstros"):
			var lm := str(u.estado(m)["local"])
			por_lugar[lm] = Array(por_lugar.get(lm, [])) + [m]
	for l in por_lugar:
		var e := u.entidade(l)
		if e.is_empty() or not Natureza.tem_natureza(u, l) or Motor.adormecido(u, l):
			continue
		var cac: Array = por_lugar[l]
		var reg := Natureza.de(u, l)
		for nome in reg["especies"]:
			var esp: Dictionary = reg["especies"][nome]
			if esp["papel"] != "predador":
				continue
			var antes := float(esp["n"])
			esp["n"] = maxf(0.0, antes - 0.012 * cac.size() * dias / 7.0)
			# Acuadas, as feras fogem para o vizinho (uma vez por espécie e lugar).
			var ultima_fuga := int(reg["alertas"].get("fuga_" + nome, -99999)) if reg["alertas"].get("fuga_" + nome, null) is int else -99999
			if antes >= 0.3 and float(esp["n"]) < 0.3 and DataMundo.ordem(u.relogio) - ultima_fuga > 5 * DataMundo.DIAS_POR_ANO:
				reg["alertas"]["fuga_" + nome] = DataMundo.ordem(u.relogio)
				var viz := _vizinho(u, l)
				if viz == "":
					continue
				var regv := Natureza.de(u, viz)
				var ev := {"op": "evento_natural", "lugar": viz, "tipo": "feras", "forca": 1.0, "ate": DataMundo.ordem(u.relogio) + 60}
				if regv["especies"].has(nome):
					regv["especies"][nome]["n"] = clampf(float(regv["especies"][nome]["n"]) + 0.4, 0.0, 1.5)
				novos.append(Simulador.registrar(u, {"tipo": "feras migram", "lugar": viz, "sujeitos": [l, viz] + cac.slice(0, 2), "causas": [Simulador.causa_de_presenca(u, cac[0])],
					"descricao": "Caçados demais em %s, os %s fugiram para %s, que passou a sofrer ataques." % [e["nome"], nome, u.entidade(viz)["nome"]],
					"dados": {"importancia": 0.5, "mudancas": [ev]}}))
				# Alguém valente do vizinho vira caçador de monstros.
				var bravos: Array = Natureza._mentes_em(u, viz).filter(func(m): return float(Personalidade.tracos(u, m)["coragem"]) > 0.65 and not Pecas.marcas(u, m).has("caçador de monstros"))
				if not bravos.is_empty() and rng.randf() < 0.6:
					novos.append(Simulador.registrar(u, {"tipo": "caçador de monstros", "lugar": viz, "sujeitos": [bravos[0]], "causas": [novos.back()],
						"descricao": "%s pegou em armas e virou caçador de monstros." % u.entidade(bravos[0])["nome"],
						"dados": {"importancia": 0.4, "mudancas": [{"op": "marca", "quem": bravos[0], "marca": "caçador de monstros"}]}}))
	return novos


static func _vizinho(u: Universo, l: String) -> String:
	var melhor := ""
	var dist := 99999
	for e in u.entidades_ativas():
		var o: String = e["id"]
		if o == l or not Natureza.tem_natureza(u, o) or Mapa.especie(u, o) != "povoado":
			continue
		var d := Mapa.dias_de_viagem(u, l, o)
		if d >= 0 and d < dist:
			dist = d
			melhor = o
	return melhor


## Um torneio: os lutadores da sociedade se enfrentam em chaves; sai um campeão.
static func torneio(u: Universo, sid: String, rng: RandomNumberGenerator) -> String:
	var lutadores: Array = Sociedades.membros(u, sid).filter(func(m):
		var t := Personalidade.tracos(u, m)
		return Estado.idade(u, m) >= 16 and Estado.idade(u, m) <= 50 and float(t["coragem"]) + float(t["orgulho"]) > 1.0 and Estado.saude_atual(u, m) > 0.6)
	if lutadores.size() < 4:
		return ""
	lutadores.shuffle()
	var chave: Array = lutadores.slice(0, 8 if lutadores.size() >= 8 else 4)
	var finalista := ""
	while chave.size() > 1:
		var prox: Array = []
		for i in range(0, chave.size() - 1, 2):
			var a: String = chave[i]
			var b: String = chave[i + 1]
			var venc: String = a if rng.randf() < Combate.chance(u, a, b) else b
			if chave.size() == 2:
				finalista = b if venc == a else a
			prox.append(venc)
		chave = prox
	var campeao: String = chave[0]
	var titulos := 1
	for f in u.fatos.sobre(campeao):
		if f["canon"] and f["tipo"] == "torneio" and f["sujeitos"][0] == campeao:
			titulos += 1
	var ops: Array = [{"op": "mudar", "quem": campeao, "chave": "reputacao", "delta": 0.6},
		{"op": "marca", "quem": campeao, "marca": "campeão do torneio de " + u.entidade(sid)["nome"]},
		{"op": "relacao", "de": finalista, "para": campeao, "deltas": {"raiva": 0.3, "respeito": 0.3}},
		{"op": "emocao", "quem": finalista, "emocao": "rivalidade", "forca": 0.5, "alvo": campeao}]
	var texto := "%s venceu o torneio de %s, derrotando %s na final." % [u.entidade(campeao)["nome"], u.entidade(sid)["nome"], u.entidade(finalista)["nome"]]
	if titulos >= 3 and Lendas.titulo(u, campeao) == "":
		ops.append({"op": "definir", "quem": campeao, "chave": "titulo", "valor": "o Invicto"})
		texto += " É o %sº título: passou a ser chamado de o Invicto." % titulos
	var sede := Guerras._sede(u, sid)
	return Simulador.registrar(u, {"tipo": "torneio", "lugar": sede, "sujeitos": [campeao, finalista, sid], "causas": [Simulador.causa_de_presenca(u, campeao)],
		"descricao": texto, "dados": {"importancia": 0.45 if titulos < 3 else 0.6, "mudancas": ops}})
