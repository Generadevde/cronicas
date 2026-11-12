class_name Extrator
extends RefCounted
## Lê o texto dos capítulos e propõe fatos. Nunca decide sozinho:
## tudo vira PROPOSTA na margem, e o autor aceita, ajusta ou risca.
##
## Funciona com um catálogo de ações em português e um dicionário que o autor
## ensina ("esmurrou" = vitória). Frases com dois ou mais nomes e nenhuma ação
## conhecida viram "dúvida", para o autor ensinar o que significam.

## Catálogo de ações. 'formas' já normalizadas (sem acento, minúsculas).
## 'papeis': "par" = A faz algo com B; "um" = só o sujeito; "lugar" = A vai/está em B (um lugar).
const ACOES := {
	"vitoria": {"nome": "vitória em luta", "papeis": "par",
		"formas": ["venceu", "vence", "derrotou", "derrota", "superou", "nocauteou", "derrubou", "humilhou",
			"levou a melhor sobre", "ganhou de", "bateu em"]},
	"derrota": {"nome": "derrota em luta", "papeis": "par",
		"formas": ["perdeu para", "foi derrotado por", "foi derrotada por", "foi vencido por", "foi vencida por"]},
	"morte_por": {"nome": "morte causada", "papeis": "par",
		"formas": ["matou", "assassinou", "executou", "envenenou", "decapitou", "mata"]},
	"morte": {"nome": "morte", "papeis": "um",
		"formas": ["morreu", "faleceu", "pereceu", "foi morto", "foi morta", "morre", "tombou morto", "tombou morta"]},
	"ferimento": {"nome": "ferimento", "papeis": "par",
		"formas": ["feriu", "machucou", "golpeou", "cortou", "atingiu", "esfaqueou"]},
	"luta": {"nome": "luta", "papeis": "par",
		"formas": ["enfrentou", "lutou contra", "lutou com", "duelou com", "desafiou", "atacou", "confrontou"]},
	"vitoria_um": {"nome": "vitória", "papeis": "um",
		"formas": ["venceu", "saiu vitorioso", "saiu vitoriosa", "triunfou"]},
	"derrota_um": {"nome": "derrota", "papeis": "um",
		"formas": ["perdeu", "foi derrotado", "foi derrotada", "caiu derrotado", "caiu derrotada"]},
	"testemunho": {"nome": "testemunho", "papeis": "um",
		"formas": ["viu tudo", "viu", "assistiu", "testemunhou", "presenciou", "observou tudo"]},
	"filiacao": {"nome": "filiação", "papeis": "par",
		"formas": ["filho de", "filha de", "herdeiro de", "herdeira de"]},
	"paternidade": {"nome": "paternidade", "papeis": "par",
		"formas": ["pai de", "mae de"]},
	"casamento": {"nome": "casamento", "papeis": "par",
		"formas": ["casou com", "casou-se com", "se casou com", "esposa de", "marido de", "casada com", "casado com"]},
	"amor": {"nome": "amor", "papeis": "par",
		"formas": ["ama", "amava", "se apaixonou por", "apaixonou-se por", "apaixonado por", "apaixonada por"]},
	"odio": {"nome": "ódio", "papeis": "par",
		"formas": ["odeia", "odiava", "passou a odiar", "jurou vinganca contra", "jurou vingar-se de"]},
	"medo": {"nome": "medo", "papeis": "par",
		"formas": ["teme", "temia", "tem medo de", "tinha medo de", "fugiu de"]},
	"amizade": {"nome": "amizade", "papeis": "par",
		"formas": ["amigo de", "amiga de", "aliou-se a", "se aliou a", "fez amizade com", "salvou"]},
	"traicao": {"nome": "traição", "papeis": "par",
		"formas": ["traiu", "enganou", "abandonou", "apunhalou pelas costas"]},
	"ensino": {"nome": "ensino", "papeis": "par",
		"formas": ["ensinou", "treinou", "aceitou como discipulo", "tornou-se mestre de", "tomou como aprendiz"]},
	"aprendizado": {"nome": "aprendizado", "papeis": "par",
		"formas": ["discipulo de", "aprendiz de", "aluno de", "aluna de", "treinou com", "aprendeu com"]},
	"chegada": {"nome": "chegada", "papeis": "lugar",
		"formas": ["chegou a", "chegou em", "chegou ao", "chegou a cidade de", "foi para", "viajou para", "mudou-se para",
			"partiu para", "voltou para", "voltou a", "entrou em", "fugiu para", "esta em", "estava em", "mora em", "morava em", "vive em"]},
	"guerra": {"nome": "declaração de guerra", "papeis": "par",
		"formas": ["declarou guerra a", "declarou guerra ao", "declarou guerra contra", "declara guerra a", "declarou guerra", "entrou em guerra com",
			"entrou em guerra contra", "invadiu", "invade", "marchou contra", "atacou o reino de"]},
	"nascimento": {"nome": "nascimento", "papeis": "um",
		"formas": ["nasceu"]},
	"usar_poder": {"nome": "uso de poder", "papeis": "um",
		"formas": ["usou magia", "usou a magia", "usou sua magia", "usou o poder", "usou seu poder", "usou o dom", "usou seu dom",
			"lancou um feitico", "lancou feitico", "lancou uma magia", "lancou magia", "conjurou", "invocou", "fez um feitico",
			"fez magia", "usou"]},
}

