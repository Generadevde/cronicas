class_name Consequencias
extends RefCounted
## O que o autor escreve de forma livre e que precisa ter consequência de verdade:
## desastres num lugar (gente morre, se fere, tem medo; a comida encurta), coisas
## destruídas, tronos que mudam de dono, gente que adoece ou se cura.
## Tudo vira fato com a frase como causa (dá para desfazer) e é contado em palavras.

## palavra-chave → [nome, mortos, feridos, comida] (frações de quem está no lugar, no caso "médio").
const DESASTRES := {
	"enchente": ["enchente", 0.02, 0.06, -15.0], "inundac": ["inundação", 0.02, 0.06, -15.0], "transbord": ["enchente", 0.01, 0.04, -10.0],
	"seca": ["seca", 0.0, 0.0, -30.0], "estiagem": ["seca", 0.0, 0.0, -30.0],
	"incendio": ["incêndio", 0.03, 0.1, -10.0], "pegou fogo": ["incêndio", 0.03, 0.1, -10.0], "em chamas": ["incêndio", 0.03, 0.1, -10.0],
	"terremoto": ["terremoto", 0.04, 0.12, -5.0], "tremor": ["terremoto", 0.01, 0.05, 0.0],
	"peste": ["peste", 0.08, 0.2, 0.0], "praga": ["praga", 0.03, 0.08, -25.0], "epidemia": ["epidemia", 0.06, 0.2, 0.0], "doenca": ["doença", 0.02, 0.12, 0.0],
	"fome": ["fome", 0.04, 0.1, -30.0],
	"nevasca": ["nevasca", 0.01, 0.05, -12.0], "geada": ["geada", 0.0, 0.01, -15.0], "onda de frio": ["onda de frio", 0.01, 0.04, -8.0],
	"onda de calor": ["onda de calor", 0.01, 0.04, -8.0],
	"tempestade": ["tempestade", 0.01, 0.04, -5.0], "furacao": ["furacão", 0.03, 0.1, -12.0], "tornado": ["tornado", 0.03, 0.1, -8.0],
	"erupcao": ["erupção", 0.05, 0.12, -15.0], "vulcao": ["erupção", 0.03, 0.08, -10.0], "avalanche": ["avalanche", 0.02, 0.05, 0.0],
	"deslizamento": ["deslizamento", 0.02, 0.05, 0.0], "tsunami": ["tsunami", 0.08, 0.15, -15.0], "maremoto": ["maremoto", 0.08, 0.15, -15.0],
}
const FORTE := ["terrivel", "devastador", "arrasou", "destruiu a cidade", "destruiu a vila", "catastrof", "a pior", "o pior", "imens", "enorme", "violent", "matou", "dizimou"]
const FRACO := ["leve", "pequen", "fraca", "fraco", "parte d", "esta se aproximando", "se aproxima", "ameaca", "comecou a"]
const DESTRUIR := ["destruiu", "destruida", "destruido", "destruidas", "destruidos", "derrubou", "derrubada", "derrubado", "desabou", "ruiu", "caiu", "queimou", "queimada",
	"queimado", "incendiou", "arrasou", "arrasada", "arrasado", "demoliu", "demolida", "demolido", "foi abaixo", "em ruinas", "afundou"]
const TRONO := ["tomou o trono", "assumiu o trono", "subiu ao trono", "foi coroado", "foi coroada", "tornou-se rei", "tornou-se rainha", "tornou-se imperador",
	"tornou-se imperatriz", "virou rei", "virou rainha", "virou imperador", "tomou o poder", "assumiu o poder", "usurpou"]
const ADOECER := ["adoeceu", "ficou doente", "caiu doente", "foi ferido", "foi ferida", "ficou ferido", "ficou ferida", "se feriu", "esta doente", "esta ferido", "esta ferida"]
const CURAR := ["se recuperou", "recuperou-se", "se curou", "curou-se", "sarou", "foi curado", "foi curada", "melhorou"]


static func _tem(n: String, lista: Array) -> bool:
	for w in lista:
		if n.contains(" " + str(w)):
			return true
	return false


static func _nomes(u: Universo, original: String, so_pessoas: bool) -> Array:
	var r: Array = []
	for m in Ligador.new(u).encontrar(original):
		var e: Dictionary = u.entidade(str(m["entidade"]))
		if not e.is_empty() and (e["tipo"] == "pessoa") == so_pessoas and not r.has(e["id"]):
			r.append(e["id"])
	return r


static func _quantos(n: int) -> String:
	if n <= 0:
		return "ninguém"
	if n == 1:
		return "uma pessoa"
	if n <= 3:
		return "algumas pessoas"
	if n <= 10:
		return "várias pessoas"
	return "muita gente"


