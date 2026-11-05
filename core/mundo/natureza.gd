class_name Natureza
extends RefCounted
## A natureza de cada lugar, em números simples: o nível de cada espécie
## (1.0 = o quanto a terra comporta), a população e a comida. Sobe e desce com
## as estações, o clima e os acontecimentos (seca, praga, inverno rigoroso…).
## Os números ficam em extras["natureza"][lugar] e só viram fato quando afetam
## alguém: colheita perdida, fome, feras descendo às vilas, uma espécie sumindo.
##
## Acontecimentos naturais são fatos com a operação "evento_natural"; valem para
## o lugar e tudo o que fica dentro dele no mapa.

## Espécies comuns de cada terreno (nomes livres; o autor cria as dele em Criadores).
const BIOMAS := {
	"floresta": [["árvores", "planta"], ["cervos", "presa"], ["lobos", "predador"], ["ervas curativas", "rara"]],
	"campo": [["capim", "planta"], ["coelhos", "presa"], ["raposas", "predador"]],
	"planicie": [["capim", "planta"], ["cavalos selvagens", "presa"], ["raposas", "predador"]],
	"colina": [["arbustos", "planta"], ["cabras", "presa"], ["linces", "predador"]],
	"montanha": [["líquens", "planta"], ["cabras-monteses", "presa"], ["ursos", "predador"], ["flor-de-pedra", "rara"]],
	"agua": [["algas", "planta"], ["peixes", "presa"], ["garças", "predador"]],
	"deserto": [["cactos", "planta"], ["lagartos", "presa"], ["escorpiões", "predador"]],
	"pantano": [["juncos", "planta"], ["sapos", "presa"], ["crocodilos", "predador"], ["musgo-de-sangue", "rara"]],
	"gelo": [["musgo", "planta"], ["focas", "presa"], ["ursos-brancos", "predador"]],
}

## Acontecimentos naturais que o autor pode escrever (palavras → tipo).
const EVENTOS := {
	"seca": {"nome": "seca", "palavras": ["seca", "estiagem", "sem chuva", "falta de chuva", "calor"], "dias": 150, "simbolo": "☀"},
	"praga": {"nome": "praga nas lavouras", "palavras": ["praga", "gafanhoto", "gafanhotos", "lagarta", "ferrugem", "fungo"], "dias": 90, "simbolo": "☠"},
	"epidemia": {"nome": "peste", "palavras": ["peste", "epidemia", "doenca", "febre", "pestilencia", "contagio"], "dias": 120, "simbolo": "☠"},
	"inverno": {"nome": "inverno rigoroso", "palavras": ["inverno rigoroso", "nevasca", "geada", "frio intenso", "inverno"], "dias": 90, "simbolo": "❄"},
	"enchente": {"nome": "enchente", "palavras": ["enchente", "inundacao", "cheia", "diluvio", "chuva forte", "tempestade"], "dias": 30, "simbolo": "≋"},
	"fartura": {"nome": "fartura", "palavras": ["fartura", "colheita farta", "boa colheita", "abundancia", "chuva boa", "chuvas boas"], "dias": 180, "simbolo": "✿"},
	"incendio": {"nome": "incêndio", "palavras": ["incendio", "fogo", "queimada", "chamas"], "dias": 21, "simbolo": "♨"},
	"feras": {"nome": "feras famintas", "palavras": ["feras", "lobos", "monstros", "monstro", "matilha", "predadores"], "dias": 60, "simbolo": "✧"},
	"terremoto": {"nome": "terremoto", "palavras": ["terremoto", "tremor", "sismo", "abalo"], "dias": 7, "simbolo": "⚡"},
}

const FORCAS := {"leve": 0.5, "fraca": 0.5, "pequena": 0.6, "forte": 1.4, "terrivel": 1.7, "grande": 1.4,
	"severa": 1.5, "intensa": 1.4, "devastadora": 1.9, "longa": 1.0, "rigoroso": 1.2}

const PAPEIS := {"planta": "planta", "plantas": "planta", "presa": "presa", "presas": "presa", "caca": "presa",
	"predador": "predador", "predadores": "predador", "cacador": "predador", "rara": "rara", "raro": "rara", "raras": "rara"}

const OFICIOS_COMIDA := ["lavrador", "pastor", "pescador", "caçador"]


# ---------------------------------------------------------------- espécies de cada terreno (editáveis)

## Espécies de um terreno: as que você escreveu na aba Universo, ou as sugestões.
static func especies_do_terreno(u: Universo, terreno: String) -> Array:
	var meus: Dictionary = u.extra("biomas", {})
	if meus.has(terreno):
		return meus[terreno]
	return BIOMAS.get(terreno, [])