const NEGACOES := ["nao", "nunca", "jamais"]


## Analisa um capítulo e devolve as NOVAS propostas (já adicionadas ao universo).
static func analisar(u: Universo, cid: String) -> Array:
	var cap := u.capitulo(cid)
	if cap.is_empty() or not cap["canon"] or cap.has("vivido"):
		return []
	var novas: Array = []
	var lig := Ligador.new(u)
	var assinaturas := {}
	for p in u.propostas:
		assinaturas[p["assinatura"]] = true

	var ultimo_sujeito := ""
	var recentes: Array = []  # pessoas citadas, da mais recente para a mais antiga
	var candidatas: Array = []  # [{prop, idx}] na ordem do texto
	var idx := -1
	for frase in frases(cap["texto"]):
		idx += 1
		var norm := TextUtil.normalizar(frase)
		var mencoes := lig.encontrar(frase)
		mencoes = _resolver_pronomes(norm, mencoes, ultimo_sujeito)
		# "Eles lutaram por 10 dias": luta entre as duas últimas pessoas citadas.
		var plural := _luta_no_plural(u, cid, frase, norm, mencoes, recentes)
		if not plural.is_empty():
			candidatas.append({"prop": plural, "idx": idx})
		for m in mencoes:
			if Estado.tem_mente(u, m["entidade"]) or Sugestoes.categoria(u.entidade(m["entidade"]).get("tipo", "")) == "pessoa":
				recentes.erase(m["entidade"])
				recentes.push_front(m["entidade"])
		if mencoes.is_empty() or not plural.is_empty():
			continue
		for m in mencoes:
			if not _eh_lugar(u, m["entidade"]):
				ultimo_sujeito = m["entidade"]
				break
		var da_frase: Array = []
		var posicoes_par := {}
		for acao in _acoes_na_frase(u, norm):
			if posicoes_par.has(acao["pos"]):
				continue
			var prop := _montar(u, cid, frase, mencoes, acao)
			if prop.is_empty():
				continue
			if ACOES[acao["acao"]]["papeis"] != "um":
				posicoes_par[acao["pos"]] = true
			da_frase.append(prop)
		da_frase = da_frase.filter(func(p): return p["acao"] != "usar_poder" or _fala_de_poder(u, norm, mencoes))
		da_frase = _juntar_luta_e_resultado(u, cid, frase, da_frase)
		da_frase.append_array(Regras.propostas_da_frase(u, cid, frase, mencoes))
		for prop in da_frase:
			candidatas.append({"prop": prop, "idx": idx})
		if da_frase.is_empty() and _pessoas_distintas(mencoes) >= 2:
			candidatas.append({"idx": idx, "prop": {
				"id": Ids.novo("prp"), "capitulo": cid, "frase": frase.strip_edges(),
				"acao": "", "sujeitos": [], "lugar": "", "status": "duvida",
				"descricao": "Não entendi o que acontece nesta frase.",
				"palavra": _palavra_candidata(norm, mencoes),
				"assinatura": "%s|%s|duvida" % [cid, TextUtil.chave(frase)],
			}})
	for c in _juntar_entre_frases(u, cid, candidatas):
		var prop: Dictionary = c["prop"]
		if assinaturas.has(prop["assinatura"]):
			continue
		assinaturas[prop["assinatura"]] = true
		u.propostas.append(prop)
		novas.append(prop)
	if not novas.is_empty():
		u.marcar_mudanca()
	return novas


