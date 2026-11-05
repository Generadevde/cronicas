class_name Ameacas
extends RefCounted
## Criaturas que aparecem e atacam, escritas pelo autor ("à noite, slimes começam a
## aparecer e atacam as pessoas"; "todo inverno, dragões descem e queimam as casas").
##
## A espécie é uma entidade (tipo "criatura") e a ameaça fica no estado dela, sempre
## mudada por operações dentro de fatos (o mundo pode ser reconstruído).
## A cada passo: as criaturas aparecem quando a frase disse (à noite, no inverno, de vez
## em quando…), atacam, ferem e matam; as pessoas sentem medo, revidam, viram heróis,
## inventam defesas (fogueiras, paliçada, vigia) e descobrem fraquezas. Tudo vira fato.

## Força de algumas criaturas conhecidas (as outras ficam em 1).
const FORCAS := {"slime": 0.5, "rato": 0.25, "lobo": 1.0, "goblin": 0.8, "zumbi": 1.0, "morto-vivo": 1.0, "esqueleto": 0.9,
	"orc": 1.6, "troll": 3.0, "ogro": 3.0, "dragao": 8.0, "demonio": 4.0, "fantasma": 1.2, "espectro": 1.5, "aranha": 0.7,
	"monstro": 2.0, "besta": 2.0, "criatura": 1.0, "alien": 2.0, "alienigena": 2.0, "robo": 2.0, "drone": 1.0, "kraken": 6.0,
	"tubarao": 1.5, "urso": 2.0, "serpente": 1.2, "cobra": 0.6, "vampiro": 2.5, "lobisomem": 3.0, "gigante": 5.0,
	"bandido": 1.0, "pirata": 1.2, "harpia": 1.0, "grifo": 2.5, "verme": 0.6, "mosquito": 0.1, "inseto": 0.3, "sombra": 1.5}

## Defesas que as pessoas podem inventar, na ordem em que costumam aparecer.
const DEFESAS := [
	["acender fogueiras em volta de onde dormem", 0.2],
	["montar turnos de vigia", 0.15],
	["erguer uma paliçada", 0.25],
	["fazer lanças e tochas para todos", 0.15],
	["dormir todos juntos num abrigo só", 0.15],
]
const FRAQUEZAS := ["o fogo", "o sal", "a água do mar", "a luz forte", "o ferro", "o barulho"]


static func todas(u: Universo) -> Array:
	var r: Array = []
	for e in u.entidades_ativas():
		var a: Dictionary = u.estado(e["id"]).get("ameaca", {})
		if not a.is_empty():
			r.append(e["id"])
	return r


static func dados(u: Universo, especie: String) -> Dictionary:
	return u.estado(especie).get("ameaca", {})


static func aplicar_op(u: Universo, op: Dictionary, _fato: Dictionary) -> bool:
	var quem := str(op.get("quem", ""))
	match str(op.get("op", "")):
		"ameaca":
			if u.entidades.has(quem):
				var a: Dictionary = op.get("dados", {}).duplicate(true)
				a["ativa"] = true
				a["ataques"] = 0
				a["mortes"] = 0
				a["mortas"] = 0
				u.estado(quem)["ameaca"] = a
			return true
		"ameaca_mudar":
			var a := dados(u, quem)
			if a.is_empty():
				return true
			for k in ["pop", "ataques", "mortes", "mortas"]:
				if op.has(k):
					a[k] = maxf(0.0, float(a.get(k, 0)) + float(op[k]))
			if op.has("forca_mult"):
				a["forca"] = float(a["forca"]) * float(op["forca_mult"])
			if op.has("ativa"):
				a["ativa"] = bool(op["ativa"])
			if op.has("ultima_defesa"):
				a["ultima_defesa"] = int(op["ultima_defesa"])
			if op.has("fraqueza"):
				a["fraqueza"] = str(op["fraqueza"])
			if op.has("defesa"):
				var d: Dictionary = a.get("defesas", {})
				d[str(op["defesa"])] = true
				a["defesas"] = d
			return true
	return false


