class_name Mapa
extends RefCounted
## O mapa em texto. Cada lugar pode ficar DENTRO de outro (planeta → região →
## cidade → casa) numa posição (coluna, linha) da grade do lugar de cima.
## O terreno de cada grade é gerado pela semente do universo (sempre igual) e
## o autor pode pintar por cima. Tudo fica em extras["mapa"]:
##   pos:      {id: {pai, x, y}}
##   pintura:  {pai: {"x,y": terreno}}
## Colocar ou mover algo no mapa vira fato (origem autor).

const COLS := 44
const LINHAS := 22
const VELOCIDADE_KM_DIA := 30.0  ## a pé ou de carroça, num dia de viagem

const TERRENOS := {
	"agua": {"simbolo": "≈", "nome": "água", "cor": "#3E5F80"},
	"planicie": {"simbolo": "·", "nome": "planície", "cor": "#8A7444"},
	"campo": {"simbolo": "\"", "nome": "campo", "cor": "#6E7A3A"},
	"floresta": {"simbolo": "♣", "nome": "floresta", "cor": "#3D5A2A"},
	"colina": {"simbolo": "∩", "nome": "colina", "cor": "#7A5A2E"},
	"montanha": {"simbolo": "▲", "nome": "montanha", "cor": "#5A3A1A"},
	"deserto": {"simbolo": "∴", "nome": "deserto", "cor": "#A87A3A"},
	"pantano": {"simbolo": "ψ", "nome": "pântano", "cor": "#4E5E3A"},
	"gelo": {"simbolo": "*", "nome": "gelo", "cor": "#7088A0"},
	"vazio": {"simbolo": " ", "nome": "vazio", "cor": "#5A3A1A"},
}

## Palavras do terreno escritas pelo autor ("na montanha", "perto do rio").
const PALAVRAS_TERRENO := {
	"montanha": "montanha", "montanhas": "montanha", "serra": "montanha", "pico": "montanha", "monte": "montanha",
	"colina": "colina", "colinas": "colina", "morro": "colina",
	"floresta": "floresta", "bosque": "floresta", "mata": "floresta", "selva": "floresta",
	"rio": "agua", "lago": "agua", "mar": "agua", "costa": "agua", "praia": "agua", "lagoa": "agua", "baia": "agua",
	"deserto": "deserto", "dunas": "deserto", "areia": "deserto",
	"pantano": "pantano", "brejo": "pantano", "charco": "pantano",
	"campo": "campo", "campos": "campo", "pradaria": "campo", "vale": "campo",
	"planicie": "planicie", "estepe": "planicie",
	"gelo": "gelo", "geleira": "gelo", "neve": "gelo", "tundra": "gelo",
}

## Que tipo de lugar é (pelo tipo livre). Só para escala, símbolo e simulação.
const ESPECIES_DE_LUGAR := [
	["cosmico", ["galaxia", "universo", "cosmos", "estrela", "sol", "sistema", "nebulosa", "dimensao", "plano"]],
	["planeta", ["planeta", "mundo", "lua", "satelite", "asteroide"]],
	["regiao", ["continente", "regiao", "reino", "imperio", "provincia", "condado", "ducado", "pais", "nacao", "territorio", "terra", "terras", "baronia", "republica"]],
	["povoado", ["cidade", "capital", "vila", "aldeia", "povoado", "porto", "metropole", "cidadela", "vilarejo", "colonia", "acampamento", "bairro", "assentamento"]],
	["construcao", ["casa", "cabana", "torre", "castelo", "fortaleza", "forte", "templo", "mosteiro", "igreja", "santuario", "ruina", "ruinas", "taverna", "estalagem", "mercado", "farol", "ponte", "mina", "fazenda", "sitio", "moinho", "palacio", "academia", "biblioteca", "prisao", "cemiterio", "tumba", "estacao", "base"]],
	["natural", ["floresta", "bosque", "montanha", "serra", "lago", "rio", "mar", "oceano", "ilha", "deserto", "pantano", "caverna", "vale", "colina", "costa", "baia", "cachoeira", "vulcao", "geleira", "planicie", "campo", "selva"]],
]

const SIMBOLOS := {
	"cosmico": "✦", "planeta": "◉", "regiao": "◇", "povoado": "●", "natural": "◆", "outro": "◆",
}
const SIMBOLOS_CONSTRUCAO := [
	[["casa", "cabana", "fazenda", "sitio", "moinho", "taverna", "estalagem"], "⌂"],
	[["torre", "castelo", "fortaleza", "forte", "palacio", "prisao", "cidadela"], "♜"],
	[["ruina", "ruinas", "tumba", "cemiterio"], "†"],
	[["templo", "mosteiro", "igreja", "santuario"], "✝"],
	[["porto", "farol"], "⚓"],
	[["mina", "caverna"], "Ω"],
]