## Lê "cervos: presa" (uma por linha) e guarda como as espécies do terreno.
## Vira fato; com 'aplicar', os lugares que já existem ganham as novas e perdem as tiradas.
static func definir_terreno(u: Universo, terreno: String, texto: String, aplicar: bool = true) -> Array:
	var lista: Array = []
	for linha in texto.split("\n", false):
		var partes := linha.split(":", true, 1)
		var nome := partes[0].strip_edges().trim_prefix("•").trim_prefix("-").strip_edges()
		if nome == "":
			continue
		var papel := "presa"
		if partes.size() > 1:
			papel = PAPEIS.get(TextUtil.normalizar(partes[1]).strip_edges(), "presa")
		lista.append([nome, papel])
	var antes := especies_do_terreno(u, terreno).map(func(p): return p[0])
	u.extra("biomas", {})[terreno] = lista
	u.fatos.registrar({
		"tipo": "natureza", "descricao": "O autor definiu a vida de %s: %s." % [Mapa.TERRENOS.get(terreno, {}).get("nome", terreno), ", ".join(lista.map(func(p): return p[0]))],
		"data": DataMundo.copiar(u.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "biomas"},
		"dados": {"importancia": 0.2, "terreno": terreno},
	})
	if aplicar:
		var novos := lista.map(func(p): return p[0])
		for lugar in dados(u):
			var reg: Dictionary = dados(u)[lugar]
			if not u.entidades.has(lugar):
				continue
			var comp := _composicao_do_lugar(u, lugar)
			if float(comp.get(terreno, 0.0)) < 0.08:
				continue
			for nome in antes:
				if not novos.has(nome) and reg["especies"].has(nome) and reg["especies"][nome].get("entidade", "") == "":
					reg["especies"].erase(nome)
			for p in lista:
				if not reg["especies"].has(p[0]):
					reg["especies"][p[0]] = {"n": 0.7, "papel": p[1], "peso": float(comp[terreno]), "entidade": ""}
				else:
					reg["especies"][p[0]]["papel"] = p[1]
	u.marcar_mudanca()
	return lista


static func texto_do_terreno(u: Universo, terreno: String) -> String:
	var nomes := {"planta": "planta", "presa": "presa", "predador": "predador", "rara": "rara"}
	return "\n".join(especies_do_terreno(u, terreno).map(func(p): return "%s: %s" % [p[0], nomes.get(p[1], p[1])]))


# ---------------------------------------------------------------- estado

static func dados(u: Universo) -> Dictionary:
	return u.extra("natureza", {})


## Registro da natureza de um lugar (criado na primeira vez, a partir do terreno).
static func de(u: Universo, lugar: String) -> Dictionary:
	var d := dados(u)
	if not d.has(lugar):
		d[lugar] = _iniciar(u, lugar)
	return d[lugar]


static func tem_natureza(u: Universo, lugar: String) -> bool:
	if not u.entidades.has(lugar) or u.entidade(lugar)["removida"]:
		return false
	return Mapa.especie(u, lugar) in ["regiao", "povoado", "natural", "outro"]


static func populacao_inicial(u: Universo, lugar: String) -> float:
	for campo in ["população", "populacao", "habitantes", "moradores"]:
		var v := u.valor_campo(lugar, campo)
		if v != "":
			var n := Combate.ler_numero(v)
			if n >= 0:
				return n
	var t := TextUtil.palavras(TextUtil.normalizar(u.entidade(lugar).get("tipo", "")))
	if Mapa.especie(u, lugar) != "povoado":
		return 0.0
	if "capital" in t or "metropole" in t:
		return 40000.0
	if "cidade" in t or "cidadela" in t:
		return 8000.0
	if "porto" in t:
		return 3000.0
	if "vila" in t or "vilarejo" in t:
		return 700.0
	return 150.0


static func _iniciar(u: Universo, lugar: String) -> Dictionary:
	var comp := _composicao_do_lugar(u, lugar)
	var esp := {}
	for t in comp:
		var bioma := especies_do_terreno(u, t)
		if float(comp[t]) < 0.08 or bioma.is_empty():
			continue
		for par in bioma:
			var nome: String = par[0]
			if not esp.has(nome):
				esp[nome] = {"n": 0.75 + 0.2 * float(comp[t]), "papel": par[1], "peso": 0.0, "entidade": ""}
			esp[nome]["peso"] = float(esp[nome]["peso"]) + float(comp[t])
	# Espécies criadas pelo autor cujo habitat cita este lugar ou o terreno dele.
	for e in u.entidades_ativas():
		if Sugestoes.categoria(e["tipo"]) != "criatura" or Estado.tem_mente(u, e["id"]):
			continue
		var hab := TextUtil.normalizar(u.valor_campo(e["id"], "habitat") + " " + u.valor_campo(e["id"], "onde vive"))
		if hab == "":
			continue
		var casa := hab.contains(TextUtil.normalizar(u.entidade(lugar)["nome"]))
		for t in comp:
			if float(comp[t]) >= 0.15 and hab.contains(TextUtil.normalizar(Mapa.TERRENOS[t]["nome"])):
				casa = true
		if casa:
			esp[e["nome"]] = {"n": 0.7, "papel": _papel_da_ficha(u, e["id"]), "peso": 0.5, "entidade": e["id"]}
	var pop := populacao_inicial(u, lugar)
	if pop > 0:
		esp["lavouras"] = {"n": 0.9, "papel": "cultivo", "peso": 1.0, "entidade": ""}
		esp["rebanhos"] = {"n": 0.85, "papel": "rebanho", "peso": 1.0, "entidade": ""}
		if float(comp.get("agua", 0.0)) >= 0.08 and not esp.has("peixes"):
			esp["peixes"] = {"n": 0.8, "papel": "presa", "peso": float(comp["agua"]), "entidade": ""}
	return {"pop": pop, "pop_ref": pop, "comida": 1.0, "especies": esp, "alertas": {}, "clima": _clima(u, lugar)}