const LUTA_PLURAL := ["lutaram", "se enfrentaram", "duelaram", "batalharam", "travaram uma luta", "travaram um duelo", "se bateram", "brigaram",
	"combateram", "se atracaram"]
const PRONOMES_PLURAIS := ["eles", "elas", "os dois", "as duas", "ambos", "ambas"]


static func _luta_no_plural(u: Universo, cid: String, frase: String, norm: String, mencoes: Array, recentes: Array) -> Dictionary:
	if not LUTA_PLURAL.any(func(w): return (" " + norm + " ").contains(" " + w + " ") or (" " + norm).contains(" " + w)):
		return {}
	var pessoas: Array = []
	for m in mencoes:
		if not _eh_lugar(u, m["entidade"]) and not pessoas.has(m["entidade"]):
			pessoas.append(m["entidade"])
	if pessoas.size() < 2:
		if not PRONOMES_PLURAIS.any(func(w): return (" " + norm + " ").contains(" " + w + " ")) and pessoas.size() == 0:
			return {}
		for r in recentes:
			if pessoas.size() >= 2:
				break
			if not pessoas.has(r):
				pessoas.append(r)
	if pessoas.size() < 2:
		return {}
	var lugar := ""
	for m in mencoes:
		if _eh_lugar(u, m["entidade"]):
			lugar = m["entidade"]
	var s: Array = [pessoas[1], pessoas[0]] if mencoes.is_empty() else [pessoas[0], pessoas[1]]
	return {
		"id": Ids.novo("prp"), "capitulo": cid, "frase": frase.strip_edges(),
		"acao": "luta", "sujeitos": s, "lugar": lugar, "status": "pendente",
		"descricao": descrever(u, "luta", s, lugar),
		"assinatura": "%s|%s|luta|%s" % [cid, TextUtil.chave(frase), ",".join(s)],
	}


## "usou" só é uso de poder se a frase falar de magia ou citar um poder.
static func _fala_de_poder(u: Universo, norm: String, mencoes: Array) -> bool:
	for p in ["magia", "feitic", "encant", "poder", "dom "]:
		if norm.contains(p):
			return true
	return mencoes.any(func(m): return Poderes.eh_poder(u, m["entidade"]))


## Divide um texto em frases (pontos finais, exclamações, interrogações e quebras de linha).
static func frases(texto: String) -> Array:
	var lista: Array = []
	var atual := ""
	for i in texto.length():
		var c: String = texto[i]
		atual += c
		if c == "." and i > 0 and i + 1 < texto.length() and texto[i - 1].is_valid_int() and texto[i + 1].is_valid_int():
			continue
		if c in [".", "!", "?", "\n", ";"]:
			if atual.strip_edges() != "":
				lista.append(atual)
			atual = ""
	if atual.strip_edges() != "":
		lista.append(atual)
	return lista


## Encontra as ações na frase (catálogo + dicionário do autor): [{acao, pos, fim}].
static func _acoes_na_frase(u: Universo, norm: String) -> Array:
	var achados: Array = []
	var formas: Array = []
	for id in ACOES:
		for f in ACOES[id]["formas"]:
			formas.append([f, id])
	for palavra in u.dicionario:
		formas.append([palavra, u.dicionario[palavra]])
	formas.sort_custom(func(a, b): return a[0].length() > b[0].length())
	var ocupado := {}
	for par in formas:
		var forma: String = par[0]
		var desde := 0
		while true:
			var pos := norm.find(forma, desde)
			if pos < 0:
				break
			desde = pos + 1
			var fim := pos + forma.length()
			if (pos > 0 and TextUtil.eh_letra(norm[pos - 1])) or (fim < norm.length() and TextUtil.eh_letra(norm[fim])):
				continue
			# Uma forma mais longa já cobriu este trecho? (formas de mesmo tamanho convivem)
			if ocupado.get(pos, 0) > forma.length():
				continue
			var antes := TextUtil.palavras(norm.substr(maxi(0, pos - 12), mini(12, pos)))
			if not antes.is_empty() and antes[antes.size() - 1] in NEGACOES:
				continue
			for k in range(pos, fim):
				ocupado[k] = maxi(ocupado.get(k, 0), forma.length())
			achados.append({"acao": par[1], "pos": pos, "fim": fim})
	# Mesma posição: ações de duas pessoas antes das de uma só.
	achados.sort_custom(func(a, b):
		if a["pos"] != b["pos"]:
			return a["pos"] < b["pos"]
		return ACOES.get(a["acao"], {}).get("papeis", "um") != "um" and ACOES.get(b["acao"], {}).get("papeis", "um") == "um")
	return achados