static var _cache_terreno: Dictionary = {}


static func dados(u: Universo) -> Dictionary:
	var m: Dictionary = u.extra("mapa", {})
	if not m.has("pos"):
		m["pos"] = {}
	if not m.has("pintura"):
		m["pintura"] = {}
	return m


# ---------------------------------------------------------------- hierarquia e posições

static func posicao(u: Universo, eid: String) -> Dictionary:
	return dados(u)["pos"].get(eid, {})


static func no_mapa(u: Universo, eid: String) -> bool:
	return dados(u)["pos"].has(eid)


static func pai(u: Universo, eid: String) -> String:
	return str(posicao(u, eid).get("pai", ""))


## Lugares acima deste, do mais próximo ao mais distante.
static func ancestrais(u: Universo, eid: String) -> Array:
	var lista: Array = []
	var atual := pai(u, eid)
	while atual != "" and not lista.has(atual) and lista.size() < 32:
		lista.append(atual)
		atual = pai(u, atual)
	return lista


static func filhos(u: Universo, de: String) -> Array:
	var lista: Array = []
	var pos: Dictionary = dados(u)["pos"]
	for eid in pos:
		if str(pos[eid].get("pai", "")) == de and u.entidades.has(eid) and not u.entidade(eid)["removida"]:
			lista.append(eid)
	lista.sort_custom(func(a, b): return TextUtil.chave(u.entidade(a)["nome"]) < TextUtil.chave(u.entidade(b)["nome"]))
	return lista


static func descendentes(u: Universo, de: String) -> Array:
	var lista: Array = []
	var fila: Array = filhos(u, de)
	while not fila.is_empty():
		var e: String = fila.pop_front()
		if lista.has(e):
			continue
		lista.append(e)
		fila.append_array(filhos(u, e))
	return lista


## O que está numa célula da grade de 'de'.
static func em(u: Universo, de: String, x: int, y: int) -> String:
	for eid in filhos(u, de):
		var p := posicao(u, eid)
		if int(p["x"]) == x and int(p["y"]) == y:
			return eid
	return ""


## Coloca (ou move) algo no mapa. Vira fato do autor.
static func colocar(u: Universo, eid: String, de: String, x: int, y: int, registrar_fato: bool = true) -> void:
	if not u.entidades.has(eid) or eid == de or ancestrais(u, de).has(eid):
		return
	x = clampi(x, 0, COLS - 1)
	y = clampi(y, 0, LINHAS - 1)
	var antes := posicao(u, eid)
	dados(u)["pos"][eid] = {"pai": de, "x": x, "y": y}
	if registrar_fato:
		var onde: String = ("em " + u.entidade(de)["nome"]) if de != "" else "no cosmos"
		var verbo := "foi colocado" if antes.is_empty() else "foi movido"
		u.fatos.registrar({
			"tipo": "mapa",
			"descricao": "%s %s no mapa, %s." % [u.entidade(eid)["nome"], verbo, onde],
			"sujeitos": [eid] + ([de] if de != "" else []),
			"lugar": de,
			"data": DataMundo.copiar(u.relogio),
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "mapa"},
			"dados": {"importancia": 0.05, "x": x, "y": y, "antes": antes},
		})
	u.marcar_mudanca()


static func tirar(u: Universo, eid: String) -> void:
	if dados(u)["pos"].erase(eid):
		u.marcar_mudanca()


# ---------------------------------------------------------------- tipos de lugar

static func especie(u: Universo, eid: String) -> String:
	return especie_do_tipo(u.entidade(eid).get("tipo", ""))


static var _cache_especie: Dictionary = {}


static func especie_do_tipo(tipo: String) -> String:
	if _cache_especie.has(tipo):
		return _cache_especie[tipo]
	var r := _especie_do_tipo(tipo)
	if _cache_especie.size() > 2000:
		_cache_especie.clear()
	_cache_especie[tipo] = r
	return r


static func _especie_do_tipo(tipo: String) -> String:
	var palavras := TextUtil.palavras(TextUtil.normalizar(tipo))
	for par in ESPECIES_DE_LUGAR:
		for p in palavras:
			if p in par[1]:
				return par[0]
	if Sugestoes.categoria(tipo) == "lugar":
		return "outro"
	return ""