static func _papel_da_ficha(u: Universo, eid: String) -> String:
	var t := TextUtil.normalizar(u.entidade(eid)["tipo"] + " " + u.valor_campo(eid, "comportamento") + " " + u.valor_campo(eid, "perigo") + " " + u.valor_campo(eid, "dieta"))
	for p in ["predador", "carnivor", "caca", "feroz", "monstro", "perigos"]:
		if t.contains(p):
			return "predador"
	if t.contains("planta") or t.contains("arvore") or t.contains("flor") or t.contains("erva"):
		return "rara" if t.contains("rar") or t.contains("magic") or t.contains("cura") else "planta"
	return "presa"


static func _composicao_do_lugar(u: Universo, lugar: String) -> Dictionary:
	var esp := Mapa.especie(u, lugar)
	if esp == "regiao" or esp == "natural":
		var c := Mapa.composicao(u, lugar)
		c.erase("vazio")
		if not c.is_empty():
			return c
	# Povoado: o terreno ao redor dele no mapa de cima.
	var p := Mapa.posicao(u, lugar)
	if not p.is_empty() and str(p["pai"]) != "":
		var c2 := Mapa.composicao(u, str(p["pai"]), 5, int(p["x"]), int(p["y"]))
		c2.erase("vazio")
		if not c2.is_empty():
			return c2
	var t := Mapa.terreno_do_lugar(u, lugar)
	if t != "":
		return {t: 1.0}
	return {"campo": 0.6, "floresta": 0.4}


static func _clima(u: Universo, lugar: String) -> String:
	for c in [lugar] + Mapa.ancestrais(u, lugar):
		var v := TextUtil.normalizar(u.valor_campo(c, "clima"))
		if v != "":
			return v
	var t := Mapa.terreno_do_lugar(u, lugar)
	if t == "gelo":
		return "frio"
	if t == "deserto":
		return "arido"
	return "temperado"


# ---------------------------------------------------------------- acontecimentos

## Transforma um texto livre em acontecimentos naturais com força e duração.
## "uma seca terrível por um ano" → [{tipo: seca, forca: 1.7, dias: 360}]
static func interpretar(texto: String) -> Array:
	var t := " " + TextUtil.normalizar(texto) + " "
	var achados: Array = []
	for tipo in EVENTOS:
		for p in EVENTOS[tipo]["palavras"]:
			var pn := TextUtil.normalizar(p)
			if t.contains(" " + pn + " ") or t.contains(" " + pn + "s ") or t.contains(" " + pn + ","):
				if tipo == "inverno" and pn == "inverno" and not (t.contains("rigoroso") or t.contains("terrivel") or t.contains("cruel") or t.contains("duro")):
					continue
				if tipo == "seca" and pn == "calor" and not t.contains("calor extremo") and not t.contains("onda de calor"):
					continue
				achados.append(tipo)
				break
	var forca := 1.0
	for p in TextUtil.palavras(t):
		if FORCAS.has(p):
			forca = maxf(forca, FORCAS[p]) if FORCAS[p] > 1.0 else minf(forca, FORCAS[p])
	var dias := _duracao(t)
	var saida: Array = []
	for tipo in achados:
		saida.append({"tipo": tipo, "forca": forca, "dias": dias if dias > 0 else int(EVENTOS[tipo]["dias"])})
	return saida


