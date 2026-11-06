class_name RegrasVivas
extends RefCounted
## Regras vivas: as leis que o autor escreve mandam no mundo, e as pessoas se adaptam.
##
## Dois tipos (além das leis de causa e efeito de Regras):
##   Perigo — "os humanos não podem pegar a luz do sol", "o frio mata os elfos".
##       Quem se expõe se fere ou morre; com o tempo alguém tem uma ideia (trabalhar à
##       noite, cavar casas debaixo da terra, roupas fechadas…) e o lugar se adapta —
##       a cidade vira "subterrânea" no mapa. Se a regra já existia quando o povo
##       nasceu, ele já nasce adaptado; se vier depois, ele sofre até aprender.
##   Dom — "a magia só acontece em quem mora no Polo Sul".
##       O lugar passa a existir no mapa (se ainda não existe); quem mora lá desperta o
##       dom; quem sai perde (ou não, se a regra fala de quem NASCE lá); quem tem ficha
##       com o dom mas não cumpre a regra não consegue usá-lo; os ambiciosos viajam para lá.
## A regra fica no fato da frase (desfazer a frase desfaz a regra e tudo o que ela causou).

const CONDICOES := {
	"sol": ["luz do sol", "luz solar", "raios do sol", "sol", "luz do dia", "dia claro"],
	"frio": ["frio", "neve", "gelo", "inverno"],
	"calor": ["calor", "verao"],
	"noite": ["escuridao", "escuro", "noite", "trevas"],
	"agua": ["agua", "mar", "chuva"],
	"ferro": ["ferro", "metal", "aco"],
	"lua": ["luz da lua", "lua cheia", "lua"],
}
const NOMES_COND := {"sol": "a luz do sol", "frio": "o frio", "calor": "o calor", "noite": "a escuridão", "agua": "a água", "ferro": "o ferro", "lua": "a luz da lua"}

const VERBOS_PERIGO := {"nao podem": 0.35, "nao pode": 0.35, "nao conseguem": 0.3, "nao suportam": 0.35, "nao toleram": 0.35, "sao proibidos": 0.3,
	"morrem": 0.55, "morre": 0.55, "mata": 0.55, "matam": 0.55, "queimam": 0.3, "queima": 0.3, "ferem": 0.25, "fere": 0.25,
	"machuca": 0.25, "machucam": 0.25, "adoecem": 0.25, "adoece": 0.25, "cega": 0.2, "cegam": 0.2, "derretem": 0.5, "viram po": 0.6,
	"viram pedra": 0.6, "enfraquecem": 0.15, "enfraquece": 0.15, "sofrem": 0.2, "envenena": 0.35}

## As ideias que surgem para viver com cada perigo: [ideia, quanto protege, moradia].
const ADAPTACOES := {
	"sol": [["passaram a trabalhar só à noite e dormir de dia", 0.25, ""], ["cavaram as primeiras casas debaixo da terra", 0.35, "subterrânea"],
		["costuraram roupas que cobrem o corpo inteiro", 0.15, ""], ["abriram túneis entre as casas para nunca sair ao sol", 0.2, "subterrânea, com túneis"]],
	"frio": [["aprenderam a manter fogueiras acesas dia e noite", 0.25, ""], ["ergueram casas de pedra grossa", 0.3, ""], ["passaram a vestir peles", 0.2, ""]],
	"calor": [["passaram a trabalhar só de madrugada", 0.3, ""], ["cavaram poços e cisternas", 0.25, ""], ["ergueram casas de paredes grossas e janelas pequenas", 0.2, ""]],
	"noite": [["passaram a se recolher antes do anoitecer", 0.3, ""], ["acenderam tochas em todas as ruas", 0.3, ""], ["ergueram muros e portões que fecham ao pôr do sol", 0.2, "murada"]],
	"agua": [["ergueram as casas sobre palafitas", 0.35, "sobre palafitas"], ["passaram a evitar a chuva e o mar", 0.25, ""]],
	"ferro": [["trocaram o ferro por pedra, osso e madeira", 0.5, ""]],
	"lua": [["passaram a se trancar nas noites de lua", 0.4, ""]],
	"_": [["aprenderam a evitar %s", 0.4, ""]],
}
## Ofícios que passam o dia ao ar livre (se expõem mais).
const AO_AR_LIVRE := ["pescad", "coletor", "cacad", "campon", "lavrad", "pastor", "lenhad", "soldad", "guarda", "marinh", "construt", "carpint", "minei", "agricult"]