## Lugar = tipo de lugar ou qualquer coisa colocada no mapa.
static func e_lugar(u: Universo, eid: String) -> bool:
	return especie(u, eid) != "" or no_mapa(u, eid)


static func simbolo(u: Universo, eid: String) -> String:
	var esp := especie(u, eid)
	var palavras := TextUtil.palavras(TextUtil.normalizar(u.entidade(eid).get("tipo", "")))
	for par in SIMBOLOS_CONSTRUCAO:
		for p in palavras:
			if p in par[0]:
				return par[1]
	if esp == "natural":
		for p in palavras:
			if PALAVRAS_TERRENO.has(p):
				return TERRENOS[PALAVRAS_TERRENO[p]]["simbolo"]
	if esp == "povoado" and ("aldeia" in palavras or "vila" in palavras or "vilarejo" in palavras or "povoado" in palavras or "acampamento" in palavras):
		return "•"
	if esp == "povoado" and "capital" in palavras:
		return "◉"
	return SIMBOLOS.get(esp, "◆")


## Quilômetros que cada célula da grade deste lugar representa.
## O autor pode escrever na ficha "largura: 800 km" ou "tamanho: 40 km".
static func km_por_celula(u: Universo, eid: String) -> float:
	if eid == "":
		return -1.0
	for chave in ["largura", "tamanho", "extensão", "extensao", "área", "area"]:
		var v := u.valor_campo(eid, chave)
		if v != "" and TextUtil.normalizar(v).contains("km"):
			var n := Combate.ler_numero(v)
			if n > 0:
				return n / float(COLS)
	match especie(u, eid):
		"cosmico":
			return -1.0
		"planeta":
			return 220.0
		"regiao":
			var t := TextUtil.normalizar(u.entidade(eid)["tipo"])
			return 90.0 if t.contains("continente") else 14.0
		"povoado":
			return 0.12
		"construcao":
			return 0.01
		"natural":
			return 3.0
	return 6.0


# ---------------------------------------------------------------- viagem

## Dias de viagem entre dois lugares do mapa (-1 = não dá para saber).
static var _cache_viagem: Dictionary = {}


static func dias_de_viagem(u: Universo, de: String, para: String) -> int:
	if de == "" or para == "":
		return -1
	if de == para:
		return 0
	var chave := "%s|%s|%s|%d|%d|%d" % [u.id, de, para, hash(dados(u)["pos"]), hash(Cosmos.leis(u)), _hash_cadeia(u, de) + _hash_cadeia(u, para)]
	if _cache_viagem.has(chave):
		return _cache_viagem[chave]
	if _cache_viagem.size() > 20000:
		_cache_viagem.clear()
	var d := _calcular_viagem(u, de, para)
	_cache_viagem[chave] = d
	return d


static func _hash_cadeia(u: Universo, eid: String) -> int:
	var h := hash(u.entidade(eid).get("campos", []))
	for a in ancestrais(u, eid):
		h = h * 31 + hash(u.entidade(a).get("campos", []))
	return h


static func _calcular_viagem(u: Universo, de: String, para: String) -> int:
	if not no_mapa(u, de) or not no_mapa(u, para):
		return -1
	var cadeia_a: Array = [de] + ancestrais(u, de)
	var cadeia_b: Array = [para] + ancestrais(u, para)
	var comum := ""
	for c in cadeia_a:
		if cadeia_b.has(c):
			comum = c
			break
	if comum == "":
		return -1  # mundos diferentes: só as regras do universo (Parte 5) dizem como ir
	var escala := km_por_celula(u, comum)
	if escala <= 0:
		return -1
	var pa := _ponto_em(u, cadeia_a, comum)
	var pb := _ponto_em(u, cadeia_b, comum)
	var km := pa.distance_to(pb) * escala
	# A tecnologia do universo encurta o caminho (carroças, estradas, navios, máquinas).
	var vel := float(u.extra("leis", {}).get("velocidade_viagem", VELOCIDADE_KM_DIA * (0.75 + 0.9 * float(Cosmos.leis(u)["tecnologia"]))))
	return maxi(1, ceili(km / maxf(vel, 0.1)))


## Ponto (na grade de 'comum') por onde passa a cadeia de lugares até lá.
static func _ponto_em(u: Universo, cadeia: Array, comum: String) -> Vector2:
	var i := cadeia.find(comum)
	if i <= 0:
		return Vector2(COLS / 2.0, LINHAS / 2.0)  # o próprio lugar: o centro dele
	var p := posicao(u, cadeia[i - 1])
	return Vector2(float(p["x"]), float(p["y"]))


# ---------------------------------------------------------------- terreno