static func _duracao(t: String) -> int:
	var unidades := {"dia": 1, "dias": 1, "semana": 7, "semanas": 7, "mes": 30, "meses": 30, "estacao": 90, "estacoes": 90, "ano": 360, "anos": 360}
	var palavras := TextUtil.palavras(t)
	for i in palavras.size():
		var p: String = palavras[i]
		if unidades.has(p) and i > 0:
			var antes: String = palavras[i - 1]
			var n := Combate.ler_numero(antes)
			if n <= 0:
				n = {"um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "dez": 10}.get(antes, 0)
			if n > 0:
				return int(n * unidades[p])
	return 0


## O autor intervém num lugar com texto livre. Vira fato (origem autor) com as
## operações dos acontecimentos entendidos. Devolve {fato, entendidos: [tipos]}.
static func intervir(u: Universo, lugar: String, texto: String) -> Dictionary:
	texto = texto.strip_edges()
	if texto == "" or not u.entidades.has(lugar):
		return {"fato": "", "entendidos": []}
	var eventos := interpretar(texto)
	var ops: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for ev in eventos:
		ops.append({"op": "evento_natural", "lugar": lugar, "tipo": ev["tipo"], "forca": ev["forca"], "ate": agora + int(ev["dias"])})
	var desc := texto.substr(0, 1).to_upper() + texto.substr(1)
	if not desc.ends_with("."):
		desc += "."
	var nome_lugar: String = u.entidade(lugar)["nome"]
	if not TextUtil.chave(desc).contains(TextUtil.chave(nome_lugar)):
		desc = desc.trim_suffix(".") + " em " + nome_lugar + "."
	var leis := Regras.termos_no_texto(u, texto)
	var fid := Simulador.registrar(u, {
		"tipo": "intervenção" if eventos.is_empty() else EVENTOS[eventos[0]["tipo"]]["nome"],
		"descricao": desc,
		"sujeitos": [lugar],
		"lugar": lugar,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "intervir"},
		"dados": {"importancia": 0.7 if not eventos.is_empty() or not leis.is_empty() else 0.5, "texto": texto, "mudancas": ops,
			"sem_efeito": eventos.is_empty() and leis.is_empty()},
	})
	# Termos que você definiu ("chuva de sangue → …") valem aqui também.
	var por_lei: Array = []
	for r in leis:
		var fx := Regras.disparar(u, r, {"sujeito": "", "outro": "", "lugar": lugar}, fid)
		if fx != "":
			por_lei.append(r["texto"])
	u.marcar_mudanca()
	return {"fato": fid, "entendidos": eventos.map(func(e): return e["tipo"]), "leis": por_lei}


## Acontecimentos naturais valendo agora num lugar (dele e dos lugares onde ele fica).
static func eventos_ativos(u: Universo, lugar: String) -> Array:
	var lista: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for c in [lugar] + Mapa.ancestrais(u, lugar):
		if not u.entidades.has(c):
			continue
		for ev in u.estado(c).get("eventos_naturais", []):
			if not ev.get("fim", false) and int(ev["desde"]) <= agora and int(ev["ate"]) >= agora:
				lista.append(ev)
	return lista


## Operações próprias da natureza (chamadas por Mudancas via sistemas_de_mudanca).
static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	match str(op.get("op", "")):
		"evento_natural":
			var lugar := str(op.get("lugar", ""))
			if not u.entidades.has(lugar):
				return true
			var s := u.estado(lugar)
			if not s.has("eventos_naturais"):
				s["eventos_naturais"] = []
			s["eventos_naturais"].append({"tipo": str(op.get("tipo", "")), "forca": float(op.get("forca", 1.0)),
				"desde": DataMundo.ordem(fato.get("data", u.relogio)), "ate": int(op.get("ate", 0)),
				"fato": fato.get("id", ""), "lugar": lugar})
			return true
		"fim_evento":
			var lugar := str(op.get("lugar", ""))
			if u.entidades.has(lugar):
				for ev in u.estado(lugar).get("eventos_naturais", []):
					if ev["fato"] == str(op.get("evento", "")):
						ev["fim"] = true
			return true
		"natureza_nivel":
			var reg := de(u, str(op.get("lugar", "")))
			var esp: Dictionary = reg["especies"].get(str(op.get("especie", "")), {})
			if not esp.is_empty():
				esp["n"] = clampf(float(esp["n"]) + float(op.get("delta", 0.0)), 0.0, 1.5)
			return true
	return false


# ---------------------------------------------------------------- o passo da natureza

static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var dt := dias / 7.0
	var est := estacao(u.relogio)
	var tecnica := 0.8 + 0.5 * float(Cosmos.leis(u)["tecnologia"])
	_por_lugar = {"": []}
	for e0 in u.entidades_ativas():
		if Estado.tem_mente(u, e0["id"]) and Estado.vivo(u, e0["id"]):
			var l0: String = u.estado(e0["id"])["local"]
			if not _por_lugar.has(l0):
				_por_lugar[l0] = []
			_por_lugar[l0].append(e0["id"])
	for e in u.entidades_ativas():
		var lugar: String = e["id"]
		if not tem_natureza(u, lugar) or Motor.adormecido(u, lugar):
			continue
		var reg := de(u, lugar)
		reg["tecnica"] = tecnica
		var evs := eventos_ativos(u, lugar)
		novos.append_array(_fim_dos_eventos(u, lugar))
		if _pode_ter_evento_espontaneo(u, lugar):
			novos.append_array(_evento_espontaneo(u, lugar, reg, est, rng, dias))
		_dinamica(reg, evs, est, dt, rng)
		novos.append_array(_consequencias(u, lugar, reg, evs, rng, dias))
	_por_lugar = {}
	return novos


static func estacao(data: Dictionary) -> String:
	var d := int(data.get("dia", 1))
	if d <= 90:
		return "primavera"
	if d <= 180:
		return "verão"
	if d <= 270:
		return "outono"
	return "inverno"


