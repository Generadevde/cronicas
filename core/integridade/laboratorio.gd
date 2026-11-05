class_name Laboratorio
extends RefCounted
## Laboratório de possibilidades: testar futuros diferentes a partir de um mesmo
## momento, sem perder a história original. Você abre ramos (cópias do universo),
## faz em cada um uma mudança (o príncipe assume, o general dá um golpe, um conselheiro
## faz um pacto), deixa cada ramo avançar sozinho e compara os futuros lado a lado:
## quem governa, quem morreu, que guerras começaram, que lendas surgiram. Quando gostar
## de um, ele vira o canon; os outros ficam guardados como possibilidades.
## Ramos nunca contaminam o canon até você decidir.
##
## Versões do universo: fotos do mundo em momentos importantes, para voltar atrás.


## Abre um ramo: uma cópia do universo, guardada à parte (não mexe no canon).
static func abrir_ramo(u: Universo, nome: String) -> Universo:
	var r := Universo.de_dicionario(u.para_dicionario().duplicate(true))
	r.id = Ids.novo("uni")
	r.nome = "%s — %s" % [u.nome, nome]
	var raiz: String = u.extras.get("ramo", {}).get("raiz", u.id)
	r.extras["ramo"] = {"nome": nome, "pai": u.id, "raiz": raiz, "desde": DataMundo.ordem(u.relogio), "fatos_no_ponto": u.fatos.quantidade()}
	return r


## Uma mudança escrita no ramo ("o príncipe Edric assume o trono", "o general Varga dá
## um golpe", "o conselheiro Tobias faz um pacto com a Mãe das Cinzas", "o rei morre").
## Devolve o que o ramo entendeu.
static func mudar(r: Universo, texto: String) -> String:
	var n := " " + TextUtil.normalizar(texto) + " "
	var m: Array = Ligador.new(r).encontrar(texto).map(func(x): return x["entidade"])
	var pessoas: Array = m.filter(func(x): return Estado.tem_mente(r, x))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(texto + r.id)
	var autor := {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "laboratorio"}
	if pessoas.is_empty():
		return "Não achei ninguém no texto."
	var p: String = pessoas[0]
	var sid := ""
	for s in Sociedades.todas(r):
		if m.has(s):
			sid = s
	if sid == "":
		sid = Sociedades.de_lugar(r, str(r.estado(p).get("local", "")))
	if n.contains(" golpe "):
		var l := Sociedades.lider(r, sid)
		var fs := Sociedades.golpe(r, sid, p, l, rng)
		return "Golpe: " + (r.fatos.obter(fs[0])["descricao"] if not fs.is_empty() else "não aconteceu")
	if n.contains(" pacto "):
		var ser := ""
		for x in m:
			if Pactos.ofertantes(r).has(x):
				ser = x
		if ser == "":
			return "Não achei com quem é o pacto (a entidade precisa ter \"o que oferece\")."
		var d := {"tipo": "poder", "alvo": sid, "texto": "o poder em %s" % r.entidade(sid).get("nome", "?"), "desespero": 1.0}
		var fid := Pactos.fazer(r, ser, p, d, "", true, [], true)
		Simulador.registrar(r, {"tipo": "sucessão", "descricao": "Com a ajuda de %s, %s passou a governar %s." % [r.entidade(ser)["nome"], r.entidade(p)["nome"], r.entidade(sid)["nome"]],
			"sujeitos": [sid, p], "causas": [fid], "dados": {"importancia": 0.8, "mudancas": [{"op": "definir", "quem": sid, "chave": "lider", "valor": p}, {"op": "definir", "quem": sid, "chave": "sem_governante", "valor": false}]}})
		return "Pacto: %s fez um pacto com %s e tomou o poder." % [r.entidade(p)["nome"], r.entidade(ser)["nome"]]
	if n.contains(" morre ") or n.contains(" morreu "):
		Simulador.registrar(r, {"tipo": "morte", "descricao": "%s morreu." % r.entidade(p)["nome"], "sujeitos": [p], "origem": autor,
			"dados": {"acao": "morte", "importancia": 0.9, "mudancas": [{"op": "morrer", "quem": p}]}})
		return "%s morreu." % r.entidade(p)["nome"]
	if (n.contains(" assume ") or n.contains(" governa") or n.contains(" trono ") or n.contains(" coroad")) and sid != "":
		Simulador.registrar(r, {"tipo": "sucessão", "descricao": "%s assumiu o governo de %s." % [r.entidade(p)["nome"], r.entidade(sid)["nome"]], "sujeitos": [sid, p], "origem": autor,
			"dados": {"importancia": 0.8, "mudancas": [{"op": "definir", "quem": sid, "chave": "lider", "valor": p}, {"op": "definir", "quem": sid, "chave": "sem_governante", "valor": false}]}})
		return "%s assumiu o governo." % r.entidade(p)["nome"]
	var lugar := str(r.estado(p).get("local", ""))
	if lugar != "":
		Natureza.intervir(r, lugar, texto)
		return "Registrado em %s." % r.entidade(lugar)["nome"]
	return "Não entendi a mudança."


