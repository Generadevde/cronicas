class_name Autor
extends RefCounted
## O Autor e o Arauto. Você pode existir no mundo como uma força cósmica — "o Autor",
## com o nome que quiser —, fora do mapa, sem envelhecer nem morrer. Qualquer
## personagem com a marca "conhece o Autor" é o seu arauto. O que você revela a ele
## vira fato de origem autor (visão, ordem, profecia), e ele reage com a própria mente:
## obedece, duvida, espalha ou esconde. O mundo fica sabendo pelas notícias, com
## atraso. O arauto só sabe o que você revela. Dá para fazer pactos com o Autor
## como com qualquer força (escreva "o que oferece" e "o que cobra" na ficha dele).

const MARCA := "conhece o Autor"


static func entidade(u: Universo) -> String:
	for e in u.entidades_ativas():
		if TextUtil.normalizar(e["tipo"]) == "autor" or u.estado(e["id"]).get("eh_autor", false):
			return e["id"]
	return ""


## Passa a existir no mundo. Devolve o id (o mesmo, se já existir).
static func existir(u: Universo, nome: String = "o Autor") -> String:
	var a := entidade(u)
	if a != "":
		return a
	a = u.criar_entidade(nome.strip_edges() if nome.strip_edges() != "" else "o Autor", "autor", [], [
		{"chave": "natureza", "valor": "força cósmica, fora do mapa, não envelhece nem morre"},
		{"chave": "o que oferece", "valor": ""},
		{"chave": "o que cobra", "valor": ""}])
	u.definir_tem_mente(a, false)
	return a


static func eh_arauto(u: Universo, eid: String) -> bool:
	for m in Pecas.marcas(u, eid):
		var n := TextUtil.normalizar(str(m))
		if n.contains("conhece o autor") or n.begins_with("arauto"):
			return true
	return false


static func arautos(u: Universo) -> Array:
	return u.entidades_ativas().filter(func(e): return Estado.tem_mente(u, e["id"]) and eh_arauto(u, e["id"])).map(func(e): return e["id"])


static func tornar_arauto(u: Universo, eid: String) -> String:
	var a := existir(u)
	return Simulador.registrar(u, {"tipo": "arauto", "descricao": "%s passou a conhecer %s." % [u.entidade(eid)["nome"], u.entidade(a)["nome"]],
		"sujeitos": [eid, a], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "autor"},
		"dados": {"importancia": 0.6, "secreto": true, "mudancas": [{"op": "marca", "quem": eid, "marca": MARCA}, {"op": "conhecer", "quem": eid}]}})


const TIPOS := {"visao": "uma visão", "ordem": "uma ordem", "profecia": "uma profecia"}


## Revela algo ao arauto. tipo: visao, ordem, profecia. Devolve o id do fato.
static func revelar(u: Universo, arauto: String, texto: String, tipo: String = "visao") -> String:
	var a := existir(u)
	if not eh_arauto(u, arauto):
		tornar_arauto(u, arauto)
	var emocao := "medo" if tipo == "ordem" else "esperanca"
	return Simulador.registrar(u, {"tipo": "revelação", "sujeitos": [arauto, a], "lugar": u.estado(arauto).get("local", ""),
		"descricao": "%s revelou a %s %s: “%s”" % [u.entidade(a)["nome"], u.entidade(arauto)["nome"], TIPOS.get(tipo, "algo"), texto.strip_edges()],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "autor"},
		"dados": {"importancia": 0.7, "secreto": true, "revelacao": {"tipo": tipo, "texto": texto.strip_edges()},
			"mudancas": [{"op": "conhecer", "quem": arauto}, {"op": "emocao", "quem": arauto, "emocao": emocao, "forca": 0.5, "alvo": a}]}})


## No passo: cada revelação nova recebe a reação do arauto (uma semana depois).
static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var a := entidade(u)
	if a == "":
		return []
	var feitas: Dictionary = u.extra("revelacoes", {})
	var novos: Array = []
	for fid in u.fatos.ids_sobre(a):
		var f := u.fatos.obter(fid)
		if not f["canon"] or not f["dados"].has("revelacao") or feitas.has(fid):
			continue
		if DataMundo.ordem(u.relogio) - DataMundo.ordem(f["data"]) < 7:
			continue
		feitas[fid] = true
		var arauto: String = f["sujeitos"][0]
		if not Estado.vivo(u, arauto) or Motor.dormindo(u, arauto):
			continue
		novos.append(reagir(u, arauto, f, rng))
	return novos.filter(func(x): return x != "")


