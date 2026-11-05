class_name Forcas
extends RefCounted
## Forças militares: exércitos, frotas, esquadrilhas, legiões de mortos… Toda força
## é uma entidade (aparece na wiki) e a ficha é texto livre:
##   tamanho — "20 mil", "300", "1,5 milhão"
##   tipo de força — infantaria, cavalaria, frota, aviões, naves, magos, monstros,
##                   máquinas, sobrenaturais (ou qualquer texto: o programa reconhece palavras)
##   pertence a / lado — a sociedade (o nome dela também serve no nome da força)
##   comandante — uma pessoa
##   moral — "alta", "baixa", "fanática"…
##   pontos fortes — "imune a balas, invisível na areia, mais forte à noite"
##   fraquezas — "some com a luz do dia, teme o fogo"
## O que muda na guerra (baixas, reforços, moral, suprimentos, troca de lado) fica
## no estado, por fatos — e a guerra recalcula sozinha.

## Tipos de força: palavras que os reconhecem, poder por soldado, armas (com o que
## atacam), domínio (terra, mar, ar, espaço, alma) e se dependem de magia ou técnica.
const TIPOS := {
	"infantaria": {"nome": "infantaria", "palavras": ["infantaria", "soldado", "lanceiro", "arqueiro", "legiao", "milicia", "guarda", "tropa", "batalhao", "regimento", "exercito", "guerreiro", "piqueiro", "fuzileiro", "divisao", "homens", "mercenario"],
		"poder": 1.0, "armas": ["armas", "armas comuns", "espada", "lanca", "flecha", "aco", "ferro"], "dominio": "terra", "depende": ""},
	"cavalaria": {"nome": "cavalaria", "palavras": ["cavalaria", "cavaleiro", "cavalo", "montaria", "lanceiros montados", "cavalos"],
		"poder": 1.6, "armas": ["armas", "armas comuns", "espada", "lanca", "aco", "ferro"], "dominio": "terra", "depende": ""},
	"avioes": {"nome": "aviões", "palavras": ["aviao", "avioes", "caca", "cacas", "bombardeiro", "forca aerea", "esquadrilha", "helicoptero", "drone", "drones", "dirigivel"],
		"poder": 6.0, "armas": ["armas", "armas comuns", "bala", "bomba", "tiro", "fogo", "explos", "metralha"], "dominio": "ar", "depende": "tecnologia"},
	"frota": {"nome": "frota", "palavras": ["frota", "navio", "navios", "armada", "marinha", "galera", "galeras", "esquadra", "barco", "barcos", "nau", "naus"],
		"poder": 4.0, "armas": ["armas", "armas comuns", "canhao", "bala", "fogo", "flecha"], "dominio": "mar", "depende": ""},
	"naves": {"nome": "naves", "palavras": ["nave", "naves", "cruzador estelar", "frota estelar", "nave de guerra", "naves de guerra"],
		"poder": 25.0, "armas": ["armas", "laser", "raio", "energia", "fogo", "explos"], "dominio": "espaco", "depende": "tecnologia"},
	"magos": {"nome": "magos", "palavras": ["mago", "magos", "feiticeiro", "feiticeiros", "bruxa", "bruxas", "bruxo", "conjurador", "sacerdote", "sacerdotes", "xama", "xamas", "druida"],
		"poder": 8.0, "armas": ["magia", "feitico", "fogo", "raio", "luz", "gelo"], "dominio": "terra", "depende": "magia"},
	"monstros": {"nome": "monstros", "palavras": ["monstro", "monstros", "dragao", "dragoes", "gigante", "gigantes", "troll", "trolls", "besta", "bestas", "fera", "feras", "lobo", "lobos", "orc", "orcs"],
		"poder": 5.0, "armas": ["garra", "dente", "forca bruta", "veneno"], "dominio": "terra", "depende": ""},
	"maquinas": {"nome": "máquinas", "palavras": ["maquina", "maquinas", "tanque", "tanques", "robo", "robos", "automato", "automatos", "golem", "golens", "artilharia", "canhoes", "blindado", "blindados"],
		"poder": 4.0, "armas": ["armas", "armas comuns", "bala", "aco", "fogo", "explos", "canhao"], "dominio": "terra", "depende": "tecnologia"},
	"sobrenaturais": {"nome": "sobrenaturais", "palavras": ["fantasma", "fantasmas", "espirito", "espiritos", "espectro", "espectros", "morto-vivo", "mortos-vivos", "mortos", "demonio", "demonios", "anjo", "anjos", "assombracao", "sombras", "zumbi", "zumbis", "esqueleto", "esqueletos"],
		"poder": 6.0, "armas": ["medo", "alma", "frio", "magia"], "dominio": "alma", "depende": "magia"},
}

