class_name Povoador
extends RefCounted
## Gera o que o autor não quer fazer à mão: planetas, regiões, cidades, famílias,
## facções e figuras históricas, coerentes com o terreno, as línguas e as eras.
## Cada geração é um fato do autor ("O autor povoou X") que guarda o que criou,
## para revisar e desfazer (as entidades ficam marcadas como retiradas, nada some).
## Também cria lugares a partir do que o autor escreve no mapa.

const CLIMAS := ["temperado", "frio", "quente e úmido", "árido", "temperado e chuvoso"]
const LUAS := ["uma lua pálida", "duas luas, uma prateada e outra cor de cobre", "nenhuma lua", "três luas pequenas", "uma lua enorme e avermelhada"]
const DIAS := ["dias de 24 horas", "dias longos, de 30 horas", "dias curtos, de 20 horas"]
const GRAVIDADES := ["como a nossa", "um pouco mais leve que a nossa", "um pouco mais pesada que a nossa"]
const RECURSOS := {
	"floresta": "madeira, caça, ervas", "montanha": "ferro, pedra, prata", "colina": "pedra, pastos",
	"agua": "peixe, sal", "campo": "trigo, cavalos", "planicie": "trigo, gado", "deserto": "sal, vidro, especiarias",
	"pantano": "turfa, ervas raras", "gelo": "peles, óleo de foca",
}
const OFICIOS := {
	"agua": ["pescador", "pescadora", "barqueiro", "mercador"], "floresta": ["lenhador", "caçadora", "curandeira", "carpinteiro"],
	"montanha": ["mineiro", "ferreiro", "pastora"], "colina": ["pastor", "pedreiro", "tecelã"], "campo": ["lavrador", "moleiro", "padeira"],
	"planicie": ["lavradora", "vaqueiro", "seleiro"], "deserto": ["mercador", "caravaneiro", "vidreira"],
	"pantano": ["coletora de ervas", "barqueiro", "curandeiro"], "gelo": ["caçador", "peleiro"],
}
const OFICIOS_COMUNS := ["ferreiro", "escriba", "soldado", "taverneira", "curandeira", "mercador", "guarda"]
const TRACOS := ["calmo", "gentil", "corajoso", "orgulhoso", "ambicioso", "curioso", "desconfiado", "alegre",
	"rancoroso", "paciente", "impulsivo", "leal", "ganancioso", "tímido", "sábio", "teimoso"]
const FACCOES := [["guilda", "Guilda dos Mercadores de %s"], ["ordem", "Ordem de %s"], ["irmandade", "Irmandade de %s"],
	["conselho", "Conselho de %s"], ["companhia", "Companhia Livre de %s"]]
const FEITOS := ["fundou %s", "defendeu %s de um cerco", "trouxe a primeira colheita a %s", "fez as pazes entre as famílias de %s",
	"descobriu a nascente que abastece %s", "enfrentou a grande fera de %s", "ergueu a muralha de %s"]


static func _rng(u: Universo, chave: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(u.semente()) + "|" + chave + "|" + str(u.fatos.quantidade()))
	return r


static func _escolha(rng: RandomNumberGenerator, lista: Array):
	return lista[rng.randi() % lista.size()]


static func _fato_raiz(u: Universo, tipo: String, texto: String, lugar: String) -> String:
	return u.fatos.registrar({
		"tipo": tipo, "descricao": texto, "sujeitos": [lugar] if lugar != "" else [], "lugar": lugar,
		"data": DataMundo.copiar(u.relogio),
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "povoador"},
		"dados": {"importancia": 0.3, "criados": []},
	})


static func _anotar(u: Universo, raiz: String, eid: String) -> void:
	var f := u.fatos.obter(raiz)
	if not f.is_empty():
		f["dados"]["criados"].append(eid)


# ---------------------------------------------------------------- planeta

