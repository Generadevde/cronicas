class_name Regras
extends RefCounted
## Leis do Universo escritas em português, que o mundo passa a seguir sozinho.
## Cada lei tem quatro peças: QUANDO (o gatilho), QUEM (a quem vale), O QUÊ
## (os efeitos, ver Pecas) e SE (condições). Ficam em extras["regras"].
##
## Gatilhos: uma ação (vencer, perder, lutar, matar, morrer, casar, nascer,
## chegar, treinar, usar magia ou um poder), um TERMO escrito por você
## ("beber da fonte de Varn", "chuva de sangue") que é reconhecido nos capítulos
## e nas intervenções, a passagem do tempo ("a cada 100 anos"), um campo de
## ficha ("quem tem 'conhece o Autor'") ou "sempre" (vale para quem combina).
##
## Quando uma lei dispara, o efeito vira fato com causa (o que disparou) e
## pode ser desfeito como qualquer fato.

const GATILHOS := [
	["usar_poder", ["usa magia", "usar magia", "usam magia", "usa a magia", "usar a magia", "lanca feitico", "lanca um feitico",
		"lancar feitico", "lancam feiticos", "por feitico", "a cada feitico", "conjura", "conjurar", "usa um poder", "usa poder",
		"usar poder", "usa seu poder", "usa o poder", "usar o poder", "usa o dom", "usar o dom", "usa feiticos", "faz magia", "fazer magia"]],
	["matar", ["mata alguem", "matar alguem", "mata", "matar", "matam", "assassina", "assassinar"]],
	["vitoria", ["a cada vitoria", "cada vitoria", "vence uma luta", "vencer uma luta", "vence", "vencer", "vencem", "vitoria", "vitorias", "derrota alguem", "derrotar alguem"]],
	["derrota", ["a cada derrota", "e derrotado", "for derrotado", "for derrotada", "perde uma luta", "perder uma luta", "perde uma batalha", "derrota", "derrotas"]],
	["morte", ["morre", "morrer", "morrem", "a morte de", "falece", "falecer"]],
	["luta", ["luta", "lutar", "lutam", "enfrenta", "enfrentar", "duela", "duelar", "batalha"]],
	["casamento", ["se casa", "se casar", "casam", "casar", "casamento"]],
	["nascimento", ["nasce", "nascer", "nascem", "nascimento"]],
	["chegada", ["chega a", "chegar a", "chega em", "chegar em", "entra em", "entrar em", "visita", "visitar", "pisa em", "pisar em"]],
	["treino", ["treina", "treinar", "treinam", "treino"]],
	["ferimento", ["e ferido", "for ferido", "for ferida", "e ferida", "se ferir"]],
	["evento:seca", ["seca", "estiagem"]], ["evento:praga", ["praga"]], ["evento:epidemia", ["peste", "epidemia"]],
	["evento:inverno", ["inverno rigoroso", "nevasca"]], ["fome", ["fome"]],
]
const NOMES_GATILHO := {"usar_poder": "usar um poder", "matar": "matar alguém", "vitoria": "vencer uma luta",
	"derrota": "perder uma luta", "morte": "morrer", "luta": "lutar", "casamento": "casar", "nascimento": "nascer",
	"chegada": "chegar a um lugar", "treino": "treinar", "ferimento": "ser ferido", "fome": "fome",
	"evento:seca": "seca", "evento:praga": "praga", "evento:epidemia": "peste", "evento:inverno": "inverno rigoroso"}
const MARCADORES := ["toda vez que", "sempre que", "a cada", "quando", "depois de", "apos", "ao"]
const PALAVRAS_VAZIAS := ["de", "da", "do", "das", "dos", "a", "o", "as", "os", "um", "uma", "uns", "umas", "que", "em", "no",
	"na", "nos", "nas", "e", "com", "por", "para", "pela", "pelo", "se", "quem", "ao", "aos", "sua", "seu", "suas", "seus"]


static func todas(u: Universo) -> Array:
	return u.extra("regras", [])


static func obter(u: Universo, rid: String) -> Dictionary:
	for r in todas(u):
		if r["id"] == rid:
			return r
	return {}


# ---------------------------------------------------------------- escrever uma lei

## Cria uma lei a partir de uma frase. Devolve a regra (com o que foi entendido).
static func criar(u: Universo, texto: String) -> Dictionary:
	var r := interpretar(u, texto)
	if r.is_empty():
		return {}
	r["id"] = Ids.novo("lei")
	r["ligada"] = true
	r["disparos"] = 0
	r["aplicados"] = {}
	r["desde"] = DataMundo.ordem(u.relogio)
	var origem: Dictionary = u.fatos.todos()[0] if u.fatos.quantidade() > 0 else {}
	r["fato"] = u.fatos.registrar({
		"tipo": "lei do universo",
		"descricao": "Passou a valer: %s" % _frase(texto),
		"data": DataMundo.copiar(origem.get("data", u.relogio)),  # as leis valem desde sempre
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "leis"},
		"dados": {"importancia": 0.4, "regra": r["id"]},
	})
	todas(u).append(r)
	u.marcar_mudanca()
	return r


static func _frase(t: String) -> String:
	t = t.strip_edges()
	if t == "":
		return t
	t = t.substr(0, 1).to_upper() + t.substr(1)
	return t if t.ends_with(".") else t + "."