static func _montar(u: Universo, cid: String, frase: String, mencoes: Array, achado: Dictionary) -> Dictionary:
	var acao: String = achado["acao"]
	if not ACOES.has(acao):
		return {}
	var def: Dictionary = ACOES[acao]
	var antes: Array = mencoes.filter(func(m): return m["fim"] <= achado["pos"])
	var depois: Array = mencoes.filter(func(m): return m["inicio"] >= achado["fim"])
	var a := "" if antes.is_empty() else str(antes.back()["entidade"])
	var b := "" if depois.is_empty() else str(depois[0]["entidade"])
	if def["papeis"] == "um" and not antes.is_empty():
		a = _sujeito_de_uma_pessoa(u, TextUtil.normalizar(frase), antes, achado["pos"])
	var sujeitos: Array = []
	var lugar := ""
	match def["papeis"]:
		"par":
			if a == "" or b == "" or a == b:
				return {}
			sujeitos = [a, b]
		"um":
			if a == "":
				a = b
			if a == "":
				return {}
			sujeitos = [a]
			if b != "" and Sugestoes.categoria(u.entidade(b).get("tipo", "")) == "lugar":
				lugar = b
		"lugar":
			if a == "" or b == "":
				return {}
			sujeitos = [a]
			lugar = b
	# Lugar mencionado na frase (ex.: "na praça de Varn") vira o "onde".
	if lugar == "":
		for m in mencoes:
			if not sujeitos.has(m["entidade"]) and Sugestoes.categoria(u.entidade(m["entidade"]).get("tipo", "")) == "lugar":
				lugar = m["entidade"]
				break
	# Guerra só entre sociedades diferentes (pessoas valem pela sociedade que governam).
	if acao == "guerra":
		var sa := Guerras.sociedade_de(u, a)
		var sb := Guerras.sociedade_de(u, b)
		if sa == "" or sb == "" or sa == sb:
			return {}
		sujeitos = [sa, sb]
		lugar = b if Mapa.e_lugar(u, b) else ""
	var prop := {
		"id": Ids.novo("prp"), "capitulo": cid, "frase": frase.strip_edges(),
		"acao": acao, "sujeitos": sujeitos, "lugar": lugar, "status": "pendente",
		"descricao": descrever(u, acao, sujeitos, lugar),
	}
	prop["assinatura"] = "%s|%s|%s|%s" % [cid, TextUtil.chave(frase), acao, ",".join(sujeitos)]
	return prop