## Gera um planeta com clima, luas, regiões e terreno. Devolve o id do planeta.
static func gerar_planeta(u: Universo, nome: String = "") -> String:
	var rng := _rng(u, "planeta")
	var lingua := Linguas.do_lugar(u, "")
	if nome.strip_edges() == "":
		nome = Linguas.gerar(u, lingua, "lugares", rng)
	var clima: String = _escolha(rng, CLIMAS)
	var raiz := _fato_raiz(u, "geração", "O autor gerou o planeta %s." % nome, "")
	var pid := u.criar_entidade(nome, "planeta", [], [
		{"chave": "clima", "valor": clima},
		{"chave": "luas", "valor": _escolha(rng, LUAS)},
		{"chave": "dia e noite", "valor": _escolha(rng, DIAS)},
		{"chave": "gravidade", "valor": _escolha(rng, GRAVIDADES)},
		{"chave": "estações", "valor": "quatro estações de 90 dias"},
		{"chave": "língua", "valor": lingua},
	])
	_anotar(u, raiz, pid)
	var f := u.fatos.obter(raiz)
	f["sujeitos"] = [pid]
	var livres := Mapa.celulas_livres(u, "", ["vazio"])
	var centro: Vector2i = livres[rng.randi() % livres.size()] if not livres.is_empty() else Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2)
	Mapa.colocar(u, pid, "", centro.x, centro.y, false)
	# Regiões espalhadas pela terra firme.
	var terra := Mapa.celulas_livres(u, pid, ["campo", "planicie", "floresta", "colina", "deserto", "pantano"])
	var escolhidas: Array = _espalhar(terra, 3 + rng.randi() % 3, 9.0, rng)
	var nomes_regiao := ["Terras de %s", "Vale de %s", "Reino de %s", "Marca de %s", "%s"]
	for c in escolhidas:
		var t := Mapa.terreno_em(u, pid, c.x, c.y)
		var rnome: String = _escolha(rng, nomes_regiao) % Linguas.gerar(u, lingua, "lugares", rng)
		var lat := absf((c.y + 0.5) / Mapa.LINHAS - 0.5) * 2.0
		var rclima := "frio" if lat > 0.6 else ("quente" if lat < 0.2 else clima)
		if t == "deserto":
			rclima = "árido"
		var rid := u.criar_entidade(rnome, "região", [], [
			{"chave": "clima", "valor": rclima},
			{"chave": "terreno", "valor": Mapa.TERRENOS[t]["nome"]},
			{"chave": "recursos", "valor": RECURSOS.get(t, "")},
		])
		Mapa.colocar(u, rid, pid, c.x, c.y, false)
		_anotar(u, raiz, rid)
	u.marcar_mudanca()
	return pid


static func _espalhar(celulas: Array, quantos: int, distancia: float, rng: RandomNumberGenerator) -> Array:
	var escolhidas: Array = []
	var tentativas := 0
	while escolhidas.size() < quantos and tentativas < 400 and not celulas.is_empty():
		tentativas += 1
		var c: Vector2i = celulas[rng.randi() % celulas.size()]
		var longe := true
		for e in escolhidas:
			if Vector2(c - e).length() < distancia:
				longe = false
				break
		if longe:
			escolhidas.append(c)
	return escolhidas


# ---------------------------------------------------------------- povoar

## Povoa um lugar: cria povoados, famílias, uma facção e figuras históricas.
## Num planeta sem regiões, cria as regiões primeiro. Devolve {fato, criados}.
static func povoar(u: Universo, lugar: String) -> Dictionary:
	if not u.entidades.has(lugar):
		return {"fato": "", "criados": []}
	var rng := _rng(u, "povoar:" + lugar)
	var raiz := _fato_raiz(u, "povoamento", "O autor povoou %s." % u.entidade(lugar)["nome"], lugar)
	var alvos: Array = []
	match Mapa.especie(u, lugar):
		"planeta":
			alvos = Mapa.filhos(u, lugar).filter(func(x): return Mapa.especie(u, x) == "regiao")
			if alvos.is_empty():
				alvos = [lugar]
		"povoado":
			_povoar_povoado(u, lugar, raiz, rng)
		_:
			alvos = [lugar]
	for r in alvos:
		_povoar_regiao(u, r, raiz, rng)
	u.marcar_mudanca()
	return {"fato": raiz, "criados": u.fatos.obter(raiz)["dados"]["criados"]}