static func reescrever(u: Universo, rid: String, texto: String) -> Dictionary:
	var r := obter(u, rid)
	if r.is_empty():
		return {}
	var novo := interpretar(u, texto)
	if novo.is_empty():
		return r
	for k in novo:
		r[k] = novo[k]
	u.fatos.registrar({
		"tipo": "lei do universo", "descricao": "A lei foi reescrita: %s" % _frase(texto),
		"data": DataMundo.copiar(u.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "leis"},
		"dados": {"importancia": 0.3, "regra": rid},
	})
	u.marcar_mudanca()
	return r


## Lei de campo: "quem tem '<chave>' na ficha" recebe os efeitos (uma vez cada).
static func criar_de_campo(u: Universo, chave: String, efeito: String) -> Dictionary:
	var r := criar(u, "\"%s\" → %s" % [chave, efeito])
	if r.is_empty():
		return r
	r["quando"] = {"tipo": "campo", "texto": chave}
	r["texto"] = "Quem tem \"%s\" na ficha: %s" % [chave, efeito.strip_edges().trim_suffix(".")]
	r["avisos"] = r["avisos"].filter(func(a): return not a.begins_with("O gatilho"))
	u.marcar_mudanca()
	return r


static func ligar(u: Universo, rid: String, valor: bool) -> void:
	var r := obter(u, rid)
	if r.is_empty() or bool(r["ligada"]) == valor:
		return
	r["ligada"] = valor
	u.fatos.registrar({
		"tipo": "lei do universo", "descricao": "A lei \"%s\" foi %s." % [r["texto"], "religada" if valor else "suspensa"],
		"data": DataMundo.copiar(u.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "leis"},
		"dados": {"importancia": 0.3, "regra": rid},
	})
	u.marcar_mudanca()


## Apaga uma lei (nada se perde: ela fica guardada como desligada e marcada como apagada).
static func apagar(u: Universo, rid: String) -> void:
	var r := obter(u, rid)
	if r.is_empty():
		return
	ligar(u, rid, false)
	r["apagada"] = true
	u.marcar_mudanca()


## Lê a frase e monta {texto, quando, quem, efeitos, se, entendida, avisos}.
static func interpretar(u: Universo, texto: String) -> Dictionary:
	var original := texto.strip_edges().trim_suffix(".")
	if original == "":
		return {}
	var r := {"texto": original, "quando": {}, "quem": {"tipo": "todos"}, "efeitos": [], "se": [], "avisos": []}
	var t := original
	# "termo → efeitos" (o jeito curto de definir o efeito de algo).
	for seta in ["→", "->", "=>"]:
		if t.contains(seta):
			var partes := t.split(seta, true, 1)
			r["quando"] = _termo(u, partes[0])
			r["efeitos"] = Pecas.ler(u, partes[1])
			if r["quando"].get("lugar", "") != "":
				for e in r["efeitos"]:
					if e["alvo"] in ["lugar", "todos_no_lugar"] and e.get("lugar_alvo", "") == "":
						e["lugar_alvo"] = r["quando"]["lugar"]
			return _fechar(u, r)
	var n := TextUtil.normalizar(t)
	# Escopo: "Neste mundo," / "Em Varn," / "Neste planeta,".
	var rx := RegEx.new()
	rx.compile("^(neste mundo|neste universo|neste planeta|em todo o universo|em todo lugar|aqui)\\s*,?\\s*")
	var m := rx.search(n)
	if m != null:
		n = n.substr(m.get_end())
	# Condições: ", se estiver ferido", "só se tiver a espada", "30% das vezes".
	n = _tirar_condicoes(u, n, r)
	# Periodicidade: "a cada 100 anos", "todo inverno".
	rx.compile("(?:a cada|todo|toda|todos os|todas as|uma vez a cada|uma vez por)\\s+(?:(\\d+|um|uma|dois|duas|tres|quatro|cinco|dez|vinte|cem|mil)\\s+)?(dias?|semanas?|mes|meses|anos?|decadas?|seculos?|inverno|verao|primavera|outono)\\b,?")
	m = rx.search(n)
	if m != null:
		var qtd := Pecas._num(m.get_string(1)) if m.get_string(1) != "" else 1.0
		var unid := m.get_string(2)
		var dias := int(qtd * Pecas.UNIDADES.get(unid, 360))
		var estacao := ""
		if unid in ["inverno", "verao", "primavera", "outono"]:
			dias = 360
			estacao = unid
		r["quando"] = {"tipo": "periodico", "a_cada": maxi(1, dias), "estacao": estacao}
		n = (n.substr(0, m.get_start()) + " " + n.substr(m.get_end())).strip_edges()
	# Gatilho com marcador ("a cada vitória", "quando chover sangue,").
	if r["quando"].is_empty():
		for mk in MARCADORES:
			var i := (" " + n + " ").find(" " + mk + " ")
			if i < 0:
				continue
			var depois := n.substr(i + mk.length()).strip_edges()
			var fim := depois.find(",")
			var clausula := depois if fim < 0 else depois.substr(0, fim)
			var resto_dir := "" if fim < 0 else depois.substr(fim + 1)
			var clausula_o := _original_de(original, clausula)
			var g := _gatilho(u, clausula_o)
			if g.is_empty():
				g = _termo(u, clausula_o)
			r["quando"] = g
			n = (n.substr(0, i) + " " + resto_dir).strip_edges().trim_prefix(",").strip_edges()
			break
	# "X atacam quem corta árvores": efeito antes de "quem", gatilho depois.
	var sujeito_txt := ""
	var efeito_txt := ""
	var iq := (" " + n + " ").find(" quem ")
	if r["quando"].is_empty() and iq > 0:
		efeito_txt = n.substr(0, iq - 1).strip_edges()
		var clausula2 := _original_de(original, n.substr(iq + 4).strip_edges())
		var g2 := _gatilho(u, clausula2)
		r["quando"] = g2 if not g2.is_empty() else _termo(u, clausula2)
		var efs := Pecas.ler(u, efeito_txt)
		for e in efs:
			if e["alvo"] == "entidade:" or e.get("peca", "") == "ferir":
				e["alvo"] = "sujeito"
		r["efeitos"] = efs
		return _fechar(u, r)
	# "Quem <gatilho> <efeito>" ou "<sujeito> <efeito>": acha onde começa o efeito.
	var palavras := n.split(" ", false)
	var comeca_com_quem := not palavras.is_empty() and palavras[0] in ["quem", "aquele", "aqueles", "todo", "todos"]
	var corte := -1
	var candidatos: Array = []
	for k in range(1, palavras.size()):
		if not _verbo_de_efeito(palavras[k]):
			continue
		var e := Pecas.ler_um(u, _original_de(original, " ".join(palavras.slice(k))))
		if e.is_empty() or e.get("livre", false):
			continue
		candidatos.append(k)
	if comeca_com_quem and r["quando"].is_empty():
		for k in candidatos:
			if not _gatilho(u, _original_de(original, " ".join(palavras.slice(0, k)))).is_empty():
				corte = k
				break
	if corte < 0 and not candidatos.is_empty():
		corte = candidatos[0]
	if corte < 0:
		for k in range(1, palavras.size()):
			if _verbo_de_efeito(palavras[k]):
				corte = k
				break
	if corte < 0:
		# Não achou efeito conhecido: tudo depois do sujeito vira marca (entendida em parte).
		corte = mini(2, palavras.size() - 1) if palavras.size() > 1 else 0
	sujeito_txt = " ".join(palavras.slice(0, corte))
	efeito_txt = " ".join(palavras.slice(corte))
	var sujeito_orig := _original_de(original, sujeito_txt)
	if comeca_com_quem and r["quando"].is_empty():
		var g4 := _gatilho(u, sujeito_orig)
		r["quando"] = g4 if not g4.is_empty() else _termo(u, sujeito_orig)
	elif sujeito_txt != "" and not comeca_com_quem:
		r["quem"] = _quem(u, sujeito_orig)
	r["efeitos"] = Pecas.ler(u, _original_de(original, efeito_txt))
	if r["quando"].is_empty():
		r["quando"] = {"tipo": "sempre"}
	return _fechar(u, r)