static func _efeitos(evs: Array, clima: String, est: String) -> Dictionary:
	var ef := {"plantas": 1.0, "decai_plantas": 0.0, "decai_cultivo": 0.0, "decai_presa": 0.0,
		"predador": 0.0, "pop": 0.0, "doenca": 0.0}
	var sazonal := {"primavera": 1.25, "verão": 1.0, "outono": 0.75, "inverno": 0.3}
	ef["plantas"] = float(sazonal[est])
	if clima.contains("frio") or clima.contains("gelad") or clima.contains("neve"):
		ef["plantas"] *= 0.75 if est != "inverno" else 0.3
	elif clima.contains("tropical") or clima.contains("quente") and not clima.contains("arid"):
		ef["plantas"] = maxf(ef["plantas"], 0.9)
	if clima.contains("arid") or clima.contains("seco") or clima.contains("desert"):
		ef["plantas"] *= 0.65
	for ev in evs:
		var f := float(ev["forca"])
		match str(ev["tipo"]):
			"seca":
				ef["plantas"] *= maxf(0.0, 1.0 - 0.85 * f)
				ef["decai_plantas"] += 0.035 * f
				ef["decai_cultivo"] += 0.05 * f
			"praga":
				ef["decai_cultivo"] += 0.09 * f
			"epidemia":
				ef["pop"] -= 0.004 * f
				ef["doenca"] += 0.05 * f
			"inverno":
				ef["plantas"] *= 0.15
				ef["decai_cultivo"] += 0.04 * f
				ef["decai_presa"] += 0.02 * f
			"enchente":
				ef["decai_cultivo"] += 0.08 * f
			"fartura":
				ef["plantas"] *= 1.0 + 0.6 * f
			"incendio":
				ef["decai_plantas"] += 0.14 * f
				ef["decai_presa"] += 0.04 * f
			"feras":
				ef["predador"] += 0.06 * f
	return ef


static func _media(reg: Dictionary, papeis: Array) -> float:
	var soma := 0.0
	var peso := 0.0
	for nome in reg["especies"]:
		var e: Dictionary = reg["especies"][nome]
		if e["papel"] in papeis:
			var w := maxf(0.05, float(e.get("peso", 1.0)))
			soma += float(e["n"]) * w
			peso += w
	return soma / peso if peso > 0 else -1.0


static func _dinamica(reg: Dictionary, evs: Array, est: String, dt: float, rng: RandomNumberGenerator) -> void:
	var ef := _efeitos(evs, str(reg.get("clima", "")), est)
	var plantas := maxf(0.0, _media(reg, ["planta", "rara"]))
	var presas := maxf(0.0, _media(reg, ["presa"]))
	var predadores := maxf(0.0, _media(reg, ["predador"]))
	var pop := float(reg["pop"])
	var fome := 1.0 - clampf(float(reg["comida"]), 0.0, 1.0)
	for nome in reg["especies"]:
		var e: Dictionary = reg["especies"][nome]
		var n := float(e["n"])
		var ruido := rng.randf_range(-0.004, 0.004)
		match str(e["papel"]):
			"planta", "rara":
				n += dt * (0.1 * ef["plantas"] * n * (1.0 - n) + 0.01 * ef["plantas"] * (1.0 - n) - ef["decai_plantas"] * n - 0.02 * presas * n * (1.0 - ef["plantas"] * 0.5) + ruido)
			"cultivo":
				var cuidado := 1.0 if pop > 0 else 0.0
				n += dt * (0.14 * ef["plantas"] * cuidado * float(reg.get("tecnica", 1.0)) * (1.0 - n) - ef["decai_cultivo"] * n - (0.015 if est == "inverno" else 0.0) * n + ruido)
			"rebanho":
				var pasto := plantas if plantas > 0 else 0.6
				n += dt * (0.03 * n * (pasto - 0.4) - 0.04 * predadores * n * float(ef["predador"] > 0.0) - fome * 0.03 * n - ef["decai_presa"] * n + ruido)
			"presa":
				var alimento := plantas if plantas > 0 else 0.7
				var caca := (0.01 + fome * 0.03) * minf(1.0, pop / 2000.0)
				n += dt * (0.06 * n * (alimento - n * 0.7) - 0.05 * predadores * n - caca * n - ef["decai_presa"] * n + ruido)
			"predador":
				n += dt * (0.05 * n * (presas - 0.45) + ef["predador"] * (1.0 - n * 0.6) - 0.006 * n + ruido)
		if n < 0.015:
			n = 0.0
		e["n"] = clampf(n, 0.0, 1.5)
	# Comida e gente.
	if pop > 0:
		var cultivo := maxf(0.0, _media(reg, ["cultivo"]))
		var rebanho := maxf(0.0, _media(reg, ["rebanho"]))
		var caca_pesca := clampf(presas * 1.2, 0.0, 1.0)
		var comida := 0.62 * cultivo + 0.23 * rebanho + 0.15 * caca_pesca
		# O que chega pelas caravanas (Economia) ajuda; o que sai pesa um pouco.
		var troca := float(reg.get("importado", 0.0)) - float(reg.get("exportado", 0.0)) * 0.3
		reg["comida"] = clampf(comida / 0.85 + troca, 0.0, 1.3)
		var taxa := float(ef["pop"])
		if reg["comida"] >= 0.9:
			taxa += 0.0004
		elif reg["comida"] < 0.55:
			taxa -= 0.007 * (0.55 - reg["comida"]) / 0.55 + 0.001
		reg["pop"] = maxf(0.0, pop * (1.0 + taxa * dt))