static func _povoar_regiao(u: Universo, regiao: String, raiz: String, rng: RandomNumberGenerator) -> void:
	var lingua := Linguas.do_lugar(u, regiao)
	var bons := Mapa.celulas_livres(u, regiao, ["campo", "planicie", "colina", "floresta"])
	# Prefere perto d'água.
	var g := Mapa.terreno(u, regiao)
	bons.sort_custom(func(a, b): return _perto_agua(g, a) > _perto_agua(g, b))
	var candidatos: Array = bons.slice(0, maxi(6, bons.size() / 2))
	var lugares := _espalhar(candidatos if candidatos.size() >= 4 else bons, 1 + 1 + rng.randi() % 3, 7.0, rng)
	var tipos := ["cidade", "vila", "aldeia", "aldeia", "vila"]
	var criados_aqui: Array = []
	for i in lugares.size():
		var c: Vector2i = lugares[i]
		var tipo: String = tipos[i] if i < tipos.size() else "aldeia"
		if i == 0 and Mapa.especie(u, regiao) == "regiao" and rng.randf() < 0.4:
			tipo = "capital"
		if _perto_agua(g, c) >= 3 and tipo != "capital" and rng.randf() < 0.5:
			tipo = "porto" if tipo == "cidade" else "vila de pescadores" if tipo == "vila" else tipo
		var t := Mapa.terreno_em(u, regiao, c.x, c.y)
		var pop: int = {"capital": 30000 + rng.randi() % 20000, "cidade": 5000 + rng.randi() % 7000, "porto": 2500 + rng.randi() % 3000,
			"vila": 400 + rng.randi() % 700, "vila de pescadores": 300 + rng.randi() % 400}.get(tipo, 80 + rng.randi() % 150)
		var nome := Linguas.gerar(u, lingua, "lugares", rng)
		var pid := u.criar_entidade(nome, tipo, [], [
			{"chave": "população", "valor": str(pop)},
			{"chave": "recursos", "valor": RECURSOS.get(t, "")},
		])
		Mapa.colocar(u, pid, regiao, c.x, c.y, false)
		_anotar(u, raiz, pid)
		criados_aqui.append(pid)
		_povoar_povoado(u, pid, raiz, rng)
	# Uma facção da região, com sede no maior povoado.
	if not criados_aqui.is_empty():
		var sede: String = criados_aqui[0]
		var f: Array = _escolha(rng, FACCOES)
		var fnome: String = f[1] % (u.entidade(sede)["nome"] if f[0] != "ordem" else Linguas.gerar(u, lingua, "lugares", rng))
		var fid := u.criar_entidade(fnome, f[0], [], [
			{"chave": "sede", "valor": u.entidade(sede)["nome"]},
			{"chave": "objetivos", "valor": _escolha(rng, ["controlar o comércio da região", "proteger a região", "guardar um segredo antigo", "ganhar influência sobre o governo"])},
		])
		_anotar(u, raiz, fid)
	# Figuras históricas: já mortas, viram lenda.
	var era := Cosmos.era_de(u, int(u.relogio["ano"]) - 150)
	for k in 1 + rng.randi() % 2:
		var alvo_lugar: String = criados_aqui[rng.randi() % criados_aqui.size()] if not criados_aqui.is_empty() else regiao
		var hnome := "%s %s" % [Linguas.gerar(u, lingua, "pessoas", rng), Linguas.gerar(u, lingua, "sobrenomes", rng)]
		var anos_atras := 60 + rng.randi() % 300
		var feito: String = _escolha(rng, FEITOS) % u.entidade(alvo_lugar)["nome"]
		var hid := u.criar_entidade(hnome, "pessoa", [], [
			{"chave": "época", "valor": ("%s, há %d anos" % [era["nome"], anos_atras]) if not era.is_empty() else "há %d anos" % anos_atras},
			{"chave": "feito", "valor": feito},
		])
		u.definir_tem_mente(hid, false)
		_anotar(u, raiz, hid)
		var ano_feito := int(u.relogio["ano"]) - anos_atras
		var lenda := Simulador.registrar(u, {
			"tipo": "lenda", "descricao": "%s %s." % [hnome, feito], "sujeitos": [hid, alvo_lugar], "lugar": alvo_lugar,
			"data": DataMundo.criar(ano_feito, 1 + rng.randi() % 360),
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "povoador"},
			"dados": {"importancia": 0.5, "povoamento": raiz, "mudancas": [{"op": "nascer", "quem": hid, "lugar": alvo_lugar}]},
		})
		Simulador.registrar(u, {
			"tipo": "morte", "descricao": "%s morreu, deixando o nome na memória de %s." % [hnome, u.entidade(alvo_lugar)["nome"]],
			"sujeitos": [hid], "lugar": alvo_lugar, "data": DataMundo.criar(ano_feito + 20 + rng.randi() % 30, 1 + rng.randi() % 360),
			"causas": [lenda] if lenda != "" else [], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "povoador"},
			"dados": {"importancia": 0.3, "povoamento": raiz, "mudancas": [{"op": "morrer", "quem": hid}]},
		})