## Vantagem de um tipo sobre outro (multiplica o dano de A em B).
const VANTAGEM := {
	"infantaria": {"cavalaria": 1.2},
	"cavalaria": {"infantaria": 1.25, "magos": 1.5},
	"magos": {"sobrenaturais": 1.8, "monstros": 1.4, "infantaria": 1.2},
	"monstros": {"infantaria": 1.4, "cavalaria": 1.4},
	"maquinas": {"infantaria": 1.5, "cavalaria": 1.6, "monstros": 1.3},
	"avioes": {"infantaria": 1.6, "cavalaria": 1.6, "frota": 1.5, "maquinas": 1.4},
	"frota": {"frota": 1.0},
	"naves": {"avioes": 2.0, "frota": 2.0, "maquinas": 1.5},
	"sobrenaturais": {"infantaria": 1.3, "cavalaria": 1.3},
}

## Quem consegue atingir o que voa.
const ATINGE_O_AR := ["avioes", "naves", "magos", "sobrenaturais"]

## Palavras de cada terreno (para "invisível na areia", "forte nas montanhas").
const PALAVRAS_TERRENO := {
	"deserto": ["deserto", "areia", "dunas"], "floresta": ["floresta", "mata", "bosque", "arvores"],
	"montanha": ["montanha", "montanhas", "serra", "rochas", "pedra"], "colina": ["colina", "colinas", "morro"],
	"agua": ["mar", "agua", "oceano", "rio", "lago"], "pantano": ["pantano", "brejo", "lama"],
	"gelo": ["gelo", "neve", "frio"], "campo": ["campo", "campos", "pradaria"], "planicie": ["planicie", "planicies", "campo aberto"],
}

## Palavras que sinalizam as condições de uma batalha.
const PALAVRAS_CONDICAO := {
	"dia": ["dia", "luz do dia", "sol", "luz do sol", "claridade", "manha", "tarde"],
	"noite": ["noite", "escuro", "escuridao", "lua", "trevas"],
	"inverno": ["inverno", "neve", "frio"], "verao": ["verao", "calor"],
	"chuva": ["chuva", "tempestade", "agua"],
}


# ---------------------------------------------------------------- o que é uma força

const PALAVRAS_DE_FORCA := ["exercito", "frota", "legiao", "tropa", "tropas", "batalhao", "horda", "esquadra", "esquadrilha", "forca aerea",
	"marinha", "armada", "milicia", "regimento", "divisao", "cavalaria", "infantaria", "hoste", "falange", "brigada", "forca militar", "guarnicao"]


static func eh_forca(u: Universo, eid: String) -> bool:
	var e := u.entidade(eid)
	if e.is_empty() or e["removida"]:
		return false
	var t := " " + TextUtil.normalizar(e["tipo"]) + " "
	for w in PALAVRAS_DE_FORCA:
		if t.contains(" " + w):
			return true
	return Sociedades._campo(u, eid, ["tipo de forca"]) != "" and Sociedades._campo(u, eid, ["tamanho"]) != ""


static func todas(u: Universo) -> Array:
	return Sociedades._lembrar(u, "forcas", func(): return u.entidades_ativas().filter(func(e): return eh_forca(u, e["id"])).map(func(e): return e["id"]))


