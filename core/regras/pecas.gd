class_name Pecas
extends RefCounted
## As peças de efeito que as regras escritas usam ("o quê" de uma regra).
## Cada efeito é um dicionário {peca, alvo, ...}; ler() tira os efeitos de um texto
## em português, e operacoes() transforma um efeito nas operações de mudança que
## vão dentro do fato (e assim tudo pode ser desfeito e reconstruído).
##
## Peças: envelhecer, poder (por cento ou somado), esquecer, morrer, ferir, curar,
## emocao, relacao, mover, reviver, evento (seca, praga…), natureza (espécie ±%),
## marca (um estado com nome: "amaldiçoado", "conhece o Autor"), traco, nada.
## O que não se encaixa em nenhuma peça vira MARCA com o próprio texto: assim nada
## fica sem efeito, e a regra é marcada como "entendida em parte" para você conferir.

const NUMEROS := {"um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6,
	"sete": 7, "oito": 8, "nove": 9, "dez": 10, "vinte": 20, "trinta": 30, "cem": 100, "mil": 1000, "meio": 0.5}
const UNIDADES := {"dia": 1, "dias": 1, "semana": 7, "semanas": 7, "mes": 30, "meses": 30, "estacao": 90,
	"ano": 360, "anos": 360, "decada": 3600, "decadas": 3600, "seculo": 36000, "seculos": 36000}
const EMOCOES := {"medo": "medo", "odio": "odio", "raiva": "raiva", "amor": "amor", "alegria": "alegria",
	"tristeza": "tristeza", "culpa": "culpa", "esperanca": "esperanca", "paz": "paz", "solidao": "solidao",
	"desespero": "desespero", "gratidao": "gratidao", "inveja": "inveja", "orgulho": "orgulho", "luto": "luto", "rancor": "rancor"}
const RELACOES := {"odiar": {"raiva": 0.6}, "amar": {"afeto": 0.6}, "temer": {"medo": 0.6}, "respeitar": {"respeito": 0.5},
	"confiar": {"confianca": 0.5}, "desconfiar": {"confianca": -0.5}}


static func _num(p: String) -> float:
	var n := Combate.ler_numero(p)
	if n > 0:
		return n
	return float(NUMEROS.get(p, 0))


## Quantidade + unidade de tempo no texto ("um ano", "3 meses", "o último ano") em dias.
static func _dias(t: String, padrao: int) -> int:
	var w := TextUtil.palavras(t)
	for i in w.size():
		if UNIDADES.has(w[i]):
			var n := _num(w[i - 1]) if i > 0 else 0.0
			if n <= 0:
				n = 1.0
			return int(n * UNIDADES[w[i]])
	return padrao


static func _pct(t: String, padrao: float) -> float:
	var rx := RegEx.new()
	rx.compile("(\\d+(?:[.,]\\d+)?)\\s*(%|por cento)")
	var m := rx.search(t)
	if m != null:
		return float(m.get_string(1).replace(",", ".")) / 100.0
	return padrao


## Lê um texto de efeito e devolve a lista de efeitos.
## Partes separadas por ";" ou " e " viram efeitos diferentes.
static func ler(u: Universo, texto: String) -> Array:
	var efeitos: Array = []
	var partes: Array = []
	for bloco in texto.replace("\n", ";").split(";", false):
		for p in _dividir_e(bloco):
			if p.strip_edges() != "":
				partes.append(p.strip_edges())
	var ultimo_alvo := ""
	for p in partes:
		var e := ler_um(u, p)
		if e.is_empty():
			continue
		# "todos em Varn sentem medo e fogem": o alvo continua no segundo pedaço.
		if e.get("alvo_explicito", false):
			ultimo_alvo = e["alvo"]
		elif ultimo_alvo != "" and e["alvo"] == "sujeito":
			e["alvo"] = ultimo_alvo
			e["lugar_alvo"] = efeitos.back().get("lugar_alvo", "") if not efeitos.is_empty() else ""
		efeitos.append(e)
	return efeitos