static func _perto_agua(g: Array, c: Vector2i) -> int:
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-3, 4):
			var y := c.y + dy
			var x := c.x + dx
			if y >= 0 and y < Mapa.LINHAS and x >= 0 and x < Mapa.COLS and g[y][x] == "agua":
				n += 1
	return n


## Famílias de um povoado (com mente própria: passam a viver na simulação).
static func _povoar_povoado(u: Universo, lugar: String, raiz: String, rng: RandomNumberGenerator) -> void:
	var lingua := Linguas.do_lugar(u, lugar)
	var t := Mapa.terreno_do_lugar(u, lugar)
	var oficios: Array = OFICIOS.get(t, []) + OFICIOS_COMUNS
	var pop := Natureza.populacao_inicial(u, lugar)
	var familias := 1 + (1 if pop > 300 else 0) + (1 if pop > 3000 else 0)
	var ano := int(u.relogio["ano"])
	var lider := ""
	for i in familias:
		var sobrenome := Linguas.gerar(u, lingua, "sobrenomes", rng)
		var idade_pai := 28 + rng.randi() % 25
		var adultos: Array = []
		for j in 2:
			var nome := "%s %s" % [Linguas.gerar(u, lingua, "pessoas", rng), sobrenome]
			var idade := idade_pai + (rng.randi() % 7 - 3 if j == 1 else 0)
			var eid := _pessoa(u, nome, idade, _escolha(rng, oficios), rng, lugar, raiz)
			adultos.append(eid)
		var casou := Simulador.registrar(u, {
			"tipo": "casamento", "descricao": "%s e %s se casaram." % [u.entidade(adultos[0])["nome"], u.entidade(adultos[1])["nome"]],
			"sujeitos": adultos.duplicate(), "lugar": lugar, "data": DataMundo.criar(ano - idade_pai + 22, 1 + rng.randi() % 360),
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "povoador"},
			"dados": {"importancia": 0.2, "povoamento": raiz, "mudancas": [
				{"op": "vinculo", "quem": adultos[0], "tipo": "conjuges", "outro": adultos[1]},
				{"op": "vinculo", "quem": adultos[1], "tipo": "conjuges", "outro": adultos[0]},
				{"op": "relacao", "de": adultos[0], "para": adultos[1], "deltas": {"afeto": 0.6, "confianca": 0.5}},
				{"op": "relacao", "de": adultos[1], "para": adultos[0], "deltas": {"afeto": 0.6, "confianca": 0.5}}]},
		})
		for k in rng.randi() % 3 + 1:
			var idade_filho := rng.randi() % maxi(1, idade_pai - 23)
			var fnome := "%s %s" % [Linguas.gerar(u, lingua, "pessoas", rng), sobrenome]
			var filho := _pessoa(u, fnome, idade_filho, "aprendiz" if idade_filho >= 12 else "criança", rng, lugar, raiz, casou)
			for a in adultos:
				Simulador.registrar(u, {
					"tipo": "filiação", "descricao": "%s é filho de %s." % [fnome, u.entidade(a)["nome"]],
					"sujeitos": [filho, a], "lugar": lugar, "data": DataMundo.criar(ano - idade_filho, 1),
					"causas": [casou] if casou != "" else [], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "povoador"},
					"dados": {"importancia": 0.1, "povoamento": raiz, "mudancas": [{"op": "familia", "pai": a, "filho": filho}]},
				})
		if i == 0 and Mapa.especie(u, lugar) == "povoado" and pop >= 300:
			lider = adultos[0]
	if lider != "":
		var cargo: String = "senhor de " + u.entidade(lugar)["nome"] if pop < 5000 else "governante de " + u.entidade(lugar)["nome"]
		var campos: Array = u.entidade(lider)["campos"].duplicate(true)
		campos.append({"chave": "cargo", "valor": cargo})
		u.editar_entidade(lider, {"campos": campos})
		var cl: Array = u.entidade(lugar)["campos"].duplicate(true)
		cl.append({"chave": "quem governa", "valor": u.entidade(lider)["nome"]})
		u.editar_entidade(lugar, {"campos": cl})


