class_name Obras
extends RefCounted
## Obras dentro do universo: o mundo produz a sua própria literatura. Escritores
## publicam livros, poetas compõem canções, historiadores escrevem crônicas, pintores
## retratam acontecimentos, músicos criam hinos, dramaturgos levam guerras ao palco.
##
## Cada obra é uma entidade com autor, data, tema (ligado aos fatos reais que retrata),
## estilo e viés (o que o autor sabia, sentia e queria mostrar). Pode ser copiada,
## proibida, queimada, perdida e reencontrada. Quem a encontra, séculos depois, lê com
## os valores do seu tempo — e as duas versões passam a circular e mudar a cultura.
## O texto em si: resumo e trechos-modelo; a IA local escreve mais, se ligada.

const TIPOS := {
	"livro": {"palavras": ["escritor", "escritora", "poeta", "cronista", "historiador", "historiadora", "escriba", "erudito", "monge", "soldado", "veterano"], "nome": "livro"},
	"cancao": {"palavras": ["bardo", "menestrel", "cantor", "cantora", "musico", "musica", "trovador"], "nome": "canção"},
	"pintura": {"palavras": ["pintor", "pintora", "artista", "retratista"], "nome": "pintura"},
	"peca": {"palavras": ["dramaturgo", "dramaturga", "ator", "atriz", "comediante"], "nome": "peça"},
	"hino": {"palavras": ["sacerdote", "sacerdotisa", "profeta"], "nome": "hino"},
}
const TITULOS := {
	"livro": ["Memórias %s", "Crônica %s", "Cinzas %s", "O Que Restou %s"],
	"cancao": ["A Balada %s", "Canção %s", "O Lamento %s"],
	"pintura": ["O Último Dia %s", "Retrato %s"],
	"peca": ["A Tragédia %s", "Os Dias %s"],
	"hino": ["Hino %s", "Louvor %s"],
}
const FEMININAS := ["guerra", "conquista", "batalha", "noite", "areia", "areias", "vingança", "fome", "revolta", "queda", "aliança", "colina", "cidade"]


## "Conquista de Sokovia" → "da Conquista de Sokovia"; "Sokov" → "de Sokov"; "A Noite dos…" → "da Noite dos…".
static func _de(nome: String) -> String:
	var p := nome.split(" ", false)
	if p.is_empty():
		return "de " + nome
	var w := str(p[0]).to_lower()
	if w in ["a", "as"]:
		return "d" + w + " " + " ".join(p.slice(1))
	if w in ["o", "os"]:
		return "d" + w + " " + " ".join(p.slice(1))
	if FEMININAS.has(TextUtil.normalizar(w)):
		return "da " + nome
	if p.size() > 1 and w == w.to_lower():
		return "do " + nome
	return "de " + nome


static func eh_obra(u: Universo, eid: String) -> bool:
	return u.estado(eid).has("obra")


static func todas(u: Universo) -> Array:
	return u.entidades_ativas().filter(func(e): return e.get("sim", {}).has("obra")).map(func(e): return e["id"])


static func dados(u: Universo, o: String) -> Dictionary:
	return u.estado(o).get("obra", {})


static func _tipo_do_autor(u: Universo, eid: String) -> String:
	var of := TextUtil.normalizar(u.valor_campo(eid, "ofício") + " " + u.valor_campo(eid, "profissão") + " " + u.entidade(eid)["tipo"])
	for t in TIPOS:
		for w in TIPOS[t]["palavras"]:
			if of.contains(w):
				return t
	if Pecas.marcas(u, eid).any(func(m): return str(m).begins_with("veterano")):
		return "livro"
	return ""


# ---------------------------------------------------------------- escrever