# ---------------------------------------------------------------- o que vira fato

static func _alerta(reg: Dictionary, nome: String) -> bool:
	return reg["alertas"].get(nome, false)


static func _fato(u: Universo, lugar: String, tipo: String, texto: String, imp: float, causas: Array, ops: Array = [], sujeitos: Array = []) -> String:
	var cs: Array = causas.filter(func(c): return c != "" and u.fatos.existe(c))
	if cs.is_empty():
		cs = [u.entidade(lugar).get("fato_criacao", "")]
		cs = cs.filter(func(c): return c != "" and u.fatos.existe(c))
	return Simulador.registrar(u, {
		"tipo": tipo, "descricao": texto, "sujeitos": [lugar] + sujeitos, "lugar": lugar, "causas": cs,
		"dados": {"importancia": imp, "natureza": true, "mudancas": ops},
	})


static func _causa_principal(evs: Array, tipos: Array) -> String:
	for ev in evs:
		if ev["tipo"] in tipos:
			return ev["fato"]
	return evs[0]["fato"] if not evs.is_empty() else ""


static var _por_lugar: Dictionary = {}  ## {lugar: [mentes]} durante um passo (rápido)


static func _mentes_em(u: Universo, lugar: String) -> Array:
	if not _por_lugar.is_empty():
		return Array(_por_lugar.get(lugar, [])).filter(func(m): return Estado.vivo(u, m) and u.estado(m)["local"] == lugar)
	var lista: Array = []
	for e in u.entidades_ativas():
		if Estado.tem_mente(u, e["id"]) and Estado.vivo(u, e["id"]) and u.estado(e["id"])["local"] == lugar:
			lista.append(e["id"])
	return lista