## Terreno de uma célula da grade de 'de' (com a pintura do autor por cima).
static func terreno_em(u: Universo, de: String, x: int, y: int) -> String:
	return terreno(u, de)[y][x]


## Grade de terreno (LINHAS × COLS) de um lugar. Determinística pela semente.
static func terreno(u: Universo, de: String) -> Array:
	var pintura: Dictionary = dados(u)["pintura"].get(de, {})
	var chave := "%s|%s|%d|%d" % [u.id, de, u.semente(), hash(pintura)]
	if _cache_terreno.has(chave):
		return _cache_terreno[chave]
	var grade := _gerar(u, de)
	for k in pintura:
		var partes: PackedStringArray = str(k).split(",")
		if partes.size() == 2:
			var x := int(partes[0])
			var y := int(partes[1])
			if x >= 0 and x < COLS and y >= 0 and y < LINHAS and TERRENOS.has(pintura[k]):
				grade[y][x] = pintura[k]
	if _cache_terreno.size() > 64:
		_cache_terreno.clear()
	_cache_terreno[chave] = grade
	return grade


## O autor pinta o terreno (pincel). Devolve true se mudou algo.
static func pintar(u: Universo, de: String, x: int, y: int, t: String) -> bool:
	if not TERRENOS.has(t) or x < 0 or y < 0 or x >= COLS or y >= LINHAS:
		return false
	var p: Dictionary = dados(u)["pintura"]
	if not p.has(de):
		p[de] = {}
	var k := "%d,%d" % [x, y]
	if p[de].get(k, "") == t:
		return false
	p[de][k] = t
	return true


## Fato único depois de uma sessão de pintura.
static func registrar_pintura(u: Universo, de: String, celulas: int) -> void:
	if celulas <= 0:
		return
	u.fatos.registrar({
		"tipo": "mapa",
		"descricao": "O autor redesenhou o terreno %s (%d trechos)." % [("de " + u.entidade(de)["nome"]) if de != "" else "do cosmos", celulas],
		"sujeitos": [de] if de != "" else [],
		"lugar": de,
		"data": DataMundo.copiar(u.relogio),
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "mapa"},
		"dados": {"importancia": 0.05},
	})
	u.marcar_mudanca()


## Quanto de cada terreno há numa grade (frações que somam 1).
static func composicao(u: Universo, de: String, raio: int = -1, cx: int = 0, cy: int = 0) -> Dictionary:
	var g := terreno(u, de)
	var conta := {}
	var total := 0
	for y in LINHAS:
		for x in COLS:
			if raio >= 0 and Vector2(x - cx, (y - cy) * 2.0).length() > raio:
				continue
			var t: String = g[y][x]
			conta[t] = int(conta.get(t, 0)) + 1
			total += 1
	for t in conta:
		conta[t] = float(conta[t]) / maxf(1.0, total)
	return conta


## Terreno do lugar visto de fora (a célula onde ele está no mapa de cima).
static func terreno_do_lugar(u: Universo, eid: String) -> String:
	var p := posicao(u, eid)
	if p.is_empty():
		return ""
	var t := terreno_em(u, str(p["pai"]), int(p["x"]), int(p["y"]))
	return "" if t == "vazio" else t