## Texto legível de um fato a partir da ação e dos participantes.
static func descrever(u: Universo, acao: String, sujeitos: Array, lugar: String) -> String:
	var n := func(i: int) -> String:
		return u.entidade(sujeitos[i]).get("nome", "?") if i < sujeitos.size() else "?"
	var onde := ""
	if lugar != "":
		onde = " em %s" % u.entidade(lugar).get("nome", "?")
	match acao:
		"vitoria": return "%s venceu %s%s." % [n.call(0), n.call(1), onde]
		"luta": return "%s enfrentou %s%s (resultado em aberto)." % [n.call(0), n.call(1), onde]
		"vitoria_um": return "%s venceu%s." % [n.call(0), onde]
		"derrota_um": return "%s perdeu%s." % [n.call(0), onde]
		"derrota": return "%s perdeu para %s%s." % [n.call(0), n.call(1), onde]
		"morte_por": return "%s matou %s%s." % [n.call(0), n.call(1), onde]
		"morte": return "%s morreu%s." % [n.call(0), onde]
		"ferimento": return "%s feriu %s%s." % [n.call(0), n.call(1), onde]
		"testemunho": return "%s testemunhou o que aconteceu%s." % [n.call(0), onde]
		"filiacao": return "%s é filho(a) de %s." % [n.call(0), n.call(1)]
		"paternidade": return "%s é pai ou mãe de %s." % [n.call(0), n.call(1)]
		"casamento": return "%s e %s estão casados." % [n.call(0), n.call(1)]
		"amor": return "%s ama %s." % [n.call(0), n.call(1)]
		"odio": return "%s odeia %s." % [n.call(0), n.call(1)]
		"medo": return "%s teme %s." % [n.call(0), n.call(1)]
		"amizade": return "%s e %s ficaram próximos." % [n.call(0), n.call(1)]
		"traicao": return "%s traiu %s." % [n.call(0), n.call(1)]
		"ensino": return "%s passou a ensinar %s." % [n.call(0), n.call(1)]
		"aprendizado": return "%s passou a aprender com %s." % [n.call(0), n.call(1)]
		"chegada": return "%s foi para %s." % [n.call(0), u.entidade(lugar).get("nome", "?")]
		"nascimento": return "%s nasceu%s." % [n.call(0), onde]
		"usar_poder": return "%s usou um poder%s." % [n.call(0), onde]
		"guerra": return "%s declarou guerra a %s." % [n.call(0), n.call(1)]
	return "Acontecimento envolvendo %s." % ", ".join(sujeitos.map(func(s): return u.entidade(s).get("nome", "?")))


## "Ele"/"Ela" no começo de uma frase (ou depois de "e") apontam para quem
## era o sujeito da frase anterior. Simples, mas resolve o caso mais comum.
static func _resolver_pronomes(norm: String, mencoes: Array, ultimo: String) -> Array:
	if ultimo == "":
		return mencoes
	var lista := mencoes.duplicate()
	for pron in ["ele", "ela"]:
		var desde := 0
		while true:
			var pos := norm.find(pron, desde)
			if pos < 0:
				break
			desde = pos + 1
			var fim: int = pos + str(pron).length()
			if (pos > 0 and TextUtil.eh_letra(norm[pos - 1])) or (fim < norm.length() and TextUtil.eh_letra(norm[fim])):
				continue
			var antes := norm.substr(0, pos).strip_edges()
			if antes == "" or antes.ends_with(" e") or antes == "e" or antes.ends_with(",") or antes.ends_with("entao"):
				if not lista.any(func(m): return m["fim"] <= pos):
					lista.append({"inicio": pos, "fim": fim, "entidade": ultimo, "texto": pron, "pronome": true})
	lista.sort_custom(func(a, b): return a["inicio"] < b["inicio"])
	return lista


## Quem faz uma ação de uma pessoa só ("viu", "morreu", "perdeu")?
## Divide a frase por vírgulas: se há um nome no mesmo trecho do verbo, é ele
## ("e Lucas perdeu"). Senão, volta pelos trechos anteriores pulando apostos que
## começam com artigo ("Daren, o filho de Lucas, viu tudo" → Daren).
static func _sujeito_de_uma_pessoa(u: Universo, norm: String, antes: Array, pos_verbo: int) -> String:
	var inicio_trecho := norm.rfind(",", pos_verbo - 1) + 1
	var candidatos: Array = antes.filter(func(m): return m["inicio"] >= inicio_trecho and not _eh_lugar(u, m["entidade"]))
	if not candidatos.is_empty():
		return str(candidatos.back()["entidade"])
	var fim := inicio_trecho - 1
	while fim > 0:
		var ini := norm.rfind(",", fim - 1) + 1
		var trecho := norm.substr(ini, fim - ini).strip_edges()
		var aposto := false
		for artigo in ["o ", "a ", "os ", "as ", "um ", "uma ", "seu ", "sua ", "que "]:
			if trecho.begins_with(artigo):
				aposto = true
		if not aposto:
			var no_trecho: Array = antes.filter(func(m): return m["inicio"] >= ini and m["fim"] <= fim and not _eh_lugar(u, m["entidade"]))
			if not no_trecho.is_empty():
				return str(no_trecho.back()["entidade"])
		fim = ini - 1
	for m in antes:
		if not _eh_lugar(u, m["entidade"]):
			return str(m["entidade"])
	return str(antes[0]["entidade"])


static func _eh_lugar(u: Universo, eid: String) -> bool:
	return Sugestoes.categoria(u.entidade(eid).get("tipo", "")) == "lugar"