## O viés do autor sobre um fato: quem ele odeia, ama e teme entre os envolvidos.
static func vies(u: Universo, autor: String, f: Dictionary) -> Dictionary:
	var odeia: Array = []
	var ama: Array = []
	var envolvidos: Array = Array(f["sujeitos"])
	# Numa guerra, os lados contam como envolvidos.
	var g := str(f["dados"].get("guerra", ""))
	if g != "" and not Guerras.dados(u, g).is_empty():
		envolvidos.append_array(Guerras.dados(u, g)["a"] + Guerras.dados(u, g)["b"])
	var minha := Sociedades.de_lugar(u, str(u.estado(autor).get("local", "")))
	for s in envolvidos:
		if s == autor or not u.entidades.has(s):
			continue
		var raiva := Estado.valor_relacao(u, autor, s, "raiva")
		if Sociedades.eh_sociedade(u, s):
			raiva = maxf(raiva, Guerras.rancor(u, minha, s) if minha != "" else 0.0)
			if g != "" and minha != "" and Guerras.lado_de(u, g, minha) != "" and Guerras.lado_de(u, g, s) != "" and Guerras.lado_de(u, g, minha) != Guerras.lado_de(u, g, s):
				raiva = maxf(raiva, 0.7)
		if raiva >= 0.5:
			odeia.append(s)
		elif Estado.valor_relacao(u, autor, s, "afeto") >= 0.5 or s == minha:
			ama.append(s)
	# Sem repetição; os povos na frente das pessoas.
	var unicos: Array = []
	for x in odeia:
		if not unicos.has(x):
			unicos.append(x)
	odeia = unicos
	odeia.sort_custom(func(a, b): return Sociedades.eh_sociedade(u, a) and not Sociedades.eh_sociedade(u, b))
	var povos: Array = odeia.filter(func(x): return Sociedades.eh_sociedade(u, x))
	var palavra := ""
	if not povos.is_empty():
		palavra = "ódio aos de %s" % ", ".join(povos.map(func(x): return u.entidade(x)["nome"]))
	elif not odeia.is_empty():
		palavra = "ódio a %s" % ", ".join(odeia.map(func(x): return u.entidade(x)["nome"]))
	else:
		palavra = "saudade e orgulho" if not ama.is_empty() else "um olhar distante"
	return {"odeia": odeia, "ama": ama, "texto": palavra}


## Alguém cria uma obra sobre um fato que viveu ou conhece. Devolve o id do fato.
static func criar(u: Universo, autor: String, tema: String, rng: RandomNumberGenerator, tipo: String = "") -> String:
	var f := u.fatos.obter(tema)
	if f.is_empty():
		return ""
	if tipo == "":
		tipo = _tipo_do_autor(u, autor)
		if tipo == "":
			tipo = "livro"
	var sobre := _sobre(u, f)
	var titulos: Array = TITULOS[tipo]
	var titulo := (titulos[rng.randi() % titulos.size()] as String) % _de(sobre)
	var v := vies(u, autor, f)
	var estilo := "amargo" if not v["odeia"].is_empty() else ("épico" if float(Personalidade.tracos(u, autor)["orgulho"]) > 0.6 else "sereno")
	var resumo := "%s conta %s, com %s." % [u.entidade(autor)["nome"], _primeira_minuscula(f["descricao"].trim_suffix(".")), v["texto"]]
	var o := u.criar_entidade(titulo, TIPOS[tipo]["nome"], [], [{"chave": "autor", "valor": u.entidade(autor)["nome"]}, {"chave": "tema", "valor": f["descricao"]},
		{"chave": "estilo", "valor": estilo}, {"chave": "viés", "valor": v["texto"]}, {"chave": "resumo", "valor": resumo}], [tema])
	var lugar := str(u.estado(autor).get("local", ""))
	return Simulador.registrar(u, {"tipo": "obra", "lugar": lugar, "sujeitos": [autor, o], "causas": [tema],
		"descricao": "%s %s \"%s\"." % [u.entidade(autor)["nome"], {"livro": "escreveu o livro", "cancao": "compôs a canção", "pintura": "pintou o quadro", "peca": "escreveu a peça", "hino": "compôs o hino"}[tipo], titulo],
		"dados": {"importancia": 0.5, "mudancas": [{"op": "definir", "quem": o, "chave": "obra", "valor": {"autor": autor, "tipo": tipo, "tema": tema, "vies": v,
			"povo": Sociedades.de_lugar(u, lugar),
			"copias": {lugar: 1} if lugar != "" else {}, "leituras": [{"por": autor, "texto": resumo, "ano": int(u.relogio["ano"]), "original": true}]}}]}})