## O tipo da força: o campo "tipo de força", depois o tipo e o nome da entidade.
static func tipo(u: Universo, fid: String) -> String:
	return Sociedades._lembrar(u, "tipoforca|" + fid, func(): return _tipo(u, fid))


static func _tipo(u: Universo, fid: String) -> String:
	var e := u.entidade(fid)
	for txt in [Sociedades._campo(u, fid, ["tipo de forca", "tipo"]), e["tipo"] + " " + e["nome"]]:
		var n := " " + TextUtil.normalizar(txt) + " "
		var melhor := ""
		var pos := 99999
		for t in TIPOS:
			# "exército" é genérico: só vale se nada mais específico aparecer.
			for w in TIPOS[t]["palavras"]:
				var i := n.find(" " + w)
				if i >= 0 and w != "exercito" and i < pos:
					pos = i
					melhor = t
		if melhor != "":
			return melhor
	return "infantaria"


static func nome_tipo(u: Universo, fid: String) -> String:
	return TIPOS[tipo(u, fid)]["nome"]


## A sociedade de quem a força é (o que a guerra mudou, a ficha ou o nome).
static func lado(u: Universo, fid: String) -> String:
	var s := u.estado(fid)
	if str(s.get("lado", "")) != "":
		return str(s["lado"])
	return Sociedades._lembrar(u, "ladoforca|" + fid, func(): return _lado_da_ficha(u, fid))


static func _lado_da_ficha(u: Universo, fid: String) -> String:
	var lig := Ligador.new(u)
	for txt in [Sociedades._campo(u, fid, ["pertence", "lado", "de quem", "dono", "nacao", "reino", "senhor"]), u.entidade(fid)["nome"]]:
		for m in lig.encontrar(txt):
			if Sociedades.eh_sociedade(u, m["entidade"]):
				return m["entidade"]
			var sid := Sociedades.de_lugar(u, m["entidade"]) if Mapa.e_lugar(u, m["entidade"]) else ""
			if sid != "":
				return sid
	var c := comandante(u, fid)
	if c != "":
		for sid in Sociedades.todas(u):
			if Sociedades.lider(u, sid) == c:
				return sid
	return ""


static func comandante(u: Universo, fid: String) -> String:
	var s := u.estado(fid)
	if s.has("comandante"):
		return str(s["comandante"])
	var txt := Sociedades._campo(u, fid, ["comandante", "general", "lider", "capitao", "almirante", "chefe"])
	if txt == "":
		return ""
	var ps := Sociedades.pessoas_no_texto(u, txt)
	return ps[0] if not ps.is_empty() else ""


## Tamanho de agora: o da ficha, menos as baixas, mais os reforços.
static func tamanho(u: Universo, fid: String) -> float:
	return maxf(0.0, tamanho_inicial(u, fid) - float(u.estado(fid).get("baixas", 0.0)) + float(u.estado(fid).get("reforcos", 0.0)))


static func tamanho_inicial(u: Universo, fid: String) -> float:
	var n := Combate.ler_numero(Sociedades._campo(u, fid, ["tamanho", "soldados", "numero", "efetivo", "quantos"]))
	if n <= 0:
		n = Combate.ler_numero(u.entidade(fid)["nome"])
	return n if n > 0 else 1000.0


const MORAIS := {"fanatic": 0.95, "inabalavel": 0.95, "altissima": 0.95, "alta": 0.8, "boa": 0.7, "media": 0.6, "normal": 0.6,
	"baixa": 0.4, "pessima": 0.25, "quebrada": 0.15, "desesperad": 0.5}


static func moral(u: Universo, fid: String) -> float:
	var base := 0.65
	var txt := TextUtil.normalizar(Sociedades._campo(u, fid, ["moral", "animo"]))
	for k in MORAIS:
		if txt.contains(k):
			base = float(MORAIS[k])
			break
	if tipo(u, fid) == "sobrenaturais" or txt.contains("nao tem") or txt.contains("sem medo"):
		base = maxf(base, 0.9)
	return clampf(base + float(u.estado(fid).get("moral_delta", 0.0)), 0.05, 1.0)