## Força da criatura (pelo nome e pelos adjetivos da frase).
static func forca_de(nome: String, texto: String) -> float:
	var n := TextUtil.normalizar(nome)
	var f := 1.0
	for k in FORCAS:
		if n.begins_with(k) or n.contains(k):
			f = float(FORCAS[k])
			break
	var t := " " + TextUtil.normalizar(texto) + " "
	for par in [[" gigante", 3.0], [" enorme", 2.5], [" grande", 1.5], [" pequen", 0.5], [" fraco", 0.6], [" fortes", 1.6], [" forte ", 1.6],
			[" venenos", 1.4], [" ferozes", 1.5], [" feroz", 1.5], [" famint", 1.3], [" ancia", 2.0], [" antig", 1.3]]:
		if t.contains(par[0]):
			f *= float(par[1])
	return f


## Quantas noites (ou dias) do passo a criatura aparece.
static func _vezes(u: Universo, a: Dictionary, dias: int, rng: RandomNumberGenerator) -> int:
	var hoje := DataMundo.ordem(u.relogio)
	match str(a.get("quando", "sempre")):
		"noite", "dia", "sempre":
			return dias
		"inverno", "verao", "primavera", "outono":
			var n := 0
			for d in dias:
				var data := Vivencia._de_ordem(hoje - d)
				if TextUtil.normalizar(Natureza.estacao(data)) == str(a["quando"]):
					n += 1
			return n
		"lua":
			return 1 if (hoje / 30) != ((hoje - dias) / 30) else 0
		_:
			var n2 := 0
			for d in dias:
				if rng.randf() < 0.12:
					n2 += 1
			return n2


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for especie in todas(u):
		var a := dados(u, especie)
		if not a.get("ativa", false):
			continue
		var lugar := str(a.get("lugar", ""))
		var gente := _pessoas(u, lugar)
		if gente.is_empty():
			continue
		var vezes := _vezes(u, a, dias, rng)
		if vezes <= 0:
			continue
		novos.append_array(_atacar(u, especie, a, lugar, gente, vezes, rng))
	return novos


static func _pessoas(u: Universo, lugar: String) -> Array:
	var r: Array = []
	if lugar == "":
		return r
	var dentro := {lugar: true}
	for d in Mapa.descendentes(u, lugar):
		dentro[d] = true
	for e in u.entidades_ativas():
		var x: String = e["id"]
		if Estado.tem_mente(u, x) and Estado.vivo(u, x) and dentro.has(str(u.estado(x).get("local", ""))):
			r.append(x)
	return r


static func defesa(u: Universo, lugar: String) -> float:
	return clampf(float(u.estado(lugar).get("defesa", 0.0)), 0.0, 0.85)