static func _consequencias(u: Universo, lugar: String, reg: Dictionary, evs: Array, rng: RandomNumberGenerator, dias: int) -> Array:
	var novos: Array = []
	var nome: String = u.entidade(lugar)["nome"]
	var al: Dictionary = reg["alertas"]
	var esps: Dictionary = reg["especies"]
	# Lavouras perdidas.
	if esps.has("lavouras"):
		var lav := float(esps["lavouras"]["n"])
		if lav < 0.5 and not _alerta(reg, "lavouras"):
			al["lavouras"] = true
			var tipos := evs.map(func(x): return x["tipo"])
			var como := "estão fracassando"
			if "seca" in tipos:
				como = "estão secando"
			elif "praga" in tipos:
				como = "foram tomadas pela praga"
			elif "inverno" in tipos:
				como = "se perderam na geada"
			elif "enchente" in tipos:
				como = "ficaram debaixo d'água"
			novos.append(_fato(u, lugar, "colheita perdida", "As lavouras de %s %s." % [nome, como], 0.55, [_causa_principal(evs, ["seca", "praga", "inverno", "enchente"])]))
		elif lav > 0.8 and _alerta(reg, "lavouras"):
			al.erase("lavouras")
	# Fome.
	if float(reg["pop"]) > 0:
		var comida := float(reg["comida"])
		if comida < 0.55 and not _alerta(reg, "fome"):
			al["fome"] = true
			var causa := _ultimo_fato_natural(u, lugar)
			var ops: Array = []
			for m in _mentes_em(u, lugar):
				ops.append({"op": "emocao", "quem": m, "emocao": "medo", "forca": 0.35, "alvo": ""})
				ops.append({"op": "conhecer", "quem": m})
			var fid := _fato(u, lugar, "fome", "A fome chegou a %s." % nome, 0.75, [causa, _causa_principal(evs, ["seca", "praga", "inverno", "enchente"])], ops)
			al["fome_fato"] = fid
			novos.append(fid)
		elif comida > 0.8 and _alerta(reg, "fome"):
			al.erase("fome")
			novos.append(_fato(u, lugar, "fim da fome", "A fome passou em %s." % nome, 0.4, [str(al.get("fome_fato", ""))]))
		# Quem tem medo e não tem raízes pode partir por causa da fome.
		if _alerta(reg, "fome"):
			for m in _mentes_em(u, lugar):
				var t := Personalidade.tracos(u, m)
				var chance := 0.03 * dias / 7.0 * (1.0 + float(t["prudencia"]) - float(t["coragem"]) * 0.5)
				if Estado.objetivos_ativos(u, m).is_empty() and rng.randf() < chance:
					var destino := _destino_com_comida(u, lugar)
					if destino != "":
						var nm: String = u.entidade(m)["nome"]
						novos.append(_fato(u, lugar, "migração", "%s deixou %s por causa da fome, rumo a %s%s." % [nm, nome, u.entidade(destino)["nome"], Viagens.duracao(u, lugar, destino)],
							0.4, [str(al.get("fome_fato", ""))], Viagens.ops_de_ida(u, m, lugar, destino), [m]))
		# Perda de gente.
		var ref := float(reg["pop_ref"])
		if ref > 0 and float(reg["pop"]) < ref * 0.9:
			var perdidos := roundi(ref - float(reg["pop"]))
			reg["pop_ref"] = reg["pop"]
			var motivo := "a peste" if evs.any(func(x): return x["tipo"] == "epidemia") else "a fome"
			novos.append(_fato(u, lugar, "perda de habitantes", "%s perdeu cerca de %s habitantes para %s." % [nome, Paginas._numero(perdidos), motivo], 0.6,
				[str(al.get("fome_fato", "")) if motivo == "a fome" else _causa_principal(evs, ["epidemia"])]))
		elif float(reg["pop"]) > ref * 1.15:
			reg["pop_ref"] = reg["pop"]
	# Feras famintas descendo às vilas.
	var predadores := _media(reg, ["predador"])
	var presas := _media(reg, ["presa"])
	if predadores > 0.35 and presas >= 0 and presas < 0.3 and float(reg["pop"]) > 0 and not _alerta(reg, "feras"):
		al["feras"] = true
		var quem := _maior(reg, "predador")
		var ops: Array = []
		if esps.has("rebanhos"):
			ops.append({"op": "natureza_nivel", "lugar": lugar, "especie": "rebanhos", "delta": -0.15})
		var fid := _fato(u, lugar, "feras", "%s famintos desceram até %s e atacaram os rebanhos." % [quem.capitalize(), nome], 0.55,
			[_causa_principal(evs, ["feras", "seca", "inverno", "incendio"]), _ultimo_fato_natural(u, lugar)], ops)
		novos.append(fid)
		var mentes := _mentes_em(u, lugar)
		if not mentes.is_empty() and rng.randf() < 0.3:
			var vit: String = mentes[rng.randi() % mentes.size()]
			novos.append(_fato(u, lugar, "ataque de feras", "%s foi ferido pelos %s perto de %s." % [u.entidade(vit)["nome"], quem, nome], 0.5, [fid],
				[{"op": "ferir", "quem": vit, "descricao": "mordidas de " + quem, "gravidade": 0.25}], [vit]))
	elif _alerta(reg, "feras") and (presas > 0.5 or predadores < 0.2):
		al.erase("feras")
	# Espécies que sumiram (não conta lavouras e rebanhos).
	for nome_esp in esps:
		var e: Dictionary = esps[nome_esp]
		if e["papel"] in ["cultivo", "rebanho"]:
			continue
		var chave: String = "sumiu:" + nome_esp
		if float(e["n"]) <= 0.0 and not _alerta(reg, chave):
			al[chave] = true
			novos.append(_fato(u, lugar, "espécie sumiu", "Não há mais %s nos arredores de %s." % [nome_esp, nome], 0.45,
				[_causa_principal(evs, ["seca", "incendio", "inverno"]), _ultimo_fato_natural(u, lugar)],
				[], [e["entidade"]] if e["entidade"] != "" else []))
		elif float(e["n"]) > 0.2 and _alerta(reg, chave):
			al.erase(chave)
		if e["papel"] == "rara" and float(e["n"]) > 0.85 and not _alerta(reg, "achou:" + nome_esp) and float(reg["pop"]) > 0 and rng.randf() < 0.004 * dias / 7.0:
			al["achou:" + nome_esp] = true
			novos.append(_fato(u, lugar, "descoberta", "Moradores de %s encontraram %s raras nos arredores." % [nome, nome_esp], 0.45,
				[u.entidade(lugar).get("fato_criacao", "")]))
	# Doença e terremoto atingem quem tem mente.
	for ev in evs:
		if ev["tipo"] == "epidemia":
			for m in _mentes_em(u, lugar):
				if rng.randf() < 0.04 * float(ev["forca"]) * dias / 7.0 and float(u.estado(m)["saude"]) > 0.5:
					novos.append(_fato(u, lugar, "doença", "%s adoeceu com a peste em %s." % [u.entidade(m)["nome"], nome], 0.45, [ev["fato"]],
						[{"op": "ferir", "quem": m, "descricao": "a peste", "gravidade": 0.3 * float(ev["forca"])}], [m]))
		if ev["tipo"] == "terremoto" and not ev.get("processado", false):
			ev["processado"] = true
			if float(reg["pop"]) > 0:
				reg["pop"] = float(reg["pop"]) * (1.0 - 0.02 * float(ev["forca"]))
			for m in _mentes_em(u, lugar):
				if rng.randf() < 0.25 * float(ev["forca"]):
					novos.append(_fato(u, lugar, "ferido no terremoto", "%s ficou ferido no terremoto em %s." % [u.entidade(m)["nome"], nome], 0.45, [ev["fato"]],
						[{"op": "ferir", "quem": m, "descricao": "escombros do terremoto", "gravidade": 0.2 * float(ev["forca"])}], [m]))
	return novos.filter(func(f): return f != "")