static func suprimentos(u: Universo, fid: String) -> float:
	return clampf(1.0 + float(u.estado(fid).get("suprimentos_delta", 0.0)), 0.0, 1.0)


static func pontos_fortes(u: Universo, fid: String) -> String:
	return Sociedades._campo(u, fid, ["pontos fortes", "forcas", "forte", "vantagens", "habilidades", "poderes"])


static func fraquezas(u: Universo, fid: String) -> String:
	return Sociedades._campo(u, fid, ["fraquez", "pontos fracos", "fraco", "desvantagens"])


## Forças de uma sociedade (que ainda existem).
static func da_sociedade(u: Universo, sid: String) -> Array:
	return todas(u).filter(func(f): return lado(u, f) == sid and tamanho(u, f) > 0.5 and not u.estado(f).get("dissolvida", false))


# ---------------------------------------------------------------- ler os pontos fortes e fracos

## Interpreta um texto de pontos fortes/fracos em regras:
## [{tipo: "imune"|"resiste"|"vulneravel"|"forte_em"|"fraco_em"|"voa", termos: [...]}]
static func ler_tracos(texto: String, fortes: bool) -> Array:
	var regras: Array = []
	for parte in TextUtil.normalizar(texto).replace(";", ",").replace(" e ", ",").split(","):
		var p := parte.strip_edges()
		if p == "":
			continue
		var termos := _termos_de(p)
		# "imune a balas e armas comuns": a segunda parte continua a primeira.
		var tem_marca := false
		for mk in ["imune", "resist", "aguenta", "teme", "vulnera", "morre", "ferido", "sensivel", "voa", "voador", "asas", "forte", "fraco",
				"some", "enfraquece", "invisivel", "camufl", "mais", "perde", "rapid", "nao sente"]:
			if p.contains(mk):
				tem_marca = true
				break
		if not tem_marca and not regras.is_empty() and regras.back()["tipo"] != "voa":
			regras.back()["termos"].append_array(termos)
			continue
		if p.contains("voa") or p.contains("voador") or p.contains("asas"):
			regras.append({"tipo": "voa", "termos": []})
			continue
		if p.contains("imune") or p.contains("imunes") or p.contains("nao sente") or p.contains("nao morre"):
			regras.append({"tipo": "imune", "termos": termos})
		elif p.contains("resist") or p.contains("aguenta"):
			regras.append({"tipo": "resiste", "termos": termos})
		elif p.contains("teme") or p.contains("vulnera") or p.contains("morre com") or p.contains("ferido por") or p.contains("sensivel"):
			regras.append({"tipo": "vulneravel", "termos": termos})
		elif fortes:
			regras.append({"tipo": "forte_em", "termos": termos})
		else:
			# "some com a luz do dia", "enfraquece no frio", "fraco no deserto".
			regras.append({"tipo": "fraco_em", "termos": termos})
	return regras


static func _termos_de(p: String) -> Array:
	var ignorar := ["imune", "imunes", "a", "o", "as", "os", "ao", "aos", "na", "no", "nas", "nos", "em", "de", "da", "do", "das", "dos", "com",
		"e", "mais", "muito", "forte", "fortes", "fraco", "fraca", "fracos", "some", "somem", "desaparece", "desaparecem", "enfraquece", "enfraquecem",
		"invisivel", "invisiveis", "resiste", "resistem", "resistente", "resistentes", "teme", "temem", "vulneravel", "vulneraveis", "pela", "pelo",
		"sob", "contra", "quando", "ha", "tem", "luz", "durante", "fica", "ficam", "nao", "sente", "morre", "morrem", "sensivel", "sensiveis", "camuflado", "camuflados"]
	var termos: Array = []
	var n := " " + p + " "
	# Expressões de mais de uma palavra primeiro.
	for grupo in [PALAVRAS_CONDICAO, PALAVRAS_TERRENO]:
		for k in grupo:
			for w in grupo[k]:
				if n.contains(" " + w + " ") and not termos.has(k):
					termos.append(k)
	for w in TextUtil.palavras(p):
		if not w in ignorar and w.length() > 2:
			termos.append(w)
	return termos


