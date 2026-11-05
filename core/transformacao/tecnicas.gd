class_name Tecnicas
extends RefCounted
## Criações dos personagens: técnicas de luta, feitiços e invenções. Uma técnica nova
## passa a existir no mundo (vira entidade na wiki), com nome e criador. Pode ser
## ensinada (a discípulos, filhos, amigos, numa escola), aperfeiçoada, roubada e até
## esquecida quando o último que a conhecia morre — e redescoberta séculos depois,
## às vezes nos vestígios que ficaram (um pergaminho nas ruínas).
## Escolas surgem em volta de técnicas, disputam alunos e podem ser proibidas.
## Quem conhece o quê fica no estado (por operações), e cada passo vira fato com causa.

const TIPOS := {
	"luta": {"nomes1": ["Punho", "Passo", "Lâmina", "Golpe", "Garra", "Dança", "Grito", "Escudo"],
		"nomes2": ["do Trovão", "da Névoa", "do Lobo", "das Cinzas", "do Vento Norte", "da Pedra", "do Rio", "da Lua Partida"], "tipo": "técnica de luta"},
	"magia": {"nomes1": ["Selo", "Chama", "Véu", "Canto", "Círculo", "Espelho", "Olho", "Sopro"],
		"nomes2": ["de Prata", "do Esquecimento", "das Sete Luas", "da Aurora", "do Abismo", "de Vidro", "da Serpente", "do Inverno"], "tipo": "feitiço"},
	"oficio": {"nomes1": ["Moinho", "Arado", "Forja", "Roda", "Aqueduto", "Tear", "Lente", "Arco"],
		"nomes2": ["de Ferro", "de Vento", "de Água", "Dupla", "de Bronze", "Comprido", "de Três Dentes", "Giratório"], "tipo": "invenção"},
}


# ---------------------------------------------------------------- consultas

static func eh_tecnica(u: Universo, eid: String) -> bool:
	return u.estado(eid).has("tecnica")


static func todas(u: Universo) -> Array:
	return u.entidades_ativas().filter(func(e): return e.get("sim", {}).has("tecnica")).map(func(e): return e["id"])


static func conhecem(u: Universo, t: String) -> Array:
	return Array(u.estado(t).get("conhecem", [])).filter(func(x): return u.entidades.has(x) and Estado.vivo(u, x))


static func de(u: Universo, eid: String) -> Array:
	return Array(u.estado(eid).get("tecnicas", [])).filter(func(t): return u.entidades.has(t))


static func perdida(u: Universo, t: String) -> bool:
	return u.estado(t).get("perdida", false)


static func categoria(u: Universo, t: String) -> String:
	return str(u.estado(t).get("tecnica", {}).get("cat", "luta"))


# ---------------------------------------------------------------- operações

static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	match str(op.get("op", "")):
		"tecnica_nova":
			var t := str(op.get("tecnica", ""))
			if u.entidades.has(t):
				u.estado(t)["tecnica"] = {"cat": str(op.get("cat", "luta")), "criador": str(op.get("criador", "")), "fato": fato.get("id", "")}
				u.estado(t)["conhecem"] = []
				u.estado(t)["perdida"] = false
				u.versao += 1
			return true
		"aprender":
			var t2 := str(op.get("tecnica", ""))
			var q := str(op.get("quem", ""))
			if u.entidades.has(t2) and u.entidades.has(q):
				var c: Array = u.estado(t2).get("conhecem", [])
				if not c.has(q):
					c.append(q)
				u.estado(t2)["conhecem"] = c
				var ts: Array = u.estado(q).get("tecnicas", [])
				if not ts.has(t2):
					ts.append(t2)
				u.estado(q)["tecnicas"] = ts
				u.estado(t2)["perdida"] = false
			return true
		"tecnica_perdida":
			var t3 := str(op.get("tecnica", ""))
			if u.entidades.has(t3):
				u.estado(t3)["perdida"] = true
				u.estado(t3)["vestigio"] = str(op.get("vestigio", ""))
				u.estado(t3)["perdida_em"] = DataMundo.ordem(fato.get("data", u.relogio))
			return true
	return false


# ---------------------------------------------------------------- criar