static func _maior(reg: Dictionary, papel: String) -> String:
	var melhor := ""
	var v := -1.0
	for nome in reg["especies"]:
		var e: Dictionary = reg["especies"][nome]
		if e["papel"] == papel and float(e["n"]) > v:
			v = float(e["n"])
			melhor = nome
	return melhor if melhor != "" else "feras"


## O último fato natural do lugar (para encadear causas).
static func _ultimo_fato_natural(u: Universo, lugar: String) -> String:
	var ids := u.fatos.ids_sobre(lugar)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and (f["dados"].get("natureza", false) or f["origem"].get("ref", "") == "intervir"):
			return f["id"]
	return ""


## Outro povoado próximo onde não há fome.
static func _destino_com_comida(u: Universo, lugar: String) -> String:
	var melhor := ""
	var melhor_d := 999999
	for e in u.entidades_ativas():
		var outro: String = e["id"]
		if outro == lugar or Mapa.especie(u, outro) != "povoado":
			continue
		var reg := de(u, outro)
		if float(reg["comida"]) < 0.8 or eventos_ativos(u, outro).any(func(x): return x["tipo"] in ["seca", "praga", "epidemia"]):
			continue
		var d := u.dias_de_viagem(lugar, outro)
		if d < 0:
			d = 500
		if d < melhor_d:
			melhor_d = d
			melhor = outro
	return melhor


static func _fim_dos_eventos(u: Universo, lugar: String) -> Array:
	var novos: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for ev in u.estado(lugar).get("eventos_naturais", []):
		if ev.get("fim", false) or int(ev["ate"]) >= agora:
			continue
		var nome_ev: String = EVENTOS.get(ev["tipo"], {}).get("nome", ev["tipo"])
		var fid := _fato(u, lugar, "fim de " + nome_ev, "Terminou a %s em %s." % [nome_ev, u.entidade(lugar)["nome"]] if not nome_ev in ["inverno rigoroso", "terremoto", "incêndio"] else "Terminou o %s em %s." % [nome_ev, u.entidade(lugar)["nome"]],
			0.35, [ev["fato"]], [{"op": "fim_evento", "lugar": lugar, "evento": ev["fato"]}])
		if fid == "":
			ev["fim"] = true
		novos.append(fid)
	return novos.filter(func(f): return f != "")


## Acontecimentos espontâneos só nas regiões (ou em lugares soltos, sem região acima).
static func _pode_ter_evento_espontaneo(u: Universo, lugar: String) -> bool:
	var esp := Mapa.especie(u, lugar)
	if esp == "regiao":
		return true
	for a in Mapa.ancestrais(u, lugar):
		if Mapa.especie(u, a) == "regiao":
			return false
	return esp == "povoado" or esp == "natural"


static func _evento_espontaneo(u: Universo, lugar: String, reg: Dictionary, est: String, rng: RandomNumberGenerator, dias: int) -> Array:
	if not eventos_ativos(u, lugar).is_empty():
		return []
	var clima := str(reg.get("clima", ""))
	var fator := dias / 7.0
	var chances := {
		"seca": (0.0014 if est == "verão" else 0.0004) * (2.5 if clima.contains("arid") or clima.contains("seco") else 1.0),
		"inverno": (0.004 if est == "inverno" else 0.0) * (2.0 if clima.contains("frio") else 0.6 if clima.contains("tropical") or clima.contains("quente") else 1.0),
		"praga": 0.0008 if est in ["primavera", "verão"] else 0.0,
		"enchente": 0.0006 if est in ["primavera", "outono"] else 0.0002,
		"epidemia": 0.00025,
		"fartura": 0.0009 if est in ["primavera", "verão"] else 0.0,
	}
	for tipo in chances:
		if rng.randf() < float(chances[tipo]) * fator * Diretor.fator(u, tipo):
			var forca := rng.randf_range(0.7, 1.3)
			var nome_ev: String = EVENTOS[tipo]["nome"]
			var artigo := "um" if tipo in ["inverno"] else "uma"
			var texto := "%s %s começou em %s." % [artigo.capitalize(), nome_ev, u.entidade(lugar)["nome"]]
			if tipo == "fartura":
				texto = "Um tempo de fartura começou em %s." % u.entidade(lugar)["nome"]
			var fid := _fato(u, lugar, nome_ev, texto, 0.6, [u.entidade(lugar).get("fato_criacao", "")],
				[{"op": "evento_natural", "lugar": lugar, "tipo": tipo, "forca": forca, "ate": DataMundo.ordem(u.relogio) + int(EVENTOS[tipo]["dias"] * rng.randf_range(0.7, 1.3))}])
			return [fid] if fid != "" else []
	return []


# ---------------------------------------------------------------- para as páginas

## Nível de uma espécie: quanto existe perto do que a terra comporta (100%).
static func palavra_nivel(n: float) -> String:
	if n <= 0.0:
		return "sumiu"
	return "%d%%" % maxi(1, roundi(n * 100))


static func palavra_comida(c: float) -> String:
	if c < 0.55:
		return "fome"
	if c < 0.8:
		return "comida contada"
	if c < 1.05:
		return "comida suficiente"
	return "fartura"