static func _gerar(u: Universo, de: String) -> Array:
	var grade: Array = []
	var esp := especie(u, de) if de != "" else "cosmico"
	if de == "" or esp == "cosmico":
		for y in LINHAS:
			var linha: Array = []
			for x in COLS:
				linha.append("vazio")
			grade.append(linha)
		return grade
	var ruido := _ruido_altura(u, de)
	var umidade := FastNoiseLite.new()
	umidade.seed = ruido.seed + 7
	umidade.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	umidade.frequency = 0.06
	var mistura := FastNoiseLite.new()
	mistura.seed = ruido.seed + 13
	mistura.frequency = 0.09
	var desc := TextUtil.normalizar(u.entidade(de).get("tipo", "") + " " + u.valor_campo(de, "clima") + " " +
		u.valor_campo(de, "descrição") + " " + u.valor_campo(de, "descricao") + " " + u.valor_campo(de, "terreno"))
	var vies := _vies_do_texto(desc)
	var base := terreno_do_lugar(u, de)
	if esp != "planeta":
		if base != "":
			vies[base] = float(vies.get(base, 0.0)) + 0.55
	var nivel_mar := 0.02 + float(vies.get("agua", 0.0)) * 0.35 - float(vies.get("deserto", 0.0)) * 0.2
	if esp != "planeta" and base != "agua":
		nivel_mar -= 0.25  # dentro de terra firme, pouca água
	for y in LINHAS:
		var linha: Array = []
		for x in COLS:
			var h := ruido.get_noise_2d(x, y * 2.0)
			var w := umidade.get_noise_2d(x, y * 2.0) + float(vies.get("floresta", 0.0)) * 0.3 + float(vies.get("pantano", 0.0)) * 0.3 - float(vies.get("deserto", 0.0)) * 0.5
			var lat := absf((y + 0.5) / LINHAS - 0.5) * 2.0
			var t := ""
			if h < nivel_mar - 0.18:
				t = "agua"
			elif h < nivel_mar:
				t = "agua" if esp == "planeta" or base == "agua" else "pantano" if w > 0.2 else "planicie"
			elif h > 0.55 - float(vies.get("montanha", 0.0)) * 0.3:
				t = "montanha"
			elif h > 0.38 - float(vies.get("colina", 0.0)) * 0.2 - float(vies.get("montanha", 0.0)) * 0.15:
				t = "colina"
			elif w > 0.35:
				t = "pantano" if h < nivel_mar + 0.06 else "floresta"
			elif w > 0.05:
				t = "floresta"
			elif w < -0.35:
				t = "deserto"
			elif w < -0.12:
				t = "planicie"
			else:
				t = "campo"
			if esp != "planeta" and base != "" and base != "agua" and t != "agua" and mistura.get_noise_2d(x * 1.3, y * 2.6) > 0.05:
				t = base  # o terreno de fora predomina aqui dentro
			if esp == "planeta" and t != "agua" and lat > 0.86 - float(vies.get("gelo", 0.0)) * 0.4:
				t = "gelo"
			elif esp == "planeta" and t == "agua" and lat > 0.93:
				t = "gelo"
			linha.append(t)
		grade.append(linha)
	return grade


## O relevo (altura) de uma grade: o mesmo ruído que gera o terreno e guia os rios.
static func _ruido_altura(u: Universo, de: String) -> FastNoiseLite:
	var ruido := FastNoiseLite.new()
	ruido.seed = hash(str(u.semente()) + "|" + de)
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.fractal_octaves = 4
	ruido.frequency = 0.045 if especie(u, de) == "planeta" else 0.08
	return ruido


static func _vies_do_texto(desc: String) -> Dictionary:
	var v := {}
	var palavras := TextUtil.palavras(desc)
	for p in palavras:
		if PALAVRAS_TERRENO.has(p):
			v[PALAVRAS_TERRENO[p]] = float(v.get(PALAVRAS_TERRENO[p], 0.0)) + 0.5
		match p:
			"arido", "arida", "seco", "seca", "quente":
				v["deserto"] = float(v.get("deserto", 0.0)) + 0.4
			"frio", "fria", "gelado", "gelada", "congelado":
				v["gelo"] = float(v.get("gelo", 0.0)) + 0.5
			"umido", "umida", "chuvoso", "chuvosa", "tropical":
				v["floresta"] = float(v.get("floresta", 0.0)) + 0.4
			"oceano", "oceanos", "ilhas", "arquipelago", "aquatico":
				v["agua"] = float(v.get("agua", 0.0)) + 0.6
			"montanhoso", "montanhosa", "rochoso":
				v["montanha"] = float(v.get("montanha", 0.0)) + 0.6
	return v


## Células de um terreno aceitável, para o povoador escolher onde pôr algo.
static func celulas_livres(u: Universo, de: String, aceitos: Array) -> Array:
	var g := terreno(u, de)
	var ocupadas := {}
	for f in filhos(u, de):
		var p := posicao(u, f)
		ocupadas["%d,%d" % [p["x"], p["y"]]] = true
	var lista: Array = []
	for y in range(1, LINHAS - 1):
		for x in range(2, COLS - 2):
			if aceitos.has(g[y][x]) and not ocupadas.has("%d,%d" % [x, y]):
				lista.append(Vector2i(x, y))
	return lista


# ---------------------------------------------------------------- acidentes: serras, mares, florestas, rios