const VERBOS_DE_EFEITO := ["envelhec", "rejuvenesc", "fica", "torna", "vira", "esquec", "perde", "ganha", "morre", "adoec",
	"sente", "passa", "vai", "vao", "recebe", "cura", "sara", "sangra", "vive", "ataca", "desperta", "volta", "foge",
	"fogem", "parte", "partem", "e", "sao", "enlouquec", "enfraquec", "fortalec", "cega", "ressuscit", "acorda", "levanta"]


static func _verbo_de_efeito(palavra: String) -> bool:
	for v in VERBOS_DE_EFEITO:
		if palavra == v or (v.length() > 2 and palavra.begins_with(v)):
			return true
	return false


## Recupera do texto original (com acentos) o trecho normalizado.
static func _original_de(original: String, normalizado: String) -> String:
	var o := original.strip_edges().trim_suffix(".")
	var no := TextUtil.normalizar(o)
	var i := no.find(normalizado)
	if i >= 0 and no.length() == o.length():
		return o.substr(i, normalizado.length())
	return normalizado


static func _fechar(u: Universo, r: Dictionary) -> Dictionary:
	var partes := 0
	for e in r["efeitos"]:
		if e.get("livre", false):
			partes += 1
			r["avisos"].append("\"%s\" não se encaixou em nenhuma peça: virou uma marca com esse nome." % e["texto"])
	if r["efeitos"].is_empty():
		r["avisos"].append("Não achei nenhum efeito.")
	if r["quando"].get("tipo", "") == "termo":
		r["avisos"].append("O gatilho \"%s\" é seu: vale quando aparecer num capítulo ou numa intervenção." % r["quando"]["termo"])
	r["entendida"] = "parte" if partes > 0 or r["efeitos"].is_empty() else "toda"
	return r


static func _gatilho(u: Universo, clausula: String) -> Dictionary:
	var c := " " + TextUtil.normalizar(clausula).strip_edges() + " "
	for par in GATILHOS:
		for forma in par[1]:
			if c.contains(" " + forma + " "):
				var g := {"tipo": "acao", "acao": par[0]}
				if par[0] == "usar_poder":
					g["categoria"] = _categoria_no_texto(u, c)
				var lugar := _lugar_no_texto(u, clausula)
				if lugar != "":
					g["lugar"] = lugar
				return g
	# Poder pelo nome ("quem usa o Fogo Negro").
	for m in Ligador.new(u).encontrar(clausula):
		if Sugestoes.categoria(u.entidade(m["entidade"]).get("tipo", "")) == "poder" and (c.contains(" usa ") or c.contains(" usar ") or c.contains(" lanca ") or c.contains(" invoca ")):
			return {"tipo": "acao", "acao": "usar_poder", "poder": m["entidade"], "categoria": ""}
	return {}