const DONS := ["magia", "magias", "feiticaria", "bruxaria", "telepatia", "poderes", "poder", "dons", "dom", "mana", "encantamento", "alquimia",
	"cura", "voo", "voar", "clarividencia", "necromancia", "pirocinese", "forca sobre-humana", "imortalidade"]


static var _cache_chave := ""
static var _artigo := ""
static var _cache: Array = []


## Todas as regras vivas que valem (estão nos fatos canônicos das frases).
static func todas(u: Universo) -> Array:
	var chave := "%s|%d|%d" % [u.id, u.versao, u.fatos.quantidade()]
	if chave == _cache_chave:
		return _cache
	var r: Array = []
	for f in u.fatos.todos():
		if f["canon"] and f["dados"].has("regra_viva"):
			r.append(f["dados"]["regra_viva"])
	_cache_chave = chave
	_cache = r
	return r


static func aplicar_op(u: Universo, op: Dictionary, _fato: Dictionary) -> bool:
	var quem := str(op.get("quem", ""))
	match str(op.get("op", "")):
		"adaptar":
			if not u.entidades.has(quem):
				return true
			var s := u.estado(quem)
			var ad: Dictionary = s.get("adaptacao", {})
			var c := str(op.get("cond", ""))
			ad[c] = clampf(float(ad.get(c, 0.0)) + float(op.get("delta", 0.0)), 0.0, 0.95)
			s["adaptacao"] = ad
			var ideias: Array = s.get("adaptacoes", [])
			if str(op.get("ideia", "")) != "" and not ideias.has(op["ideia"]):
				ideias.append(str(op["ideia"]))
			s["adaptacoes"] = ideias
			if str(op.get("moradia", "")) != "":
				s["moradia"] = str(op["moradia"])
			return true
		"dom":
			if not u.entidades.has(quem):
				return true
			var dons: Array = u.estado(quem).get("dons", [])
			var p := str(op.get("poder", ""))
			if bool(op.get("ganha", true)):
				if not dons.has(p):
					dons.append(p)
			else:
				dons.erase(p)
			u.estado(quem)["dons"] = dons
			return true
	return false


static func adaptacao(u: Universo, lugar: String, cond: String) -> float:
	return float(u.estado(lugar).get("adaptacao", {}).get(cond, 0.0))


# ---------------------------------------------------------------- ler a frase