## A mente do arauto decide: obedece, duvida, espalha ou esconde.
static func reagir(u: Universo, arauto: String, f: Dictionary, rng: RandomNumberGenerator) -> String:
	var t := Personalidade.tracos(u, arauto)
	var rv: Dictionary = f["dados"]["revelacao"]
	var lugar := str(u.estado(arauto).get("local", ""))
	# Quem viu o Autor crê mais do que o resto do povo.
	var fe := maxf(0.6, float(Humor.de(u, lugar)["fe"]) if lugar != "" else 0.3)
	var n: String = u.entidade(arauto)["nome"]
	var a: String = u.entidade(entidade(u))["nome"]
	var ops: Array = []
	var texto := ""
	var secreto := true
	var imp := 0.5
	if rv["tipo"] == "ordem":
		var obedece := 0.45 * float(t["lealdade"]) + 0.35 * fe + 0.25 * (1.0 - float(t["orgulho"])) + rng.randf_range(-0.1, 0.1)
		if obedece > 0.45:
			var cumprir := _ordem(u, arauto, str(rv["texto"]))
			ops.append_array(cumprir["ops"])
			texto = "%s obedeceu a %s%s." % [n, a, cumprir["texto"]]
			secreto = false
			imp = 0.65
		else:
			texto = "%s duvidou da ordem de %s e não a cumpriu." % [n, a]
			ops.append({"op": "emocao", "quem": arauto, "emocao": "culpa", "forca": 0.3, "alvo": ""})
	else:
		var espalha := 0.45 * float(t["sociabilidade"]) + 0.3 * fe + 0.2 * float(t["impulsividade"]) - 0.25 * float(t["prudencia"]) + rng.randf_range(-0.1, 0.1)
		var duvida := 0.4 * (1.0 - fe) + 0.3 * float(t["orgulho"]) - 0.3 * float(t["curiosidade"])
		if duvida > 0.45:
			texto = "%s duvidou %s de %s." % [n, "da visão" if rv["tipo"] == "visao" else "da profecia", a]
		elif espalha > 0.3:
			texto = "%s espalhou %s em %s: “%s”" % [n, "a visão" if rv["tipo"] == "visao" else "a profecia", u.entidade(lugar).get("nome", "toda parte"), rv["texto"]]
			secreto = false
			imp = 0.7 if rv["tipo"] == "profecia" else 0.6
			ops.append({"op": "mudar", "quem": arauto, "chave": "reputacao", "delta": 0.3})
			ops.append({"op": "marca", "quem": arauto, "marca": "profeta"})
			if lugar != "":
				var h := Humor.de(u, lugar)
				h["fe"] = clampf(float(h["fe"]) + 0.12, 0.0, 1.0)
		else:
			texto = "%s guardou %s em segredo." % [n, "a visão" if rv["tipo"] == "visao" else "a profecia"]
	return Simulador.registrar(u, {"tipo": "reação do arauto", "descricao": texto, "sujeitos": [arauto], "lugar": lugar, "causas": [f["id"]],
		"dados": {"importancia": imp, "secreto": secreto, "mudancas": ops}})


## Cumprir uma ordem: "vá para Varn", "mate Kai", "proteja Lia", ou qualquer efeito escrito.
static func _ordem(u: Universo, eid: String, texto: String) -> Dictionary:
	var n := " " + TextUtil.normalizar(texto) + " "
	var mencoes := Ligador.new(u).encontrar(texto)
	var pessoa := ""
	var lugar := ""
	for m in mencoes:
		if Mapa.e_lugar(u, m["entidade"]):
			lugar = m["entidade"] if lugar == "" else lugar
		elif pessoa == "" and m["entidade"] != eid:
			pessoa = m["entidade"]
	if lugar != "" and (n.contains(" va ") or n.contains(" vai ") or n.contains(" ir ") or n.contains(" parta ") or n.contains(" siga ") or n.contains(" viaje ")):
		var ops := Viagens.ops_de_ida(u, eid, str(u.estado(eid).get("local", "")), lugar)
		return {"ops": ops, "texto": " e partiu para %s" % u.entidade(lugar)["nome"]}
	if pessoa != "" and (n.contains(" mate ") or n.contains(" matar ") or n.contains(" destrua ") or n.contains(" derrube ")):
		return {"ops": [{"op": "objetivo", "quem": eid, "tipo": "vingança", "alvo": pessoa, "forca": 0.9}], "texto": " e jurou derrubar %s" % u.entidade(pessoa)["nome"]}
	if pessoa != "" and (n.contains(" proteja ") or n.contains(" proteger ") or n.contains(" salve ") or n.contains(" guarde ")):
		return {"ops": [{"op": "objetivo", "quem": eid, "tipo": "afeto", "alvo": pessoa, "forca": 0.8},
			{"op": "relacao", "de": eid, "para": pessoa, "deltas": {"afeto": 0.3}}], "texto": " e passou a proteger %s" % u.entidade(pessoa)["nome"]}
	var ops2: Array = []
	for e in Pecas.ler(u, texto):
		ops2.append_array(Pecas.operacoes(u, e, {"sujeito": eid, "outro": pessoa, "lugar": str(u.estado(eid).get("local", ""))}))
	return {"ops": ops2, "texto": ": " + texto.strip_edges().trim_suffix(".")}