## Um termo combina com uma lista (armas, condições)? "balas" combina com "bala".
static func _combina(termo: String, lista: Array) -> bool:
	var raiz := termo.substr(0, maxi(3, termo.length() - 1))
	for x in lista:
		var sx := str(x)
		if sx == termo or sx.begins_with(raiz) or termo.begins_with(sx):
			return true
	return false


# ---------------------------------------------------------------- força contra força

## Condições de uma batalha num lugar: terreno, dia ou noite, estação, acontecimentos.
static func condicoes(u: Universo, lugar: String, noite: bool) -> Array:
	var c: Array = ["noite" if noite else "dia"]
	var terr := Mapa.terreno_do_lugar(u, lugar)
	if terr == "":
		var comp := Mapa.composicao(u, lugar)
		var maior := 0.0
		for t in comp:
			if float(comp[t]) > maior and t != "vazio":
				maior = float(comp[t])
				terr = t
	if terr != "":
		c.append(terr)
	var est := Natureza.estacao(u.relogio)
	if est == "inverno":
		c.append("inverno")
	elif est == "verao":
		c.append("verao")
	for ev in Natureza.eventos_ativos(u, lugar):
		match str(ev["tipo"]):
			"inverno": c.append("inverno")
			"enchente": c.append("chuva")
			"seca": c.append("verao")
			"incendio": c.append("fogo")
	return c