## Tenta ler a frase como perigo ou dom. Devolve {tipo, texto, regra} ou {}.
static func ler(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var dom := _ler_dom(u, original, n, raiz, foco)
	if not dom.is_empty():
		return dom
	return _ler_perigo(u, original, n, raiz, foco)


static func _condicao(n: String) -> String:
	for c in CONDICOES:
		for w in CONDICOES[c]:
			if n.contains(" " + w + " ") or n.ends_with(" " + w):
				return c
	return ""


## Quem a regra atinge: um povo ("elfos" → povo elfo) ou todos.
static func _sujeito(n: String) -> Dictionary:
	for par in [["elfos", "elfo"], ["anoes", "anão"], ["orcs", "orc"], ["gnomos", "gnomo"], ["vampiros", "vampiro"], ["humanos", ""], ["pessoas", ""], ["todos", ""], ["homens", ""], ["habitantes", ""], ["moradores", ""], ["criancas", ""], ["ninguem", ""]]:
		if n.contains(" " + par[0] + " ") or n.ends_with(" " + par[0]) or n.begins_with(par[0] + " "):
			return {"povo": par[1], "palavra": par[0]}
	if n.begins_with("quem ") or n.contains(" quem "):
		return {"povo": "", "palavra": "pessoas"}
	return {}


static func _escopo(u: Universo, original: String, n: String, foco: String) -> String:
	if n.contains(" neste mundo") or n.contains(" nesse mundo") or n.contains(" neste universo") or n.contains(" em todo") or n.contains(" no mundo inteiro"):
		return ""
	for m in Ligador.new(u).encontrar(original):
		if Mapa.no_mapa(u, m["entidade"]) and not Mapa.especie(u, m["entidade"]) in ["planeta", "cosmico"]:
			return m["entidade"]
	for w in [" nesta ", " neste ", " nessa ", " nesse ", " aqui "]:
		if n.contains(w):
			return Leitor.lugar_da_gente(u, foco) if foco != "" else ""
	return ""


static func _ler_perigo(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var cond := _condicao(n)
	if cond == "":
		return {}
	var grav := 0.0
	for v in VERBOS_PERIGO:
		if n.contains(" " + v + " ") or n.ends_with(" " + v):
			grav = maxf(grav, float(VERBOS_PERIGO[v]))
	if grav <= 0.0:
		return {}
	var suj := _sujeito(n)
	if suj.is_empty():
		return {}  # um perigo atinge gente ("os dragões queimam as casas" é uma criatura, não uma lei)
	var escopo := _escopo(u, original, n, foco)
	var regra := {"id": Ids.novo("rv"), "tipo": "perigo", "cond": cond, "povo": suj["povo"], "lugar": escopo, "gravidade": grav, "texto": original.strip_edges()}
	var fid := Simulador.registrar(u, {"tipo": "lei do universo", "descricao": "Lei do mundo: %s" % original.strip_edges(), "sujeitos": [escopo] if escopo != "" else [],
		"lugar": escopo, "causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
		"dados": {"importancia": 0.5, "povoamento": raiz, "regra_viva": regra, "mudancas": []}})
	var quem := "os %s" % suj["palavra"] if suj["povo"] != "" else "as pessoas"
	var onde: Variant = (" em " + u.entidade(escopo)["nome"]) if escopo != "" else " no mundo todo"
	return {"tipo": "lei", "texto": "Perigo%s: %s fere %s (as pessoas vão ter que se adaptar)" % [onde, NOMES_COND.get(cond, cond), quem], "fato": fid, "regra": regra}


static func _ler_dom(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var so := n.contains(" so ") or n.contains(" somente ") or n.contains(" apenas ") or n.contains(" unicamente ") or n.begins_with("so ") or n.begins_with("apenas ") or n.begins_with("somente ")
	if not so:
		return {}
	var dom := ""
	for d in DONS:
		if n.contains(" " + d + " ") or n.begins_with(d + " ") or n.ends_with(" " + d):
			dom = d
			break
	if dom == "":
		return {}
	var modo := "nasce" if (n.contains(" nasc") or n.contains(" nativos")) else "mora"
	# O lugar: o nome com maiúscula depois de "no/na/em/do/da".
	var rx := RegEx.new()
	rx.compile("(?:\\bno|\\bna|\\bem|\\bdo|\\bda|\\bnos|\\bnas|\\bdos|\\bdas) ((?:[A-ZÀ-Ý][\\wÀ-ÿ'-]*)(?: (?:de |do |da )?[A-ZÀ-Ý][\\wÀ-ÿ'-]*)*)")
	var nome_lugar := ""
	_artigo = ""
	for m in rx.search_all(original):
		var cand := m.get_string(1)
		if TextUtil.normalizar(cand) in ["neste mundo", "magia"]:
			continue
		nome_lugar = cand
		var prep := TextUtil.normalizar(m.get_string(0).split(" ")[0])
		_artigo = "o" if prep in ["no", "do", "nos", "dos"] else ("a" if prep in ["na", "da", "nas", "das"] else "")
	if nome_lugar == "":
		return {}
	var lugar := ""
	for e in u.entidades_ativas():
		if TextUtil.chave(e["nome"]) == TextUtil.chave(nome_lugar):
			lugar = e["id"]
	var criados: Array = []
	if lugar == "":
		lugar = _criar_regiao(u, nome_lugar, raiz, n)
		criados.append(lugar)
	# O dom vira uma entidade de poder (se ainda não existe).
	var nome_dom: Variant = {"magias": "Magia", "poderes": "Poder", "dons": "Dom", "voar": "Voo"}.get(dom, dom.substr(0, 1).to_upper() + dom.substr(1))
	var pid := ""
	for e in u.entidades_ativas():
		if TextUtil.chave(e["nome"]) == TextUtil.chave(nome_dom):
			pid = e["id"]
	if pid == "":
		pid = u.criar_entidade(nome_dom, "magia", [], [{"chave": "quem pode ter", "valor": "só quem %s %s" % ["nasce" if modo == "nasce" else "mora", em(u, lugar)]},
			{"chave": "descrição", "valor": original.strip_edges()}], [raiz])
		Leitor._anotar(u, raiz, "criados", pid)
	var regra := {"id": Ids.novo("rv"), "tipo": "dom", "poder": pid, "onde": lugar, "modo": modo, "texto": original.strip_edges()}
	var fid := Simulador.registrar(u, {"tipo": "lei do universo", "descricao": "Lei do mundo: %s" % original.strip_edges(), "sujeitos": [pid, lugar], "lugar": lugar,
		"causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
		"dados": {"importancia": 0.6, "povoamento": raiz, "regra_viva": regra, "mudancas": []}})
	# Quem já mora (ou nasceu) lá desperta o dom agora mesmo.
	ao_povoar(u, lugar, fid)
	return {"tipo": "lei", "texto": "Dom: %s só existe em quem %s %s" % [nome_dom, "nasce" if modo == "nasce" else "mora", em(u, lugar)], "fato": fid, "regra": regra, "criados": criados}


## Uma região escrita numa regra ("o Polo Sul"): nasce no mapa do mundo, no lugar certo.
static func _criar_regiao(u: Universo, nome: String, raiz: String, n: String) -> String:
	var mundo := Leitor._mundo(u, raiz, n)
	var nn := TextUtil.normalizar(nome)
	var campos: Array = [{"chave": "descrição", "valor": "Citado nas leis do mundo."}]
	if _artigo != "":
		campos.append({"chave": "artigo", "valor": _artigo})
	var eid := u.criar_entidade(Leitor._titulo(nome), "região", [], campos, [raiz])
	Leitor._anotar(u, raiz, "criados", eid)
	var pos := Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2)
	var ter := ""
	if nn.contains("polo sul") or nn.contains("sul"):
		pos = Vector2i(Mapa.COLS / 2, Mapa.LINHAS - 3)
		ter = "gelo" if nn.contains("polo") else ""
	elif nn.contains("polo norte") or nn.contains("norte"):
		pos = Vector2i(Mapa.COLS / 2, 2)
		ter = "gelo" if nn.contains("polo") else ""
	elif nn.contains("leste") or nn.contains("oriente"):
		pos = Vector2i(Mapa.COLS - 6, Mapa.LINHAS / 2)
	elif nn.contains("oeste") or nn.contains("ocidente"):
		pos = Vector2i(5, Mapa.LINHAS / 2)
	if ter == "gelo":
		var y0 := Mapa.LINHAS - 5 if pos.y > Mapa.LINHAS / 2 else 0
		for y in range(y0, y0 + 5):
			for x in Mapa.COLS:
				Mapa.pintar(u, mundo, x, y, "gelo")
	pos = Leitor._livre_perto(u, mundo, pos)
	Mapa.colocar(u, eid, mundo, pos.x, pos.y, false)
	return eid


## Quando um lugar ganha gente: um povo que nasceu sob uma regra já nasce adaptado a ela,
## e quem nasce no lugar de um dom já nasce com ele.
static func ao_povoar(u: Universo, lugar: String, causa: String) -> void:
	for r in todas(u):
		if r["tipo"] == "perigo" and _vale_no_lugar(u, r, lugar) and adaptacao(u, lugar, r["cond"]) < 0.5:
			var ideias: Array = ADAPTACOES.get(r["cond"], ADAPTACOES["_"])
			var moradia := ""
			for i in ideias:
				if str(i[2]) != "":
					moradia = i[2]
			var ops: Array = [{"op": "adaptar", "quem": lugar, "cond": r["cond"], "delta": 0.65, "ideia": "sempre viveram assim", "moradia": moradia}]
			Simulador.registrar(u, {"tipo": "costume", "descricao": "Em %s, o povo sempre soube viver com %s%s." % [u.entidade(lugar)["nome"], NOMES_COND.get(r["cond"], r["cond"]), (": as casas são " + moradia) if moradia != "" else ""],
				"sujeitos": [lugar], "lugar": lugar, "causas": [causa], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
				"dados": {"importancia": 0.35, "mudancas": ops}})
		elif r["tipo"] == "dom":
			var ops2: Array = []
			for p in Ameacas._pessoas(u, lugar):
				if cumpre_dom(u, p, r) and not Array(u.estado(p).get("dons", [])).has(r["poder"]):
					ops2.append({"op": "dom", "quem": p, "poder": r["poder"], "ganha": true})
			if not ops2.is_empty():
				Simulador.registrar(u, {"tipo": "dom", "descricao": "Em %s, %d pessoa(s) têm %s." % [u.entidade(lugar)["nome"], ops2.size(), u.entidade(r["poder"])["nome"]],
					"sujeitos": [lugar, r["poder"]], "lugar": lugar, "causas": [causa], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
					"dados": {"importancia": 0.4, "mudancas": ops2}})


static func _vale_no_lugar(u: Universo, r: Dictionary, lugar: String) -> bool:
	var escopo := str(r.get("lugar", ""))
	return escopo == "" or escopo == lugar or Mapa.ancestrais(u, lugar).has(escopo)


## Quem está "no" lugar do dom: dentro dele, ou no mesmo mapa a poucos quadros.
static func dentro(u: Universo, lugar: String, regiao: String) -> bool:
	if lugar == "" or regiao == "":
		return false
	if lugar == regiao or Mapa.ancestrais(u, lugar).has(regiao):
		return true
	if Mapa.pai(u, lugar) != Mapa.pai(u, regiao):
		return false
	var a := Mapa.posicao(u, lugar)
	var b := Mapa.posicao(u, regiao)
	if a.is_empty() or b.is_empty():
		return false
	return Vector2(float(a["x"]) - float(b["x"]), float(a["y"]) - float(b["y"])).length() <= 6.0


static func cumpre_dom(u: Universo, eid: String, r: Dictionary) -> bool:
	if r["modo"] == "nasce":
		var nasceu := u.valor_campo(eid, "nasceu em")
		var lugar_nasc := ""
		for e in u.entidades_ativas():
			if nasceu != "" and TextUtil.chave(e["nome"]) == TextUtil.chave(nasceu):
				lugar_nasc = e["id"]
		if lugar_nasc != "":
			return dentro(u, lugar_nasc, r["onde"])
	return dentro(u, str(u.estado(eid).get("local", "")), r["onde"])


## Um poder preso a uma regra só funciona para quem a cumpre.
static func permite(u: Universo, eid: String, pid: String) -> bool:
	for r in todas(u):
		if r["tipo"] == "dom" and r["poder"] == pid and not cumpre_dom(u, eid, r):
			return false
	return true


# ---------------------------------------------------------------- simular

static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var regras := todas(u)
	if regras.is_empty():
		return novos
	for r in regras:
		match str(r["tipo"]):
			"perigo":
				novos.append_array(_perigo(u, r, dias, rng))
			"dom":
				novos.append_array(_dom(u, r, dias, rng))
	return novos.filter(func(x): return x != "")


static func _causa(u: Universo, r: Dictionary) -> String:
	for f in u.fatos.todos():
		if f["canon"] and f["dados"].get("regra_viva", {}).get("id", "") == r["id"]:
			return f["id"]
	return ""


static func _ativa_agora(u: Universo, cond: String) -> float:
	var est := TextUtil.normalizar(Natureza.estacao(u.relogio))
	match cond:
		"frio":
			return 1.0 if est == "inverno" else (0.3 if est in ["outono", "primavera"] else 0.0)
		"calor":
			return 1.0 if est == "verao" else 0.2
		"lua":
			return 0.25
	return 1.0


static func _perigo(u: Universo, r: Dictionary, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var forca := _ativa_agora(u, r["cond"])
	if forca <= 0.0:
		return novos
	var lugares: Array = []
	for e in u.entidades_ativas():
		var l: String = e["id"]
		if Mapa.no_mapa(u, l) and _vale_no_lugar(u, r, l) and not Mapa.especie(u, l) in ["planeta", "cosmico"]:
			var gente := Ameacas._pessoas(u, l).filter(func(p): return str(u.estado(p).get("local", "")) == l)
			if not gente.is_empty():
				lugares.append([l, gente])
	var causa := ""
	for par in lugares:
		var l: String = par[0]
		var gente: Array = par[1]
		if str(r.get("povo", "")) != "":
			gente = gente.filter(func(p): return TextUtil.normalizar(u.valor_campo(p, "povo")) == TextUtil.normalizar(r["povo"]))
		if gente.is_empty():
			continue
		if causa == "":
			causa = _causa(u, r)
		var ad := adaptacao(u, l, r["cond"])
		var feridos: Array = []
		var mortos: Array = []
		for p in gente:
			var of := TextUtil.normalizar(Vivencia.oficio(u, p))
			var fora := AO_AR_LIVRE.any(func(w): return of.contains(w))
			var chance := (1.0 - ad) * (0.22 if fora else 0.08) * forca * dias / 7.0
			if rng.randf() < chance:
				if Estado.saude_atual(u, p) - float(r["gravidade"]) <= 0.12 or rng.randf() < float(r["gravidade"]) * 0.15:
					mortos.append(p)
				else:
					feridos.append(p)
		var oque: Variant = NOMES_COND.get(r["cond"], r["cond"])
		var conta := 0
		for p in mortos.slice(0, 3):
			novos.append(Simulador.registrar(u, {"tipo": "morte", "descricao": "%s morreu por causa d%s." % [u.entidade(p)["nome"], oque.replace("a ", "a ").replace("o ", "o ")], "sujeitos": [p, l], "lugar": l,
				"causas": [causa], "dados": {"importancia": 0.75, "mudancas": [{"op": "morrer", "quem": p}]}}))
			conta += 1
		var ops: Array = []
		for p in feridos:
			ops.append({"op": "ferir", "quem": p, "descricao": "ferida d%s" % oque, "gravidade": float(r["gravidade"]) * (0.5 + rng.randf() * 0.5)})
			ops.append({"op": "emocao", "quem": p, "emocao": "medo", "forca": 0.4, "alvo": ""})
		if not ops.is_empty():
			var nomes: Array = feridos.slice(0, 3).map(func(p): return u.entidade(p)["nome"])
			novos.append(Simulador.registrar(u, {"tipo": "ferimento", "descricao": "Em %s, %s %s ferid%s %s." % [u.entidade(l)["nome"], ", ".join(nomes) + (" e mais %d" % (feridos.size() - 3) if feridos.size() > 3 else ""),
				"foi" if feridos.size() == 1 else "foram", "o" if feridos.size() == 1 else "os", _pela(oque)], "sujeitos": [feridos[0], l], "lugar": l,
				"causas": [causa], "dados": {"importancia": 0.45, "mudancas": ops}}))
		# Sofrer faz pensar: alguém tem uma ideia para viver com isso.
		if (not feridos.is_empty() or not mortos.is_empty() or ad < 0.3) and ad < 0.9:
			var ideia := _ideia(u, r, l, gente, rng, dias)
			if ideia != "":
				novos.append(ideia)
	return novos


static func _ideia(u: Universo, r: Dictionary, lugar: String, gente: Array, rng: RandomNumberGenerator, dias: int) -> String:
	var feitas: Array = u.estado(lugar).get("adaptacoes", [])
	var ultima := int(u.estado(lugar).get("ultima_ideia", -9999))
	if DataMundo.ordem(u.relogio) - ultima < 30:
		return ""
	var pensador := ""
	var pv := -1.0
	for p in gente:
		var t := Personalidade.tracos(u, p)
		var v := float(t["curiosidade"]) + 0.4 * float(t["prudencia"]) + rng.randf() * 0.4
		if v > pv:
			pv = v
			pensador = p
	if pensador == "" or rng.randf() > (0.25 + 0.3 * float(Personalidade.tracos(u, pensador)["curiosidade"])) * dias / 7.0:
		return ""
	for i in ADAPTACOES.get(r["cond"], ADAPTACOES["_"]):
		var texto := str(i[0]) % NOMES_COND.get(r["cond"], r["cond"]) if str(i[0]).contains("%s") else str(i[0])
		if feitas.has(texto):
			continue
		var ops: Array = [{"op": "adaptar", "quem": lugar, "cond": r["cond"], "delta": float(i[1]), "ideia": texto, "moradia": str(i[2])},
			{"op": "definir", "quem": lugar, "chave": "ultima_ideia", "valor": DataMundo.ordem(u.relogio)},
			{"op": "mudar", "quem": pensador, "chave": "reputacao", "delta": 0.2}]
		for p in gente:
			if p != pensador:
				ops.append({"op": "relacao", "de": p, "para": pensador, "deltas": {"respeito": 0.08}})
		return Simulador.registrar(u, {"tipo": "adaptação", "descricao": "Em %s, por ideia de %s, %s." % [u.entidade(lugar)["nome"], u.entidade(pensador)["nome"], texto],
			"sujeitos": [pensador, lugar], "lugar": lugar, "causas": [_causa(u, r)], "dados": {"importancia": 0.6, "mudancas": ops}})
	return ""


static func _dom(u: Universo, r: Dictionary, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var pid: String = r["poder"]
	if not u.entidades.has(pid) or not u.entidades.has(str(r["onde"])):
		return novos
	var nome_dom: String = u.entidade(pid)["nome"]
	var regiao: String = r["onde"]
	var causa := _causa(u, r)
	var ganham: Array = []
	var perdem: Array = []
	var partem: Array = []
	for e in u.entidades_ativas():
		var p: String = e["id"]
		if not Estado.tem_mente(u, p) or not Estado.vivo(u, p):
			continue
		var tem := Array(u.estado(p).get("dons", [])).has(pid)
		var cumpre := cumpre_dom(u, p, r)
		if cumpre and not tem and rng.randf() < 0.35 * dias / 7.0:
			ganham.append(p)
		elif tem and not cumpre:
			perdem.append(p)
		elif not cumpre and not Viagens.viajando(u, p):
			var t := Personalidade.tracos(u, p)
			if float(t["ambicao"]) > 0.65 and rng.randf() < 0.02 * dias / 7.0 and partem.size() < 2:
				partem.append(p)
	for p in ganham.slice(0, 3):
		novos.append(Simulador.registrar(u, {"tipo": "dom", "descricao": "%s despertou a %s %s." % [u.entidade(p)["nome"], nome_dom.to_lower(), em(u, regiao)],
			"sujeitos": [p, pid], "lugar": str(u.estado(p).get("local", "")), "causas": [causa],
			"dados": {"importancia": 0.5, "mudancas": [{"op": "dom", "quem": p, "poder": pid, "ganha": true}, {"op": "mudar", "quem": p, "chave": "reputacao", "delta": 0.15}]}}))
	if ganham.size() > 3:
		var ops: Array = ganham.slice(3).map(func(p): return {"op": "dom", "quem": p, "poder": pid, "ganha": true})
		novos.append(Simulador.registrar(u, {"tipo": "dom", "descricao": "Mais %d pessoas despertaram a %s %s." % [ganham.size() - 3, nome_dom.to_lower(), em(u, regiao)],
			"sujeitos": [regiao, pid], "lugar": regiao, "causas": [causa], "dados": {"importancia": 0.35, "mudancas": ops}}))
	for p in perdem.slice(0, 4):
		novos.append(Simulador.registrar(u, {"tipo": "dom perdido", "descricao": "Longe %s, %s perdeu a %s." % [de_(u, regiao), u.entidade(p)["nome"], nome_dom.to_lower()],
			"sujeitos": [p, pid], "lugar": str(u.estado(p).get("local", "")), "causas": [causa],
			"dados": {"importancia": 0.5, "mudancas": [{"op": "dom", "quem": p, "poder": pid, "ganha": false}, {"op": "emocao", "quem": p, "emocao": "tristeza", "forca": 0.5, "alvo": ""}]}}))
	for p in partem:
		var de := str(u.estado(p).get("local", ""))
		if de == "":
			continue
		var ops2 := Viagens.ops_de_ida(u, p, de, regiao) if u.dias_de_viagem(de, regiao) >= 0 else [{"op": "mover", "quem": p, "lugar": regiao}]
		novos.append(Simulador.registrar(u, {"tipo": "partida", "descricao": "%s deixou %s e partiu %s em busca da %s." % [u.entidade(p)["nome"], u.entidade(de)["nome"], para(u, regiao), nome_dom.to_lower()],
			"sujeitos": [p, regiao], "lugar": de, "causas": [causa], "dados": {"importancia": 0.5, "mudancas": ops2}}))
	return novos


## "no Polo Sul", "na Ilha Negra", "em Brasa" (pelo artigo guardado na ficha).
static func em(u: Universo, l: String) -> String:
	var a := u.valor_campo(l, "artigo")
	return ("no " if a == "o" else ("na " if a == "a" else "em ")) + str(u.entidade(l).get("nome", "?"))


static func para(u: Universo, l: String) -> String:
	var a := u.valor_campo(l, "artigo")
	return ("para o " if a == "o" else ("para a " if a == "a" else "para ")) + str(u.entidade(l).get("nome", "?"))


static func de_(u: Universo, l: String) -> String:
	var a := u.valor_campo(l, "artigo")
	return ("do " if a == "o" else ("da " if a == "a" else "de ")) + str(u.entidade(l).get("nome", "?"))


static func _pela(oque: String) -> String:
	if oque.begins_with("a "):
		return "pela " + oque.substr(2)
	if oque.begins_with("o "):
		return "pelo " + oque.substr(2)
	return "por " + oque


## Texto para a página do lugar.
static func resumo_do_lugar(u: Universo, lugar: String) -> String:
	var partes: Array = []
	var mor := str(u.estado(lugar).get("moradia", ""))
	if mor != "":
		partes.append("Casas: %s." % mor)
	var ideias: Array = u.estado(lugar).get("adaptacoes", [])
	if not ideias.is_empty():
		partes.append("Como vivem com as leis do mundo: %s." % "; ".join(ideias))
	for r in todas(u):
		if r["tipo"] == "dom" and r["onde"] == lugar:
			partes.append("Aqui desperta a %s." % str(u.entidade(r["poder"]).get("nome", "?")).to_lower())
	return " ".join(partes)