static func eh_ramo(u: Universo) -> bool:
	return u.extras.has("ramo")


## Compara ramos: para cada um, quem governa cada sociedade, quem morreu (dos que
## estavam vivos no ponto de separação), guerras começadas, títulos e lendas.
static func comparar(ramos: Array) -> Array:
	var tabela: Array = []
	for r in ramos:
		var u: Universo = r
		var desde := int(u.extras.get("ramo", {}).get("fatos_no_ponto", 0))
		var linha := {"nome": str(u.extras.get("ramo", {}).get("nome", u.nome)), "data": DataMundo.texto(u.relogio), "governos": {}, "mortos": [], "guerras": [], "lendas": [], "fatos": 0}
		for sid in Sociedades.todas(u):
			var l := Sociedades.lider(u, sid)
			linha["governos"][u.entidade(sid)["nome"]] = "%s (%s)" % [u.entidade(l).get("nome", "ninguém") if l != "" else "ninguém", Sociedades.NOMES_TIPO.get(Sociedades.tipo(u, sid), "?")]
		for f in u.fatos.todos():
			if int(f["seq"]) <= desde or not f["canon"]:
				continue
			linha["fatos"] = int(linha["fatos"]) + 1
			match str(f["tipo"]):
				"morte", "morte natural", "luta":
					for s in f["sujeitos"]:
						if u.entidades.has(s) and not Estado.vivo(u, s) and Estado.tem_mente(u, s) and not linha["mortos"].has(u.entidade(s)["nome"]):
							linha["mortos"].append(u.entidade(s)["nome"])
				"declaração de guerra":
					linha["guerras"].append(f["descricao"])
				"título", "culto", "legado", "religião nova":
					linha["lendas"].append(f["descricao"])
		for e in u.entidades_ativas():
			if Estado.tem_mente(u, e["id"]) and not Estado.vivo(u, e["id"]) and not linha["mortos"].has(e["nome"]):
				var m: Dictionary = u.estado(e["id"]).get("morte", {})
				var fm := u.fatos.obter(str(m.get("fato", "")))
				if not fm.is_empty() and int(fm["seq"]) > desde:
					linha["mortos"].append(e["nome"])
		tabela.append(linha)
	return tabela


## O ramo vira o canon: o universo do canon passa a ter a história do ramo (com o
## mesmo id), e a história antiga fica guardada como uma possibilidade (uma versão).
static func tornar_canon(canon: Universo, ramo: Universo, biblioteca: Biblioteca = null) -> Universo:
	if biblioteca != null:
		Versoes.salvar(biblioteca, canon, "antes de escolher o ramo \"%s\"" % ramo.extras.get("ramo", {}).get("nome", "?"))
	var d := ramo.para_dicionario().duplicate(true)
	d["id"] = canon.id
	d["nome"] = canon.nome
	var novo := Universo.de_dicionario(d)
	novo.extras.erase("ramo")
	var hist: Array = novo.extras.get("ramos_escolhidos", [])
	hist.append({"nome": ramo.extras.get("ramo", {}).get("nome", "?"), "quando": DataMundo.texto(ramo.relogio)})
	novo.extras["ramos_escolhidos"] = hist
	if biblioteca != null:
		biblioteca.salvar(novo)
	return novo


## Traz um personagem (com a ficha) de um ramo para outro, como criação do autor.
static func trazer_entidade(de: Universo, para: Universo, eid: String) -> String:
	var e := de.entidade(eid)
	if e.is_empty():
		return ""
	if para.entidades.has(eid):
		return eid
	var novo := para.criar_entidade(e["nome"], e["tipo"], e["apelidos"], e["campos"].duplicate(true))
	para.fatos.registrar({"tipo": "vindo de outro ramo", "descricao": "%s veio de outra possibilidade (%s)." % [e["nome"], de.extras.get("ramo", {}).get("nome", de.nome)],
		"sujeitos": [novo], "data": DataMundo.copiar(para.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "laboratorio"}, "dados": {"importancia": 0.4}})
	return novo


## Traz um acontecimento (o que diz, não o que mudou) de um ramo para outro, como nota do autor.
static func trazer_fato(de: Universo, para: Universo, fid: String) -> String:
	var f := de.fatos.obter(fid)
	if f.is_empty():
		return ""
	return para.fatos.registrar({"tipo": "eco de outro ramo", "descricao": "Em outra possibilidade: %s" % f["descricao"], "sujeitos": f["sujeitos"].filter(func(s): return para.entidades.has(s)),
		"data": DataMundo.copiar(para.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "laboratorio"}, "dados": {"importancia": 0.3}})
