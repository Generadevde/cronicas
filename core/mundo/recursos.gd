class_name Recursos
extends RefCounted
## O que um grupo precisa para viver, escrito pelo autor ("essas pessoas precisam
## sobreviver", "o oxigênio está acabando", "a água é escassa").
##
## Cada recurso fica no estado do lugar: a reserva (em dias, por pessoa), de onde vem
## (coleta: pesca, caça, frutas; ou nada, como o oxigênio de uma nave quebrada) e o
## rendimento. A cada passo: quem pode trabalha, o grupo consome, a reserva sobe ou
## desce; falta vira fome, fraqueza, briga, roubo e morte; sorte vira fartura; quem sabe
## consertar pode salvar todos. Cada mudança vira fato.

## Rendimento da coleta por terreno (quanto um coletor junta por dia, em dias de comida).
const RENDE := {"agua": 1.6, "floresta": 1.5, "campo": 1.7, "planicie": 1.5, "colina": 1.3, "pantano": 1.2,
	"montanha": 1.0, "deserto": 0.7, "gelo": 0.8, "vazio": 0.0}

const COMO_SE_COLETA := {"comida": ["pescou", "caçou", "colheu frutas", "achou ovos de aves", "pegou caranguejos"],
	"agua": ["achou uma nascente", "juntou água da chuva"], "lenha": ["cortou lenha"]}


static func de(u: Universo, lugar: String) -> Dictionary:
	return u.estado(lugar).get("recursos", {})


static func lugares(u: Universo) -> Array:
	var r: Array = []
	for e in u.entidades_ativas():
		if not Dictionary(u.estado(e["id"]).get("recursos", {})).is_empty():
			r.append(e["id"])
	return r


static func aplicar_op(u: Universo, op: Dictionary, _fato: Dictionary) -> bool:
	var quem := str(op.get("quem", ""))
	match str(op.get("op", "")):
		"recurso":
			if u.entidades.has(quem):
				var rs: Dictionary = u.estado(quem).get("recursos", {})
				rs[str(op["nome"])] = Dictionary(op.get("dados", {})).duplicate(true)
				u.estado(quem)["recursos"] = rs
			return true
		"recurso_delta":
			var r: Dictionary = de(u, quem).get(str(op.get("nome", "")), {})
			if r.is_empty():
				return true
			if op.has("delta"):
				r["reserva"] = clampf(float(r["reserva"]) + float(op["delta"]), 0.0, 90.0)
			if op.has("rende_mult"):
				r["rende"] = float(r.get("rende", 1.0)) * float(op["rende_mult"])
			if op.has("fonte"):
				r["fonte"] = str(op["fonte"])
			if op.has("alerta"):
				r["alerta"] = str(op["alerta"])
			return true
	return false


## Rendimento de quem coleta, pelo terreno do lugar.
static func rendimento(u: Universo, lugar: String) -> float:
	var t := TextUtil.normalizar(u.entidade(lugar).get("tipo", ""))
	if t.contains("nave") or t.contains("estacao") or t.contains("bunker") or t.contains("base"):
		return 0.0
	if t.contains("ilha"):
		return 1.45
	var ter := Mapa.terreno_do_lugar(u, lugar)
	return float(RENDE.get(ter, 1.3))


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for lugar in lugares(u):
		var gente := Ameacas._pessoas(u, lugar)
		if gente.is_empty():
			continue
		for nome in de(u, lugar):
			novos.append_array(_um(u, lugar, str(nome), gente, dias, rng))
	return novos.filter(func(x): return x != "")