static func _categoria_no_texto(u: Universo, c: String) -> String:
	if c.contains("magia") or c.contains("feitic") or c.contains("encant") or c.contains("arcan"):
		return "magia"
	if c.contains("poder") or c.contains("dom"):
		return ""
	return ""


static func _lugar_no_texto(u: Universo, t: String) -> String:
	for m in Ligador.new(u).encontrar(t):
		if Mapa.e_lugar(u, m["entidade"]):
			return m["entidade"]
	return ""


## Um gatilho com palavras do autor ("bebe da fonte de Varn").
static func _termo(u: Universo, clausula: String) -> Dictionary:
	var limpo := TextUtil.normalizar(clausula).strip_edges()
	for p in ["quem ", "aquele que ", "aqueles que ", "alguem ", "houver ", "ha ", "tiver "]:
		limpo = limpo.trim_prefix(p)
	var g := {"tipo": "termo", "termo": limpo, "raizes": raizes(limpo)}
	var lugar := _lugar_no_texto(u, clausula)
	if lugar != "":
		g["lugar"] = lugar
	return g


## Raízes das palavras que importam (para achar "bebeu da fonte" quando a lei diz "bebe da fonte").
static func raizes(t: String) -> Array:
	var r: Array = []
	for w in TextUtil.palavras(TextUtil.normalizar(t)):
		if w in PALAVRAS_VAZIAS or w.length() < 3:
			continue
		r.append(w.substr(0, 4) if w.length() >= 4 else w)
	return r


static func _quem(u: Universo, t: String) -> Dictionary:
	var q := {"tipo": "filtro", "palavras": [], "lugar": "", "entidade": ""}
	var mencoes := Ligador.new(u).encontrar(t)
	for m in mencoes:
		if Mapa.e_lugar(u, m["entidade"]):
			q["lugar"] = m["entidade"]
		elif q["entidade"] == "" and Sugestoes.categoria(u.entidade(m["entidade"]).get("tipo", "")) in ["pessoa", "entidade", "criatura"] and mencoes.size() == 1:
			q["entidade"] = m["entidade"]
	var nomes_citados := ""
	for m in mencoes:
		nomes_citados += " " + TextUtil.normalizar(u.entidade(m["entidade"])["nome"])
	for w in TextUtil.palavras(TextUtil.normalizar(t)):
		if w in PALAVRAS_VAZIAS or w in ["todos", "todas", "qualquer", "aquele", "aqueles", "neste", "mundo"] or nomes_citados.contains(w):
			continue
		q["palavras"].append(w.substr(0, maxi(3, w.length() - 2)))
	if q["entidade"] != "":
		q["tipo"] = "entidade"
	elif q["palavras"].is_empty() and q["lugar"] == "":
		q["tipo"] = "todos"
	return q


static func _tirar_condicoes(u: Universo, n: String, r: Dictionary) -> String:
	var rx := RegEx.new()
	# chance
	rx.compile("(\\d+)\\s*%\\s*das vezes|as vezes|raramente|quase sempre")
	var m := rx.search(n)
	if m != null:
		var ch := 0.5
		if m.get_string(1) != "":
			ch = float(m.get_string(1)) / 100.0
		elif m.get_string(0) == "raramente":
			ch = 0.15
		elif m.get_string(0) == "quase sempre":
			ch = 0.85
		r["se"].append({"tipo": "chance", "valor": ch})
		n = (n.substr(0, m.get_start()) + n.substr(m.get_end())).strip_edges().trim_suffix(",")
	# "se/só se estiver ferido", "se tiver a marca X", "se for de Kresk", "se for velho"
	rx.compile("(?:^|,\\s*|\\s)(?:so |somente |apenas )?se (estiver|for|tiver|morar|houver|ainda)\\s+([^,]+)")
	m = rx.search(n)
	while m != null:
		var verbo := m.get_string(1)
		var resto := m.get_string(2).strip_edges()
		var cond := {}
		if verbo == "estiver" and resto.begins_with("ferid"):
			cond = {"tipo": "ferido"}
		elif verbo == "estiver" and (resto.begins_with("em ") or resto.begins_with("no ") or resto.begins_with("na ")):
			cond = {"tipo": "em", "lugar": _lugar_no_texto(u, resto)}
		elif verbo == "for" and (resto.begins_with("velh") or resto.begins_with("idos")):
			cond = {"tipo": "idade_min", "valor": 60}
		elif verbo == "for" and (resto.begins_with("crianca") or resto.begins_with("jovem")):
			cond = {"tipo": "idade_max", "valor": 15 if resto.begins_with("crianca") else 25}
		elif verbo in ["for", "morar"] and (resto.begins_with("de ") or resto.begins_with("do ") or resto.begins_with("da ") or resto.begins_with("em ")):
			cond = {"tipo": "de", "lugar": _lugar_no_texto(u, resto), "texto": resto.substr(3)}
		elif verbo == "tiver":
			cond = {"tipo": "tem", "texto": resto.trim_prefix("a marca ").trim_prefix("o ").trim_prefix("a ").trim_prefix("um ").trim_prefix("uma ").trim_prefix("\"").trim_suffix("\"")}
		else:
			cond = {"tipo": "tem", "texto": resto}
			r["avisos"].append("Condição \"se %s %s\" lida como: ter \"%s\" na ficha ou nas marcas." % [verbo, resto, resto])
		r["se"].append(cond)
		n = (n.substr(0, m.get_start()) + " " + n.substr(m.get_end())).strip_edges().trim_suffix(",").strip_edges()
		m = rx.search(n)
	return n