## Palavras que o autor usa para nomear a natureza ("montanha do sul", "rio da pedra azul").
const TERMOS_ACIDENTE := {
	"montanha": "montanha", "montanhas": "montanha", "serra": "montanha", "serras": "montanha", "pico": "montanha",
	"picos": "montanha", "monte": "montanha", "montes": "montanha", "cordilheira": "montanha",
	"colina": "colina", "colinas": "colina", "outeiro": "colina", "outeiros": "colina", "morros": "colina",
	"floresta": "floresta", "florestas": "floresta", "bosque": "floresta", "mata": "floresta", "selva": "floresta",
	"mar": "agua", "oceano": "agua", "lago": "agua", "lagoa": "agua", "baia": "agua", "golfo": "agua", "enseada": "agua",
	"deserto": "deserto", "areias": "deserto", "dunas": "deserto",
	"pantano": "pantano", "brejo": "pantano", "charco": "pantano", "charcos": "pantano", "alagado": "pantano",
	"geleira": "gelo", "gelos": "gelo", "glaciar": "gelo",
	"planicie": "planicie", "planicies": "planicie", "campos": "planicie", "pradaria": "planicie", "estepe": "planicie", "vale": "planicie",
	"rio": "rio", "riacho": "rio", "ribeirao": "rio", "corrego": "rio",
}

const MODELOS_NOME := {
	"montanha": ["Montanhas de %s", "Serra de %s", "Picos de %s", "Montes %s"],
	"colina": ["Colinas de %s", "Outeiros de %s"],
	"floresta": ["Floresta de %s", "Mata de %s", "Bosque de %s"],
	"oceano": ["Oceano %s", "Mar de %s", "Mar %s"],
	"lago": ["Lago %s", "Lagoa de %s"],
	"deserto": ["Deserto de %s", "Areias de %s"],
	"pantano": ["Pântano de %s", "Charcos de %s"],
	"gelo": ["Gelos de %s", "Terras Brancas de %s"],
	"planicie": ["Planície de %s", "Campos de %s"],
	"rio": ["Rio %s", "Rio %s", "Rio de %s"],
}

const TAMANHO_MINIMO := {"agua": 3, "montanha": 6, "colina": 10, "floresta": 8, "deserto": 8, "pantano": 6, "gelo": 10, "planicie": 30}

static var _cache_rios: Dictionary = {}
static var _cache_acidentes: Dictionary = {}
static var _ultima_base := ""


static func _nomes(u: Universo, de: String) -> Dictionary:
	var m := dados(u)
	if not m.has("nomes"):
		m["nomes"] = {}
	if not m["nomes"].has(de):
		m["nomes"][de] = {}
	return m["nomes"][de]


static func _grupo(t: String) -> String:
	if t == "campo":
		return "planicie"
	return t


## Rios de uma grade: nascem nas montanhas e descem pelo relevo até a água.
## Cada um: {chave, pontos: Array[Vector2i]}.
static func rios(u: Universo, de: String) -> Array:
	var autor: Array = dados(u).get("rios_autor", {}).get(de, [])
	var chave := "%s|%s|%d|%d|%d" % [u.id, de, u.semente(), hash(dados(u)["pintura"].get(de, {})), autor.size()]
	if _cache_rios.has(chave):
		return _cache_rios[chave]
	var lista: Array = []
	var esp := especie(u, de) if de != "" else "cosmico"
	if de != "" and not esp in ["cosmico", "construcao"]:
		var g := terreno(u, de)
		var alt := _ruido_altura(u, de)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(u.semente()) + "|rios|" + de)
		var fontes: Array = []
		for y in LINHAS:
			for x in COLS:
				if g[y][x] in ["montanha", "colina"]:
					fontes.append(Vector2i(x, y))
		var quantos: int = {"planeta": 6, "regiao": 3, "natural": 2}.get(esp, 1)
		var escolhidas := 0
		var usadas: Array = []
		for tentativa in 60:
			if escolhidas >= quantos or fontes.is_empty():
				break
			var f: Vector2i = fontes[rng.randi() % fontes.size()]
			if usadas.any(func(o): return Vector2(f - o).length() < 7.0):
				continue
			var pontos := _descer(g, alt, f)
			if pontos.size() >= 5 and g[pontos.back().y][pontos.back().x] == "agua" or pontos.size() >= 9:
				lista.append({"chave": "rio:%d,%d" % [f.x, f.y], "pontos": pontos})
				usadas.append(f)
				escolhidas += 1
	# O rio termina onde encontra a água.
	if de != "":
		var gg := terreno(u, de)
		for r in lista:
			var corte: Array = []
			for p in r["pontos"]:
				corte.append(p)
				if gg[p.y][p.x] == "agua" and corte.size() > 1:
					break
			r["pontos"] = corte
	for r in autor:
		var pts: Array = []
		for p in r["pontos"]:
			pts.append(Vector2i(int(p[0]), int(p[1])))
		lista.append({"chave": str(r["chave"]), "pontos": pts})
	if _cache_rios.size() > 64:
		_cache_rios.clear()
	_cache_rios[chave] = lista
	return lista