## Tenta dar consequência à frase. Devolve o item da margem ({} se a frase não é disso).
static func ler(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var r := _pessoa_doente(u, original, n, raiz, foco)
	if r.is_empty():
		r = _trono(u, original, n, raiz, foco)
	if r.is_empty():
		r = _destruir(u, original, n, raiz, foco)
	if r.is_empty():
		r = _desastre(u, original, n, raiz, foco)
	return r


static func _fato(u: Universo, tipo: String, original: String, sujeitos: Array, lugar: String, raiz: String, imp: float, ops: Array) -> String:
	return Simulador.registrar(u, {"tipo": tipo, "descricao": original, "sujeitos": sujeitos, "lugar": lugar, "causas": [raiz],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": imp, "mudancas": ops}})


static func _desastre(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var d: Array = []
	for k in DESASTRES:
		if n.contains(" " + k):
			d = DESASTRES[k]
			break
	if d.is_empty() or foco == "":
		return {}
	var grau := 1.0
	if _tem(n, FORTE):
		grau = 2.5
	elif _tem(n, FRACO):
		grau = 0.3
	var rng := Povoador._rng(u, "desastre:" + original)
	var gente: Array = Ameacas._pessoas(u, foco)
	# Quem o autor escreveu pelo nome não morre por acaso: isso é decisão dele.
	var povo: Array = gente.filter(func(p): return u.valor_campo(p, "descrição") == "")
	var ops: Array = []
	var mortos := int(roundf(povo.size() * float(d[1]) * grau))
	var feridos := int(roundf(povo.size() * float(d[2]) * grau))
	if grau > 2.0 and float(d[1]) > 0.0:
		mortos = maxi(mortos, 1)
	for i in mini(mortos + feridos, povo.size()):
		var j := rng.randi_range(i, povo.size() - 1)
		var t = povo[i]
		povo[i] = povo[j]
		povo[j] = t
		if i < mortos:
			ops.append({"op": "morrer", "quem": povo[i]})
		else:
			ops.append({"op": "ferir", "quem": povo[i], "descricao": "ferido na " + str(d[0]) if not str(d[0]) in ["peste", "epidemia", "doença", "praga", "fome"] else "doente (" + str(d[0]) + ")", "gravidade": 0.25 * minf(grau, 2.0)})
	for p in gente:
		if not ops.any(func(o): return o["quem"] == p and o["op"] == "morrer"):
			ops.append({"op": "emocao", "quem": p, "emocao": "medo", "forca": clampf(0.3 * grau, 0.15, 0.9), "alvo": ""})
	var comida := false
	if float(d[3]) < 0.0:
		for nome in Recursos.de(u, foco):
			ops.append({"op": "recurso_delta", "quem": foco, "nome": nome, "delta": float(d[3]) * grau, "alerta": str(d[0])})
			comida = true
	var fid := _fato(u, "desastre", original, [foco], foco, raiz, clampf(0.45 + 0.15 * grau, 0.4, 0.9), ops)
	var partes: Array = []
	if mortos > 0:
		partes.append("%s morreu" % _quantos(mortos) if mortos == 1 else "%s morreram" % _quantos(mortos))
	if feridos > 0:
		partes.append("%s ficou mal" % _quantos(feridos) if feridos == 1 else "%s ficaram mal" % _quantos(feridos))
	if comida:
		partes.append("as reservas encurtaram")
	if not gente.is_empty():
		partes.append("o povo ficou com medo")
	var lugar_nome := str(u.entidade(foco)["nome"])
	return {"tipo": "consequencia", "texto": "%s em %s: %s." % [str(d[0]).substr(0, 1).to_upper() + str(d[0]).substr(1), lugar_nome, ", ".join(partes) if not partes.is_empty() else "ninguém vivia ali para sofrer"], "id": fid}


## "A ponte caiu", "o incêndio destruiu o mercado": a coisa fica em ruínas (ou danificada).
static func _destruir(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	if not _tem(n, DESTRUIR):
		return {}
	var alvo := ""
	for eid in _nomes(u, original, false):
		if eid != foco and Mapa.especie(u, eid) != "planeta":
			alvo = eid
			break
	if alvo == "":
		# Pelo tipo: "a ponte", "o mercado". Primeiro o que fica no lugar em cena; se só existe um, é ele.
		var todos: Array = []
		var daqui: Array = []
		var foco_nome := str(u.entidade(foco).get("nome", "")) if foco != "" else ""
		for e in u.entidades_ativas():
			if e["tipo"] == "pessoa" or e["id"] == foco:
				continue
			var tipo := TextUtil.normalizar(str(e["tipo"]))
			if tipo.length() < 4 or not n.contains(" " + tipo + " "):
				continue
			todos.append(e["id"])
			if foco != "" and (Mapa.pai(u, e["id"]) == foco or u.valor_campo(e["id"], "fica em") == foco_nome):
				daqui.append(e["id"])
		if not daqui.is_empty():
			alvo = daqui[0]
		elif todos.size() == 1:
			alvo = todos[0]
	if alvo == "":
		return {}
	var parte := n.contains(" parte d") or n.contains(" metade d")
	var condicao := "danificado" if parte else "em ruínas"
	var fid := _fato(u, "destruição", original, [alvo], foco, raiz, 0.6, [{"op": "definir", "quem": alvo, "chave": "condicao", "valor": condicao}])
	return {"tipo": "consequencia", "texto": "%s agora está %s." % [str(u.entidade(alvo)["nome"]), condicao], "id": fid}


## "Bren tomou o trono": o cargo muda de dono; quem governava vira "antigo".
static func _trono(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	if not _tem(n, TRONO) or foco == "":
		return {}
	var quem: Array = _nomes(u, original, true)
	if quem.is_empty():
		return {}
	var novo: String = quem[0]
	var lugar_nome := str(u.entidade(foco)["nome"])
	var titulo := "governante"
	for t in ["imperatriz", "imperador", "rainha", "rei"]:
		if n.contains(" " + t):
			titulo = t
			break
	var antigo := ""
	for e in u.entidades_ativas():
		if e["tipo"] == "pessoa" and e["id"] != novo and TextUtil.normalizar(u.valor_campo(e["id"], "cargo")).ends_with(" de " + TextUtil.normalizar(lugar_nome)):
			antigo = e["id"]
	_cargo(u, novo, "%s de %s" % [titulo, lugar_nome])
	var ops: Array = []
	if antigo != "":
		_cargo(u, antigo, "antigo " + u.valor_campo(antigo, "cargo"))
		if Estado.vivo(u, antigo):
			ops.append({"op": "emocao", "quem": antigo, "emocao": "raiva", "forca": 0.8, "alvo": novo})
			ops.append({"op": "objetivo", "quem": antigo, "tipo": "vingar", "alvo": novo, "forca": 0.7})
	var cl: Array = u.entidade(foco)["campos"].filter(func(c): return c["chave"] != "quem governa")
	cl.append({"chave": "quem governa", "valor": str(u.entidade(novo)["nome"])})
	u.editar_entidade(foco, {"campos": cl})
	var fid := _fato(u, "sucessão", original, [novo, foco] + ([antigo] if antigo != "" else []), foco, raiz, 0.8, ops)
	var t2 := "%s agora governa %s." % [str(u.entidade(novo)["nome"]), lugar_nome]
	if antigo != "":
		t2 += " %s perdeu o cargo%s." % [str(u.entidade(antigo)["nome"]), " e não vai esquecer" if Estado.vivo(u, antigo) else ""]
	return {"tipo": "consequencia", "texto": t2, "id": fid}


static func _cargo(u: Universo, eid: String, cargo: String) -> void:
	var cs: Array = u.entidade(eid)["campos"].filter(func(c): return c["chave"] != "cargo")
	cs.append({"chave": "cargo", "valor": cargo})
	u.editar_entidade(eid, {"campos": cs})


## "Kai adoeceu", "John foi ferido", "Kai se recuperou".
static func _pessoa_doente(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var curou := _tem(n, CURAR)
	if not curou and not _tem(n, ADOECER):
		return {}
	var quem: Array = _nomes(u, original, true)
	if quem.is_empty():
		return {}
	var p: String = quem[0]
	var nome := str(u.entidade(p)["nome"])
	if curou:
		var fid := _fato(u, "cura", original, [p], foco, raiz, 0.4, [{"op": "curar", "quem": p, "quanto": 1.0}])
		return {"tipo": "consequencia", "texto": "%s está bem de novo." % nome, "id": fid}
	var grave := _tem(n, ["grave", "muito", "quase morr", "a beira da morte", "mortal"])
	var doente := n.contains(" doente") or n.contains(" adoeceu")
	var fid2 := _fato(u, "ferimento", original, [p], foco, raiz, 0.6 if grave else 0.45,
		[{"op": "ferir", "quem": p, "descricao": "doente" if doente else "ferido", "gravidade": 0.75 if grave else 0.3}])
	return {"tipo": "consequencia", "texto": "%s está %s%s." % [nome, "doente" if doente else "ferido", " e corre perigo" if grave else ""], "id": fid2}