# ---------------------------------------------------------------- descrever (para a ficha da lei)

static func descrever_quando(u: Universo, q: Dictionary) -> String:
	match str(q.get("tipo", "")):
		"acao":
			var s: String = NOMES_GATILHO.get(q["acao"], q["acao"])
			if q["acao"] == "usar_poder":
				if q.get("poder", "") != "":
					s = "usar %s" % u.entidade(q["poder"]).get("nome", "?")
				elif q.get("categoria", "") == "magia":
					s = "usar magia"
			if q.get("lugar", "") != "":
				s += " em %s" % u.entidade(q["lugar"]).get("nome", "?")
			return "ao " + s
		"termo":
			return "quando acontecer: \"%s\"" % q["termo"]
		"periodico":
			if q.get("estacao", "") != "":
				return "todo %s" % q["estacao"]
			return "a cada %s" % Pecas._tempo(int(q["a_cada"]))
		"campo":
			return "para quem tem \"%s\" na ficha" % q["texto"]
		"sempre":
			return "sempre (vale para quem combina)"
	return "?"


static func descrever_quem(u: Universo, q: Dictionary) -> String:
	match str(q.get("tipo", "todos")):
		"todos":
			return "todos"
		"entidade":
			return u.entidade(q["entidade"]).get("nome", "?")
	var partes: Array = []
	if not q["palavras"].is_empty():
		partes.append(" ".join(q["palavras"]) + "…")
	if q.get("lugar", "") != "":
		partes.append("de %s" % u.entidade(q["lugar"]).get("nome", "?"))
	return " ".join(partes)


static func descrever_se(u: Universo, se: Array) -> String:
	var partes: Array = []
	for c in se:
		match str(c["tipo"]):
			"chance":
				partes.append("%d%% das vezes" % roundi(float(c["valor"]) * 100))
			"ferido":
				partes.append("se estiver ferido")
			"em":
				partes.append("se estiver em %s" % u.entidade(c["lugar"]).get("nome", "?"))
			"de":
				partes.append("se for de %s" % (u.entidade(c["lugar"]).get("nome", "?") if c["lugar"] != "" else c["texto"]))
			"idade_min":
				partes.append("se tiver %d anos ou mais" % int(c["valor"]))
			"idade_max":
				partes.append("se tiver até %d anos" % int(c["valor"]))
			"tem":
				partes.append("se tiver \"%s\"" % c["texto"])
	return ", ".join(partes) if not partes.is_empty() else "sem condições"


# ---------------------------------------------------------------- disparar

## Um fato novo aconteceu: as leis reagem. Devolve os fatos de efeito criados.
static func reagir(u: Universo, fid: String) -> Array:
	var f := u.fatos.obter(fid)
	if f.is_empty() or not f["canon"] or f["dados"].get("efeito_de_lei", false) or todas(u).is_empty():
		return []
	var novos: Array = []
	var d: Dictionary = f["dados"]
	var acao := str(d.get("acao", ""))
	var s: Array = f["sujeitos"]
	for r in todas(u):
		if not r["ligada"]:
			continue
		var q: Dictionary = r["quando"]
		var ctxs: Array = []
		# Fato que veio de um termo da lei (capítulo ou intervenção).
		if str(d.get("regra", "")) == r["id"] and f["tipo"] != "lei do universo":
			ctxs.append({"sujeito": s[0] if not s.is_empty() else "", "outro": s[1] if s.size() > 1 else "", "lugar": f["lugar"]})
		elif q.get("tipo", "") == "acao":
			ctxs = _contextos_da_acao(u, q, f, acao, s)
		for ctx in ctxs:
			if q.get("lugar", "") != "" and not _no_lugar(u, str(ctx.get("lugar", "")), q["lugar"]) and not _no_lugar(u, u.estado(str(ctx.get("sujeito", ""))).get("local", "") if ctx["sujeito"] != "" else "", q["lugar"]):
				continue
			var fx := disparar(u, r, ctx, fid)
			if fx != "":
				novos.append(fx)
	return novos


static func _no_lugar(u: Universo, onde: String, lugar: String) -> bool:
	return onde != "" and (onde == lugar or Mapa.ancestrais(u, onde).has(lugar))