## Alguém inventa uma técnica. Devolve o id do fato.
static func inventar(u: Universo, eid: String, rng: RandomNumberGenerator, cat: String = "", nome: String = "") -> String:
	if cat == "":
		cat = _categoria_de(u, eid)
	var def: Dictionary = TIPOS[cat]
	if nome == "":
		for i in 10:
			nome = "%s %s" % [def["nomes1"][rng.randi() % def["nomes1"].size()], def["nomes2"][rng.randi() % def["nomes2"].size()]]
			if not u.entidades_ativas().any(func(e): return e["nome"] == nome):
				break
	var lugar := str(u.estado(eid).get("local", ""))
	var forca := 2 + rng.randi() % 4
	var campos: Array = [{"chave": "criador", "valor": u.entidade(eid)["nome"]}]
	if cat == "oficio":
		campos.append({"chave": "efeito", "valor": "lavouras crescem 10%"})
	else:
		campos.append({"chave": "força", "valor": str(forca)})
	if lugar != "":
		campos.append({"chave": "origem", "valor": u.entidade(lugar)["nome"]})
	var causa := _causa(u, eid)
	var t := u.criar_entidade(nome, def["tipo"], [], campos, [causa] if causa != "" else [])
	return Simulador.registrar(u, {"tipo": "invenção", "lugar": lugar, "sujeitos": [eid, t], "causas": [causa] if causa != "" else [],
		"descricao": "%s criou %s: %s." % [u.entidade(eid)["nome"], {"luta": "uma técnica de luta", "magia": "um feitiço novo", "oficio": "uma invenção"}[cat], nome],
		"dados": {"importancia": 0.65, "tecnica": t, "mudancas": [{"op": "tecnica_nova", "tecnica": t, "cat": cat, "criador": eid},
			{"op": "aprender", "tecnica": t, "quem": eid}, {"op": "mudar", "quem": eid, "chave": "reputacao", "delta": 0.4}]}})


static func _categoria_de(u: Universo, eid: String) -> String:
	for o in Estado.objetivos_ativos(u, eid):
		var tp := TextUtil.normalizar(str(o["tipo"]))
		if tp == "saber":
			return "magia" if float(Cosmos.leis(u)["magia"]) >= 0.3 else "oficio"
		if tp == "riqueza":
			return "oficio"
		if tp in ["forca", "poder"] or tp.begins_with("vingan"):
			return "luta"
	var of := TextUtil.normalizar(u.valor_campo(eid, "ofício") + " " + u.valor_campo(eid, "profissão"))
	if of.contains("mago") or of.contains("feitic") or of.contains("sacerd"):
		return "magia"
	if of.contains("ferreir") or of.contains("lavrad") or of.contains("artes") or of.contains("constru"):
		return "oficio"
	return "luta"


static func _causa(u: Universo, eid: String) -> String:
	for o in Estado.objetivos_ativos(u, eid):
		if u.fatos.existe(str(o.get("fato", ""))):
			return str(o["fato"])
	return Simulador.causa_de_presenca(u, eid)


# ---------------------------------------------------------------- o passo

static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var agora := DataMundo.ordem(u.relogio)
	var ctrl: Dictionary = u.extra("tecnicas_ctrl", {"mes": -999, "ano": -999})
	var mes := agora - int(ctrl["mes"]) >= 28
	var ano := agora - int(ctrl["ano"]) >= DataMundo.DIAS_POR_ANO
	if not mes:
		return novos
	ctrl["mes"] = agora
	var lista := todas(u)
	# Esquecidas: o último que conhecia morreu.
	for t in lista:
		if not perdida(u, t) and conhecem(u, t).is_empty() and not Array(u.estado(t).get("conhecem", [])).is_empty():
			novos.append(_perder(u, t))
	# Ensinar.
	for t in lista:
		if not perdida(u, t):
			novos.append_array(_ensinar(u, t, rng))
	# Inventar (gente curiosa, com um objetivo).
	for eid in Simulador._mentes(u):
		var tr := Personalidade.tracos(u, eid)
		if float(tr["curiosidade"]) < 0.6 or Estado.idade(u, eid) < 16 or de(u, eid).size() >= 3:
			continue
		var p := 0.0012 * Diretor.fator(u, "invencao") * float(tr["curiosidade"]) * (1.0 + float(tr["ambicao"])) * (2.0 if Simulador.detalhe(u, eid) == "alto" else 1.0)
		if rng.randf() < p:
			novos.append(inventar(u, eid, rng))
	if ano:
		ctrl["ano"] = agora
		for t in lista:
			if perdida(u, t):
				novos.append(_redescobrir(u, t, rng))
			else:
				novos.append_array(_aperfeicoar_e_roubar(u, t, rng))
				novos.append(_fundar_escola(u, t, rng))
				novos.append_array(_efeito_do_oficio(u, t))
		novos.append_array(Escolas.passo(u, rng))
	return novos.filter(func(x): return x != "")