## " e " separa efeitos, mas não dentro de nomes ("Pedra e Cal") nem números.
static func _dividir_e(t: String) -> Array:
	var r: Array = []
	var atual := ""
	var palavras := t.split(" ", false)
	for i in palavras.size():
		var w: String = palavras[i]
		if w == "e" and i > 0 and i < palavras.size() - 1 and palavras[i + 1].substr(0, 1) == palavras[i + 1].substr(0, 1).to_lower():
			r.append(atual)
			atual = ""
			continue
		atual += (" " if atual != "" else "") + w
	r.append(atual)
	return r


static func ler_um(u: Universo, original: String) -> Dictionary:
	var t := " " + TextUtil.normalizar(original) + " "
	var e := {"texto": original.strip_edges(), "alvo": "sujeito"}
	# Alvo explícito.
	var lig := Ligador.new(u)
	var mencoes := lig.encontrar(original)
	var lugar_citado := ""
	var pessoa_citada := ""
	for m in mencoes:
		if Mapa.e_lugar(u, m["entidade"]):
			if lugar_citado == "":
				lugar_citado = m["entidade"]
		elif pessoa_citada == "":
			pessoa_citada = m["entidade"]
	if (t.contains(" todos ") or t.contains(" moradores ") or t.contains(" quem mora ") or t.contains(" o povo ") or t.contains(" habitantes ")) and lugar_citado != "":
		e["alvo"] = "todos_no_lugar"
		e["lugar_alvo"] = lugar_citado
		e["alvo_explicito"] = true
	elif t.contains(" todos ") or t.contains(" quem estiver ") or t.contains(" todos ali ") or t.contains(" quem esta ali "):
		e["alvo"] = "todos_no_lugar"
		e["alvo_explicito"] = true
	elif t.contains(" o outro ") or t.contains(" o vencido ") or t.contains(" o derrotado ") or t.contains(" a vitima ") or t.contains(" o alvo ") or t.contains(" quem perdeu "):
		e["alvo"] = "outro"
		e["alvo_explicito"] = true
	elif pessoa_citada != "" and not t.contains(" a " + TextUtil.normalizar(u.entidade(pessoa_citada)["nome"])):
		e["alvo"] = "entidade:" + pessoa_citada
	var rx := RegEx.new()
	# quanto tempo vivem ("os elfos vivem 700 anos")
	rx.compile("\\bvive(?:m)?\\s+(?:ate\\s+|por\\s+|uns\\s+|cerca de\\s+)?(\\d+(?:[.,]\\d+)?(?:\\s+mil)?|cem|mil)\\s+anos")
	var mv := rx.search(t)
	if mv != null:
		e["peca"] = "expectativa"
		e["anos"] = _num(mv.get_string(1))
		return e
	# perder saúde ("perde 10% da saúde")
	if (t.contains("perde") or t.contains("perdem")) and (t.contains("saude") or t.contains(" vida")) and t.contains("%"):
		e["peca"] = "ferir"
		e["gravidade"] = _pct(t, 0.1)
		e["descricao"] = "desgaste"
		return e
	# envelhecer / rejuvenescer
	if t.contains("envelhec"):
		e["peca"] = "envelhecer"
		e["dias"] = _dias(t, 360)
		return e
	if t.contains("rejuvenesc"):
		e["peca"] = "envelhecer"
		e["dias"] = -_dias(t, 360)
		return e
	# força / poder
	if t.contains("mais forte") or t.contains("mais poderos") or t.contains("mais fraco") or t.contains("mais fraca") or t.contains("perde forca") or t.contains("perde poder") or t.contains("ganha forca") or t.contains("ganha poder"):
		var sinal := -1.0 if (t.contains("fraco") or t.contains("fraca") or t.contains("perde")) else 1.0
		rx.compile("(?:ganha|perde)m?\\s+(\\d+(?:[.,]\\d+)?)\\s+(?:de\\s+)?(?:forca|poder)")
		var m := rx.search(t)
		e["peca"] = "poder"
		if m != null and not t.contains("%"):
			e["soma"] = sinal * float(m.get_string(1).replace(",", "."))
		else:
			e["pct"] = sinal * _pct(t, 0.1)
		return e
	# memória
	if t.contains("esquec") or t.contains("perde a memoria") or t.contains("perdem a memoria"):
		e["peca"] = "esquecer"
		e["dias"] = 36000 * 10 if t.contains("memoria") and not t.contains("ultim") else _dias(t, 360)
		return e
	# os mortos despertam
	if t.contains("mortos") and (t.contains("desperta") or t.contains("levanta") or t.contains("volta") or t.contains("ressuscita") or t.contains("acorda")):
		e["peca"] = "reviver"
		e["alvo"] = "mortos_no_lugar"
		if lugar_citado != "":
			e["lugar_alvo"] = lugar_citado
		e["marca"] = "morto-vivo"
		return e
	if t.contains("ressuscit") or t.contains("volta a vida") or t.contains("volta dos mortos"):
		e["peca"] = "reviver"
		return e
	# Poderes que mudam o motor: parar o tempo, sono eterno, apagar, ver o futuro, voltar no tempo.
	if t.contains("para o tempo") or t.contains("parar o tempo") or t.contains("congela o tempo") or t.contains("pausa o tempo") or t.contains("o tempo para"):
		e["peca"] = "pausar"
		e["dias"] = _dias(t, 7)
		return e
	if t.contains("sono eterno") or t.contains("dorme para sempre") or t.contains("dormem para sempre") or t.contains("cai em sono") or t.contains("caem em sono") or t.contains("adormece"):
		e["peca"] = "adormecer"
		e["alvo"] = "lugar"
		if lugar_citado != "":
			e["lugar_alvo"] = lugar_citado
		return e
	if t.contains("quebra a maldicao") or t.contains("desperta do sono") or t.contains("despertam do sono") or t.contains("acorda do sono"):
		e["peca"] = "despertar"
		e["alvo"] = "lugar"
		if lugar_citado != "":
			e["lugar_alvo"] = lugar_citado
		return e
	if t.contains("apagad") and t.contains("existencia") or t.contains("deixa de existir") or t.contains("apaga da existencia") or t.contains("apaga o outro"):
		e["peca"] = "apagar"
		if not e.get("alvo_explicito", false) and pessoa_citada == "":
			e["alvo"] = "outro"
		return e
	if t.contains("ve o futuro") or t.contains("ver o futuro") or t.contains("preve o futuro") or t.contains("enxerga o futuro") or t.contains("visao do futuro"):
		e["peca"] = "prever"
		e["dias"] = _dias(t, 360) if (t.contains(" ano") or t.contains(" mes") or t.contains(" dia")) else 360
		return e
	if t.contains("volta ao passado") or t.contains("voltar ao passado") or t.contains("viaja ao passado") or t.contains("volta no tempo") or t.contains("voltar no tempo"):
		e["peca"] = "galho"
		e["anos"] = int(_dias(t, 3600) / 360)
		return e
	# morte, doença, ferimento, cura
	if rx.compile("\\bmorre(m)?\\b") == OK and rx.search(t) != null or t.contains(" cai morto ") or t.contains(" cai morta "):
		e["peca"] = "morrer"
		return e
	if t.contains("adoec") or t.contains("fica doente") or t.contains("ficam doentes"):
		e["peca"] = "ferir"
		e["gravidade"] = 0.3
		e["descricao"] = "doença"
		return e
	rx.compile("\\b(\\w+)\\s+(?:atacam|ataca|mordem|morde)\\b")
	var ataque := rx.search(t)
	if ataque != null or t.contains("e atacado por") or t.contains("sao atacados por"):
		var quem := ataque.get_string(1) if ataque != null else ""
		if quem == "" or quem in ["que", "quem"]:
			rx.compile("atacad[oa]s? (?:por|pel[oa]s?) (\\w+)")
			var m2 := rx.search(t)
			quem = m2.get_string(1) if m2 != null else "feras"
		e["peca"] = "ferir"
		e["gravidade"] = 0.25
		e["descricao"] = "ataque de " + quem
		return e
	if t.contains(" se fere") or t.contains(" fica ferid") or t.contains(" ficam ferid") or t.contains(" se machuca") or t.contains(" sangra"):
		e["peca"] = "ferir"
		e["gravidade"] = 0.2
		e["descricao"] = "ferimento"
		return e
	if t.contains(" se cura") or t.contains(" cura-se") or t.contains(" e curad") or t.contains(" sao curad") or t.contains(" se curam") or t.contains(" sara"):
		e["peca"] = "curar"
		e["quanto"] = 0.5
		return e
	# emoções
	for w in TextUtil.palavras(t):
		if EMOCOES.has(w) and (t.contains("sent") or t.contains("tom") or t.contains("enche") or t.contains("invade") or t.contains("fica com") or t.contains("ficam com")):
			e["peca"] = "emocao"
			e["emocao"] = EMOCOES[w]
			e["forca"] = 0.5
			if pessoa_citada != "" and t.contains(" de " + TextUtil.normalizar(u.entidade(pessoa_citada)["nome"]).split(" ")[0]) or t.contains(" por " + TextUtil.normalizar(u.entidade(pessoa_citada)["nome"] if pessoa_citada != "" else "~").split(" ")[0]):
				e["por"] = pessoa_citada
				e["alvo"] = "sujeito" if not e.get("alvo_explicito", false) else e["alvo"]
			return e
	# relações ("passa a odiar o outro")
	for verbo in RELACOES:
		if t.contains(" a " + verbo) or t.contains(" passa a " + verbo) or t.contains(" passam a " + verbo):
			e["peca"] = "relacao"
			e["deltas"] = RELACOES[verbo]
			e["com"] = "outro" if (t.contains(" o outro") or t.contains(" quem ")) else ("entidade:" + pessoa_citada if pessoa_citada != "" else "outro")
			if e["alvo"] == "outro" or e["alvo"].begins_with("entidade:"):
				e["alvo"] = "sujeito"
			return e
	# acontecimentos naturais (seca, praga, peste…)
	var naturais := Natureza.interpretar(original)
	if not naturais.is_empty():
		e["peca"] = "evento"
		e["evento"] = naturais[0]["tipo"]
		e["forca"] = naturais[0]["forca"]
		e["dias"] = naturais[0]["dias"]
		e["alvo"] = "lugar"
		if lugar_citado != "":
			e["lugar_alvo"] = lugar_citado
		return e
	# espécies e lavouras sobem ou descem
	rx.compile("(lavouras|colheitas?|rebanhos|gado|peixes|caca|[a-z\\-]+)\\s+(caem|cai|diminuem|diminui|perdem|somem|crescem|cresce|aumentam|aumenta|dobram)")
	var mn := rx.search(t)
	if mn != null:
		var nome_esp := mn.get_string(1)
		nome_esp = {"colheita": "lavouras", "colheitas": "lavouras", "gado": "rebanhos"}.get(nome_esp, nome_esp)
		var sobe := mn.get_string(2) in ["crescem", "cresce", "aumentam", "aumenta", "dobram"]
		e["peca"] = "natureza"
		e["especie"] = nome_esp
		e["delta"] = (1.0 if sobe else -1.0) * _pct(t, 1.0 if mn.get_string(2) == "dobram" else 0.3)
		if mn.get_string(2) == "somem":
			e["delta"] = -1.5
		e["alvo"] = "lugar"
		if lugar_citado != "":
			e["lugar_alvo"] = lugar_citado
		return e
	# mover ("vai para Kresk", "é levado a Varn")
	if lugar_citado != "" and (t.contains(" vai para ") or t.contains(" vao para ") or t.contains(" levad") or t.contains(" parte para ") or t.contains(" partem para ") or t.contains(" foge para ") or t.contains(" fogem para ") or t.contains(" e mandado para ")):
		e["peca"] = "mover"
		e["lugar"] = lugar_citado
		e["alvo"] = "sujeito" if not e.get("alvo_explicito", false) else e["alvo"]
		return e
	if t.contains(" nada acontece ") or t.contains(" nada muda ") or t.strip_edges() == "nada":
		e["peca"] = "nada"
		return e
	# traços e marcas ("fica amaldiçoado", "torna-se corajoso", "passa a ser arauto")
	rx.compile("(?:fica|ficam|torna-se|tornam-se|se torna|se tornam|vira|viram|passa a ser|passam a ser|e marcad[oa] como|ganha a marca|recebe a marca)\\s+(.+)$")
	var mm := rx.search(t.strip_edges())
	if mm != null:
		var resto := mm.get_string(1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		var traco := _traco_de(resto)
		if not traco.is_empty():
			e["peca"] = "traco"
			e["traco"] = traco["traco"]
			e["delta"] = traco["delta"]
			return e
		e["peca"] = "marca"
		e["marca"] = _limpo(original, resto)
		return e
	# Nenhuma peça conhecida: vira marca com o próprio texto (entendido em parte).
	e["peca"] = "marca"
	e["marca"] = original.strip_edges().trim_suffix(".")
	e["livre"] = true
	return e


static func _traco_de(texto: String) -> Dictionary:
	var w := TextUtil.palavras(TextUtil.normalizar(texto))
	if w.size() > 2:
		return {}
	for p in w:
		for k in Personalidade.PISTAS:
			if p.begins_with(k):
				var melhor := ""
				var v := 0.0
				for traco in Personalidade.PISTAS[k]:
					if absf(Personalidade.PISTAS[k][traco]) > absf(v):
						v = Personalidade.PISTAS[k][traco]
						melhor = traco
				return {"traco": melhor, "delta": 0.15 * signf(v)}
	return {}


## Recorta do texto original o pedaço que corresponde ao normalizado (para guardar com acento).
static func _limpo(original: String, normalizado: String) -> String:
	var o := original.strip_edges().trim_suffix(".")
	var n := TextUtil.normalizar(o)
	var i := n.find(normalizado)
	if i >= 0 and i + normalizado.length() <= o.length():
		return o.substr(i, normalizado.length()).strip_edges()
	return normalizado


## Descrição curta de um efeito, para mostrar na ficha da regra.
static func descrever(u: Universo, e: Dictionary) -> String:
	var quem: String = {"sujeito": "quem fez", "outro": "o outro", "todos_no_lugar": "todos no lugar", "lugar": "o lugar",
		"mortos_no_lugar": "os mortos do lugar"}.get(e.get("alvo", "sujeito"), "")
	if str(e.get("alvo", "")).begins_with("entidade:"):
		quem = u.entidade(str(e["alvo"]).trim_prefix("entidade:")).get("nome", "?")
	if e.get("lugar_alvo", "") != "":
		quem += " (%s)" % u.entidade(e["lugar_alvo"]).get("nome", "?")
	var o := ""
	match str(e.get("peca", "")):
		"envelhecer":
			var d := int(e["dias"])
			o = ("envelhece " if d > 0 else "rejuvenesce ") + _tempo(absi(d))
		"poder":
			o = ("força %+d%%" % roundi(float(e["pct"]) * 100)) if e.has("pct") else ("força %+.1f" % float(e["soma"]))
		"esquecer":
			o = "esquece " + ("tudo" if int(e["dias"]) >= 360000 else "o último " + _tempo(int(e["dias"])) if int(e["dias"]) in [360, 30, 1] else "os últimos " + _tempo(int(e["dias"])))
		"morrer":
			o = "morre"
		"ferir":
			o = "fica ferido (%s)" % e.get("descricao", "")
		"curar":
			o = "se cura"
		"emocao":
			o = "sente %s" % Paginas.NOMES_EMOCAO.get(e["emocao"], e["emocao"])
		"relacao":
			o = "muda o que sente por %s (%s)" % ["o outro" if e["com"] == "outro" else u.entidade(str(e["com"]).trim_prefix("entidade:")).get("nome", "?"), ", ".join(e["deltas"].keys())]
		"mover":
			o = "vai para %s" % u.entidade(e["lugar"]).get("nome", "?")
		"reviver":
			o = "voltam à vida" if e.get("alvo", "") == "mortos_no_lugar" else "volta à vida"
		"evento":
			o = Natureza.EVENTOS.get(e["evento"], {}).get("nome", e["evento"])
		"natureza":
			o = "%s %+d%%" % [e["especie"], roundi(float(e["delta"]) * 100)]
		"traco":
			o = "%s %s" % ["mais" if float(e.get("delta", 0.15)) > 0 else "menos", Personalidade.NOMES.get(e["traco"], e["traco"])]
		"marca":
			o = "passa a ter a marca \"%s\"" % e["marca"]
		"nada":
			o = "nada acontece"
		"expectativa":
			o = "vive cerca de %d anos" % int(e["anos"])
		"pausar":
			o = "o tempo para por %s (menos para quem usou e quem ele tocar)" % _tempo(int(e.get("dias", 7)))
		"adormecer":
			o = "cai em sono eterno (sai da simulação até a maldição ser quebrada)"
		"despertar":
			o = "desperta do sono eterno"
		"apagar":
			o = "é apagado da existência"
		"prever":
			o = "vê o futuro (a simulação de %s à frente)" % _tempo(int(e.get("dias", 360)))
		"galho":
			o = "volta ao passado (abre um galho da linha do tempo)"
	return "%s → %s" % [quem, o]


static func _tempo(d: int) -> String:
	if d >= 360:
		var a := roundi(d / 360.0)
		return "%d ano%s" % [a, "s" if a > 1 else ""] if a > 1 else "ano"
	if d >= 30:
		var m := roundi(d / 30.0)
		return "%d meses" % m if m > 1 else "mês"
	return "%d dias" % d if d > 1 else "dia"


# ---------------------------------------------------------------- efeito → operações

## Quem recebe o efeito, dado o contexto {sujeito, outro, lugar}.
static func alvos(u: Universo, e: Dictionary, ctx: Dictionary) -> Array:
	var alvo := str(e.get("alvo", "sujeito"))
	var lugar := str(e.get("lugar_alvo", "")) if str(e.get("lugar_alvo", "")) != "" else str(ctx.get("lugar", ""))
	match alvo:
		"sujeito":
			return [ctx["sujeito"]] if str(ctx.get("sujeito", "")) != "" else []
		"outro":
			return [ctx["outro"]] if str(ctx.get("outro", "")) != "" else []
		"lugar":
			return [lugar] if lugar != "" else []
		"todos_no_lugar":
			var r: Array = []
			for c in [lugar] + Mapa.descendentes(u, lugar):
				r.append_array(Natureza._mentes_em(u, c))
			return r
		"mortos_no_lugar":
			var r2: Array = []
			for ent in u.entidades_ativas():
				if Sugestoes.categoria(ent["tipo"]) == "pessoa" and not Estado.vivo(u, ent["id"]):
					var onde: String = u.estado(ent["id"])["local"]
					if lugar == "" or onde == lugar or Mapa.ancestrais(u, onde).has(lugar):
						r2.append(ent["id"])
			return r2
	if alvo.begins_with("entidade:"):
		return [alvo.trim_prefix("entidade:")]
	return []


## As operações de um efeito, já com os alvos resolvidos.
static func operacoes(u: Universo, e: Dictionary, ctx: Dictionary) -> Array:
	var ops: Array = []
	for q in alvos(u, e, ctx):
		match str(e.get("peca", "")):
			"envelhecer":
				ops.append({"op": "envelhecer", "quem": q, "dias": int(e["dias"])})
			"poder":
				var delta: float = float(e["soma"]) if e.has("soma") else Estado.poder(u, q) * float(e["pct"])
				ops.append({"op": "mudar", "quem": q, "chave": "poder", "delta": delta})
			"esquecer":
				ops.append({"op": "esquecer", "quem": q, "dias": int(e["dias"])})
			"morrer":
				if Estado.vivo(u, q):
					ops.append({"op": "morrer", "quem": q})
			"ferir":
				ops.append({"op": "ferir", "quem": q, "descricao": e.get("descricao", "ferimento"), "gravidade": float(e.get("gravidade", 0.2))})
			"curar":
				ops.append({"op": "curar", "quem": q, "quanto": float(e.get("quanto", 0.5))})
			"emocao":
				ops.append({"op": "emocao", "quem": q, "emocao": e["emocao"], "forca": float(e.get("forca", 0.5)), "alvo": str(e.get("por", ""))})
			"relacao":
				var com: String = str(ctx.get("outro", "")) if e["com"] == "outro" else str(e["com"]).trim_prefix("entidade:")
				if com != "" and com != q:
					ops.append({"op": "relacao", "de": q, "para": com, "deltas": e["deltas"]})
			"mover":
				ops.append({"op": "mover", "quem": q, "lugar": e["lugar"]})
			"reviver":
				ops.append({"op": "reviver", "quem": q})
				if e.has("marca"):
					ops.append({"op": "marca", "quem": q, "marca": e["marca"]})
			"evento":
				ops.append({"op": "evento_natural", "lugar": q, "tipo": e["evento"], "forca": float(e.get("forca", 1.0)),
					"ate": DataMundo.ordem(u.relogio) + int(e.get("dias", 90))})
			"natureza":
				var reg := Natureza.de(u, q) if Natureza.tem_natureza(u, q) else {}
				if not reg.is_empty():
					var achou := ""
					for nome in reg["especies"]:
						if TextUtil.chave(nome).begins_with(TextUtil.chave(e["especie"]).substr(0, 4)):
							achou = nome
					if achou != "":
						ops.append({"op": "natureza_nivel", "lugar": q, "especie": achou, "delta": float(e["delta"]) * float(reg["especies"][achou]["n"])})
			"traco":
				ops.append({"op": "traco", "quem": q, "traco": e["traco"], "delta": float(e.get("delta", 0.15))})
			"marca":
				ops.append({"op": "marca", "quem": q, "marca": e["marca"]})
			"pausar":
				var tocados: Array = [q]
				if str(ctx.get("outro", "")) != "":
					tocados.append(ctx["outro"])
				ops.append({"op": "pausar", "quem": tocados, "dias": int(e.get("dias", 7))})
			"adormecer":
				ops.append({"op": "adormecer", "lugar": q})
			"despertar":
				ops.append({"op": "despertar", "lugar": q})
			"apagar":
				ops.append({"op": "apagar", "quem": q})
			"prever":
				ops.append({"op": "prever", "quem": q, "dias": int(e.get("dias", 360))})
				ops.append({"op": "marca", "quem": q, "marca": "viu o futuro"})
			"galho":
				ops.append({"op": "galho", "quem": q, "anos": int(e.get("anos", 10))})
	return ops


# ---------------------------------------------------------------- operações novas

static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	var quem := str(op.get("quem", ""))
	match str(op.get("op", "")):
		"envelhecer":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				s["envelhecido"] = int(s.get("envelhecido", 0)) + int(op.get("dias", 0))
			return true
		"esquecer":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				var limite := DataMundo.ordem(fato.get("data", u.relogio)) - int(op.get("dias", 360))
				var recente := func(fid: String) -> bool:
					var f := u.fatos.obter(fid)
					return not f.is_empty() and DataMundo.ordem(f["data"]) >= limite
				for fid in s["conhece"].keys():
					if recente.call(fid):
						s["conhece"].erase(fid)
				s["memorias"] = s["memorias"].filter(func(m): return not recente.call(m["fato"]))
				s["emocoes"] = s["emocoes"].filter(func(em): return not recente.call(str(em.get("fato", ""))))
			return true
		"reviver":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				s["vivo"] = true
				s["morte"] = {}
				s["saude"] = maxf(0.3, float(s["saude"]))
			return true
		"marca":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				if not s.has("marcas"):
					s["marcas"] = []
				var m := str(op.get("marca", "")).strip_edges()
				if m != "" and not s["marcas"].has(m):
					s["marcas"].append(m)
			return true
		"desmarcar":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				s["marcas"] = Array(s.get("marcas", [])).filter(func(x): return x != str(op.get("marca", "")))
			return true
	return false


static func marcas(u: Universo, eid: String) -> Array:
	return u.estado(eid).get("marcas", [])