static func _contextos_da_acao(u: Universo, q: Dictionary, f: Dictionary, acao: String, s: Array) -> Array:
	var a: String = s[0] if not s.is_empty() else ""
	var b: String = s[1] if s.size() > 1 else ""
	var lugar: String = f["lugar"] if f["lugar"] != "" else (u.estado(a)["local"] if a != "" else "")
	var ctx := func(suj: String, outro: String) -> Array:
		return [{"sujeito": suj, "outro": outro, "lugar": lugar}] if suj != "" else []
	match str(q["acao"]):
		"vitoria":
			if acao in ["vitoria", "morte_por"]:
				return ctx.call(a, b)
			if acao == "vitoria_um":
				return ctx.call(a, "")
			if acao == "derrota":
				return ctx.call(b, a)
		"derrota":
			if acao in ["vitoria", "morte_por"] and acao != "morte_por":
				return ctx.call(b, a)
			if acao == "derrota":
				return ctx.call(a, b)
			if acao == "derrota_um":
				return ctx.call(a, "")
		"matar":
			if acao == "morte_por":
				return ctx.call(a, b)
		"morte":
			if acao == "morte_por":
				return ctx.call(b, a)
			if acao == "morte" or f["tipo"] in ["morte", "morte natural"]:
				return ctx.call(a, "")
		"luta":
			if acao in ["luta", "vitoria", "morte_por", "derrota"]:
				return ctx.call(a, b) + ctx.call(b, a)
		"casamento":
			if acao == "casamento" or f["tipo"] == "casamento":
				return ctx.call(a, b) + ctx.call(b, a)
		"nascimento":
			if acao == "nascimento" or f["tipo"] == "nascimento":
				return ctx.call(a, "")
		"chegada":
			if acao == "chegada" or f["tipo"] == "chegada":
				return [{"sujeito": a, "outro": "", "lugar": f["lugar"]}] if a != "" else []
		"treino":
			if f["tipo"] == "treino":
				return ctx.call(a, b)
		"ferimento":
			if acao == "ferimento":
				return ctx.call(b, a)
			if f["tipo"] in ["ataque de feras", "doença", "ferido no terremoto"] and s.size() > 1:
				return ctx.call(s[1], "")
		"usar_poder":
			if acao == "usar_poder" and _poder_combina(u, q, f):
				return ctx.call(a, b)
		"fome":
			if f["tipo"] == "fome":
				return [{"sujeito": "", "outro": "", "lugar": f["lugar"]}]
	if str(q["acao"]).begins_with("evento:"):
		var tipo_ev := str(q["acao"]).trim_prefix("evento:")
		for op in f["dados"].get("mudancas", []):
			if op.get("op", "") == "evento_natural" and op.get("tipo", "") == tipo_ev:
				return [{"sujeito": "", "outro": "", "lugar": op["lugar"]}]
	return []


static func _poder_combina(u: Universo, q: Dictionary, f: Dictionary) -> bool:
	var pid := str(f["dados"].get("poder", ""))
	if q.get("poder", "") != "":
		return pid == q["poder"]
	if q.get("categoria", "") == "":
		return true
	if pid != "" and Poderes.categoria(u, pid) == q["categoria"]:
		return true
	return _categoria_no_texto(u, " " + TextUtil.normalizar(str(f["dados"].get("frase", "")) + " " + f["descricao"]) + " ") == q["categoria"]


## Confere QUEM e SE para o sujeito; se valer, cria o fato com os efeitos. Devolve o id.
static func disparar(u: Universo, r: Dictionary, ctx: Dictionary, causa: String) -> String:
	var suj := str(ctx.get("sujeito", ""))
	if suj != "" and not combina_quem(u, r["quem"], suj):
		return ""
	if not _condicoes(u, r, ctx, causa):
		return ""
	var ops: Array = []
	var frases: Array = []
	var alvos_todos: Array = []
	for e in r["efeitos"]:
		var o := Pecas.operacoes(u, e, ctx)
		if o.is_empty() and e.get("peca", "") != "nada":
			continue
		ops.append_array(o)
		var quem := Pecas.alvos(u, e, ctx)
		alvos_todos.append_array(quem)
		frases.append(_texto_do_efeito(u, e, quem))
	if ops.is_empty():
		return ""
	var causas: Array = []
	var fc := u.fatos.obter(causa)
	if not fc.is_empty():
		causas.append(causa)
	var fl := u.fatos.obter(r["fato"])
	var data: Dictionary = fc.get("data", u.relogio) if not fc.is_empty() else u.relogio
	if not fl.is_empty() and DataMundo.ordem(fl["data"]) <= DataMundo.ordem(data):
		causas.append(r["fato"])
	var sujeitos: Array = []
	for x in [suj] + alvos_todos:
		if x != "" and u.entidades.has(x) and not sujeitos.has(x):
			sujeitos.append(x)
	r["disparos"] = int(r.get("disparos", 0)) + 1
	return Simulador.registrar(u, {
		"tipo": "efeito de lei",
		"descricao": "%s (lei: %s)" % [_frase("; ".join(frases)).trim_suffix("."), r["texto"]],
		"sujeitos": sujeitos, "lugar": str(ctx.get("lugar", "")), "data": DataMundo.copiar(data), "causas": causas,
		"origem": {"tipo": BancoDeFatos.ORIGEM_SIMULACAO if not causas.is_empty() else BancoDeFatos.ORIGEM_AUTOR, "ref": r["id"]},
		"dados": {"importancia": 0.5, "efeito_de_lei": true, "regra": r["id"], "mudancas": ops},
	})