static func _atacar(u: Universo, especie: String, a: Dictionary, lugar: String, gente: Array, vezes: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var nome_pl := str(a.get("plural", u.entidade(especie)["nome"]))
	var base := float(a.get("base", 3.0))
	var pop := maxf(float(a.get("pop", base)), base)  # elas não param de vir
	var def := defesa(u, lugar)
	var chance := clampf(0.55 + pop * 0.03 - def * 0.8, 0.05, 0.95)
	var ataques := 0
	for i in vezes:
		if rng.randf() < chance:
			ataques += 1
	if ataques == 0:
		return novos
	var primeiro := int(a.get("ataques", 0)) == 0
	var quando_txt: Variant = {"noite": "à noite", "dia": "durante o dia", "inverno": "neste inverno", "verao": "neste verão", "lua": "na lua cheia"}.get(str(a.get("quando", "")), "")
	var ops_resumo: Array = [{"op": "ameaca_mudar", "quem": especie, "ataques": ataques, "pop": pop * 0.04 * ataques}]
	if primeiro:
		for p in gente:
			ops_resumo.append({"op": "emocao", "quem": p, "emocao": "medo", "forca": 0.6, "alvo": especie})
	var desc := ("Pela primeira vez, %s atacaram %s%s." % [nome_pl, u.entidade(lugar)["nome"], (" " + quando_txt) if quando_txt != "" else ""]) if primeiro \
		else ("%s atacaram %s %s." % [Conversa._maiuscula(nome_pl), u.entidade(lugar)["nome"], "uma vez" if ataques == 1 else "%d vezes" % ataques])
	var causa := _causa(u, especie, a)
	var resumo := Simulador.registrar(u, {"tipo": "ataque de criaturas", "descricao": desc, "sujeitos": [especie, lugar], "lugar": lugar,
		"causas": [causa], "dados": {"importancia": 0.8 if primeiro else 0.45, "mudancas": ops_resumo}})
	if resumo == "":
		return novos
	novos.append(resumo)
	# Até três encontros contados um a um; o resto fica no resumo.
	var forca := float(a.get("forca", 1.0))
	var efeito := str(a.get("efeito", "atacar"))
	var vivos := gente.duplicate()
	for k in mini(ataques, 3):
		if vivos.is_empty():
			break
		var quem := _quem_enfrenta(u, vivos, rng)
		var r := _encontro(u, especie, a, lugar, quem, forca, def, efeito, resumo, rng)
		novos.append_array(r["fatos"])
		vivos.erase(quem)  # cada um enfrenta no máximo uma vez por passo
	# O que a gente faz depois: inventar defesas, descobrir fraquezas, caçar.
	novos.append_array(_reagir(u, especie, a, lugar, gente.filter(func(p): return Estado.vivo(u, p)), resumo, rng))
	return novos.filter(func(x): return x != "")


static func _causa(u: Universo, especie: String, a: Dictionary) -> String:
	var ids := u.fatos.ids_sobre(especie)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and f["tipo"] in ["ataque de criaturas", "ameaça"]:
			return f["id"]
	return str(a.get("fato", ""))


## Quem enfrenta: às vezes um corajoso se põe na frente; senão, quem estiver mais exposto.
static func _quem_enfrenta(u: Universo, gente: Array, rng: RandomNumberGenerator) -> String:
	var melhor := ""
	var melhor_v := -1.0
	for p in gente:
		var t := Personalidade.tracos(u, p)
		var of := TextUtil.normalizar(Vivencia.oficio(u, p))
		var v := float(t["coragem"]) * 0.6 + rng.randf() * 0.7
		if of.contains("guard") or of.contains("soldad") or of.contains("cacad") or of.contains("guerr"):
			v += 0.4
		if Estado.idade(u, p) >= 0 and Estado.idade(u, p) < 12:
			v += 0.25 * rng.randf()  # crianças também são pegas desprevenidas
		if v > melhor_v:
			melhor_v = v
			melhor = p
	return melhor


static func _encontro(u: Universo, especie: String, a: Dictionary, lugar: String, quem: String, forca: float, def: float, efeito: String, causa: String, rng: RandomNumberGenerator) -> Dictionary:
	var t := Personalidade.tracos(u, quem)
	var nome := str(u.entidade(quem)["nome"])
	var sing := str(u.entidade(especie)["nome"]).to_lower()
	var plural := str(a.get("plural", sing))
	var idade := Estado.idade(u, quem)
	var fraco := 0.5 if (idade >= 0 and (idade < 12 or idade > 65)) else 1.0
	var minha := (1.0 + 0.6 * float(t["coragem"]) + Vivencia.habilidade(u, quem, "luta")) * Estado.saude_atual(u, quem) * fraco * (1.0 + def)
	if str(a.get("fraqueza", "")) != "":
		minha *= 1.5
	var p_vence := minha / (minha + forca * 1.2)
	var r := {"fatos": [], "morreu": false}
	if rng.randf() < p_vence:
		var mortas := 1 + (1 if rng.randf() < 0.4 else 0)
		var desc := "%s enfrentou %s e matou %s." % [nome, plural, "um" if mortas == 1 else "dois"]
		if efeito == "destruir":
			desc = "%s espantou %s antes que destruíssem tudo." % [nome, plural]
		var ops: Array = [{"op": "ameaca_mudar", "quem": especie, "pop": -mortas, "mortas": mortas}, {"op": "mudar", "quem": quem, "chave": "reputacao", "delta": 0.1}]
		r["fatos"].append(Simulador.registrar(u, {"tipo": "luta contra criaturas", "descricao": desc, "sujeitos": [quem, especie], "lugar": lugar,
			"causas": [causa], "dados": {"importancia": 0.45, "mudancas": ops}}))
		return r
	# Perdeu: o que acontece depende do que as criaturas fazem.
	var morre_fogo := efeito == "destruir" and rng.randf() < clampf(forca * 0.04, 0.0, 0.4)
	match efeito:
		"destruir" when not morre_fogo:
			r["fatos"].append(Simulador.registrar(u, {"tipo": "destruição", "descricao": "%s destruíram a casa de %s." % [Conversa._maiuscula(plural), nome], "sujeitos": [especie, quem, lugar], "lugar": lugar,
				"causas": [causa], "dados": {"importancia": 0.45, "mudancas": [{"op": "recurso_delta", "quem": lugar, "nome": "comida", "delta": -1.5},
					{"op": "ferir", "quem": quem, "descricao": "queimaduras", "gravidade": 0.2}]}}))
			return r
		"roubar":
			r["fatos"].append(Simulador.registrar(u, {"tipo": "roubo", "descricao": "%s levaram a comida de %s." % [Conversa._maiuscula(plural), nome], "sujeitos": [especie, quem, lugar], "lugar": lugar,
				"causas": [causa], "dados": {"importancia": 0.3, "mudancas": [{"op": "recurso_delta", "quem": lugar, "nome": "comida", "delta": -1.0}]}}))
			return r
	var grave := clampf(0.15 + forca * 0.08 + rng.randf() * 0.25, 0.1, 0.8)
	var morre := Estado.saude_atual(u, quem) - grave <= 0.15 or rng.randf() < clampf(forca * 0.05, 0.02, 0.5)
	if efeito == "levar":
		r["fatos"].append(Simulador.registrar(u, {"tipo": "desaparecimento", "descricao": "%s foi levado por %s e não voltou." % [nome, plural], "sujeitos": [quem, especie], "lugar": lugar,
			"causas": [causa], "dados": {"importancia": 0.8, "mudancas": [{"op": "morrer", "quem": quem}, {"op": "ameaca_mudar", "quem": especie, "mortes": 1}]}}))
		r["morreu"] = true
		return r
	if morre:
		r["fatos"].append(Simulador.registrar(u, {"tipo": "morte", "descricao": "%s foi morto por %s." % [nome, plural], "sujeitos": [especie, quem], "lugar": lugar,
			"causas": [causa], "dados": {"acao": "morte_por", "importancia": 0.9, "mudancas": [{"op": "morrer", "quem": quem}, {"op": "ameaca_mudar", "quem": especie, "mortes": 1}]}}))
		r["morreu"] = true
	else:
		r["fatos"].append(Simulador.registrar(u, {"tipo": "ferimento", "descricao": "%s foi ferido por %s." % [nome, plural], "sujeitos": [quem, especie], "lugar": lugar,
			"causas": [causa], "dados": {"importancia": 0.4, "mudancas": [{"op": "ferir", "quem": quem, "descricao": "ferida de %s" % sing, "gravidade": grave},
				{"op": "emocao", "quem": quem, "emocao": "medo", "forca": 0.5, "alvo": especie}]}}))
	return r


## Depois dos ataques: alguém inventa uma defesa, descobre uma fraqueza ou chama para a caçada.
static func _reagir(u: Universo, especie: String, a: Dictionary, lugar: String, gente: Array, causa: String, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	if gente.is_empty():
		return novos
	var plural := str(a.get("plural", u.entidade(especie)["nome"]))
	var conhecidas: Dictionary = a.get("defesas", {})
	# Quem pensa: o mais curioso (ou corajoso) entre os adultos.
	var pensador := ""
	var pv := -1.0
	for p in gente:
		if Estado.idade(u, p) >= 0 and Estado.idade(u, p) < 14:
			continue
		var t := Personalidade.tracos(u, p)
		var v := float(t["curiosidade"]) + 0.5 * float(t["coragem"]) + 0.3 * float(t["prudencia"]) + rng.randf() * 0.3
		if v > pv:
			pv = v
			pensador = p
	if pensador == "":
		return novos
	var nome := str(u.entidade(pensador)["nome"])
	var chance := 0.18 + 0.2 * float(Personalidade.tracos(u, pensador)["curiosidade"])
	# Uma ideia nova leva tempo para nascer (no mínimo um mês entre uma defesa e outra).
	var hoje := DataMundo.ordem(u.relogio)
	if rng.randf() < chance and hoje - int(a.get("ultima_defesa", -9999)) >= 30:
		for d in DEFESAS:
			if conhecidas.has(d[0]):
				continue
			var ops: Array = [{"op": "mudar", "quem": lugar, "chave": "defesa", "delta": d[1]}, {"op": "ameaca_mudar", "quem": especie, "defesa": d[0], "ultima_defesa": hoje},
				{"op": "mudar", "quem": pensador, "chave": "reputacao", "delta": 0.15}]
			for p in gente:
				if p != pensador:
					ops.append({"op": "relacao", "de": p, "para": pensador, "deltas": {"respeito": 0.08, "confianca": 0.04}})
			novos.append(Simulador.registrar(u, {"tipo": "defesa", "descricao": "%s convenceu todos a %s contra %s." % [nome, d[0], plural], "sujeitos": [pensador, lugar, especie], "lugar": lugar,
				"causas": [causa], "dados": {"importancia": 0.55, "mudancas": ops}}))
			return novos
	# Uma fraqueza (uma vez só).
	if str(a.get("fraqueza", "")) == "" and int(a.get("ataques", 0)) >= 3 and rng.randf() < 0.25:
		var fr: String = FRAQUEZAS[rng.randi() % FRAQUEZAS.size()]
		novos.append(Simulador.registrar(u, {"tipo": "descoberta", "descricao": "%s descobriu que %s machuca %s." % [nome, fr, plural], "sujeitos": [pensador, especie], "lugar": lugar,
			"causas": [causa], "dados": {"importancia": 0.6, "mudancas": [{"op": "ameaca_mudar", "quem": especie, "fraqueza": fr, "forca_mult": 0.7},
				{"op": "mudar", "quem": pensador, "chave": "reputacao", "delta": 0.2}]}}))
		return novos
	# Caçada: com defesa e alguém corajoso, eles vão atrás.
	if defesa(u, lugar) >= 0.4 and rng.randf() < 0.2:
		var heroi := _quem_enfrenta(u, gente, rng)
		var pop := maxf(float(a.get("pop", 3.0)), float(a.get("base", 3.0)))
		novos.append(Simulador.registrar(u, {"tipo": "caçada", "descricao": "%s liderou uma caçada e matou %d %s." % [u.entidade(heroi)["nome"], maxi(2, int(pop * 0.6)), plural], "sujeitos": [heroi, especie, lugar], "lugar": lugar,
			"causas": [causa], "dados": {"importancia": 0.6, "mudancas": [{"op": "ameaca_mudar", "quem": especie, "pop": -pop * 0.6, "mortas": maxi(2, int(pop * 0.6))},
				{"op": "mudar", "quem": heroi, "chave": "reputacao", "delta": 0.3}]}}))
	return novos


## Texto para a página da criatura e para o lugar.
static func resumo(u: Universo, especie: String) -> String:
	var a := dados(u, especie)
	if a.is_empty():
		return ""
	var s := "Aparecem %s em %s e %s %s." % [{"noite": "à noite", "dia": "de dia", "inverno": "no inverno", "verao": "no verão", "lua": "na lua cheia", "raro": "de vez em quando"}.get(str(a["quando"]), "sempre"),
		u.entidade(str(a["lugar"])).get("nome", "?"), {"atacar": "atacam", "destruir": "destroem", "roubar": "roubam", "levar": "levam", "rondar": "rondam"}.get(str(a["efeito"]), "atacam"), str(a.get("alvo", "as pessoas"))]
	s += " Ataques: %d · mortes: %d · criaturas mortas: %d." % [int(a.get("ataques", 0)), int(a.get("mortes", 0)), int(a.get("mortas", 0))]
	if not Dictionary(a.get("defesas", {})).is_empty():
		s += " Defesas: %s." % ", ".join(Dictionary(a["defesas"]).keys())
	if str(a.get("fraqueza", "")) != "":
		s += " Fraqueza: %s." % a["fraqueza"]
	return s
