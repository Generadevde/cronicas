class_name Economia
extends RefCounted
## Economia por região, só o necessário: o que cada povoado produz e come vem da
## Natureza; aqui as CARAVANAS levam comida de onde sobra para onde falta (entre
## povoados a poucos dias de viagem), o PREÇO sobe quando falta, e cada sociedade
## junta RIQUEZA com os impostos. Regra: se um número não muda o que alguém faz,
## ele não existe. Números em extras["economia"].

const DIAS_DE_CARAVANA := 30   ## povoados a até um mês de viagem trocam comida


static func dados(u: Universo) -> Dictionary:
	return u.extra("economia", {})


static func riqueza(u: Universo, sid: String) -> float:
	return float(dados(u).get("riqueza", {}).get(sid, 0.0))


static func preco(u: Universo, lugar: String) -> float:
	if not Natureza.tem_natureza(u, lugar):
		return 1.0
	return clampf(1.0 / (float(Natureza.de(u, lugar)["comida"]) + 0.05), 0.4, 6.0)


static func palavra_preco(p: float) -> String:
	if p >= 2.5:
		return "caríssimo"
	if p >= 1.5:
		return "caro"
	if p <= 0.8:
		return "barato"
	return "normal"


static func passo(u: Universo, dias: int, _rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var d := dados(u)
	d["acumulado"] = int(d.get("acumulado", 0)) + dias
	var mes := int(d["acumulado"]) >= 30
	if mes:
		d["acumulado"] = int(d["acumulado"]) - 30
	var povoados: Array = []
	for e in u.entidades_ativas():
		if Mapa.especie(u, e["id"]) == "povoado" and Natureza.tem_natureza(u, e["id"]) and float(Natureza.de(u, e["id"])["pop"]) > 0:
			povoados.append(e["id"])
	# O que veio pelas caravanas vai sendo comido.
	for p in povoados:
		var reg := Natureza.de(u, p)
		reg["importado"] = float(reg.get("importado", 0.0)) * pow(0.6, dias / 30.0)
		reg["exportado"] = float(reg.get("exportado", 0.0)) * pow(0.6, dias / 30.0)
	if not mes:
		return novos
	# Caravanas: de quem tem sobra para quem tem falta.
	for b in povoados:
		var rb := Natureza.de(u, b)
		var falta := 0.8 - float(rb["comida"])
		if falta <= 0.0:
			continue
		var melhor := ""
		var melhor_sobra := 0.0
		for a in povoados:
			if a == b:
				continue
			var sobra := float(Natureza.de(u, a)["comida"]) - 1.0
			if sobra <= 0.08:
				continue
			var dd := u.dias_de_viagem(a, b)
			if dd < 0 or dd > DIAS_DE_CARAVANA:
				continue
			if sobra > melhor_sobra:
				melhor_sobra = sobra
				melhor = a
		if melhor == "":
			continue
		var ra := Natureza.de(u, melhor)
		var peso := clampf(float(ra["pop"]) / maxf(1.0, float(rb["pop"])), 0.2, 2.0)
		var t := minf(melhor_sobra * peso, falta) * 0.6
		rb["importado"] = float(rb.get("importado", 0.0)) + t
		ra["exportado"] = float(ra.get("exportado", 0.0)) + t / peso
		var al: Dictionary = rb["alertas"]
		if t > 0.04 and (al.get("fome", false) or float(rb["comida"]) < 0.6) and not al.get("caravanas", false):
			al["caravanas"] = true
			var causa := str(al.get("fome_fato", ""))
			if not u.fatos.existe(causa):
				causa = Natureza._ultimo_fato_natural(u, b)
			novos.append(_fato(u, b, "caravanas", "Caravanas de %s levaram comida a %s." % [u.entidade(melhor)["nome"], u.entidade(b)["nome"]],
				0.4, [causa], [melhor]))
	for p in povoados:
		var reg2 := Natureza.de(u, p)
		var al2: Dictionary = reg2["alertas"]
		if not al2.get("fome", false) and float(reg2["comida"]) >= 0.8:
			al2.erase("caravanas")
		var pr := preco(u, p)
		if pr >= 2.5 and not al2.get("caro", false):
			al2["caro"] = true
			novos.append(_fato(u, p, "preços", "O pão está caríssimo em %s." % u.entidade(p)["nome"], 0.4, [str(al2.get("fome_fato", ""))], []))
		elif pr < 1.5:
			al2.erase("caro")
	# Riqueza das sociedades (impostos sobre o que o povo produz).
	var riq: Dictionary = d.get("riqueza", {})
	for sid in Sociedades.todas(u):
		var entra := 0.0
		for p in Sociedades.territorio(u, sid):
			if povoados.has(p):
				var reg3 := Natureza.de(u, p)
				entra += float(reg3["pop"]) / 1000.0 * minf(1.0, float(reg3["comida"])) * Sociedades.imposto(u, sid)
		riq[sid] = float(riq.get(sid, 0.0)) + entra - float(riq.get(sid, 0.0)) * 0.02  # o governo também gasta
	d["riqueza"] = riq
	return novos.filter(func(x): return x != "")


static func _fato(u: Universo, lugar: String, tipo: String, texto: String, imp: float, causas: Array, sujeitos: Array) -> String:
	var cs: Array = causas.filter(func(c): return c != "" and u.fatos.existe(c))
	if cs.is_empty():
		var fc: String = u.entidade(lugar).get("fato_criacao", "")
		if u.fatos.existe(fc):
			cs = [fc]
	return Simulador.registrar(u, {
		"tipo": tipo, "descricao": texto, "sujeitos": [lugar] + sujeitos, "lugar": lugar, "causas": cs,
		"dados": {"importancia": imp, "economia": true},
	})