static func _pessoa(u: Universo, nome: String, idade: int, oficio: String, rng: RandomNumberGenerator, lugar: String, raiz: String, causa: String = "") -> String:
	var tr: Array = []
	while tr.size() < 2:
		var x: String = _escolha(rng, TRACOS)
		if not tr.has(x):
			tr.append(x)
	var eid := u.criar_entidade(nome, "pessoa", [], [
		{"chave": "idade", "valor": "%d anos" % idade},
		{"chave": "ofício", "valor": oficio},
		{"chave": "personalidade", "valor": " e ".join(tr)},
	])
	_anotar(u, raiz, eid)
	Simulador.registrar(u, {
		"tipo": "nascimento", "descricao": "%s nasceu em %s." % [nome, u.entidade(lugar)["nome"]],
		"sujeitos": [eid], "lugar": lugar, "data": DataMundo.criar(int(u.relogio["ano"]) - idade, 1 + rng.randi() % 360),
		"causas": [causa] if causa != "" and u.fatos.existe(causa) else [], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "povoador"},
		"dados": {"importancia": 0.05, "povoamento": raiz, "mudancas": [{"op": "nascer", "quem": eid, "lugar": lugar}]},
	})
	return eid


## Desfaz uma geração: o que ela criou é retirado do universo (continua guardado).
static func desfazer(u: Universo, raiz: String) -> int:
	var f := u.fatos.obter(raiz)
	if f.is_empty():
		return 0
	var n := 0
	for eid in f["dados"].get("criados", []):
		if u.entidades.has(eid) and not u.entidade(eid)["removida"]:
			u.remover_entidade(eid)
			Mapa.tirar(u, eid)
			n += 1
	for g in u.fatos.todos():
		if g["canon"] and str(g["dados"].get("povoamento", "")) == raiz:
			g["canon"] = false
	u.desfazer_fato(raiz)
	return n


# ---------------------------------------------------------------- criar escrevendo no mapa

const ARTIGOS := ["um", "uma", "o", "a", "uns", "umas", "os", "as"]
const LIGACOES := ["na", "no", "nas", "nos", "em", "perto", "junto", "ao", "à", "a", "sobre", "entre", "chamada",
	"chamado", "de", "do", "da", "dos", "das", "com", "onde", "que", "beira", "aos", "pé", "pe"]