static func _sobre(u: Universo, f: Dictionary) -> String:
	var g := str(f["dados"].get("guerra", ""))
	if g != "" and u.entidades.has(g):
		return u.entidade(g)["nome"]
	if f["dados"].has("nome"):
		return str(f["dados"]["nome"])
	if f["lugar"] != "" and u.entidades.has(f["lugar"]):
		return u.entidade(f["lugar"])["nome"]
	for s in f["sujeitos"]:
		if u.entidades.has(s):
			return u.entidade(s)["nome"]
	return "um tempo antigo"


static func _primeira_minuscula(t: String) -> String:
	return t.substr(0, 1).to_lower() + t.substr(1) if t != "" else t


# ---------------------------------------------------------------- a vida das obras

static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	match str(op.get("op", "")):
		"obra_copias":
			var o := str(op.get("obra", ""))
			if u.entidades.has(o) and u.estado(o).has("obra"):
				var c: Dictionary = u.estado(o)["obra"].get("copias", {})
				var l := str(op.get("lugar", ""))
				c[l] = maxi(0, int(c.get(l, 0)) + int(op.get("delta", 0)))
				if int(c[l]) == 0:
					c.erase(l)
				u.estado(o)["obra"]["copias"] = c
			return true
		"obra_estado":
			var o2 := str(op.get("obra", ""))
			if u.entidades.has(o2) and u.estado(o2).has("obra"):
				u.estado(o2)["obra"][str(op.get("chave", ""))] = op.get("valor")
			return true
		"obra_leitura":
			var o3 := str(op.get("obra", ""))
			if u.entidades.has(o3) and u.estado(o3).has("obra"):
				var ls: Array = u.estado(o3)["obra"].get("leituras", [])
				ls.append(op.get("leitura", {}))
				u.estado(o3)["obra"]["leituras"] = ls
			return true
	return false


static func copias(u: Universo, o: String) -> int:
	var t := 0
	for l in dados(u, o).get("copias", {}):
		t += int(dados(u, o)["copias"][l])
	return t