static func _ultimo_fato(u: Universo, t: String) -> String:
	var ids := u.fatos.ids_sobre(t)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"]:
			return f["id"]
	return str(u.entidade(t).get("fato_criacao", ""))


## A quem ensinar: discípulos, filhos, cônjuges e amigos próximos no mesmo lugar.
static func _ensinar(u: Universo, t: String, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var secreta: Variant = TextUtil.normalizar(u.valor_campo(t, "segredo") + " " + u.valor_campo(t, "secreta")) != "" or u.entidade(t)["campos"].any(func(c): return TextUtil.normalizar(c["valor"]).contains("secreta"))
	for mestre in conhecem(u, t):
		if Motor.dormindo(u, mestre):
			continue
		var fam: Dictionary = u.estado(mestre)["familia"]
		var cands: Array = []
		for d in fam["discipulos"]:
			cands.append([d, 0.25])
		for f in fam["filhos"]:
			cands.append([f, 0.12])
		if not secreta:
			for outro in u.estado(mestre)["relacoes"]:
				if Estado.valor_relacao(u, mestre, outro, "afeto") >= 0.5:
					cands.append([outro, 0.04])
		for c in cands:
			var aluno: String = c[0]
			if not u.entidades.has(aluno) or not Estado.vivo(u, aluno) or conhecem(u, t).has(aluno) or Estado.idade(u, aluno) < 10:
				continue
			if u.estado(aluno)["local"] != u.estado(mestre)["local"]:
				continue
			if rng.randf() < float(c[1]):
				novos.append(Simulador.registrar(u, {"tipo": "ensino de técnica", "lugar": u.estado(mestre)["local"], "sujeitos": [mestre, aluno, t],
					"causas": [_ultimo_fato(u, t)], "descricao": "%s ensinou %s a %s." % [u.entidade(mestre)["nome"], u.entidade(t)["nome"], u.entidade(aluno)["nome"]],
					"dados": {"importancia": 0.4, "mudancas": [{"op": "aprender", "tecnica": t, "quem": aluno},
						{"op": "relacao", "de": aluno, "para": mestre, "deltas": {"respeito": 0.3}}]}}))
				break
	return novos


static func _perder(u: Universo, t: String) -> String:
	# O último que conhecia: quem morreu por último.
	var ultimo := ""
	var quando := -1
	for q in u.estado(t).get("conhecem", []):
		var fm := Sociedades._fato_da_morte(u, q)
		var seq := int(u.fatos.obter(fm).get("seq", -1)) if fm != "" else -1
		if seq > quando:
			quando = seq
			ultimo = q
	var causa := Sociedades._fato_da_morte(u, ultimo) if ultimo != "" else ""
	var lugar := str(u.estado(ultimo).get("local", "")) if ultimo != "" else ""
	return Simulador.registrar(u, {"tipo": "técnica perdida", "lugar": lugar, "sujeitos": [t] + ([ultimo] if ultimo != "" else []),
		"causas": [causa] if u.fatos.existe(causa) else [_ultimo_fato(u, t)],
		"descricao": "%s se perdeu%s: ninguém mais sabe fazê-la." % [u.entidade(t)["nome"], (" com a morte de " + u.entidade(ultimo)["nome"]) if ultimo != "" else ""],
		"dados": {"importancia": 0.6, "mudancas": [{"op": "tecnica_perdida", "tecnica": t, "vestigio": lugar}]}})


## Redescoberta: alguém curioso, de preferência onde ficaram os vestígios (ou nas ruínas).
static func _redescobrir(u: Universo, t: String, rng: RandomNumberGenerator) -> String:
	var vest := str(u.estado(t).get("vestigio", ""))
	var anos := (DataMundo.ordem(u.relogio) - int(u.estado(t).get("perdida_em", DataMundo.ordem(u.relogio)))) / float(DataMundo.DIAS_POR_ANO)
	if anos < 1:
		return ""
	var melhor := ""
	var chance := 0.0
	for eid in Simulador._mentes(u):
		var tr := Personalidade.tracos(u, eid)
		var c := 0.004 * float(tr["curiosidade"])
		var onde := str(u.estado(eid).get("local", ""))
		if vest != "" and (onde == vest or Mapa.ancestrais(u, vest).has(onde) or Mapa.ancestrais(u, onde).has(vest)):
			c *= 8.0
		if Cidades.em_ruinas(u, onde):
			c *= 2.0
		if _categoria_de(u, eid) == categoria(u, t):
			c *= 1.5
		if c > chance:
			chance = c
			melhor = eid
	if melhor == "" or rng.randf() > chance:
		return ""
	var perda := ""
	var ids := u.fatos.ids_sobre(t)
	for i in range(ids.size() - 1, -1, -1):
		if u.fatos.obter(ids[i])["tipo"] == "técnica perdida" and u.fatos.obter(ids[i])["canon"]:
			perda = ids[i]
			break
	var onde_txt := ""
	if vest != "" and str(u.estado(melhor).get("local", "")) == vest:
		onde_txt = " nos vestígios deixados em %s" % u.entidade(vest)["nome"]
	return Simulador.registrar(u, {"tipo": "redescoberta", "lugar": u.estado(melhor).get("local", ""), "sujeitos": [melhor, t],
		"causas": [perda] if perda != "" else [_ultimo_fato(u, t)],
		"descricao": "%s redescobriu %s%s, perdida havia %d ano%s." % [u.entidade(melhor)["nome"], u.entidade(t)["nome"], onde_txt, int(anos), "" if int(anos) == 1 else "s"],
		"dados": {"importancia": 0.7, "mudancas": [{"op": "aprender", "tecnica": t, "quem": melhor}, {"op": "mudar", "quem": melhor, "chave": "reputacao", "delta": 0.6}]}})


## Aperfeiçoar (gente curiosa) e roubar (gente ambiciosa e fria que vê a técnica de perto).
static func _aperfeicoar_e_roubar(u: Universo, t: String, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for q in conhecem(u, t):
		var tr := Personalidade.tracos(u, q)
		if float(tr["curiosidade"]) > 0.65 and rng.randf() < 0.08:
			novos.append(Simulador.registrar(u, {"tipo": "técnica aperfeiçoada", "sujeitos": [q, t], "lugar": u.estado(q)["local"], "causas": [_ultimo_fato(u, t)],
				"descricao": "%s aperfeiçoou %s." % [u.entidade(q)["nome"], u.entidade(t)["nome"]],
				"dados": {"importancia": 0.35, "mudancas": [{"op": "mudar", "quem": t, "chave": "nivel", "delta": 1.0}]}}))
		for ladrao in Natureza._mentes_em(u, str(u.estado(q)["local"])):
			if ladrao == q or conhecem(u, t).has(ladrao) or Estado.familia_proxima(u, q).has(ladrao):
				continue
			var tl := Personalidade.tracos(u, ladrao)
			if float(tl["empatia"]) < 0.35 and float(tl["ambicao"]) > 0.6 and rng.randf() < 0.03:
				novos.append(Simulador.registrar(u, {"tipo": "técnica roubada", "sujeitos": [ladrao, q, t], "lugar": u.estado(q)["local"], "causas": [_ultimo_fato(u, t)],
					"descricao": "%s roubou o segredo de %s, de %s." % [u.entidade(ladrao)["nome"], u.entidade(t)["nome"], u.entidade(q)["nome"]],
					"dados": {"importancia": 0.55, "mudancas": [{"op": "aprender", "tecnica": t, "quem": ladrao},
						{"op": "relacao", "de": q, "para": ladrao, "deltas": {"raiva": 0.6, "confianca": -0.5}}]}}))
				break
	return novos


## Uma escola nasce quando três ou mais conhecem a técnica no mesmo lugar.
static func _fundar_escola(u: Universo, t: String, rng: RandomNumberGenerator) -> String:
	if Escolas.da_tecnica(u, t) != "":
		return ""
	var por_lugar := {}
	for q in conhecem(u, t):
		var l := str(u.estado(q)["local"])
		por_lugar[l] = Array(por_lugar.get(l, [])) + [q]
	for l in por_lugar:
		if l == "" or por_lugar[l].size() < 3:
			continue
		var fundador: String = por_lugar[l][0]
		for q in por_lugar[l]:
			if float(Personalidade.tracos(u, q)["sociabilidade"]) > float(Personalidade.tracos(u, fundador)["sociabilidade"]):
				fundador = q
		if rng.randf() < 0.5:
			return Escolas.fundar(u, t, fundador, l, [_ultimo_fato(u, t)])
	return ""


## Invenções de ofício melhoram a terra de onde há quem as use.
static func _efeito_do_oficio(u: Universo, t: String) -> Array:
	if categoria(u, t) != "oficio":
		return []
	var lugares := {}
	for q in conhecem(u, t):
		lugares[str(u.estado(q)["local"])] = true
	for l in lugares:
		if l != "" and Natureza.tem_natureza(u, l):
			var esp: Dictionary = Natureza.de(u, l)["especies"].get("lavouras", {})
			if not esp.is_empty():
				esp["n"] = clampf(float(esp["n"]) + 0.03, 0.0, 1.5)
	return []