## Lê o que o autor escreveu ("uma casa na montanha", "uma torre em ruínas perto do rio
## chamada Vigia Negra") e devolve {nome, tipo, campos, terreno, gente}.
static func ler_texto_do_mapa(texto: String) -> Dictionary:
	var original := texto.strip_edges().trim_suffix(".")
	var nome := ""
	var rx := RegEx.new()
	rx.compile("(?i)(?:chamad[oa]|de nome|conhecid[oa] como)\\s+(.+)$")
	var m := rx.search(original)
	var resto := original
	if m != null:
		nome = m.get_string(1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		resto = original.substr(0, m.get_start()).strip_edges()
	else:
		var rq := RegEx.new()
		rq.compile("[\"“](.+?)[\"”]")
		var mq := rq.search(original)
		if mq != null:
			nome = mq.get_string(1)
			resto = original.replace(mq.get_string(0), "").strip_edges()
	var palavras := resto.split(" ", false)
	var i := 0
	while i < palavras.size() and TextUtil.normalizar(palavras[i]) in ARTIGOS:
		i += 1
	var tipo_partes: Array = []
	while i < palavras.size():
		var p := TextUtil.normalizar(palavras[i])
		if p in LIGACOES and not tipo_partes.is_empty():
			# "vila de pescadores", "torre de vigia": "de" + palavra comum continua o tipo
			if p in ["de", "do", "da", "dos", "das"] and i + 1 < palavras.size() and not TextUtil.normalizar(palavras[i + 1]) in Mapa.PALAVRAS_TERRENO and palavras[i + 1].substr(0, 1) == palavras[i + 1].substr(0, 1).to_lower():
				tipo_partes.append(palavras[i])
				tipo_partes.append(palavras[i + 1])
				i += 2
				continue
			break
		tipo_partes.append(palavras[i])
		i += 1
	var tipo := " ".join(tipo_partes).strip_edges()
	var t_norm := TextUtil.normalizar(original)
	var terreno := ""
	for palavra in TextUtil.palavras(TextUtil.normalizar(" ".join(palavras.slice(i)))):
		if Mapa.PALAVRAS_TERRENO.has(palavra):
			terreno = Mapa.PALAVRAS_TERRENO[palavra]
			break
	var campos: Array = [{"chave": "descrição", "valor": original}]
	if t_norm.contains("ruina") or t_norm.contains("abandonad") or t_norm.contains("destruid"):
		campos.append({"chave": "estado", "valor": "em ruínas" if t_norm.contains("ruina") else "abandonada"})
		if not TextUtil.normalizar(tipo).contains("ruina"):
			pass
	var gente := ""
	var rg := RegEx.new()
	rg.compile("(?i)\\bde (pescadores|mineiros|lenhadores|camponeses|pastores|monges|caçadores|cacadores|mercadores|bandidos|piratas|ferreiros|eremitas|magos|bruxas|soldados)")
	var mg := rg.search(original)
	if mg != null:
		gente = mg.get_string(1)
		campos.append({"chave": "moradores", "valor": gente})
	return {"nome": nome, "tipo": tipo if tipo != "" else "lugar", "campos": campos, "terreno": terreno, "gente": gente}


## Cria no mapa o que o autor escreveu num ponto. Devolve {eid, sugestao}.
## 'sugestao' é o que o programa propõe completar (quem mora ali, desde quando),
## para o autor confirmar com completar().
static func criar_por_texto(u: Universo, texto: String, de: String, x: int, y: int) -> Dictionary:
	var acid := ler_acidente(texto)
	if not acid.is_empty() and de != "":
		return _criar_acidente(u, acid, texto, de, x, y)
	var lido := ler_texto_do_mapa(texto)
	var rng := _rng(u, "mapa:%s:%d:%d" % [de, x, y])
	var lingua := Linguas.do_lugar(u, de)
	var nome: String = lido["nome"]
	if nome == "":
		var base: String = Linguas.gerar(u, lingua, "lugares", rng)
		nome = "%s de %s" % [str(lido["tipo"]).capitalize(), base] if Mapa.especie_do_tipo(lido["tipo"]) in ["construcao", "natural", ""] else base
	var eid := u.criar_entidade(nome, lido["tipo"], [], lido["campos"])
	if lido["terreno"] != "" and de != "":
		var atual := Mapa.terreno_em(u, de, x, y)
		if atual != lido["terreno"] and lido["terreno"] != "agua":
			Mapa.pintar(u, de, x, y, lido["terreno"])
	Mapa.colocar(u, eid, de, x, y)
	return {"eid": eid, "sugestao": sugerir(u, eid, rng)}


## O que falta num lugar recém-criado: quem mora ali, desde quando e por quê.
static func sugerir(u: Universo, eid: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = _rng(u, "sugerir:" + eid)
	var esp := Mapa.especie(u, eid)
	var tipo := TextUtil.normalizar(u.entidade(eid)["tipo"])
	var estado := TextUtil.normalizar(u.valor_campo(eid, "estado"))
	if estado.contains("ruina") or estado.contains("abandon") or tipo.contains("ruina") or esp == "natural" or esp == "regiao" or esp == "planeta" or esp == "cosmico":
		return {}
	var lingua := Linguas.do_lugar(u, eid)
	var quantos := 1
	if esp == "povoado":
		quantos = 2
	var sobrenome := Linguas.gerar(u, lingua, "sobrenomes", rng)
	var gente := u.valor_campo(eid, "moradores")
	var oficio: String = gente.trim_suffix("es").trim_suffix("s") if gente != "" else _escolha(rng, OFICIOS_COMUNS)
	var moradores: Array = []
	for i in quantos:
		moradores.append({"nome": "%s %s" % [Linguas.gerar(u, lingua, "pessoas", rng), sobrenome],
			"idade": 25 + rng.randi() % 40, "oficio": oficio if i == 0 else _escolha(rng, OFICIOS_COMUNS)})
	var desde := int(u.relogio["ano"]) - (3 + rng.randi() % 40)
	var motivos := ["buscava sossego longe de tudo", "herdou o lugar da família", "fugiu de uma dívida antiga", "foi mandado para vigiar a região", "encontrou ali o que procurava"]
	return {"moradores": moradores, "desde": desde, "por_que": _escolha(rng, motivos)}


## O autor confirma a sugestão: os moradores passam a existir e a morar ali.
static func completar(u: Universo, eid: String, sugestao: Dictionary) -> Array:
	var criados: Array = []
	if sugestao.is_empty() or not u.entidades.has(eid):
		return criados
	for m in sugestao.get("moradores", []):
		var pid := u.criar_entidade(m["nome"], "pessoa", [], [
			{"chave": "idade", "valor": "%d anos" % int(m["idade"])},
			{"chave": "ofício", "valor": m["oficio"]},
			{"chave": "história", "valor": "Mora em %s desde o ano %d; %s." % [u.entidade(eid)["nome"], int(sugestao["desde"]), sugestao["por_que"]]},
		])
		Simulador.registrar(u, {
			"tipo": "nascimento", "descricao": "%s nasceu." % m["nome"], "sujeitos": [pid],
			"data": DataMundo.criar(int(u.relogio["ano"]) - int(m["idade"]), 1),
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "mapa"},
			"dados": {"importancia": 0.05, "completou": eid, "mudancas": [{"op": "nascer", "quem": pid}]},
		})
		Simulador.registrar(u, {
			"tipo": "chegada", "descricao": "%s passou a morar em %s." % [m["nome"], u.entidade(eid)["nome"]], "sujeitos": [pid, eid], "lugar": eid,
			"data": DataMundo.criar(int(sugestao["desde"]), 1),
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "mapa"},
			"dados": {"importancia": 0.1, "completou": eid, "mudancas": [{"op": "mover", "quem": pid, "lugar": eid}]},
		})
		criados.append(pid)
	u.marcar_mudanca()
	return criados