## A luta numa frase e o resultado logo depois ("Kai enfrentou Lucas. (...) e Lucas perdeu.")
## viram uma vitória só, se estiverem a até duas frases de distância.
static func _juntar_entre_frases(u: Universo, cid: String, candidatas: Array) -> Array:
	var usadas := {}
	var saida: Array = []
	for i in candidatas.size():
		var c: Dictionary = candidatas[i]
		var p: Dictionary = c["prop"]
		if not p["acao"] in ["vitoria_um", "derrota_um"]:
			continue
		var x: String = p["sujeitos"][0]
		for j in range(i - 1, -1, -1):
			var l: Dictionary = candidatas[j]["prop"]
			if candidatas[j]["idx"] < c["idx"] - 2:
				break
			if l["acao"] != "luta" or usadas.has(j) or not l["sujeitos"].has(x):
				continue
			var outro: String = l["sujeitos"][1] if l["sujeitos"][0] == x else l["sujeitos"][0]
			var venc := x if p["acao"] == "vitoria_um" else outro
			var perd := outro if p["acao"] == "vitoria_um" else x
			var lugar: String = l["lugar"] if l["lugar"] != "" else p["lugar"]
			var frase := "%s … %s" % [l["frase"], p["frase"]]
			var nova := {
				"id": Ids.novo("prp"), "capitulo": cid, "frase": frase,
				"acao": "vitoria", "sujeitos": [venc, perd], "lugar": lugar, "status": "pendente",
				"descricao": descrever(u, "vitoria", [venc, perd], lugar),
				"assinatura": "%s|%s|vitoria|%s,%s" % [cid, TextUtil.chave(frase), venc, perd],
			}
			usadas[j] = true
			usadas[i] = true
			candidatas[i] = {"prop": nova, "idx": c["idx"]}
			break
	for i in candidatas.size():
		if usadas.has(i) and candidatas[i]["prop"]["acao"] != "vitoria":
			continue
		saida.append(candidatas[i])
	return saida


## "Kai enfrentou Lucas, e Lucas perdeu" → uma proposta só: "Kai venceu Lucas".
static func _juntar_luta_e_resultado(u: Universo, cid: String, frase: String, props: Array) -> Array:
	var lutas: Array = props.filter(func(p): return p["acao"] == "luta")
	if lutas.is_empty():
		return props
	var saida: Array = []
	var usadas := {}
	for p in props:
		if p["acao"] in ["vitoria_um", "derrota_um"]:
			var x: String = p["sujeitos"][0]
			var casou := false
			for l in lutas:
				if l["sujeitos"].has(x):
					var outro: String = l["sujeitos"][1] if l["sujeitos"][0] == x else l["sujeitos"][0]
					var venc := x if p["acao"] == "vitoria_um" else outro
					var perd := outro if p["acao"] == "vitoria_um" else x
					var lugar: String = l["lugar"] if l["lugar"] != "" else p["lugar"]
					var nova := {
						"id": Ids.novo("prp"), "capitulo": cid, "frase": frase.strip_edges(),
						"acao": "vitoria", "sujeitos": [venc, perd], "lugar": lugar, "status": "pendente",
						"descricao": descrever(u, "vitoria", [venc, perd], lugar),
					}
					nova["assinatura"] = "%s|%s|vitoria|%s,%s" % [cid, TextUtil.chave(frase), venc, perd]
					saida.append(nova)
					usadas[l["id"]] = true
					casou = true
					break
			if not casou:
				saida.append(p)
		elif p["acao"] != "luta":
			saida.append(p)
	for l in lutas:
		if not usadas.has(l["id"]):
			saida.append(l)
	return saida


static func _pessoas_distintas(mencoes: Array) -> int:
	var vistos := {}
	for m in mencoes:
		vistos[m["entidade"]] = true
	return vistos.size()


## Primeira palavra depois do primeiro nome: geralmente é o verbo ("Kai esmurrou Lucas").
static func _palavra_candidata(norm: String, mencoes: Array) -> String:
	var resto := norm.substr(mencoes[0]["fim"])
	var p := TextUtil.palavras(resto)
	for w in p:
		if w.length() > 2 and not w in ["que", "com", "para", "pela", "pelo", "uma", "nos", "nas", "dos", "das"]:
			return w
	return ""