## Quanto a força A causa de dano no lado inimigo (lista de forças), nas condições.
## Devolve {dano, razoes: [texto]}.
static func dano(u: Universo, a: String, inimigas: Array, cond: Array, extra: float = 1.0) -> Dictionary:
	var razoes: Array = []
	var ta := tipo(u, a)
	var def: Dictionary = TIPOS[ta]
	var p := tamanho(u, a) * float(def["poder"]) * moral(u, a) * (0.4 + 0.6 * suprimentos(u, a)) * extra
	var leis := Cosmos.leis(u)
	match str(def["depende"]):
		"magia":
			p *= 0.15 + 0.85 * float(leis["magia"]) / 0.5 if float(leis["magia"]) < 0.5 else 1.0 + (float(leis["magia"]) - 0.5)
		"tecnologia":
			p *= 0.5 + float(leis["tecnologia"])
	p *= _bonus_comandante(u, a)
	var fortes := ler_tracos(pontos_fortes(u, a), true)
	var fracos := ler_tracos(fraquezas(u, a), false)
	for r in fortes:
		if r["tipo"] == "forte_em" and r["termos"].any(func(t): return _combina(t, cond)):
			p *= 1.6
			razoes.append("%s: %s" % [u.entidade(a)["nome"], _trecho(pontos_fortes(u, a), r)])
	for r in fracos:
		if r["tipo"] == "fraco_em" and r["termos"].any(func(t): return _combina(t, cond)):
			p *= 0.3
			razoes.append("%s: %s" % [u.entidade(a)["nome"], _trecho(fraquezas(u, a), r)])
	# Divide o ataque entre as forças inimigas, pelo tamanho.
	var total_inim := 0.0
	for b in inimigas:
		total_inim += tamanho(u, b) * float(TIPOS[tipo(u, b)]["poder"])
	if total_inim <= 0:
		return {"dano": p, "razoes": razoes}
	var d := 0.0
	var a_voa: bool = def["dominio"] == "ar" or ler_tracos(pontos_fortes(u, a), true).any(func(r): return r["tipo"] == "voa")
	for b in inimigas:
		var parte := tamanho(u, b) * float(TIPOS[tipo(u, b)]["poder"]) / total_inim
		var tb := tipo(u, b)
		var m := float(VANTAGEM.get(ta, {}).get(tb, 1.0))
		# Quem voa só é atingido por quem alcança o ar.
		var b_voa: bool = TIPOS[tb]["dominio"] == "ar" or ler_tracos(pontos_fortes(u, b), true).any(func(r): return r["tipo"] == "voa")
		if b_voa and not ta in ATINGE_O_AR and not a_voa and not TextUtil.normalizar(pontos_fortes(u, a)).contains("antiaere"):
			m *= 0.08
			_razao(razoes, "%s não tem como atingir %s (%s)" % [u.entidade(a)["nome"], u.entidade(b)["nome"], TIPOS[tb]["nome"]])
		# Frotas lutam mal em terra (e quem é de terra mal alcança o mar).
		if def["dominio"] == "mar" and not cond.has("agua"):
			m *= 0.35
		# Imunidades e fraquezas do alvo contra as armas de A.
		var armas: Array = def["armas"].duplicate()
		if ta in ["infantaria", "cavalaria"] and float(leis["tecnologia"]) >= 0.5:
			armas.append_array(["bala", "tiro", "arma de fogo"])
		for r in ler_tracos(pontos_fortes(u, b), true):
			if r["tipo"] in ["imune", "resiste"] and r["termos"].any(func(t): return _combina(t, armas)):
				m *= 0.12 if r["tipo"] == "imune" else 0.5
				_razao(razoes, "%s: %s" % [u.entidade(b)["nome"], _trecho(pontos_fortes(u, b), r)])
		for r in ler_tracos(fraquezas(u, b), false):
			if r["tipo"] == "vulneravel" and r["termos"].any(func(t): return _combina(t, armas)):
				m *= 2.0
				_razao(razoes, "%s: %s" % [u.entidade(b)["nome"], _trecho(fraquezas(u, b), r)])
		if m >= 1.3:
			_razao(razoes, "Vantagem de %s sobre %s" % [TIPOS[ta]["nome"], TIPOS[tb]["nome"]])
		d += p * parte * m
	return {"dano": d, "razoes": razoes}


static func _razao(lista: Array, r: String) -> void:
	if not lista.has(r):
		lista.append(r)


## O pedaço do texto da ficha que corresponde à regra (para mostrar o "porquê").
static func _trecho(texto: String, regra: Dictionary) -> String:
	for parte in texto.replace(";", ",").split(","):
		var n := TextUtil.normalizar(parte)
		if regra["termos"].any(func(t): return n.contains(str(t).substr(0, maxi(3, str(t).length() - 1)))):
			return parte.strip_edges()
	return texto.strip_edges()


## Comandante prudente e curioso planeja melhor; fama também conta (os soldados confiam).
static func _bonus_comandante(u: Universo, fid: String) -> float:
	var c := comandante(u, fid)
	if c == "" or not u.entidades.has(c) or not Estado.vivo(u, c):
		return 0.9
	var t := Personalidade.tracos(u, c)
	var b := 0.9 + 0.25 * (float(t["prudencia"]) + float(t["curiosidade"])) / 2.0 + 0.1 * float(t["coragem"])
	b += clampf(float(u.estado(c).get("reputacao", 0.0)) * 0.03, 0.0, 0.15)
	return b


## Poder total de um lado contra o outro, nas condições. {dano, razoes}
static func poder_do_lado(u: Universo, nossas: Array, deles: Array, cond: Array, extra: float = 1.0) -> Dictionary:
	var d := 0.0
	var razoes: Array = []
	for f in nossas:
		var r := dano(u, f, deles, cond, extra)
		d += float(r["dano"])
		for x in r["razoes"]:
			_razao(razoes, x)
	return {"dano": d, "razoes": razoes}


# ---------------------------------------------------------------- criar forças