## Caminho de um rio, descendo pelo relevo a partir de 'inicio'.
static func _descer(g: Array, alt: FastNoiseLite, inicio: Vector2i) -> Array:
	var pontos: Array = [inicio]
	var atual := inicio
	var vistos := {inicio: true}
	var subidas := 0
	for passo in 90:
		if g[atual.y][atual.x] == "agua" and passo > 0:
			break
		var melhor := Vector2i(-1, -1)
		var melhor_h := 99.0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = atual + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= LINHAS or vistos.has(n):
				continue
			var h := alt.get_noise_2d(n.x, n.y * 2.0) - (0.5 if g[n.y][n.x] == "agua" else 0.0)
			if h < melhor_h:
				melhor_h = h
				melhor = n
		if melhor.x < 0:
			break
		if melhor_h > alt.get_noise_2d(atual.x, atual.y * 2.0):
			subidas += 1
			if subidas > 4:
				break
		vistos[melhor] = true
		pontos.append(melhor)
		atual = melhor
		if atual.x == 0 or atual.y == 0 or atual.x == COLS - 1 or atual.y == LINHAS - 1:
			break
	return pontos


## Serras, mares, lagos, florestas, desertos… de uma grade, cada um com nome.
## Cada um: {tipo, grupo, celulas: Array[Vector2i], centro: Vector2, nome, eid, chave}.
static func acidentes(u: Universo, de: String) -> Array:
	var g := terreno(u, de)
	var nomes := _nomes(u, de)
	var chave := "%s|%s|%d|%d|%d|%d" % [u.id, de, u.semente(), hash(dados(u)["pintura"].get(de, {})), hash(nomes), dados(u).get("rios_autor", {}).get(de, []).size()]
	if _cache_acidentes.has(chave):
		return _cache_acidentes[chave]
	var lista: Array = []
	if de == "" or especie(u, de) == "cosmico":
		return lista
	var visto := {}
	for y in LINHAS:
		for x in COLS:
			var c := Vector2i(x, y)
			if visto.has(c):
				continue
			var grupo := _grupo(g[y][x])
			if grupo in ["vazio"]:
				visto[c] = true
				continue
			var celulas: Array = []
			var fila: Array = [c]
			visto[c] = true
			while not fila.is_empty():
				var a: Vector2i = fila.pop_back()
				celulas.append(a)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = a + d
					if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= LINHAS or visto.has(n):
						continue
					var gn := _grupo(g[n.y][n.x])
					if gn == grupo or (grupo == "montanha" and gn == "colina") or (grupo == "colina" and gn == "montanha"):
						visto[n] = true
						fila.append(n)
			var tipo := grupo
			if grupo in ["montanha", "colina"]:
				var picos := celulas.filter(func(k): return g[k.y][k.x] == "montanha").size()
				tipo = "montanha" if picos >= 3 else "colina"
			if celulas.size() < int(TAMANHO_MINIMO.get(tipo, 8)):
				continue
			var soma := Vector2.ZERO
			for k in celulas:
				soma += Vector2(k)
			var centro := soma / celulas.size()
			var modelo := tipo
			if tipo == "agua":
				var borda := celulas.any(func(k): return k.x == 0 or k.y == 0 or k.x == COLS - 1 or k.y == LINHAS - 1)
				modelo = "oceano" if borda and celulas.size() >= 40 or celulas.size() >= 120 else "lago"
			# Nome guardado (do autor ou gerado uma vez) em qualquer célula do acidente.
			var achado := {}
			for k in celulas:
				var kk := "%d,%d" % [k.x, k.y]
				if nomes.has(kk) and str(nomes[kk].get("grupo", "")) in [tipo, grupo, "montanha" if tipo == "colina" else tipo]:
					achado = nomes[kk]
					achado["_chave"] = kk
					break
			if achado.is_empty():
				var rep: Vector2i = celulas[0]
				for k in celulas:
					if k.y * COLS + k.x < rep.y * COLS + rep.x:
						rep = k
				var kk := "%d,%d" % [rep.x, rep.y]
				achado = {"nome": _nome_novo(u, de, modelo, kk), "grupo": tipo, "eid": "", "base": _ultima_base}
				nomes[kk] = achado.duplicate()
				achado["_chave"] = kk
			lista.append({"tipo": modelo, "grupo": tipo, "celulas": celulas, "centro": centro,
				"nome": achado["nome"], "eid": str(achado.get("eid", "")), "chave": achado["_chave"]})
	for r in rios(u, de):
		var k: String = r["chave"]
		if not nomes.has(k):
			nomes[k] = {"nome": _nome_novo(u, de, "rio", k), "grupo": "rio", "eid": "", "base": _ultima_base}
		var meio: Vector2i = r["pontos"][r["pontos"].size() / 2]
		lista.append({"tipo": "rio", "grupo": "rio", "celulas": r["pontos"], "centro": Vector2(meio), "nome": nomes[k]["nome"],
			"eid": str(nomes[k].get("eid", "")), "chave": k})
	if _cache_acidentes.size() > 64:
		_cache_acidentes.clear()
	_cache_acidentes[chave] = lista
	return lista


