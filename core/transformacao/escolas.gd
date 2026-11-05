class_name Escolas
extends RefCounted
## Escolas, academias e linhagens: nascem em volta de uma técnica, ensinam alunos
## todo ano, disputam alunos com outras escolas do mesmo lugar e podem ser proibidas
## (uma escola de magia onde a magia é proibida). Quando a linhagem morre, a técnica
## pode se perder.


static func todas(u: Universo) -> Array:
	return u.entidades_ativas().filter(func(e): return e.get("sim", {}).has("escola")).map(func(e): return e["id"])


static func da_tecnica(u: Universo, t: String) -> String:
	for e in todas(u):
		if str(u.estado(e)["escola"].get("tecnica", "")) == t:
			return e
	return ""


static func fundar(u: Universo, t: String, fundador: String, lugar: String, causas: Array) -> String:
	var nome := "Escola %s" % _de(u.entidade(t)["nome"])
	var e := u.criar_entidade(nome, "escola", [], [{"chave": "fundador", "valor": u.entidade(fundador)["nome"]},
		{"chave": "ensina", "valor": u.entidade(t)["nome"]}, {"chave": "sede", "valor": u.entidade(lugar)["nome"]}], causas)
	return Simulador.registrar(u, {"tipo": "escola fundada", "lugar": lugar, "sujeitos": [fundador, e, t], "causas": causas,
		"descricao": "%s fundou a %s em %s." % [u.entidade(fundador)["nome"], nome, u.entidade(lugar)["nome"]],
		"dados": {"importancia": 0.55, "mudancas": [{"op": "definir", "quem": e, "chave": "escola", "valor": {"tecnica": t, "sede": lugar, "fundador": fundador}},
			{"op": "mudar", "quem": fundador, "chave": "reputacao", "delta": 0.5}]}})


## "Punho do Trovão" → "do Punho do Trovão"; "Selo de Prata" → "do Selo de Prata".
static func _de(nome: String) -> String:
	var fem := ["Lâmina", "Dança", "Garra", "Chama", "Forja", "Roda", "Lente"]
	return ("da " if fem.has(nome.split(" ")[0]) else "do ") + nome


static func passo(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var por_sede := {}
	for e in todas(u):
		var esc: Dictionary = u.estado(e)["escola"]
		if esc.get("proibida", false) or esc.get("fechada", false):
			continue
		var sede := str(esc["sede"])
		var t := str(esc["tecnica"])
		# Proibida? (a lei da sociedade proíbe magia e a técnica é um feitiço)
		var sid := Sociedades.de_lugar(u, sede)
		if sid != "" and Tecnicas.categoria(u, t) == "magia" and u.estado(sid).get("leis_feitas", {}).keys().any(func(k): return TextUtil.normalizar(k).contains("magia") and TextUtil.normalizar(k).contains("proib")):
			novos.append(Simulador.registrar(u, {"tipo": "escola proibida", "lugar": sede, "sujeitos": [e, sid], "causas": [str(u.entidade(e).get("fato_criacao", ""))],
				"descricao": "%s proibiu a %s." % [u.entidade(sid)["nome"], u.entidade(e)["nome"]],
				"dados": {"importancia": 0.55, "mudancas": [{"op": "definir", "quem": e, "chave": "escola", "valor": _com(esc, "proibida", true)}]}}))
			continue
		# Sem mestres vivos, a escola fecha.
		var mestres: Array = Tecnicas.conhecem(u, t).filter(func(q): return str(u.estado(q)["local"]) == sede)
		if mestres.is_empty():
			novos.append(Simulador.registrar(u, {"tipo": "escola fechada", "lugar": sede, "sujeitos": [e], "causas": [str(u.entidade(e).get("fato_criacao", ""))],
				"descricao": "A %s fechou as portas: não restou mestre." % u.entidade(e)["nome"],
				"dados": {"importancia": 0.45, "mudancas": [{"op": "definir", "quem": e, "chave": "escola", "valor": _com(esc, "fechada", true)}]}}))
			continue
		por_sede[sede] = Array(por_sede.get(sede, [])) + [e]
	# Cada sede: os jovens escolhem a escola de mais fama (as escolas disputam alunos).
	for sede in por_sede:
		var escolas: Array = por_sede[sede]
		escolas.sort_custom(func(a, b): return _fama(u, a) > _fama(u, b))
		var jovens: Array = Natureza._mentes_em(u, sede).filter(func(m): return Estado.idade(u, m) >= 12 and Estado.idade(u, m) <= 30)
		for e in escolas:
			var t := str(u.estado(e)["escola"]["tecnica"])
			var livres: Array = jovens.filter(func(m): return not Tecnicas.conhecem(u, t).has(m))
			if livres.is_empty() or rng.randf() > 0.6:
				continue
			var aluno: String = livres[rng.randi() % livres.size()]
			jovens.erase(aluno)
			var mestre: String = Tecnicas.conhecem(u, t).filter(func(q): return str(u.estado(q)["local"]) == sede)[0]
			novos.append(Simulador.registrar(u, {"tipo": "aluno", "lugar": sede, "sujeitos": [aluno, e, mestre, t], "causas": [Tecnicas._ultimo_fato(u, t)],
				"descricao": "%s entrou na %s e aprendeu %s com %s." % [u.entidade(aluno)["nome"], u.entidade(e)["nome"], u.entidade(t)["nome"], u.entidade(mestre)["nome"]],
				"dados": {"importancia": 0.3, "mudancas": [{"op": "aprender", "tecnica": t, "quem": aluno},
					{"op": "vinculo", "quem": mestre, "tipo": "discipulos", "outro": aluno}, {"op": "vinculo", "quem": aluno, "tipo": "mestres", "outro": mestre}]}}))
	return novos


static func _com(d: Dictionary, k: String, v) -> Dictionary:
	var c := d.duplicate()
	c[k] = v
	return c


static func _fama(u: Universo, e: String) -> float:
	var t := str(u.estado(e)["escola"]["tecnica"])
	var f := float(Tecnicas.conhecem(u, t).size())
	for q in Tecnicas.conhecem(u, t):
		f += float(u.estado(q).get("reputacao", 0.0)) * 0.3
	return f