static func _texto_do_efeito(u: Universo, e: Dictionary, quem: Array) -> String:
	var nomes: Array = quem.map(func(q): return u.entidade(q).get("nome", "?"))
	var n := ", ".join(nomes.slice(0, 3)) + (" e mais %d" % (nomes.size() - 3) if nomes.size() > 3 else "")
	var plural := nomes.size() > 1
	match str(e.get("peca", "")):
		"envelhecer":
			var d := int(e["dias"])
			return "%s %s %s" % [n, ("envelheceram" if plural else "envelheceu") if d > 0 else ("rejuvenesceram" if plural else "rejuvenesceu"), Pecas._tempo(absi(d)) if absi(d) != 360 else "um ano"]
		"poder":
			var sobe: bool = float(e.get("pct", e.get("soma", 0))) > 0
			return "%s %s" % [n, ("ficaram mais fortes" if plural else "ficou mais forte") if sobe else ("ficaram mais fracos" if plural else "ficou mais fraco")]
		"esquecer":
			return "%s %s" % [n, "esqueceram" if plural else "esqueceu"] + (" tudo" if int(e["dias"]) >= 360000 else " o que viveu no último " + Pecas._tempo(int(e["dias"])))
		"morrer":
			return "%s %s" % [n, "morreram" if plural else "morreu"]
		"ferir":
			return "%s %s (%s)" % [n, "foram feridos" if plural else "foi ferido", e.get("descricao", "")]
		"curar":
			return "%s %s" % [n, "se curaram" if plural else "se curou"]
		"emocao":
			return "%s %s %s" % [n, "sentiram" if plural else "sentiu", Paginas.NOMES_EMOCAO.get(e["emocao"], e["emocao"])]
		"relacao":
			return "%s mudou o que sente" % n
		"mover":
			return "%s %s para %s" % [n, "foram" if plural else "foi", u.entidade(e["lugar"]).get("nome", "?")]
		"reviver":
			return "%s %s à vida" % [n, "voltaram" if plural else "voltou"]
		"evento":
			return "%s começou em %s" % [Natureza.EVENTOS.get(e["evento"], {}).get("nome", e["evento"]).capitalize(), n]
		"natureza":
			return "%s em %s: %+d%%" % [e["especie"], n, roundi(float(e["delta"]) * 100)]
		"traco":
			return "%s %s" % [n, "mudou de jeito"]
		"marca":
			return "%s %s \"%s\"" % [n, "passaram a ter a marca" if plural else "passou a ter a marca", e["marca"]]
		"nada":
			return "nada aconteceu"
	return n


static func _condicoes(u: Universo, r: Dictionary, ctx: Dictionary, causa: String) -> bool:
	var suj := str(ctx.get("sujeito", ""))
	for c in r["se"]:
		match str(c["tipo"]):
			"chance":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(causa + "|" + r["id"] + "|" + suj)
				if rng.randf() >= float(c["valor"]):
					return false
			"ferido":
				if suj == "" or Estado.saude_atual(u, suj) >= 0.95:
					return false
			"em":
				if suj == "" or not _no_lugar(u, u.estado(suj)["local"], c["lugar"]):
					return false
			"de":
				if suj == "" or not _e_de(u, suj, c.get("lugar", ""), str(c.get("texto", ""))):
					return false
			"idade_min":
				if suj == "" or Estado.idade(u, suj) < int(c["valor"]):
					return false
			"idade_max":
				if suj == "" or Estado.idade(u, suj) < 0 or Estado.idade(u, suj) > int(c["valor"]):
					return false
			"tem":
				if suj == "" or not tem(u, suj, str(c["texto"])):
					return false
	return true


## A entidade "tem" algo: uma marca, um campo da ficha que cita isso, ou um poder com esse nome.
static func tem(u: Universo, eid: String, texto: String) -> bool:
	var k := TextUtil.chave(texto)
	if k == "":
		return false
	for m in Pecas.marcas(u, eid):
		if TextUtil.chave(m).contains(k):
			return true
	for c in u.entidade(eid).get("campos", []):
		if str(c["valor"]).strip_edges() == "":
			continue
		if TextUtil.chave(c["valor"]).contains(k) or TextUtil.chave(c["chave"]) == k or TextUtil.chave(str(c["chave"]) + " " + str(c["valor"])).contains(k):
			return true
	return false


static func _e_de(u: Universo, eid: String, lugar: String, texto: String) -> bool:
	if lugar != "":
		if _no_lugar(u, u.estado(eid)["local"], lugar):
			return true
		var nome := TextUtil.chave(u.entidade(lugar)["nome"])
		for c in u.entidade(eid).get("campos", []):
			if TextUtil.normalizar(c["chave"]) in ["povo", "origem", "nacao", "reino", "terra natal", "naturalidade", "raca"] and TextUtil.chave(c["valor"]).contains(nome):
				return true
		return false
	return tem(u, eid, texto)


## O sujeito combina com QUEM da lei?
static func combina_quem(u: Universo, q: Dictionary, eid: String) -> bool:
	match str(q.get("tipo", "todos")):
		"todos":
			return true
		"entidade":
			return eid == q["entidade"]
	if q.get("lugar", "") != "" and not _e_de(u, eid, q["lugar"], ""):
		return false
	if q.get("palavras", []).is_empty():
		return true
	var e := u.entidade(eid)
	var texto := TextUtil.normalizar(e.get("tipo", "") + " " + " ".join(Pecas.marcas(u, eid)))
	for c in e.get("campos", []):
		texto += " " + TextUtil.normalizar(c["valor"])
	for p in q["palavras"]:
		if not texto.contains(str(p)):
			return false
	return true


# ---------------------------------------------------------------- termos (capítulos e intervenções)

## Leis cujo termo aparece no texto (todas as raízes presentes).
static func termos_no_texto(u: Universo, texto: String) -> Array:
	var norm := " " + TextUtil.normalizar(texto) + " "
	var achadas: Array = []
	for r in todas(u):
		if not r["ligada"] or r["quando"].get("tipo", "") != "termo":
			continue
		var rz: Array = r["quando"].get("raizes", [])
		if rz.is_empty():
			continue
		var todas_ok := true
		for raiz in rz:
			if not norm.contains(" " + str(raiz)):
				todas_ok = false
				break
		if todas_ok:
			achadas.append(r)
	return achadas