## Sugere tipo, pontos fortes e fraquezas a partir do nome ("exército de fantasmas do deserto").
static func inferir(nome: String) -> Dictionary:
	var n := " " + TextUtil.normalizar(nome) + " "
	var t := "infantaria"
	var pos := 99999
	for k in TIPOS:
		for w in TIPOS[k]["palavras"]:
			var i := n.find(" " + w)
			if i >= 0 and w != "exercito" and i < pos:
				pos = i
				t = k
	var fortes: Array = []
	var fracos: Array = []
	match t:
		"sobrenaturais":
			fortes.append("imune a balas e armas comuns")
			fracos.append("vulnerável à magia")
			if n.contains("fantasma") or n.contains("espect") or n.contains("sombra") or n.contains("espirit"):
				fracos.append("some com a luz do dia")
		"monstros":
			if n.contains("drag"):
				fortes.append("voa")
				fortes.append("resiste ao fogo")
			fracos.append("teme o fogo")
		"magos":
			fracos.append("vulnerável a flechas")
		"maquinas":
			fortes.append("resiste a flechas e espadas")
			fracos.append("enfraquece na lama")
		"avioes":
			fracos.append("enfraquece na tempestade")
	for k in PALAVRAS_TERRENO:
		for w in PALAVRAS_TERRENO[k]:
			if n.contains(" do " + w) or n.contains(" da " + w) or n.contains(" das " + w) or n.contains(" dos " + w):
				var palavra: String = {"deserto": "invisível na areia", "floresta": "invisível na mata", "montanha": "forte nas montanhas",
					"agua": "forte no mar", "gelo": "forte no frio", "pantano": "forte no pântano", "colina": "forte nas colinas"}.get(k, "forte no " + w)
				if not fortes.has(palavra):
					fortes.append(palavra)
	return {"tipo": t, "fortes": ", ".join(fortes), "fracos": ", ".join(fracos)}


## Cria uma força (entidade) para uma sociedade. 'causas' liga ao fato que a fez existir.
static func criar(u: Universo, nome: String, sid: String, tam: float, causas: Array = [], dados: Dictionary = {}) -> String:
	var inf := inferir(nome)
	var t: String = dados.get("tipo", inf["tipo"])
	var tipo_ent := "exército"
	if t == "frota":
		tipo_ent = "frota"
	elif t == "avioes":
		tipo_ent = "força aérea"
	elif t == "naves":
		tipo_ent = "frota estelar"
	var campos: Array = [
		{"chave": "tamanho", "valor": _numero_texto(tam)},
		{"chave": "tipo de força", "valor": TIPOS[t]["nome"]},
		{"chave": "pertence a", "valor": u.entidade(sid).get("nome", "") if sid != "" else ""},
	]
	if str(dados.get("comandante", "")) != "":
		campos.append({"chave": "comandante", "valor": u.entidade(dados["comandante"])["nome"]})
	campos.append({"chave": "moral", "valor": str(dados.get("moral", "boa"))})
	var fortes: String = dados.get("fortes", inf["fortes"])
	var fracos: String = dados.get("fracos", inf["fracos"])
	if fortes != "":
		campos.append({"chave": "pontos fortes", "valor": fortes})
	if fracos != "":
		campos.append({"chave": "fraquezas", "valor": fracos})
	var fid := u.criar_entidade(nome, tipo_ent, [], campos, causas)
	if sid != "":
		u.estado(fid)["lado_base"] = sid
	return fid


static func _numero_texto(n: float) -> String:
	if n >= 1000000.0:
		var m := n / 1000000.0
		return ("%d milhões" % int(m)) if absf(m - roundf(m)) < 0.05 else ("%.1f milhões" % m).replace(".", ",")
	if n >= 1000.0:
		var k := n / 1000.0
		return ("%d mil" % int(roundf(k))) if absf(k - roundf(k)) < 0.05 or k >= 20 else ("%.1f mil" % k).replace(".", ",")
	return str(int(roundf(n)))


static func numero(n: float) -> String:
	return _numero_texto(n)