const MINUSCULAS := ["de", "do", "da", "dos", "das", "e", "o", "a", "os", "as", "em", "no", "na"]


## "rio da pedra azul" → {grupo: rio, termo: rio, nome: "Rio da Pedra Azul"}; {} se não for natureza.
static func ler_acidente(texto: String) -> Dictionary:
	var t := texto.strip_edges().trim_suffix(".")
	var palavras := t.split(" ", false)
	var i := 0
	while i < palavras.size() and TextUtil.normalizar(palavras[i]) in ARTIGOS:
		i += 1
	if i >= palavras.size():
		return {}
	var termo := TextUtil.normalizar(palavras[i])
	if not Mapa.TERMOS_ACIDENTE.has(termo):
		return {}
	var nome := ""
	var rx := RegEx.new()
	rx.compile("(?i)(?:chamad[oa]s?|de nome|conhecid[oa]s? como)\\s+(.+)$")
	var m := rx.search(t)
	if m != null:
		nome = m.get_string(1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	else:
		var partes: Array = []
		for j in range(i, palavras.size()):
			var p: String = palavras[j]
			if j > i and TextUtil.normalizar(p) in MINUSCULAS:
				partes.append(p.to_lower())
			else:
				partes.append(p.substr(0, 1).to_upper() + p.substr(1))
		nome = " ".join(partes)
	return {"grupo": Mapa.TERMOS_ACIDENTE[termo], "termo": palavras[i].to_lower(), "nome": nome}


static func _criar_acidente(u: Universo, acid: Dictionary, texto: String, de: String, x: int, y: int) -> Dictionary:
	var grupo: String = acid["grupo"]
	var a := {}
	if grupo == "rio":
		a = Mapa.rio_perto(u, de, x, y)
		if a.is_empty():
			a = Mapa.criar_rio(u, de, x, y)
	else:
		a = Mapa.acidente_em(u, de, x, y)
		var combina: bool = not a.is_empty() and (a["grupo"] == grupo or (grupo == "montanha" and a["grupo"] == "colina") or (grupo == "colina" and a["grupo"] == "montanha"))
		if not combina:
			# A palavra do autor vira terreno: uma mancha do que ele escreveu, ali.
			var pinta: String = {"planicie": "campo"}.get(grupo, grupo)
			var raio := 3.2 if grupo == "planicie" else 2.3
			for dy in range(-3, 4):
				for dx in range(-4, 5):
					if Vector2(dx, dy * 1.6).length() <= raio:
						Mapa.pintar(u, de, x + dx, y + dy, pinta)
			a = Mapa.acidente_em(u, de, x, y)
	var eid := u.criar_entidade(acid["nome"], acid["termo"], [], [{"chave": "descrição", "valor": texto.strip_edges()}])
	Mapa.colocar(u, eid, de, x, y, false)
	if not a.is_empty():
		Mapa.nomear_acidente(u, de, a, acid["nome"], eid)
	return {"eid": eid, "sugestao": {}, "acidente": true}