static func _um(u: Universo, lugar: String, nome: String, gente: Array, dias: int, rng: RandomNumberGenerator) -> Array:
	var r: Dictionary = de(u, lugar)[nome]
	var novos: Array = []
	var n := gente.size()
	var antes := float(r["reserva"])
	var fonte := str(r.get("fonte", "coleta"))
	# Quem trabalha: adultos com saúde. Medo das criaturas atrapalha a coleta.
	var coletores := 0.0
	for p in gente:
		var i := Estado.idade(u, p)
		if (i < 0 or (i >= 12 and i <= 70)) and Estado.saude_atual(u, p) > 0.4:
			coletores += 1.0
	var medo := 0.0
	for esp in Ameacas.todas(u):
		var a := Ameacas.dados(u, esp)
		if a.get("ativa", false) and str(a.get("lugar", "")) == lugar:
			medo = maxf(medo, 0.3 - Ameacas.defesa(u, lugar) * 0.3)
	var producao := 0.0
	if fonte == "coleta":
		producao = coletores * float(r.get("rende", 1.0)) * (1.0 - medo) / maxf(1.0, float(n))
	elif fonte == "reparo":
		producao = 1.0
	var delta := (producao - 1.0) * dias
	var depois := clampf(antes + delta, 0.0, 90.0)
	var ops: Array = [{"op": "recurso_delta", "quem": lugar, "nome": nome, "delta": depois - antes}]
	var palavra := _palavra(nome)
	var alerta := str(r.get("alerta", ""))
	var desc := ""
	var imp := 0.02
	if depois < 3.0 and antes >= 3.0 and alerta != "pouca":
		desc = ("%s está acabando em %s: dá para uns %d dias." % [Conversa._maiuscula(palavra), u.entidade(lugar)["nome"], int(depois)]) if depois >= 1.0 else "%s está no fim em %s." % [Conversa._maiuscula(palavra), u.entidade(lugar)["nome"]]
		imp = 0.55
		ops.append({"op": "recurso_delta", "quem": lugar, "nome": nome, "alerta": "pouca"})
	elif depois <= 0.0 and alerta != "acabou":
		desc = "Acabou %s em %s." % [palavra, u.entidade(lugar)["nome"]]
		imp = 0.7
		ops.append({"op": "recurso_delta", "quem": lugar, "nome": nome, "alerta": "acabou"})
	elif depois > 8.0 and alerta != "":
		desc = "%s voltou a ser suficiente em %s." % [Conversa._maiuscula(palavra), u.entidade(lugar)["nome"]]
		imp = 0.35
		ops.append({"op": "recurso_delta", "quem": lugar, "nome": nome, "alerta": ""})
	var causa := _causa(u, lugar, nome)
	var conta := Simulador.registrar(u, {"tipo": "reserva" if desc == "" else "escassez", "descricao": desc if desc != "" else "Reserva de %s em %s: %d dias." % [palavra.split(" ")[1], u.entidade(lugar)["nome"], int(depois)],
		"sujeitos": [lugar], "lugar": lugar, "causas": [causa], "dados": {"importancia": imp, "mudancas": ops, "silencioso": desc == "", "recurso": nome}})
	novos.append(conta)
	# Sorte de quem coleta (uma vez por passo, às vezes).
	if fonte == "coleta" and rng.randf() < 0.08 * dias / 7.0 and coletores > 0:
		var quem: String = gente[rng.randi() % gente.size()]
		var como: Array = COMO_SE_COLETA.get(nome, ["achou mais %s" % palavra])
		novos.append(Simulador.registrar(u, {"tipo": "fartura", "descricao": "%s %s e achou um lugar farto." % [u.entidade(quem)["nome"], como[rng.randi() % como.size()]], "sujeitos": [quem, lugar], "lugar": lugar,
			"causas": [conta], "dados": {"importancia": 0.3, "mudancas": [{"op": "recurso_delta", "quem": lugar, "nome": nome, "delta": 3.0, "rende_mult": 1.05},
				{"op": "mudar", "quem": quem, "chave": "reputacao", "delta": 0.05}]}}))
	# Sem fonte: alguém que sabe consertar pode salvar todos.
	if fonte == "nenhuma" and depois < 10.0:
		var tec := ""
		for p in gente:
			var of := TextUtil.normalizar(Vivencia.oficio(u, p))
			for w in ["engenh", "tecnic", "mecanic", "ciencia", "cientist", "inventor", "artifice", "ferreir"]:
				if of.contains(w):
					tec = p
		if tec != "" and rng.randf() < 0.45 * dias / 7.0:
			novos.append(Simulador.registrar(u, {"tipo": "conserto", "descricao": "%s conseguiu consertar o que fazia faltar %s." % [u.entidade(tec)["nome"], palavra], "sujeitos": [tec, lugar], "lugar": lugar,
				"causas": [conta], "dados": {"importancia": 0.7, "mudancas": [{"op": "recurso_delta", "quem": lugar, "nome": nome, "fonte": "reparo", "delta": 4.0},
					{"op": "mudar", "quem": tec, "chave": "reputacao", "delta": 0.3}]}}))
			return novos
	# Falta: fraqueza, brigas, roubo e morte.
	if depois <= 0.5:
		novos.append_array(_falta(u, lugar, nome, gente, dias, conta, rng))
	return novos