static func _nome_novo(u: Universo, de: String, modelo: String, chave: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(u.semente()) + "|nome|" + de + "|" + chave)
	var lingua := Linguas.do_lugar(u, de)
	var modelos: Array = MODELOS_NOME.get(modelo, ["%s"])
	# Não repete o nome-base de outro acidente deste mapa.
	var evitar: Array = []
	for v in _nomes(u, de).values():
		evitar.append(str(v.get("base", "")))
	var base := Linguas.gerar(u, lingua, "lugares", rng, evitar)
	_ultima_base = base
	return modelos[rng.randi() % modelos.size()] % base


## O acidente numa célula (o rio vence se passar ali).
static func acidente_em(u: Universo, de: String, x: int, y: int) -> Dictionary:
	var c := Vector2i(x, y)
	var achado := {}
	for a in acidentes(u, de):
		if a["grupo"] == "rio":
			if a["celulas"].has(c):
				return a
		elif achado.is_empty() and a["celulas"].has(c):
			achado = a
	return achado


## Rio que passa perto de uma célula ({} se nenhum).
static func rio_perto(u: Universo, de: String, x: int, y: int, distancia: float = 1.5) -> Dictionary:
	for a in acidentes(u, de):
		if a["grupo"] != "rio":
			continue
		for p in a["celulas"]:
			if Vector2(p - Vector2i(x, y)).length() <= distancia:
				return a
	return {}


## Dá nome (do autor) a um acidente. Vira fato. 'eid' liga o acidente a uma página da wiki.
static func nomear_acidente(u: Universo, de: String, acidente: Dictionary, nome: String, eid: String = "") -> void:
	nome = nome.strip_edges()
	if acidente.is_empty() or nome == "":
		return
	var nomes := _nomes(u, de)
	var antes: String = acidente["nome"]
	nomes[acidente["chave"]] = {"nome": nome, "grupo": acidente["grupo"], "eid": eid if eid != "" else acidente.get("eid", ""), "autor": true}
	if antes != nome:
		u.fatos.registrar({
			"tipo": "mapa",
			"descricao": "%s passou a se chamar %s." % [antes, nome],
			"sujeitos": ([eid] if eid != "" else []) + ([de] if de != "" else []),
			"lugar": de,
			"data": DataMundo.copiar(u.relogio),
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "mapa"},
			"dados": {"importancia": 0.1, "antes": antes, "depois": nome},
		})
	u.marcar_mudanca()


## O autor escreve um rio onde não havia: nasce no ponto e desce até a água.
static func criar_rio(u: Universo, de: String, x: int, y: int) -> Dictionary:
	var m := dados(u)
	if not m.has("rios_autor"):
		m["rios_autor"] = {}
	if not m["rios_autor"].has(de):
		m["rios_autor"][de] = []
	var pontos := _descer(terreno(u, de), _ruido_altura(u, de), Vector2i(x, y))
	if pontos.size() < 6:
		# Sem descida clara: o rio corre para a borda mais perto.
		var alvo := Vector2i(0 if x < COLS / 2 else COLS - 1, y)
		if mini(y, LINHAS - 1 - y) < mini(x, COLS - 1 - x):
			alvo = Vector2i(x, 0 if y < LINHAS / 2 else LINHAS - 1)
		var atual: Vector2i = pontos.back()
		while atual != alvo and pontos.size() < 60:
			atual += Vector2i(signi(alvo.x - atual.x), signi(alvo.y - atual.y))
			pontos.append(atual)
	var chave := "rio_autor:%d,%d" % [x, y]
	m["rios_autor"][de].append({"chave": chave, "pontos": pontos.map(func(p): return [p.x, p.y])})
	for a in acidentes(u, de):
		if a["chave"] == chave:
			return a
	return {}


## Entidades que são página de um acidente (desenhadas como acidente, não como lugar).
static func entidades_de_acidente(u: Universo, de: String) -> Dictionary:
	var r := {}
	for k in _nomes(u, de):
		var e: String = str(_nomes(u, de)[k].get("eid", ""))
		if e != "":
			r[e] = k
	return r