## Propostas para a margem: frases do capítulo que batem com um termo de lei.
static func propostas_da_frase(u: Universo, cid: String, frase: String, mencoes: Array) -> Array:
	var props: Array = []
	for r in termos_no_texto(u, frase):
		var pessoas: Array = mencoes.filter(func(m): return not Mapa.e_lugar(u, m["entidade"])).map(func(m): return m["entidade"])
		var lugares: Array = mencoes.filter(func(m): return Mapa.e_lugar(u, m["entidade"])).map(func(m): return m["entidade"])
		var suj: String = pessoas[0] if not pessoas.is_empty() else ""
		var precisa_sujeito: Variant = r["efeitos"].any(func(e): return e["alvo"] in ["sujeito", "outro"])
		if suj == "" and precisa_sujeito:
			continue
		var sujeitos: Array = pessoas.slice(0, 2)
		var efeitos: Array = r["efeitos"].map(func(e): return Pecas.descrever(u, e))
		props.append({
			"id": Ids.novo("prp"), "capitulo": cid, "frase": frase.strip_edges(), "acao": "regra", "regra": r["id"],
			"sujeitos": sujeitos, "lugar": lugares[0] if not lugares.is_empty() else str(r["quando"].get("lugar", "")),
			"status": "pendente",
			"descricao": "A lei \"%s\" vale para %s." % [_frase(r["texto"]).trim_suffix("."), u.entidade(suj).get("nome", "?") if suj != "" else u.entidade(lugares[0] if not lugares.is_empty() else "").get("nome", "este lugar")],
			"assinatura": "%s|%s|regra|%s" % [cid, TextUtil.chave(frase), r["id"]],
		})
	return props


# ---------------------------------------------------------------- o passo do tempo

## Leis periódicas, leis "sempre" e leis de campo, a cada passo do relógio.
static func passo(u: Universo, _dias: int, _rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for r in todas(u):
		if not r["ligada"]:
			continue
		var q: Dictionary = r["quando"]
		match str(q.get("tipo", "")):
			"periodico":
				var a_cada := int(q["a_cada"])
				var proximo := int(r.get("proximo", int(r["desde"]) + a_cada))
				if q.get("estacao", "") != "":
					proximo = int(r.get("proximo", _proxima_estacao(int(r["desde"]), str(q["estacao"]))))
				if agora >= proximo:
					r["proximo"] = proximo + a_cada
					var causa := _fato_do_tempo(u, r)
					var lugar := ""
					for e in r["efeitos"]:
						if e.get("lugar_alvo", "") != "":
							lugar = e["lugar_alvo"]
					if lugar == "" and r["quem"].get("lugar", "") != "":
						lugar = r["quem"]["lugar"]
					var alvos_lei := _quem_combina(u, r) if r["efeitos"].any(func(e): return e["alvo"] == "sujeito") else [""]
					for suj in alvos_lei:
						var fx := disparar(u, r, {"sujeito": suj, "outro": "", "lugar": lugar if suj == "" else u.estado(suj)["local"]}, causa)
						if fx != "":
							novos.append(fx)
			"sempre", "campo":
				var aplicados: Dictionary = r.get("aplicados", {})
				r["aplicados"] = aplicados
				for eid in _quem_combina(u, r):
					if aplicados.has(eid):
						continue
					if q["tipo"] == "campo" and not tem(u, eid, str(q["texto"])):
						continue
					aplicados[eid] = true
					var causa2: String = u.entidade(eid).get("fato_criacao", "")
					var fx2 := disparar(u, r, {"sujeito": eid, "outro": "", "lugar": u.estado(eid)["local"]}, causa2)
					if fx2 != "":
						novos.append(fx2)
	return novos


static func _proxima_estacao(desde: int, estacao: String) -> int:
	var inicio: Variant = {"primavera": 1, "verao": 91, "outono": 181, "inverno": 271}.get(estacao, 1)
	var ano := int(floor(float(desde - 1) / DataMundo.DIAS_POR_ANO))
	var alvo := ano * DataMundo.DIAS_POR_ANO + int(inicio)
	return alvo if alvo > desde else alvo + DataMundo.DIAS_POR_ANO


## O fato que marca a passagem do tempo da lei ("Passaram-se 100 anos").
static func _fato_do_tempo(u: Universo, r: Dictionary) -> String:
	return Simulador.registrar(u, {
		"tipo": "ciclo", "descricao": "Chegou a hora marcada pela lei: %s" % _frase(r["texto"]),
		"causas": [r["fato"]] if u.fatos.existe(r["fato"]) and DataMundo.ordem(u.fatos.obter(r["fato"])["data"]) <= DataMundo.ordem(u.relogio) else [],
		"origem": {"tipo": BancoDeFatos.ORIGEM_SIMULACAO if u.fatos.existe(r["fato"]) else BancoDeFatos.ORIGEM_AUTOR, "ref": r["id"]},
		"dados": {"importancia": 0.5, "efeito_de_lei": true, "regra": r["id"]},
	})


static func _quem_combina(u: Universo, r: Dictionary) -> Array:
	var lista: Array = []
	for e in u.entidades_ativas():
		if not Estado.tem_mente(u, e["id"]) and r["quem"].get("tipo", "todos") == "todos" and r["quando"].get("tipo", "") != "campo":
			continue
		if combina_quem(u, r["quem"], e["id"]):
			lista.append(e["id"])
	return lista


## Peça especial: "os elfos vivem 700 anos" (lida pelo Corpo).
static func expectativa_por_lei(u: Universo, eid: String) -> float:
	for r in todas(u):
		if not r["ligada"]:
			continue
		for e in r["efeitos"]:
			if e.get("peca", "") == "expectativa" and combina_quem(u, r["quem"], eid):
				return float(e["anos"])
	return -1.0