static func _falta(u: Universo, lugar: String, nome: String, gente: Array, dias: int, causa: String, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var palavra := _palavra(nome)
	var vital := nome in ["oxigenio", "ar", "agua"]
	var mortos := 0
	for p in gente:
		var i := Estado.idade(u, p)
		var fragil := Estado.saude_atual(u, p) < 0.45 or (i >= 0 and (i < 8 or i > 65))
		var chance := (0.3 if vital else (0.18 if fragil else 0.04)) * dias / 7.0
		if rng.randf() < chance and mortos < 4:
			mortos += 1
			novos.append(Simulador.registrar(u, {"tipo": "morte", "descricao": "%s morreu %s." % [u.entidade(p)["nome"], "sem %s" % palavra if vital else "de fome"], "sujeitos": [p, lugar], "lugar": lugar,
				"causas": [causa], "dados": {"importancia": 0.8, "mudancas": [{"op": "morrer", "quem": p}]}}))
		elif not vital and rng.randf() < 0.3:
			novos.append(Simulador.registrar(u, {"tipo": "fome", "descricao": "%s está fraco de fome." % u.entidade(p)["nome"], "sujeitos": [p], "lugar": lugar,
				"causas": [causa], "dados": {"importancia": 0.15, "mudancas": [{"op": "ferir", "quem": p, "descricao": "fraqueza de fome", "gravidade": 0.1}]}}))
	# Alguém sem escrúpulo rouba o pouco que resta.
	if not vital and rng.randf() < 0.35:
		var ladrao := ""
		for p in gente:
			var t := Personalidade.tracos(u, p)
			if float(t["empatia"]) < 0.4 and float(t["ambicao"]) > 0.5:
				ladrao = p
		if ladrao != "":
			var ops: Array = []
			for p in gente:
				if p != ladrao:
					ops.append({"op": "relacao", "de": p, "para": ladrao, "deltas": {"raiva": 0.25, "confianca": -0.3}})
			novos.append(Simulador.registrar(u, {"tipo": "roubo", "descricao": "%s roubou o pouco de %s que restava. Os outros descobriram." % [u.entidade(ladrao)["nome"], palavra], "sujeitos": [ladrao, lugar], "lugar": lugar,
				"causas": [causa], "dados": {"importancia": 0.55, "mudancas": ops}}))
	return novos.filter(func(x): return x != "")


static func _causa(u: Universo, lugar: String, nome: String) -> String:
	var ids := u.fatos.ids_sobre(lugar)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and str(f["dados"].get("recurso", "")) == nome:
			return f["id"]
	return ""


static func _palavra(nome: String) -> String:
	return {"comida": "a comida", "agua": "a água", "oxigenio": "o oxigênio", "ar": "o ar", "lenha": "a lenha", "remedio": "o remédio", "combustivel": "o combustível", "energia": "a energia"}.get(nome, "o " + nome if not nome.ends_with("a") else "a " + nome)


static func resumo(u: Universo, lugar: String) -> String:
	var partes: Array = []
	for nome in de(u, lugar):
		var r: Dictionary = de(u, lugar)[nome]
		partes.append("%s: reserva para %d dias%s" % [_palavra(nome).split(" ")[1], int(r["reserva"]), " (sem fonte)" if str(r.get("fonte", "")) == "nenhuma" else ""])
	return "; ".join(partes)