static func perdida(u: Universo, o: String) -> bool:
	return copias(u, o) == 0


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("obras_ctrl", {"t": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < DataMundo.DIAS_POR_ANO:
		return []
	ctrl["t"] = agora
	var novos: Array = []
	# Criar: artistas e veteranos escrevem sobre o que viveram.
	for eid in Simulador._mentes(u):
		var tipo := _tipo_do_autor(u, eid)
		if tipo == "" or rng.randf() > 0.12 * Diretor.fator(u, "obra"):
			continue
		var tema := _tema(u, eid)
		if tema != "":
			novos.append(criar(u, eid, tema, rng, tipo))
	for o in todas(u):
		var d := dados(u, o)
		if perdida(u, o):
			novos.append(_reencontrar(u, o, rng))
			continue
		var lugares: Array = d.get("copias", {}).keys()
		var copiado := {}
		for l in lugares:
			if not u.entidades.has(l):
				continue
			# Guerra e ocupação: a obra pode ser queimada.
			if u.estado(l).has("ocupado_por") and not d.get("vies", {}).get("odeia", []).is_empty() and Array(d["vies"]["odeia"]).has(str(u.estado(l)["ocupado_por"])) and rng.randf() < 0.5:
				novos.append(Simulador.registrar(u, {"tipo": "obra queimada", "lugar": l, "sujeitos": [o, str(u.estado(l)["ocupado_por"])], "causas": [Guerras._ultimo_fato(u, Guerras.lugares_em_guerra(u).get(l, ""))] if Guerras.lugares_em_guerra(u).has(l) else [],
					"descricao": "Os ocupantes queimaram as cópias de \"%s\" em %s." % [u.entidade(o)["nome"], u.entidade(l)["nome"]],
					"dados": {"importancia": 0.45, "mudancas": [{"op": "obra_copias", "obra": o, "lugar": l, "delta": -99}]}}))
				continue
			# O tempo apaga: lugares em ruínas perdem as cópias aos poucos.
			if Cidades.em_ruinas(u, l) and rng.randf() < 0.3:
				novos.append(Simulador.registrar(u, {"tipo": "obra perdida", "lugar": l, "sujeitos": [o, l], "causas": [Fios._ultimo_fato(u, o), Fios._ultimo_fato(u, l)],
					"descricao": "As últimas cópias de \"%s\" ficaram esquecidas nas ruínas de %s." % [u.entidade(o)["nome"], u.entidade(l)["nome"]],
					"dados": {"importancia": 0.35, "mudancas": [{"op": "obra_copias", "obra": o, "lugar": l, "delta": -99}, {"op": "obra_estado", "obra": o, "chave": "vestigio", "valor": l}]}}))
				continue
			# Proibida onde o governo é odiado pela obra.
			var sid := Sociedades.de_lugar(u, l)
			if sid != "" and Array(d.get("vies", {}).get("odeia", [])).has(sid) and not d.get("proibida_em", {}).has(sid) and rng.randf() < 0.4:
				var pr: Dictionary = d.get("proibida_em", {}).duplicate()
				pr[sid] = true
				novos.append(Simulador.registrar(u, {"tipo": "obra proibida", "lugar": l, "sujeitos": [o, sid], "causas": [str(u.entidade(o).get("fato_criacao", ""))],
					"descricao": "%s proibiu \"%s\"." % [u.entidade(sid)["nome"], u.entidade(o)["nome"]],
					"dados": {"importancia": 0.4, "mudancas": [{"op": "obra_estado", "obra": o, "chave": "proibida_em", "valor": pr}]}}))
				continue
			# Copiada: a obra se espalha para o vizinho (se não for proibida lá).
			if rng.randf() < 0.25:
				var viz := Aventura._vizinho(u, l)
				if viz != "" and not copiado.has(viz) and not d.get("proibida_em", {}).has(Sociedades.de_lugar(u, viz)):
					copiado[viz] = true
					novos.append(Simulador.registrar(u, {"tipo": "obra copiada", "lugar": viz, "sujeitos": [o, viz], "causas": [str(u.entidade(o).get("fato_criacao", ""))],
						"descricao": "Cópias de \"%s\" chegaram a %s." % [u.entidade(o)["nome"], u.entidade(viz)["nome"]],
						"dados": {"importancia": 0.2, "mudancas": [{"op": "obra_copias", "obra": o, "lugar": viz, "delta": 1}]}}))
	return novos.filter(func(x): return x != "")


## Sobre o que alguém escreveria: o fato mais marcante que viveu (uma batalha, uma morte, uma guerra).
static func _tema(u: Universo, eid: String) -> String:
	var melhor := ""
	var imp := 0.55
	var ja := {}
	for o in todas(u):
		if str(dados(u, o).get("autor", "")) == eid:
			ja[str(dados(u, o).get("tema", ""))] = true
	for fid in u.estado(eid).get("conhece", {}).keys():
		var f := u.fatos.obter(fid)
		if f.is_empty() or not f["canon"] or ja.has(fid) or f["tipo"] in ["notícia", "rumor", "obra"]:
			continue
		var i := float(f["dados"].get("importancia", 0.0)) + (0.2 if f["sujeitos"].has(eid) else 0.0)
		if i > imp:
			imp = i
			melhor = fid
	return melhor


## Reencontrada: alguém curioso, onde ficaram os vestígios (ou nas ruínas), acha a obra
## e a lê com os valores do seu tempo.
static func _reencontrar(u: Universo, o: String, rng: RandomNumberGenerator) -> String:
	var d := dados(u, o)
	var vest := str(d.get("vestigio", ""))
	if vest == "" or not u.entidades.has(vest):
		return ""
	var leitor := ""
	for m in Simulador._mentes(u):
		var onde := str(u.estado(m).get("local", ""))
		if onde == vest or Mapa.ancestrais(u, vest).has(onde) or Mapa.ancestrais(u, onde).has(vest):
			var t := Personalidade.tracos(u, m)
			if float(t["curiosidade"]) > 0.6 and (leitor == "" or float(t["curiosidade"]) > float(Personalidade.tracos(u, leitor)["curiosidade"])):
				leitor = m
	if leitor == "" or rng.randf() > 0.3:
		return ""
	return reinterpretar(u, o, leitor, vest)


## A leitura de alguém de outro tempo: o que a obra diz, com os valores de quem lê.
static func reinterpretar(u: Universo, o: String, leitor: String, onde: String = "") -> String:
	var d := dados(u, o)
	var original: Dictionary = d["leituras"][0]
	var anos := int(u.relogio["ano"]) - int(original.get("ano", u.relogio["ano"]))
	var t := Personalidade.tracos(u, leitor)
	var sid := Sociedades.de_lugar(u, str(u.estado(leitor).get("local", "")))
	var admira := TextUtil.normalizar(Sociedades._campo(u, sid, ["admir", "honram"]) if sid != "" else "")
	var odeia: Array = d.get("vies", {}).get("odeia", [])
	var leitura := ""
	var ops: Array = []
	if not odeia.is_empty() and (float(t["empatia"]) > 0.5 or admira.contains("paz") or admira.contains("verdade")):
		leitura = "um testemunho de como a guerra ensina o ódio: o autor não via os inimigos como gente"
		# A reconciliação vale para o povo de quem lê e para o povo de quem escreveu.
		var povos: Array = []
		for p in [sid, str(d.get("povo", ""))]:
			if p != "" and not povos.has(p):
				povos.append(p)
		for p in povos:
			for s in odeia:
				if Sociedades.eh_sociedade(u, s) and s != p:
					ops.append({"op": "rancor", "de": p, "para": s, "delta": -0.3})
					ops.append({"op": "rancor", "de": s, "para": p, "delta": -0.15})
	elif not odeia.is_empty():
		leitura = "um épico de coragem contra os de %s, que ainda merecem desconfiança" % ", ".join(odeia.map(func(x): return u.entidade(x)["nome"]))
		for s in odeia:
			if sid != "" and Sociedades.eh_sociedade(u, s) and s != sid:
				ops.append({"op": "rancor", "de": sid, "para": s, "delta": 0.2})
	else:
		leitura = "uma janela para um tempo esquecido"
	var l := {"por": leitor, "texto": leitura, "ano": int(u.relogio["ano"]), "original": false}
	ops.append({"op": "obra_leitura", "obra": o, "leitura": l})
	if onde != "":
		ops.append({"op": "obra_copias", "obra": o, "lugar": str(u.estado(leitor).get("local", onde)), "delta": 1})
		ops.append({"op": "obra_estado", "obra": o, "chave": "vestigio", "valor": ""})
	ops.append({"op": "mudar", "quem": leitor, "chave": "reputacao", "delta": 0.4})
	var causa := ""
	var ids := u.fatos.ids_sobre(o)
	for i in range(ids.size() - 1, -1, -1):
		if u.fatos.obter(ids[i])["canon"]:
			causa = ids[i]
			break
	return Simulador.registrar(u, {"tipo": "obra reencontrada" if onde != "" else "nova leitura", "lugar": u.estado(leitor).get("local", ""), "sujeitos": [leitor, o], "causas": [causa],
		"descricao": "%s %s \"%s\", escrito há %d anos, e o leu como %s." % [u.entidade(leitor)["nome"], ("encontrou nas ruínas de " + u.entidade(onde)["nome"]) if onde != "" else "releu", u.entidade(o)["nome"], anos, leitura],
		"dados": {"importancia": 0.6, "mudancas": ops}})


## O texto da obra: resumo e trechos-modelo (ou a IA local, se ligada).
static func texto(u: Universo, o: String) -> String:
	var d := dados(u, o)
	var autor := str(d.get("autor", ""))
	var tema := u.fatos.obter(str(d.get("tema", "")))
	var odeia: Array = d.get("vies", {}).get("odeia", [])
	var linhas: Array = []
	linhas.append(str(d["leituras"][0]["texto"]))
	if not tema.is_empty():
		if not odeia.is_empty():
			linhas.append("“Nunca esquecerei o que os de %s fizeram. %s”" % [u.entidade(odeia[0])["nome"], tema["descricao"]])
		else:
			linhas.append("“%s E nada mais foi igual.”" % tema["descricao"])
	var base := "\n\n".join(linhas)
	if autor != "" and u.entidades.has(autor):
		return IALocal.voz(u, autor, "Escreva um trecho da sua obra \"%s\"." % u.entidade(o)["nome"], base, [tema.get("descricao", "")], str(u.valor_campo(o, "estilo")))
	return base
