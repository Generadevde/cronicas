class_name Vivencia
extends RefCounted
## Modo Viver: você encarna um personagem e vive o mundo por dentro. Só sabe o que
## ele sabe, só pode o que ele pode; o resto do mundo segue simulando em volta.
##
## Você escreve o que ele faz em palavras livres ("vou até a forja e peço trabalho a
## Lucas"). O programa interpreta, confere se ele consegue, e as outras mentes reagem
## com as suas personalidades. As ações ficam no nível da história (pedir trabalho,
## viajar, construir uma casa), nunca no nível de passos e movimentos.
##
## Tudo o que muda o mundo vira fato (com causa). O que é só do corpo dele no momento
## (fome, cansaço, a hora do dia) fica na sessão. O diário guarda cada cena, em
## primeira e em terceira pessoa, e a sessão pode virar capítulo do Livro.
##
## Tempo: cada ação simples leva uma parte do dia (manhã, tarde, noite); trabalhos,
## treinos, viagens e esperas longas podem ser resumidos ("trabalho na forja durante
## um mês"). O resto do mundo anda em blocos de uma semana, como no Livro.

const PARTES := ["manhã", "tarde", "noite"]

## Cantos de uma cidade (nível de história: não precisam existir como entidade).
const CANTOS := {
	"forja": "ferreir", "ferraria": "ferreir", "mercado": "mercador|comerciant|vendedor", "feira": "mercador|comerciant|vendedor",
	"taverna": "tabern|estalajad|taverneir", "estalagem": "estalajad|tabern", "templo": "sacerdot|monge|clerig|sacerdotisa",
	"igreja": "padre|sacerdot", "porto": "pescador|marinheir|barqueir", "cais": "pescador|marinheir|barqueir",
	"campo": "lavrador|campones|agricultor|pastor", "moinho": "moleir", "padaria": "padeir", "praca": "", "casa": "",
	"rio": "pescador|lavadeir", "floresta": "lenhador|cacador", "quartel": "soldad|guarda", "castelo": "", "palacio": "",
	"biblioteca": "escriba|bibliotecari", "escola": "mestre|professor", "oficina": "artes|carpinteir|marceneir",
	"estabulo": "cavalari|tratador", "poco": "", "muralha": "guarda|soldad", "mina": "mineir",
}

## Preço base (em moedas) do que se compra; o preço do lugar multiplica.
const PRECOS := {"pao": 1, "comida": 1, "refeicao": 2, "cerveja": 1, "vinho": 3, "roupa": 6, "capa": 8, "botas": 7,
	"faca": 5, "espada": 40, "machado": 12, "martelo": 8, "ferramenta": 8, "arco": 15, "cavalo": 80, "mula": 40,
	"livro": 12, "remedio": 6, "erva": 2, "corda": 2, "lampiao": 4, "presente": 5, "flores": 1, "anel": 30, "colar": 25}

## Construções: custo em moedas e dias de trabalho (para quem não tem o ofício).
const OBRAS := {"casa": [40, 60], "cabana": [12, 20], "oficina": [60, 80], "forja": [70, 90], "loja": [50, 70],
	"torre": [150, 200], "muro": [25, 30], "celeiro": [30, 45], "barco": [35, 40], "ponte": [80, 90],
	"poco": [15, 15], "estabulo": [25, 30], "capela": [90, 120], "moinho": [100, 120], "taverna": [90, 110]}

## Ofícios que ajudam a construir (e quanto).
const OFICIOS_DE_OBRA := ["carpinteir", "pedreir", "construtor", "marceneir", "ferreir", "mestre de obras"]

const INTENCOES := [
	["poder", ["uso meu poder", "uso o poder", "uso minha magia", "uso a magia", "lanco um feitico", "lanco uma magia", "invoco"]],
	["casar", ["peco em casamento", "peco a mao", "me caso com", "caso com", "pedir em casamento"]],
	["cortejar", ["cortejo", "declaro meu amor", "declaro o meu amor", "me declaro", "flerto", "beijo", "namoro", "faco a corte"]],
	["pedir_trabalho", ["peco trabalho", "peco emprego", "pedir trabalho", "pedir emprego", "procuro trabalho", "procuro emprego", "ofereco meus servicos", "peco servico", "peco para trabalhar"]],
	["atacar", ["ataco", "atacar", "luto com", "lutar com", "brigo com", "desafio", "mato ", "matar ", "esfaqueio", "golpeio", "agrido", "soco "]],
	["construir", ["construo", "construir", "ergo ", "levanto um", "levanto uma", "edifico"]],
	["comprar", ["compro", "comprar"]],
	["vender", ["vendo ", "vender "]],
	["presentear", ["dou ", "presenteio", "dou de presente", "entrego ", "ofereco "]],
	["treinar", ["treino", "treinar", "estudo", "estudar", "pratico", "praticar", "aprendo", "aprender"]],
	["trabalhar", ["trabalho", "trabalhar", "faco meu oficio", "forjo", "planto", "colho", "pesco", "costuro", "cozinho", "ajudo na", "ajudo no"]],
	["ajudar", ["ajudo", "ajudar", "socorro", "cuido de", "cuido do", "cuido da"]],
	["conversar", ["converso", "conversar", "falo com", "falar com", "pergunto", "perguntar", "digo a", "digo para", "conto a", "conto para", "cumprimento", "visito"]],
	["rezar", ["rezo", "rezar", "oro ", "orar", "faco uma prece"]],
	["comer", ["como ", "comer", "almoco", "janto", "ceio", "faco uma refeicao"]],
	["dormir", ["durmo", "dormir", "descanso", "descansar", "deito", "vou dormir"]],
	["explorar", ["exploro", "explorar", "investigo", "ando pelos arredores", "caminho pelos arredores", "passeio pelos", "procuro lugares", "conhecer os arredores", "descobrir"]],
	["planejar", ["quero ", "decido ", "meu plano", "prometo a mim", "juro que"]],
	["esperar", ["espero", "passo o", "passo os", "passo a", "deixo os dias", "aguardo", "fico em casa", "deixo o tempo"]],
	["viajar", ["vou para", "vou ate", "vou a ", "vou ao ", "vou a ", "sigo para", "caminho ate", "volto para", "volto a", "volto ao", "parto para", "viajo", "ir para", "ir ate", "corro ate", "passo pela", "passo pelo"]],
]


# ---------------------------------------------------------------- sessão

static func sessoes(u: Universo) -> Dictionary:
	return u.extra("vivencias", {})


## Quem você está vivendo agora ("" se ninguém).
static func encarnado(u: Universo) -> String:
	if u == null:
		return ""
	var a := str(u.extras.get("vivendo", ""))
	return a if a != "" and u.entidades.has(a) else ""


static func sessao(u: Universo, eid: String = "") -> Dictionary:
	var quem := eid if eid != "" else encarnado(u)
	return sessoes(u).get(quem, {})


## Começa (ou retoma) a vida de um personagem que já existe.
static func comecar(u: Universo, eid: String, voz: String = "primeira") -> Dictionary:
	if not u.entidades.has(eid) or not Estado.tem_mente(u, eid):
		return {}
	var s: Dictionary = sessoes(u).get(eid, {})
	if s.is_empty():
		s = {"quem": eid, "voz": voz, "inicio": DataMundo.ordem(u.relogio), "inicio_data": DataMundo.copiar(u.relogio),
			"inicio_seq": Acompanhar._ultimo_seq(u), "parte": 0, "pendente": 0, "fome": 0.2, "cansaco": 0.1,
			"canto": "", "diario": [], "fatos": [], "conversas": {}, "visto_seq": Acompanhar._ultimo_seq(u)}
		sessoes(u)[eid] = s
		_garantir_posses(u, eid)
		_entrada(u, s, "cena", "Começo a minha história em %s." % _onde(u, eid), "%s começa a sua história em %s." % [_n(u, eid), _onde(u, eid)], "")
	s["voz"] = voz
	u.extras["vivendo"] = eid
	u.marcar_mudanca()
	return s


## Cria um personagem novo, nascido num lugar do mundo, com origem, família e ofício,
## e começa a vivê-lo. 'dados': {nome, lugar, idade, jeito, oficio, origem, familia, dinheiro}.
static func criar(u: Universo, dados: Dictionary, voz: String = "primeira") -> String:
	var nome := str(dados.get("nome", "")).strip_edges()
	var lugar := str(dados.get("lugar", ""))
	if nome == "" or not u.entidades.has(lugar):
		return ""
	var campos: Array = [{"chave": "idade", "valor": "%d anos" % int(dados.get("idade", 20))}]
	for k in [["jeito", "personalidade"], ["oficio", "ofício"], ["origem", "origem"], ["familia", "família"], ["dinheiro", "dinheiro"], ["pertences", "pertences"]]:
		if str(dados.get(k[0], "")).strip_edges() != "":
			campos.append({"chave": k[1], "valor": str(dados[k[0]]).strip_edges()})
	campos.append({"chave": "nasceu em", "valor": u.entidade(lugar)["nome"]})
	var eid := u.criar_entidade(nome, "pessoa", [], campos)
	var ops: Array = [{"op": "mover", "quem": eid, "lugar": lugar}]
	# Família: quem já existe no mundo e foi citado ("filho de Marta e Joran").
	var fam := str(dados.get("familia", ""))
	if fam != "":
		var nf := TextUtil.normalizar(fam)
		for m in Ligador.new(u).encontrar(fam):
			var p: String = m["entidade"]
			if p == eid or not Estado.tem_mente(u, p):
				continue
			var antes := nf.substr(0, int(m["inicio"]))
			if antes.contains("filh") and not antes.contains("pai de") and not antes.contains("mae de"):
				ops.append({"op": "familia", "pai": p, "filho": eid})
			elif antes.contains("pai de") or antes.contains("mae de"):
				ops.append({"op": "familia", "pai": eid, "filho": p})
			elif antes.contains("irm"):
				for pai in u.estado(p)["familia"]["pais"]:
					ops.append({"op": "familia", "pai": pai, "filho": eid})
			else:
				ops.append({"op": "relacao", "de": eid, "para": p, "deltas": {"afeto": 0.5, "confianca": 0.4}})
				ops.append({"op": "relacao", "de": p, "para": eid, "deltas": {"afeto": 0.5, "confianca": 0.4}})
	Simulador.registrar(u, {"tipo": "origem", "descricao": "%s vive em %s%s." % [nome, u.entidade(lugar)["nome"], (", " + str(dados["origem"])) if str(dados.get("origem", "")) != "" else ""],
		"sujeitos": [eid, lugar], "lugar": lugar, "causas": [u.entidade(eid).get("fato_criacao", "")], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "viver"},
		"dados": {"importancia": 0.2, "mudancas": ops}})
	comecar(u, eid, voz)
	return eid


## Para de viver (o personagem volta a ter mente própria). A sessão fica guardada.
static func parar(u: Universo) -> void:
	var s := sessao(u)
	if not s.is_empty():
		_soltar_mundo(u, s)
	u.extras.erase("vivendo")
	u.marcar_mudanca()


# ---------------------------------------------------------------- operações

## Operações próprias: "bens" (dinheiro e pertences) e "habilidade".
static func aplicar_op(u: Universo, op: Dictionary, _fato: Dictionary) -> bool:
	var quem := str(op.get("quem", ""))
	match str(op.get("op", "")):
		"bens":
			if not u.entidades.has(quem):
				return true
			var b := bens(u, quem)
			b["dinheiro"] = float(b["dinheiro"]) + float(op.get("dinheiro", 0.0))
			var item := str(op.get("item", ""))
			if item != "":
				var q := int(b["itens"].get(item, 0)) + int(op.get("qtd", 1))
				if q > 0:
					b["itens"][item] = q
				else:
					b["itens"].erase(item)
			return true
		"habilidade":
			if not u.entidades.has(quem):
				return true
			var h: Dictionary = u.estado(quem).get("habilidades", {})
			var k := str(op.get("nome", ""))
			h[k] = clampf(float(h.get(k, 0.0)) + float(op.get("delta", 0.0)), 0.0, 1.0)
			u.estado(quem)["habilidades"] = h
			return true
	return false


static func bens(u: Universo, eid: String) -> Dictionary:
	var s := u.estado(eid)
	if not s.has("bens"):
		s["bens"] = {"dinheiro": 0.0, "itens": {}}
	return s["bens"]


static func dinheiro(u: Universo, eid: String) -> float:
	return float(bens(u, eid)["dinheiro"])


## As posses de partida vêm da ficha ("dinheiro: 30 moedas", "pertences: uma faca, uma capa").
static func _garantir_posses(u: Universo, eid: String) -> void:
	for f in u.fatos.sobre(eid):
		if f["tipo"] == "posses":
			return
	var din := Combate.ler_numero(u.valor_campo(eid, "dinheiro"))
	if din <= 0.0:
		din = 15.0 if oficio(u, eid) != "" else 8.0
	var ops: Array = [{"op": "bens", "quem": eid, "dinheiro": din}]
	for p in u.valor_campo(eid, "pertences").split(","):
		var item := _coisa(p)
		if item != "":
			ops.append({"op": "bens", "quem": eid, "item": item, "qtd": 1})
	Simulador.registrar(u, {"tipo": "posses", "descricao": "%s tem %d moedas%s." % [_n(u, eid), int(din), (" e " + ", ".join(ops.slice(1).map(func(o): return o["item"]))) if ops.size() > 1 else ""],
		"sujeitos": [eid], "causas": [u.entidade(eid).get("fato_criacao", "")], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "viver"},
		"dados": {"importancia": 0.05, "mudancas": ops}})


static func oficio(u: Universo, eid: String) -> String:
	for k in ["ofício", "profissão", "trabalho", "ocupação"]:
		var v := u.valor_campo(eid, k)
		if v != "":
			return v
	return ""


static func habilidade(u: Universo, eid: String, nome: String) -> float:
	var h: Dictionary = u.estado(eid).get("habilidades", {})
	var base := 0.0
	var n := TextUtil.normalizar(nome)
	var of := TextUtil.normalizar(oficio(u, eid))
	if of != "" and n != "" and (of.contains(n.substr(0, 5)) or n.contains(of.substr(0, 5))):
		base = 0.45
	return clampf(base + float(h.get(nome, 0.0)), 0.0, 1.0)


# ---------------------------------------------------------------- agir

## Interpreta e executa o que você escreveu. Devolve {ok, texto (o que aconteceu), fatos}.
static func agir(u: Universo, texto: String) -> Dictionary:
	var eid := encarnado(u)
	var s := sessao(u)
	var r := {"ok": false, "texto": "", "fatos": []}
	if eid == "" or s.is_empty():
		r["texto"] = "Você não está vivendo ninguém."
		return r
	if not Estado.vivo(u, eid):
		r["texto"] = "%s está morto. A história dele acabou; dá para transformar a sessão em capítulo." % _n(u, eid)
		return r
	var partes := _clausulas(texto)
	var textos: Array = []
	for c in partes:
		var um := _uma(u, s, eid, c)
		textos.append(um["texto"])
		r["fatos"].append_array(um["fatos"])
		r["ok"] = r["ok"] or um["ok"]
		if not um["ok"] or not Estado.vivo(u, eid):
			break
	r["texto"] = " ".join(textos)
	u.marcar_mudanca()
	return r


## "Vou até a forja e peço trabalho a Lucas. Depois volto para casa." → três ações.
static func _clausulas(texto: String) -> Array:
	var t := texto.strip_edges()
	for sep in [". ", "; ", "! ", " e depois ", ", depois ", " depois disso ", " e então ", ", então "]:
		t = t.replace(sep, "|")
	var r: Array = []
	for parte in t.split("|"):
		var p: String = parte.strip_edges().trim_suffix(".").trim_suffix("!")
		if p == "":
			continue
		# "vou até a forja e peço…": separa o movimento do resto.
		var n := TextUtil.normalizar(p)
		var i := n.find(" e ")
		if i > 0 and _eh_movimento(n.substr(0, i)) and not _eh_movimento(n.substr(i + 3)):
			r.append(p.substr(0, i))
			r.append(p.substr(i + 3))
		else:
			r.append(p)
	return r


static func _eh_movimento(n: String) -> bool:
	for w in ["vou ", "volto ", "sigo ", "caminho ", "parto ", "corro ", "viajo"]:
		if n.begins_with(w):
			return true
	return false


static func intencao(texto: String) -> String:
	var n := " " + TextUtil.normalizar(texto) + " "
	if n.strip_edges().begins_with("como ") and not n.contains("?"):
		return "comer"
	for par in INTENCOES:
		for w in par[1]:
			if n.contains(" " + w) or n.begins_with(w):
				return par[0]
	return "outro"


static func _uma(u: Universo, s: Dictionary, eid: String, texto: String) -> Dictionary:
	var it := intencao(texto)
	var n := " " + TextUtil.normalizar(texto) + " "
	if Viagens.viajando(u, eid) and not it in ["esperar", "dormir", "planejar"]:
		return _falha("Ainda estou na estrada; só me resta seguir viagem (escreva \"espero\").", "%s ainda está na estrada." % _n(u, eid))
	if float(s["cansaco"]) >= 1.0 and not it in ["dormir", "comer", "esperar"]:
		return _falha("Estou exausto demais para isso. Preciso dormir.", "%s está exausto." % _n(u, eid))
	var lugar := str(u.estado(eid).get("local", ""))
	# Se só disse aonde vai, é um canto da cidade ou uma viagem.
	match it:
		"viajar":
			return _viajar(u, s, eid, texto, n)
		"pedir_trabalho":
			return _pedir_trabalho(u, s, eid, texto, n)
		"trabalhar":
			return _trabalhar(u, s, eid, texto, n)
		"conversar":
			return _conversar(u, s, eid, texto, n)
		"comprar":
			return _comprar(u, s, eid, texto, n, lugar)
		"vender":
			return _vender(u, s, eid, texto, n, lugar)
		"presentear":
			return _presentear(u, s, eid, texto, n)
		"comer":
			return _comer(u, s, eid, lugar)
		"dormir":
			return _dormir(u, s, eid)
		"treinar":
			return _treinar(u, s, eid, texto, n)
		"explorar":
			return _explorar(u, s, eid)
		"construir":
			return _construir(u, s, eid, texto, n)
		"ajudar":
			return _ajudar(u, s, eid, texto, n)
		"atacar":
			return _atacar(u, s, eid, texto, n)
		"cortejar", "casar":
			return _cortejar(u, s, eid, texto, n, it == "casar")
		"rezar":
			return _rezar(u, s, eid, lugar)
		"planejar":
			return _planejar(u, s, eid, texto)
		"esperar":
			return _esperar(u, s, eid, texto, n)
		"poder":
			return _poder(u, s, eid, texto)
	return _outro(u, s, eid, texto)


static func _falha(eu: String, ele: String) -> Dictionary:
	return {"ok": false, "texto": eu, "ele": ele, "fatos": []}


# ---------------------------------------------------------------- ações

static func _viajar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var aqui := str(u.estado(eid).get("local", ""))
	var destino := ""
	for m in Ligador.new(u).encontrar(texto):
		var x: String = m["entidade"]
		if x == eid:
			continue
		if Mapa.e_lugar(u, x) or Mapa.no_mapa(u, x):
			destino = x
			break
		if Estado.tem_mente(u, x) and str(u.estado(x).get("local", "")) != "":
			destino = str(u.estado(x)["local"])
			break
	if destino == "" or destino == aqui:
		var canto := _canto(n)
		if canto != "" and canto == str(s["canto"]):
			return {"ok": true, "texto": "Você já está %s." % _no(canto, "na", "no"), "fatos": []}
		if canto != "":
			s["canto"] = canto
			var fs := _gastar(u, s, 1)
			_entrada(u, s, "acao", "Fui %s." % _no(canto, "à", "ao"), "%s foi %s." % [_n(u, eid), _no(canto, "à", "ao")], "")
			return {"ok": true, "texto": "Você vai %s. %s" % [_no(canto, "à", "ao"), _quem_esta(u, eid, canto)], "fatos": fs}
		if destino == aqui and aqui != "":
			return _falha("Já estou em %s." % _n(u, aqui), "")
		return _falha("Não sei que lugar é esse. Explore os arredores ou pergunte a alguém.", "")
	if not conhecidos(u, eid).has(destino):
		return _falha("Não conheço o caminho para %s. Preciso ouvir falar de lá, ou explorar." % _n(u, destino), "")
	var dias := u.dias_de_viagem(aqui, destino) if aqui != "" else 1
	var ops := Viagens.ops_de_ida(u, eid, aqui, destino) if aqui != "" else [{"op": "mover", "quem": eid, "lugar": destino}]
	var fid := _registrar(u, s, eid, "viagem", "%s partiu de %s para %s." % [_n(u, eid), _n(u, aqui), _n(u, destino)], [eid, destino], 0.2, ops, aqui)
	s["canto"] = ""
	var r := {"ok": true, "texto": "", "fatos": [fid]}
	if dias <= 1:
		r["fatos"].append_array(_gastar(u, s, 2))
		r["texto"] = "Você chega a %s. %s" % [_n(u, destino), _quem_esta(u, eid, "")]
		_entrada(u, s, "acao", "Fui a %s." % _n(u, destino), "%s foi a %s." % [_n(u, eid), _n(u, destino)], fid)
		return r
	# A viagem é resumida: o mundo anda até a chegada.
	_entrada(u, s, "acao", "Parti de %s para %s; uma viagem de %d dias." % [_n(u, aqui), _n(u, destino), dias], "%s partiu de %s para %s." % [_n(u, eid), _n(u, aqui), _n(u, destino)], fid)
	var custo := float(dias) * 1.0 * Economia.preco(u, aqui)
	r["fatos"].append_array(_passar_dias(u, s, dias + 1))
	s["fome"] = 0.4
	s["cansaco"] = 0.6
	if Estado.vivo(u, eid) and str(u.estado(eid).get("local", "")) == destino:
		r["fatos"].append(_registrar(u, s, eid, "gastos de viagem", "%s gastou %d moedas na estrada." % [_n(u, eid), int(minf(custo, dinheiro(u, eid)))], [eid], 0.05,
			[{"op": "bens", "quem": eid, "dinheiro": -minf(custo, dinheiro(u, eid))}], destino))
		r["texto"] = "Depois de %d dias de estrada, você chega a %s. %s" % [dias, _n(u, destino), _quem_esta(u, eid, "")]
		_entrada(u, s, "acao", "Cheguei a %s, cansado da estrada." % _n(u, destino), "%s chegou a %s." % [_n(u, eid), _n(u, destino)], "")
	else:
		r["texto"] = "A viagem não terminou como você esperava."
	return r


static func _pedir_trabalho(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var canto := _canto(n)
	if canto != "":
		s["canto"] = canto
	var alvo := _pessoa_citada(u, eid, texto)
	if alvo == "" and str(s["canto"]) != "":
		alvo = _dono_do_canto(u, eid, str(s["canto"]))
	if alvo == "":
		return _falha("Pedir trabalho a quem? Diga o nome, ou vá a um lugar onde alguém trabalhe (a forja, o mercado, o porto…).", "")
	if not _perto(u, eid, alvo):
		return _falha("%s não está aqui." % _n(u, alvo), "")
	if _patrao(u, eid) == alvo:
		return _falha("Já trabalho para %s." % _n(u, alvo), "")
	var t := Personalidade.tracos(u, alvo)
	var aceita := 0.3 + 0.3 * float(t["empatia"]) + 0.25 * Decisao.afinidade(u, alvo, eid) \
		+ 0.4 * Estado.valor_relacao(u, alvo, eid, "afeto") + 0.3 * Estado.valor_relacao(u, alvo, eid, "confianca") - 0.5 * Estado.valor_relacao(u, alvo, eid, "raiva")
	var ofi := oficio(u, alvo)
	if ofi != "" and habilidade(u, eid, ofi) > 0.3:
		aceita += 0.2
	var recusas: int = int(s.get("recusas", {}).get(alvo, 0))
	aceita += 0.12 * recusas  # insistir mostra vontade
	var rng := _rng(u, s, "trabalho" + alvo)
	var fs := _gastar(u, s, 1)
	if rng.randf() < aceita:
		var salario := 2.0 + 2.0 * habilidade(u, eid, ofi)
		var fid := _registrar(u, s, eid, "trabalho", "%s passou a trabalhar para %s%s." % [_n(u, eid), _n(u, alvo), (" como aprendiz de " + ofi) if ofi != "" and habilidade(u, eid, ofi) < 0.3 else ""],
			[eid, alvo], 0.25, [{"op": "vinculo", "quem": eid, "tipo": "mestres", "outro": alvo} if habilidade(u, eid, ofi) < 0.3 else {"op": "relacao", "de": eid, "para": alvo, "deltas": {"respeito": 0.05}},
				{"op": "relacao", "de": alvo, "para": eid, "deltas": {"confianca": 0.1}}, {"op": "relacao", "de": eid, "para": alvo, "deltas": {"confianca": 0.1}},
				{"op": "definir", "quem": eid, "chave": "patrao", "valor": alvo}, {"op": "definir", "quem": eid, "chave": "salario", "valor": salario}])
		var fala := ""
		if float(t["empatia"]) > 0.6:
			fala = "— Mãos a mais são sempre bem-vindas. Começa amanhã cedo."
		elif float(t["orgulho"]) > 0.6:
			fala = "— Vamos ver do que você é capaz. Se estragar alguma coisa, paga."
		else:
			fala = "— Pode ficar. Pago %d moedas por dia." % int(salario)
		_entrada(u, s, "acao", "Pedi trabalho a %s. %s" % [_n(u, alvo), fala], "%s pediu trabalho a %s, que aceitou. %s" % [_n(u, eid), _n(u, alvo), fala], fid)
		return {"ok": true, "texto": "%s pensa um pouco. %s" % [_n(u, alvo), fala], "fatos": fs + [fid]}
	var rec: Dictionary = s.get("recusas", {})
	rec[alvo] = int(rec.get(alvo, 0)) + 1
	s["recusas"] = rec
	var fala2 := "— Agora não tenho trabalho para mais um."
	if float(t["sociabilidade"]) < 0.35:
		fala2 = "%s nem levanta os olhos: — Não preciso de ninguém." % _n(u, alvo)
	elif float(t["prudencia"]) > 0.6:
		fala2 = "— Não conheço você. Volte quando alguém por aqui souber o seu nome."
	var fid2 := _registrar(u, s, eid, "recusa", "%s pediu trabalho a %s e ouviu um não%s." % [_n(u, eid), _n(u, alvo), "" if recusas == 0 else " (pela %dª vez)" % (recusas + 1)], [eid, alvo], 0.1,
		[{"op": "relacao", "de": alvo, "para": eid, "deltas": {"confianca": 0.03}}])
	_entrada(u, s, "acao", "Pedi trabalho a %s. %s" % [_n(u, alvo), fala2], "%s pediu trabalho a %s. %s" % [_n(u, eid), _n(u, alvo), fala2], fid2)
	return {"ok": true, "texto": fala2, "fatos": fs + [fid2]}


static func _trabalhar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var canto := _canto(n)
	if canto != "":
		s["canto"] = canto
	var patrao := _patrao(u, eid)
	var ofi := oficio(u, patrao) if patrao != "" else oficio(u, eid)
	if patrao != "" and not _perto(u, eid, patrao) and Estado.vivo(u, patrao):
		return _falha("%s não está aqui; o trabalho é onde ele está." % _n(u, patrao), "")
	if patrao == "" and ofi == "":
		return _falha("Não tenho ofício nem patrão. Peço trabalho a alguém primeiro.", "")
	var dias := _duracao(n)
	var longo := dias >= 2
	if not longo:
		dias = 1
	var hab := habilidade(u, eid, ofi)
	var ganho := float(u.estado(eid).get("salario", 1.5 + 3.0 * hab)) if patrao != "" else (1.0 + 4.0 * hab) * clampf(Economia.preco(u, str(u.estado(eid)["local"])), 0.6, 2.0)
	var custo_vida := Economia.preco(u, str(u.estado(eid)["local"])) * 0.8
	var fs: Array = []
	if longo:
		fs.append_array(_passar_dias(u, s, dias))
		if not Estado.vivo(u, eid):
			return {"ok": true, "texto": "A vida de %s acabou no meio do trabalho." % _n(u, eid), "fatos": fs}
	else:
		fs.append_array(_gastar(u, s, 2))
		s["cansaco"] = float(s["cansaco"]) + 0.15
	var dias_reais := dias if longo else 1
	var liquido := ganho * dias_reais - (custo_vida * dias_reais if longo else 0.0)
	var aprende := 0.001 * dias_reais * (1.0 + float(Personalidade.tracos(u, eid)["curiosidade"]))
	var ops: Array = [{"op": "bens", "quem": eid, "dinheiro": liquido}, {"op": "habilidade", "quem": eid, "nome": ofi if ofi != "" else "trabalho", "delta": aprende}]
	if patrao != "":
		ops.append({"op": "relacao", "de": patrao, "para": eid, "deltas": {"confianca": 0.004 * dias_reais, "respeito": 0.003 * dias_reais}})
		ops.append({"op": "relacao", "de": eid, "para": patrao, "deltas": {"confianca": 0.003 * dias_reais, "afeto": 0.002 * dias_reais}})
	var quanto := "um dia" if dias_reais == 1 else _tempo(dias_reais)
	var onde := _no(str(s["canto"]), "na", "no") if str(s["canto"]) != "" else ("para " + _n(u, patrao) if patrao != "" else "no meu ofício")
	var fid := _registrar(u, s, eid, "trabalho", "%s trabalhou %s %s%s." % [_n(u, eid), quanto, onde.replace("meu", "seu"), (" e juntou %d moedas" % int(liquido)) if liquido >= 1 else ""],
		[eid] + ([patrao] if patrao != "" else []), 0.08 if dias_reais < 30 else 0.15, ops)
	fs.append(fid)
	var extra := ""
	if patrao != "" and dias_reais >= 20:
		extra = " " + _comentario_do_patrao(u, patrao, eid)
	_entrada(u, s, "acao", "Trabalhei %s %s. Ganhei %d moedas%s.%s" % [quanto, onde, int(ganho * dias_reais), (", gastei %d para viver" % int(custo_vida * dias_reais)) if longo else "", extra],
		"%s trabalhou %s %s.%s" % [_n(u, eid), quanto, onde.replace("meu", "seu"), extra], fid)
	return {"ok": true, "texto": "Você trabalha %s %s. Agora tem %d moedas.%s" % [quanto, onde, int(dinheiro(u, eid)), extra], "fatos": fs}


static func _comentario_do_patrao(u: Universo, patrao: String, eid: String) -> String:
	var t := Personalidade.tracos(u, patrao)
	var conf := Estado.valor_relacao(u, patrao, eid, "confianca")
	if conf > 0.5 and float(t["empatia"]) > 0.5:
		return "%s já me trata como se eu fosse da família." % _n(u, patrao)
	if conf > 0.4:
		return "%s já confia em mim para o trabalho mais fino." % _n(u, patrao)
	if float(t["orgulho"]) > 0.6:
		return "%s ainda acha defeito em tudo o que faço." % _n(u, patrao)
	return "%s quase não fala, mas paga em dia." % _n(u, patrao)


static func _conversar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var alvo := _pessoa_citada(u, eid, texto)
	if alvo == "" and str(s["canto"]) != "":
		alvo = _dono_do_canto(u, eid, str(s["canto"]))
	if alvo == "":
		return _falha("Falar com quem?", "")
	if not _perto(u, eid, alvo):
		return _falha("%s não está aqui." % _n(u, alvo), "")
	var convs: Dictionary = s["conversas"]
	if not convs.has(alvo) or Conversa.dados(u, str(convs[alvo])).is_empty():
		convs[alvo] = Conversa.nova(u, alvo, "personagem", eid)
	var cid: String = convs[alvo]
	# A fala: o que vem depois de "pergunto a Lucas", ou entre aspas.
	var fala := _fala(texto, alvo, u)
	var r := Conversa.perguntar(u, cid, fala if fala != "" else texto)
	var resposta: String = r["texto"]
	var ops: Array = [{"op": "relacao", "de": alvo, "para": eid, "deltas": {"confianca": 0.02, "afeto": 0.015}},
		{"op": "relacao", "de": eid, "para": alvo, "deltas": {"confianca": 0.02, "afeto": 0.015}}]
	# Conversa à toa: quem gosta de falar conta as novidades (do jeito que ouviu).
	var contou := ""
	if str(r["intencao"]) == "geral":
		var t := Personalidade.tracos(u, alvo)
		var aberto := float(r.get("abertura", 0.3))
		for f in Conversa._o_que_sabe(u, alvo):
			if Estado.conhece(u, eid, f["id"]) or f["dados"].get("secreto", false) or float(f["dados"].get("importancia", 0.0)) < 0.3:
				continue
			if float(t["sociabilidade"]) * 0.7 + aberto * 0.6 >= 0.35:
				contou = f["id"]
			break
		resposta = _papo(u, alvo, eid, aberto)
		if contou != "":
			resposta += " Ouviu a novidade? " + Conversa._maiuscula(str(u.fatos.obter(contou)["descricao"]))
			ops.append({"op": "conhecer", "quem": eid, "fato": contou})
	elif str(r["intencao"]) == "saber":
		for f in Conversa._o_que_sabe(u, alvo):
			if resposta.contains(str(f["descricao"])):
				ops.append({"op": "conhecer", "quem": eid, "fato": f["id"]})
	var fs := _gastar(u, s, 1)
	var fid := _registrar(u, s, eid, "conversa", "%s conversou com %s." % [_n(u, eid), _n(u, alvo)], [eid, alvo], 0.06, ops)
	fs.append(fid)
	# O que a conversa fez nascer (uma promessa, um pedido) vale: você está lá dentro.
	for p in Conversa.propostas(u, cid):
		var novo := u.aceitar_proposta(p["id"])
		if novo != "":
			fs.append(novo)
	var linha := "— %s" % resposta
	_entrada(u, s, "fala", "Conversei com %s. %s" % [_n(u, alvo), ("Perguntei: \"%s\". " % fala) if fala != "" else ""] + linha,
		"%s conversou com %s. %s" % [_n(u, eid), _n(u, alvo), linha], fid)
	return {"ok": true, "texto": "%s (%s)" % [linha, r["tom"]], "fatos": fs}


static func _papo(u: Universo, alvo: String, eid: String, aberto: float) -> String:
	var t := Personalidade.tracos(u, alvo)
	var lugar := str(u.estado(alvo).get("local", ""))
	var h := Humor.de(u, lugar) if lugar != "" else {"raiva": 0.2, "medo": 0.2, "alegria": 0.5}
	var ev := Natureza.eventos_ativos(u, lugar) if lugar != "" else []
	if not ev.is_empty():
		return "Com essa %s, ninguém dorme direito." % Natureza.EVENTOS.get(ev[0]["tipo"], {}).get("nome", ev[0]["tipo"])
	if not Guerras.lugares_em_guerra(u).is_empty() and Guerras.lugares_em_guerra(u).has(lugar):
		return "Dizem que a guerra chega aqui antes do inverno."
	if aberto < 0.2 and float(t["sociabilidade"]) < 0.4:
		return "Hm."
	if float(h["raiva"]) > 0.6:
		return "O povo anda com raiva. Isso não acaba bem."
	if float(h["medo"]) > 0.6:
		return "Ando com medo, para falar a verdade."
	var k := absi(hash(alvo + eid + str(DataMundo.ordem(u.relogio))))
	if float(t["sociabilidade"]) > 0.6:
		return ["Que bom ver você por aqui!", "Senta aí, me conta da vida.", "Você sumiu! Onde andava?", "Estava pensando em você esses dias."][k % 4]
	if float(t["empatia"]) > 0.6:
		return ["Você parece cansado. Tem comido direito?", "Precisando de alguma coisa, é só dizer.", "Bom dia para você também."][k % 3]
	return ["Dia comprido, não é?", "O tempo anda virando.", "Hm. Trabalho não falta.", "Tudo na mesma."][k % 4]


static func _comprar(u: Universo, s: Dictionary, eid: String, texto: String, n: String, lugar: String) -> Dictionary:
	var item := _coisa(_depois(texto, ["compro", "comprar"]))
	if item == "":
		return _falha("Comprar o quê?", "")
	var preco := ceilf(_preco(item) * Economia.preco(u, lugar))
	if dinheiro(u, eid) < preco:
		return _falha("Não tenho dinheiro: %s custa %d moedas aqui, e tenho %d." % [item, int(preco), int(dinheiro(u, eid))], "")
	var fs := _gastar(u, s, 1)
	var fid := _registrar(u, s, eid, "compra", "%s comprou %s por %s." % [_n(u, eid), _com_artigo(item), _moedas(preco)], [eid], 0.04,
		[{"op": "bens", "quem": eid, "dinheiro": -preco, "item": item, "qtd": 1}])
	_entrada(u, s, "acao", "Comprei %s por %s." % [_com_artigo(item), _moedas(preco)], "%s comprou %s." % [_n(u, eid), _com_artigo(item)], fid)
	return {"ok": true, "texto": "Você compra %s por %s (sobram %d)." % [_com_artigo(item), _moedas(preco), int(dinheiro(u, eid))], "fatos": fs + [fid]}


static func _vender(u: Universo, s: Dictionary, eid: String, texto: String, n: String, lugar: String) -> Dictionary:
	var item := _coisa(_depois(texto, ["vendo", "vender"]))
	var dono := _item_que_tem(u, eid, item)
	if dono == "":
		return _falha("Não tenho %s para vender." % (item if item != "" else "isso"), "")
	var preco := floorf(_preco(dono) * Economia.preco(u, lugar) * 0.6)
	var fs := _gastar(u, s, 1)
	var fid := _registrar(u, s, eid, "venda", "%s vendeu %s por %d moedas." % [_n(u, eid), _com_artigo(dono), int(preco)], [eid], 0.04,
		[{"op": "bens", "quem": eid, "dinheiro": preco, "item": dono, "qtd": -1}])
	_entrada(u, s, "acao", "Vendi %s por %d moedas." % [_com_artigo(dono), int(preco)], "%s vendeu %s." % [_n(u, eid), _com_artigo(dono)], fid)
	return {"ok": true, "texto": "Você vende %s por %d moedas." % [_com_artigo(dono), int(preco)], "fatos": fs + [fid]}


static func _presentear(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var alvo := _pessoa_citada(u, eid, texto)
	if alvo == "":
		return _falha("Dar a quem?", "")
	if not _perto(u, eid, alvo):
		return _falha("%s não está aqui." % _n(u, alvo), "")
	var resto := _depois(texto, ["dou de presente", "presenteio", "dou", "entrego", "ofereco", "ofereço"])
	var ops: Array = []
	var o_que := ""
	var num := Combate.ler_numero(resto)
	var tn := TextUtil.normalizar(resto)
	if tn.contains("moeda") or tn.contains("dinheiro"):
		var q := num if num > 0 else 5.0
		if dinheiro(u, eid) < q:
			return _falha("Não tenho %d moedas." % int(q), "")
		ops.append({"op": "bens", "quem": eid, "dinheiro": -q})
		ops.append({"op": "bens", "quem": alvo, "dinheiro": q})
		o_que = "%d moedas" % int(q)
	else:
		var item := _item_que_tem(u, eid, _coisa(resto.split(" a ")[0].split(" para ")[0]))
		if item == "":
			return _falha("Não tenho isso para dar.", "")
		ops.append({"op": "bens", "quem": eid, "item": item, "qtd": -1})
		ops.append({"op": "bens", "quem": alvo, "item": item, "qtd": 1})
		o_que = _com_artigo(item)
	var t := Personalidade.tracos(u, alvo)
	var afeto := 0.08 + 0.1 * float(t["empatia"]) - 0.06 * float(t["orgulho"])
	ops.append({"op": "relacao", "de": alvo, "para": eid, "deltas": {"afeto": afeto, "confianca": 0.04}})
	var fs := _gastar(u, s, 1)
	var fid := _registrar(u, s, eid, "presente", "%s deu %s a %s." % [_n(u, eid), o_que, _n(u, alvo)], [eid, alvo], 0.12, ops)
	var reacao := "%s sorri, sem jeito." % _n(u, alvo) if float(t["empatia"]) > 0.5 else ("%s aceita, desconfiado." % _n(u, alvo) if float(t["prudencia"]) > 0.6 else "%s agradece com a cabeça." % _n(u, alvo))
	_entrada(u, s, "acao", "Dei %s a %s. %s" % [o_que, _n(u, alvo), reacao], "%s deu %s a %s. %s" % [_n(u, eid), o_que, _n(u, alvo), reacao], fid)
	return {"ok": true, "texto": reacao, "fatos": fs + [fid]}


static func _comer(u: Universo, s: Dictionary, eid: String, lugar: String) -> Dictionary:
	var item := ""
	for k in bens(u, eid)["itens"]:
		if TextUtil.normalizar(k) in ["pao", "comida", "refeicao", "queijo", "fruta", "carne", "peixe"]:
			item = k
	var fs := _gastar(u, s, 0)
	var fid := ""
	if item != "":
		fid = _registrar(u, s, eid, "refeição", "%s comeu %s." % [_n(u, eid), _com_artigo(item)], [eid], 0.02, [{"op": "bens", "quem": eid, "item": item, "qtd": -1}])
	else:
		var p := ceilf(Economia.preco(u, lugar))
		if dinheiro(u, eid) < p:
			return _falha("Não tenho nada para comer, nem dinheiro para comprar.", "")
		fid = _registrar(u, s, eid, "refeição", "%s pagou %s por uma refeição." % [_n(u, eid), _moedas(p)], [eid], 0.02, [{"op": "bens", "quem": eid, "dinheiro": -p}])
	s["fome"] = 0.0
	_entrada(u, s, "corpo", "Comi.", "%s comeu." % _n(u, eid), fid)
	return {"ok": true, "texto": "Você come e a fome passa.", "fatos": fs + [fid]}


static func _dormir(u: Universo, s: Dictionary, eid: String) -> Dictionary:
	var partes := 3 - int(s["parte"])
	var fs := _gastar(u, s, partes)
	s["cansaco"] = 0.0
	var ops: Array = []
	if Estado.saude_atual(u, eid) < 0.95:
		ops.append({"op": "curar", "quem": eid, "quanto": 0.04})
	if not ops.is_empty():
		fs.append(_registrar(u, s, eid, "descanso", "%s descansou e se recuperou um pouco." % _n(u, eid), [eid], 0.03, ops))
	_entrada(u, s, "corpo", "Dormi até o dia seguinte.", "%s dormiu." % _n(u, eid), "")
	return {"ok": true, "texto": "Você dorme. Amanhece em %s." % DataMundo.texto(_agora(u, s)), "fatos": fs}


static func _treinar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var mestre := _pessoa_citada(u, eid, texto)
	if mestre != "" and not _perto(u, eid, mestre):
		return _falha("%s não está aqui para me ensinar." % _n(u, mestre), "")
	var o_que := _coisa(_depois(texto, ["treino", "treinar", "estudo", "estudar", "pratico", "praticar", "aprendo", "aprender"]).split(" com ")[0].split(" durante ")[0].split(" por ")[0])
	if o_que == "":
		o_que = oficio(u, mestre) if mestre != "" else "luta"
	var dias := maxi(_duracao(n), 1)
	var fs: Array = []
	if dias >= 2:
		fs.append_array(_passar_dias(u, s, dias))
	else:
		fs.append_array(_gastar(u, s, 2))
		s["cansaco"] = float(s["cansaco"]) + 0.12
	if not Estado.vivo(u, eid):
		return {"ok": true, "texto": "", "fatos": fs}
	var ritmo := 0.002 * (1.0 + float(Personalidade.tracos(u, eid)["curiosidade"])) * (2.0 if mestre != "" else 1.0)
	var ops: Array = [{"op": "habilidade", "quem": eid, "nome": o_que, "delta": ritmo * dias}]
	if o_que in ["luta", "espada", "armas", "combate", "arco"]:
		ops.append({"op": "mudar", "quem": eid, "chave": "poder", "delta": 0.002 * dias})
	if mestre != "":
		ops.append({"op": "relacao", "de": eid, "para": mestre, "deltas": {"respeito": 0.01 * dias}})
		ops.append({"op": "relacao", "de": mestre, "para": eid, "deltas": {"afeto": 0.005 * dias}})
	var fid := _registrar(u, s, eid, "treino", "%s treinou %s %s%s." % [_n(u, eid), o_que, "um dia" if dias == 1 else _tempo(dias), (" com " + _n(u, mestre)) if mestre != "" else ""],
		[eid] + ([mestre] if mestre != "" else []), 0.1, ops)
	fs.append(fid)
	_entrada(u, s, "acao", "Treinei %s %s%s." % [o_que, "um dia" if dias == 1 else _tempo(dias), (" com " + _n(u, mestre)) if mestre != "" else ""], "%s treinou %s." % [_n(u, eid), o_que], fid)
	return {"ok": true, "texto": "Você treina %s. Agora: %s." % [o_que, _nivel(habilidade(u, eid, o_que))], "fatos": fs}


static func _explorar(u: Universo, s: Dictionary, eid: String) -> Dictionary:
	var aqui := str(u.estado(eid).get("local", ""))
	var mapa := Mapa.pai(u, aqui)
	var conhece := conhecidos(u, eid)
	var p0 := Mapa.posicao(u, aqui)
	var melhor := ""
	var melhor_d := 9999.0
	for x in Mapa.filhos(u, mapa) + Mapa.filhos(u, aqui):
		if conhece.has(x) or x == aqui:
			continue
		var p := Mapa.posicao(u, x)
		var d := Vector2(float(p.get("x", 0)), float(p.get("y", 0))).distance_to(Vector2(float(p0.get("x", 0)), float(p0.get("y", 0)))) if Mapa.pai(u, x) == mapa else 0.5
		if d < melhor_d:
			melhor_d = d
			melhor = x
	var fs := _gastar(u, s, 2)
	s["cansaco"] = float(s["cansaco"]) + 0.1
	if melhor == "" or melhor_d > 14.0:
		_entrada(u, s, "acao", "Andei pelos arredores; nada de novo.", "%s andou pelos arredores." % _n(u, eid), "")
		return {"ok": true, "texto": "Você anda pelos arredores e não encontra nada que já não conhecesse.", "fatos": fs}
	var fid := _registrar(u, s, eid, "descoberta", "%s descobriu %s." % [_n(u, eid), _n(u, melhor)], [eid, melhor], 0.12, [], aqui, {"descobre": melhor})
	fs.append(fid)
	var desc := str(u.entidade(melhor).get("tipo", ""))
	_entrada(u, s, "acao", "Explorando os arredores, encontrei %s." % _n(u, melhor), "%s descobriu %s." % [_n(u, eid), _n(u, melhor)], fid)
	return {"ok": true, "texto": "Explorando, você encontra %s%s." % [_n(u, melhor), (" — " + desc) if desc != "" else ""], "fatos": fs}


static func _construir(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var resto := _depois(texto, ["construo", "construir", "ergo", "levanto", "edifico"])
	var coisa := _coisa(resto.split(" perto ")[0].split(" na ")[0].split(" no ")[0].split(" em ")[0].split(" ao lado")[0].split(",")[0])
	if coisa == "":
		return _falha("Construir o quê?", "")
	var chave := ""
	for k in OBRAS:
		if TextUtil.normalizar(coisa).contains(k):
			chave = k
	var base: Array = OBRAS.get(chave, [50, 60])
	var hab := 0.0
	var of := TextUtil.normalizar(oficio(u, eid))
	for w in OFICIOS_DE_OBRA:
		if of.contains(w):
			hab = 0.5
	hab = maxf(hab, habilidade(u, eid, "construir"))
	var custo := float(base[0]) * Economia.preco(u, str(u.estado(eid)["local"]))
	var dias := int(ceil(float(base[1]) * (1.2 - hab)))
	if dinheiro(u, eid) < custo:
		return _falha("Para construir %s preciso de umas %d moedas em material; tenho %d. Melhor juntar mais (trabalhando)." % [_com_artigo(coisa), int(custo), int(dinheiro(u, eid))], "")
	var aqui := str(u.estado(eid)["local"])
	var inicio := _registrar(u, s, eid, "obra", "%s começou a construir %s em %s." % [_n(u, eid), _com_artigo(coisa), _n(u, aqui)], [eid, aqui], 0.2,
		[{"op": "bens", "quem": eid, "dinheiro": -custo}], aqui)
	_entrada(u, s, "acao", "Comprei o material e comecei a construir %s. Vai levar uns %s." % [_com_artigo(coisa), _tempo(dias)], "%s começou a construir %s." % [_n(u, eid), _com_artigo(coisa)], inicio)
	var fs: Array = [inicio]
	fs.append_array(_passar_dias(u, s, dias))
	if not Estado.vivo(u, eid):
		return {"ok": true, "texto": "A obra ficou pela metade.", "fatos": fs}
	var detalhe := ""
	var dn := TextUtil.normalizar(resto)
	for w in [" perto ", " na ", " no ", " ao lado", " em "]:
		var i := dn.find(w)
		if i >= 0:
			detalhe = resto.substr(i).strip_edges()
			break
	var nome := "%s de %s" % [Conversa._maiuscula(coisa), _n(u, eid).split(" ")[0]]
	var nova := u.criar_entidade(nome, coisa, [], [{"chave": "dono", "valor": _n(u, eid)}, {"chave": "construída por", "valor": _n(u, eid)}]
		+ ([{"chave": "onde", "valor": detalhe}] if detalhe != "" else []), [inicio])
	var p := Mapa.posicao(u, aqui)
	if not p.is_empty():
		Mapa.colocar(u, nova, Mapa.pai(u, aqui), int(p.get("x", 0)), int(p.get("y", 0)), false)
	var fim := _registrar(u, s, eid, "construção", "%s terminou de construir %s%s." % [_n(u, eid), _com_artigo(coisa), (" " + detalhe) if detalhe != "" else ""], [eid, nova, aqui], 0.3,
		[{"op": "habilidade", "quem": eid, "nome": "construir", "delta": 0.05}], aqui)
	fs.append(fim)
	s["canto"] = ""
	_entrada(u, s, "acao", "Terminei %s%s. É minha." % [_com_artigo(coisa), (" " + detalhe) if detalhe != "" else ""], "%s terminou %s." % [_n(u, eid), _com_artigo(coisa)], fim)
	return {"ok": true, "texto": "Depois de %s, %s está de pé. Ela tem página na wiki: %s." % [_tempo(dias), _com_artigo(coisa), nome], "fatos": fs, "criou": nova}


static func _ajudar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var alvo := _pessoa_citada(u, eid, texto)
	if alvo == "":
		return _falha("Ajudar quem?", "")
	if not _perto(u, eid, alvo):
		return _falha("%s não está aqui." % _n(u, alvo), "")
	var t := Personalidade.tracos(u, alvo)
	var ops: Array = [{"op": "relacao", "de": alvo, "para": eid, "deltas": {"afeto": 0.06 + 0.06 * float(t["empatia"]), "confianca": 0.06 + 0.04 * float(t["lealdade"])}}]
	var o_que := "ajudou"
	if Estado.saude_atual(u, alvo) < 0.9:
		ops.append({"op": "curar", "quem": alvo, "quanto": 0.08})
		o_que = "cuidou de"
	var fs := _gastar(u, s, 2)
	var fid := _registrar(u, s, eid, "ajuda", "%s %s %s." % [_n(u, eid), o_que, _n(u, alvo)], [eid, alvo], 0.15, ops)
	var reacao := "%s agradece de coração." % _n(u, alvo) if float(t["empatia"]) > 0.5 else ("%s não agradece; orgulhoso demais." % _n(u, alvo) if float(t["orgulho"]) > 0.65 else "%s acena, agradecido." % _n(u, alvo))
	_entrada(u, s, "acao", "%s %s. %s" % ["Cuidei de" if o_que == "cuidou de" else "Ajudei", _n(u, alvo), reacao], "%s %s %s. %s" % [_n(u, eid), o_que, _n(u, alvo), reacao], fid)
	_testemunhas(u, eid, alvo, fid, {"afeto": 0.03})
	return {"ok": true, "texto": reacao, "fatos": fs + [fid]}


static func _atacar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var alvo := _pessoa_citada(u, eid, texto)
	if alvo == "" or not Estado.tem_mente(u, alvo):
		return _falha("Atacar quem?", "")
	if not _perto(u, eid, alvo):
		return _falha("%s não está aqui." % _n(u, alvo), "")
	if Estado.saude_atual(u, eid) < 0.25:
		return _falha("Mal paro em pé; não tenho como lutar agora.", "")
	var ate_morte := n.contains(" mato ") or n.contains(" matar ")
	var rng := _rng(u, s, "luta" + alvo)
	var causa := _registrar(u, s, eid, "agressão", "%s atacou %s." % [_n(u, eid), _n(u, alvo)], [eid, alvo], 0.4,
		[{"op": "relacao", "de": alvo, "para": eid, "deltas": {"raiva": 0.5, "confianca": -0.4}}])
	var ids := Decisao._confronto(u, eid, alvo, [causa], {}, rng, ate_morte)
	var fs := [causa] + ids
	fs.append_array(_gastar(u, s, 1))
	s["cansaco"] = float(s["cansaco"]) + 0.3
	var luta := u.fatos.obter(ids.back()) if not ids.is_empty() else {}
	var txt: String = luta.get("descricao", "A briga não deu em nada.")
	var venci: bool = not luta.is_empty() and luta["sujeitos"][0] == eid
	_entrada(u, s, "acao", ("Ataquei %s e venci." % _n(u, alvo)) if venci else ("Ataquei %s e perdi." % _n(u, alvo)), txt, ids.back() if not ids.is_empty() else causa)
	_testemunhas(u, eid, alvo, causa, {"medo": 0.15, "raiva": 0.1})
	return {"ok": true, "texto": txt, "fatos": fs}


static func _cortejar(u: Universo, s: Dictionary, eid: String, texto: String, n: String, casar: bool) -> Dictionary:
	var alvo := _pessoa_citada(u, eid, texto)
	if alvo == "":
		return _falha("Quem?", "")
	if not _perto(u, eid, alvo):
		return _falha("%s não está aqui." % _n(u, alvo), "")
	var impedido: Variant = Estado.familia_proxima(u, alvo).has(eid) or not Decisao._adulto(u, alvo) or not Decisao._adulto(u, eid) \
		or (not u.estado(alvo)["familia"]["conjuges"].is_empty() and not u.estado(alvo)["familia"]["conjuges"].has(eid))
	if impedido:
		var fid0 := _registrar(u, s, eid, "recusa", "%s se declarou a %s, que recusou." % [_n(u, eid), _n(u, alvo)], [eid, alvo], 0.15, [])
		_entrada(u, s, "acao", "Me declarei a %s. Não pode ser." % _n(u, alvo), "%s se declarou a %s, sem sorte." % [_n(u, eid), _n(u, alvo)], fid0)
		return {"ok": true, "texto": "%s balança a cabeça: — Isso não pode ser." % _n(u, alvo), "fatos": [fid0]}
	var afeto := Estado.valor_relacao(u, alvo, eid, "afeto")
	var chance := 0.1 + 0.5 * afeto + 0.3 * Decisao.afinidade(u, alvo, eid) + 0.1 * Estado.valor_relacao(u, alvo, eid, "confianca")
	if Decisao._pode_se_apaixonar(u, alvo, eid):
		chance += 0.25  # há atração entre os dois
	for e in Estado.emocoes_atuais(u, alvo):
		if e["emocao"] == "amor" and e["alvo"] != eid and float(e["forca_atual"]) >= 0.3:
			chance -= 0.3  # o coração já tem dono
	var rng := _rng(u, s, "amor" + alvo)
	var fs := _gastar(u, s, 1)
	if casar:
		if afeto >= 0.45 and rng.randf() < chance + 0.2:
			var fid := Simulador.registrar(u, {"tipo": "casamento", "descricao": "%s e %s se casaram." % [_n(u, eid), _n(u, alvo)], "sujeitos": [eid, alvo],
				"lugar": str(u.estado(eid)["local"]), "data": _agora(u, s), "causas": [_ultimo_meu(u, eid)], "dados": {"acao": "casamento", "importancia": 0.7}})
			s["fatos"].append(fid)
			_entrada(u, s, "acao", "Pedi %s em casamento, e a resposta foi sim." % _n(u, alvo), "%s e %s se casaram." % [_n(u, eid), _n(u, alvo)], fid)
			return {"ok": true, "texto": "%s diz sim. Vocês se casam." % _n(u, alvo), "fatos": fs + [fid]}
		var fidn := _registrar(u, s, eid, "recusa", "%s pediu %s em casamento e ouviu um não." % [_n(u, eid), _n(u, alvo)], [eid, alvo], 0.25, [])
		_entrada(u, s, "acao", "Pedi %s em casamento. Ainda não." % _n(u, alvo), "%s pediu %s em casamento, sem sorte." % [_n(u, eid), _n(u, alvo)], fidn)
		return {"ok": true, "texto": "%s desvia os olhos: — É cedo demais." % _n(u, alvo), "fatos": fs + [fidn]}
	if rng.randf() < chance:
		var fid2 := _registrar(u, s, eid, "romance", "%s e %s se aproximaram." % [_n(u, eid), _n(u, alvo)], [eid, alvo], 0.3,
			[{"op": "relacao", "de": alvo, "para": eid, "deltas": {"afeto": 0.2}}, {"op": "relacao", "de": eid, "para": alvo, "deltas": {"afeto": 0.2}},
			 {"op": "emocao", "quem": alvo, "emocao": "amor", "forca": clampf(0.3 + afeto, 0.3, 0.9), "alvo": eid}])
		_entrada(u, s, "acao", "Me aproximei de %s, que sorriu." % _n(u, alvo), "%s e %s se aproximaram." % [_n(u, eid), _n(u, alvo)], fid2)
		return {"ok": true, "texto": "%s sorri e não se afasta." % _n(u, alvo), "fatos": fs + [fid2]}
	var fid3 := _registrar(u, s, eid, "recusa", "%s tentou se aproximar de %s." % [_n(u, eid), _n(u, alvo)], [eid, alvo], 0.1, [{"op": "relacao", "de": alvo, "para": eid, "deltas": {"confianca": 0.02}}])
	_entrada(u, s, "acao", "Tentei me aproximar de %s. Não deu." % _n(u, alvo), "%s tentou se aproximar de %s." % [_n(u, eid), _n(u, alvo)], fid3)
	return {"ok": true, "texto": "%s ri, sem levar a sério." % _n(u, alvo), "fatos": fs + [fid3]}


static func _rezar(u: Universo, s: Dictionary, eid: String, lugar: String) -> Dictionary:
	var fs := _gastar(u, s, 1)
	var raiva := Estado.emocoes_atuais(u, eid).filter(func(e): return str(e.get("emocao", "")) in ["raiva", "medo", "odio"])
	var fid := ""
	if not raiva.is_empty():
		fid = _registrar(u, s, eid, "prece", "%s rezou e encontrou um pouco de paz." % _n(u, eid), [eid], 0.05,
			[{"op": "esfriar_emocao", "quem": eid, "emocao": str(raiva[0]["emocao"]), "alvo": str(raiva[0].get("alvo", "")), "quanto": 0.1}])
		fs.append(fid)
	_entrada(u, s, "acao", "Rezei.", "%s rezou." % _n(u, eid), fid)
	return {"ok": true, "texto": "Você reza. %s" % ("O peito fica mais leve." if fid != "" else "O silêncio responde."), "fatos": fs}


static func _planejar(u: Universo, s: Dictionary, eid: String, texto: String) -> Dictionary:
	var desejo := _depois(texto, ["quero", "decido", "meu plano e", "meu plano é", "prometo a mim mesmo que", "juro que"])
	if desejo == "":
		desejo = texto
	var tipo := Objetivos.categoria(desejo)
	var alvo := _pessoa_citada(u, eid, desejo)
	if alvo == "":
		for m in Ligador.new(u).encontrar(desejo):
			if m["entidade"] != eid:
				alvo = m["entidade"]
				break
	var fid := _registrar(u, s, eid, "plano", "%s decidiu: %s." % [_n(u, eid), desejo], [eid] + ([alvo] if alvo != "" else []), 0.15,
		[{"op": "objetivo", "quem": eid, "tipo": tipo, "alvo": alvo, "forca": 0.7}], "", {"texto": desejo})
	_entrada(u, s, "pensamento", "Decidi: %s." % desejo, "%s decidiu: %s." % [_n(u, eid), desejo], fid)
	return {"ok": true, "texto": "Anotado como objetivo: %s." % desejo, "fatos": [fid]}


static func _esperar(u: Universo, s: Dictionary, eid: String, texto: String, n: String) -> Dictionary:
	var dias := _duracao(n)
	if Viagens.viajando(u, eid):
		dias = maxi(dias, int(u.estado(eid)["viagem"]["chega"]) - DataMundo.ordem(_agora(u, s)) + 1)
	if dias < 1:
		dias = 1
	# Quem tem trabalho e escreve "trabalhando" passa o tempo no ofício.
	if (n.contains("trabalhando") or n.contains("no trabalho")) and (_patrao(u, eid) != "" or oficio(u, eid) != ""):
		return _trabalhar(u, s, eid, texto, n + " durante %d dias " % dias)
	var custo := Economia.preco(u, str(u.estado(eid).get("local", ""))) * 0.8 * dias
	var fs := _passar_dias(u, s, dias)
	if not Estado.vivo(u, eid):
		return {"ok": true, "texto": "", "fatos": fs}
	var gasto := minf(custo, dinheiro(u, eid))
	if gasto >= 1.0:
		fs.append(_registrar(u, s, eid, "gastos", "%s gastou %d moedas para viver." % [_n(u, eid), int(gasto)], [eid], 0.02, [{"op": "bens", "quem": eid, "dinheiro": -gasto}]))
	if custo - gasto > 3.0:
		fs.append(_registrar(u, s, eid, "fome", "%s passou fome." % _n(u, eid), [eid], 0.2, [{"op": "ferir", "quem": eid, "descricao": "fraqueza de fome", "gravidade": 0.08}]))
		_entrada(u, s, "corpo", "Faltou dinheiro; passei fome.", "%s passou fome." % _n(u, eid), fs.back())
	_entrada(u, s, "acao", "Deixei %s passar." % _tempo(dias), "%s deixou %s passar." % [_n(u, eid), _tempo(dias)], "")
	return {"ok": true, "texto": "%s se passam." % Conversa._maiuscula(_tempo(dias)), "fatos": fs}


static func _poder(u: Universo, s: Dictionary, eid: String, texto: String) -> Dictionary:
	var meus := Poderes.de(u, eid)
	if meus.is_empty():
		return _falha("Não tenho poder nenhum.", "")
	var pid: String = meus[0]
	var alvo := ""
	for m in Ligador.new(u).encontrar(texto):
		if meus.has(m["entidade"]):
			pid = m["entidade"]
		elif m["entidade"] != eid and Estado.tem_mente(u, m["entidade"]):
			alvo = m["entidade"]
	if not Poderes.pode_usar(u, eid, pid):
		return _falha("Não consigo usar %s agora." % _n(u, pid), "")
	var r := Poderes.usar(u, eid, pid, alvo, [_ultimo_meu(u, eid)])
	var fs: Array = r["fatos"]
	s["fatos"].append_array(fs)
	fs.append_array(_gastar(u, s, 1))
	var txt := str(u.fatos.obter(fs[0]).get("descricao", "")) if not fs.is_empty() else ""
	_entrada(u, s, "acao", "Usei %s%s." % [_n(u, pid), (" contra " + _n(u, alvo)) if alvo != "" else ""], txt, fs[0] if not fs.is_empty() else "")
	return {"ok": true, "texto": txt + (" (o autor decide o efeito)" if str(r.get("pedido", "")) != "" else ""), "fatos": fs}


static func _outro(u: Universo, s: Dictionary, eid: String, texto: String) -> Dictionary:
	var fs := _gastar(u, s, 1)
	var desc := texto.strip_edges().trim_suffix(".")
	var fid := _registrar(u, s, eid, "ação", "%s: \"%s\"." % [_n(u, eid), desc], [eid], 0.05, [], "", {"texto": desc})
	_entrada(u, s, "acao", Conversa._maiuscula(desc) + ".", "%s: \"%s\"." % [_n(u, eid), desc], fid)
	return {"ok": true, "texto": "Feito. (Não sei o efeito disso no mundo; ficou registrado como ação dele.)", "fatos": fs + [fid]}


# ---------------------------------------------------------------- tempo

## Gasta partes do dia (manhã, tarde, noite). A cada dia, fome e cansaço; a cada
## semana, o resto do mundo anda.
static func _gastar(u: Universo, s: Dictionary, partes: int) -> Array:
	s["parte"] = int(s["parte"]) + partes
	s["fome"] = clampf(float(s["fome"]) + 0.12 * partes, 0.0, 1.2)
	s["cansaco"] = clampf(float(s["cansaco"]) + 0.08 * partes, 0.0, 1.2)
	var dias := int(s["parte"]) / 3
	s["parte"] = int(s["parte"]) % 3
	var fs: Array = []
	if dias > 0:
		s["pendente"] = int(s["pendente"]) + dias
		if int(s["pendente"]) >= Simulador.PASSO_DIAS:
			fs.append_array(_soltar_mundo(u, s))
	# Fome demais vira fraqueza (um fato).
	if float(s["fome"]) >= 1.0:
		var eid: String = s["quem"]
		fs.append(_registrar(u, s, eid, "fome", "%s passou o dia sem comer." % _n(u, eid), [eid], 0.1, [{"op": "ferir", "quem": eid, "descricao": "fraqueza de fome", "gravidade": 0.04}]))
		s["fome"] = 0.7
	return fs


## Tempo longo resumido: o mundo anda tudo de uma vez.
static func _passar_dias(u: Universo, s: Dictionary, dias: int) -> Array:
	s["pendente"] = int(s["pendente"]) + dias
	s["fome"] = 0.3
	s["cansaco"] = 0.3
	return _soltar_mundo(u, s)


## O mundo alcança o personagem: anda os dias pendentes e o diário recebe o que chegou até ele.
static func _soltar_mundo(u: Universo, s: Dictionary) -> Array:
	var d := int(s["pendente"])
	s["pendente"] = 0
	if d <= 0:
		return []
	var antes := Acompanhar._ultimo_seq(u)
	var novos := Simulador.avancar(u, d)
	_absorver(u, s, antes)
	return novos


## O que chegou até ele enquanto o mundo andava: o que fizeram com ele, o que
## aconteceu ali, as notícias que chegaram (boatos incluídos).
static func _absorver(u: Universo, s: Dictionary, antes: int) -> void:
	var eid: String = s["quem"]
	var local := str(u.estado(eid).get("local", ""))
	var n := 0
	for f in u.fatos.todos():
		if int(f["seq"]) <= antes or not f["canon"] or n >= 6:
			continue
		if s["fatos"].has(f["id"]):
			continue
		var dele: bool = f["sujeitos"].has(eid) and f["tipo"] != "posses"
		var aqui: bool = local != "" and f["lugar"] == local and not f["tipo"] in ["notícia", "rumor"] and float(f["dados"].get("importancia", 0.0)) >= 0.3
		var noticia: bool = f["tipo"] in ["notícia", "rumor"] and f["lugar"] == local and float(f["dados"].get("importancia", 0.0)) >= 0.25
		if dele:
			_entrada(u, s, "mundo", _eu_texto(u, eid, f["descricao"]), f["descricao"], f["id"])
			n += 1
		elif aqui:
			_entrada(u, s, "mundo", "Aqui em %s: %s" % [_n(u, local), f["descricao"]], "Em %s: %s" % [_n(u, local), f["descricao"]], f["id"])
			n += 1
		elif noticia:
			var orig := u.fatos.obter(str(f["dados"].get("noticia_de", "")))
			var txt := str(f["descricao"]) if f["tipo"] == "rumor" or orig.is_empty() else str(orig["descricao"])
			_entrada(u, s, "noticia", "Ouvi dizer: %s" % txt, "%s ouviu dizer: %s" % [_n(u, eid), txt], f["id"])
			n += 1
	s["visto_seq"] = Acompanhar._ultimo_seq(u)


## A data em que o personagem está (o mundo anda em semanas; ele, dia a dia).
static func _agora(u: Universo, s: Dictionary) -> Dictionary:
	return _de_ordem(DataMundo.ordem(u.relogio) + int(s.get("pendente", 0)))


static func _de_ordem(ordem: int) -> Dictionary:
	var ano := int(floor(float(ordem - 1) / DataMundo.DIAS_POR_ANO))
	return DataMundo.criar(ano, ordem - ano * DataMundo.DIAS_POR_ANO)


static func _duracao(n: String) -> int:
	var t := " " + n + " "
	var num := 1
	var rx := RegEx.new()
	rx.compile("(\\d+)\\s*(dia|semana|mes|meses|ano|estac)")
	var m := rx.search(t)
	var unidades := {"dia": 1, "semana": 7, "mes": 30, "meses": 30, "ano": DataMundo.DIAS_POR_ANO, "estac": 90}
	if m != null:
		return int(m.get_string(1)) * int(unidades[m.get_string(2)])
	var palavras := {"dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8, "dez": 10, "uns": 3, "alguns": 3, "algumas": 3}
	for p in palavras:
		for un in ["dias", "semanas", "meses", "anos"]:
			if t.contains(" %s %s" % [p, un]):
				num = int(palavras[p])
				return num * {"dias": 1, "semanas": 7, "meses": 30, "anos": DataMundo.DIAS_POR_ANO}[un]
	for par in [["um ano", DataMundo.DIAS_POR_ANO], ["o ano", DataMundo.DIAS_POR_ANO], ["um mes", 30], ["o mes", 30], ["uma semana", 7], ["a semana", 7], ["o inverno", 90], ["o verao", 90],
			["a primavera", 90], ["o outono", 90], ["uma estacao", 90], ["a estacao", 90], ["o dia todo", 1], ["um dia", 1], ["quinze dias", 15], ["uma quinzena", 15]]:
		if t.contains(" " + par[0]):
			return int(par[1])
	return 0


static func _tempo(dias: int) -> String:
	if dias >= DataMundo.DIAS_POR_ANO:
		var a := roundi(float(dias) / DataMundo.DIAS_POR_ANO)
		return "um ano" if a == 1 else "%d anos" % a
	if dias >= 28:
		var m := roundi(dias / 30.0)
		return "um mês" if m == 1 else "%d meses" % m
	if dias >= 7 and dias % 7 == 0:
		return "uma semana" if dias == 7 else "%d semanas" % (dias / 7)
	return "um dia" if dias == 1 else "%d dias" % dias


# ---------------------------------------------------------------- fatos e diário

static func _registrar(u: Universo, s: Dictionary, eid: String, tipo: String, desc: String, sujeitos: Array, imp: float, ops: Array, lugar: String = "", extra: Dictionary = {}) -> String:
	var dados := {"importancia": imp, "mudancas": ops, "vivido": true}
	dados.merge(extra)
	var fid := Simulador.registrar(u, {"tipo": tipo, "descricao": desc, "sujeitos": sujeitos, "lugar": lugar if lugar != "" else str(u.estado(eid).get("local", "")),
		"data": _agora(u, s), "causas": [_ultimo_meu(u, eid)], "dados": dados})
	if fid != "":
		s["fatos"].append(fid)
	return fid


## A causa de cada ação: o que ele fez por último (ou o que o pôs onde está).
static func _ultimo_meu(u: Universo, eid: String) -> String:
	var s := sessao(u, eid)
	if not s.is_empty():
		for i in range(s["fatos"].size() - 1, -1, -1):
			if u.fatos.existe(s["fatos"][i]) and u.fatos.obter(s["fatos"][i])["canon"]:
				return s["fatos"][i]
	return Simulador.causa_de_presenca(u, eid)


static func _entrada(u: Universo, s: Dictionary, tipo: String, eu: String, ele: String, fid: String) -> void:
	s["diario"].append({"data": _agora(u, s), "parte": PARTES[int(s["parte"])], "tipo": tipo, "eu": eu, "ele": ele, "fato": fid})


## O texto do fato contado por ele ("Lucas foi ferido por Kai" → "Fui ferido por Kai").
static func _eu_texto(u: Universo, eid: String, desc: String) -> String:
	var nome := _n(u, eid)
	if desc.begins_with(nome + " "):
		return Conversa._maiuscula(Conversa._eu(desc.substr(nome.length() + 1)))
	for par in [[" com " + nome, " comigo"], [" a " + nome, " a mim"], [" de " + nome, " de mim"], [" para " + nome, " para mim"], [" e " + nome, " e eu"]]:
		desc = desc.replace(par[0], par[1])
	return desc.replace(nome, "eu")


static func diario(u: Universo, eid: String = "") -> Array:
	return sessao(u, eid).get("diario", [])


## A sessão vira capítulo: o diário em primeira ou terceira pessoa, num livro "Vidas".
## Os fatos já existem (o capítulo não é reanalisado para não duplicar nada).
static func virar_capitulo(u: Universo, titulo: String = "", voz: String = "") -> String:
	var eid := encarnado(u)
	if eid == "":
		for k in sessoes(u):
			eid = k
	var s := sessao(u, eid)
	if s.is_empty():
		return ""
	_soltar_mundo(u, s)
	var v: String = voz if voz != "" else str(s["voz"])
	var livro := ""
	for l in u.livros:
		if l["titulo"] == "Vidas":
			livro = l["id"]
	if livro == "":
		livro = u.criar_livro("Vidas")
	var inicio: Dictionary = s["inicio_data"]
	var fim := _agora(u, s)
	var t := titulo if titulo != "" else "A vida de %s (%s — %s)" % [_n(u, eid), DataMundo.texto(inicio), DataMundo.texto(fim)]
	var cap := u.criar_capitulo(livro, t)
	var linhas: Array = []
	var dia := ""
	var paragrafo: Array = []
	for x in s["diario"]:
		var d := DataMundo.texto(x["data"])
		if d != dia:
			if not paragrafo.is_empty():
				linhas.append(" ".join(paragrafo))
				paragrafo = []
			linhas.append("\n%s" % d)
			dia = d
		var frase := str(x["eu"] if v == "primeira" else x["ele"])
		if frase != "":
			paragrafo.append(frase)
	if not paragrafo.is_empty():
		linhas.append(" ".join(paragrafo))
	u.atualizar_capitulo(cap, {"texto": "\n".join(linhas).strip_edges(), "data": inicio})
	u.capitulos[cap]["vivido"] = {"quem": eid, "fatos": s["fatos"].duplicate()}
	return cap


# ---------------------------------------------------------------- o que ele vê

## Lugares que ele conhece: onde está e esteve, a vizinhança de casa, os que
## descobriu e aqueles de que ouviu falar.
static func conhecidos(u: Universo, eid: String) -> Dictionary:
	var r := {}
	var aqui := str(u.estado(eid).get("local", ""))
	if Viagens.viajando(u, eid):
		aqui = str(u.estado(eid)["viagem"]["de"])
	if aqui != "":
		r[aqui] = "aqui"
		for a in Mapa.ancestrais(u, aqui):
			r[a] = "de onde é"
		for f in Mapa.filhos(u, aqui):
			r[f] = "vizinhança"
		# A vizinhança que todo morador conhece.
		var p0 := Mapa.posicao(u, aqui)
		var mapa := Mapa.pai(u, aqui)
		for x in Mapa.filhos(u, mapa):
			var p := Mapa.posicao(u, x)
			if p.is_empty() or p0.is_empty():
				continue
			if Vector2(float(p["x"]), float(p["y"])).distance_to(Vector2(float(p0["x"]), float(p0["y"]))) <= 4.0:
				if not r.has(x):
					r[x] = "vizinhança"
	for f in u.fatos.sobre(eid):
		if not f["canon"]:
			continue
		var l := str(f["lugar"])
		if l != "" and not r.has(l):
			r[l] = "esteve lá"
		var d := str(f["dados"].get("descobre", ""))
		if d != "":
			r[d] = "descobriu"
	for fid in u.estado(eid).get("conhece", {}):
		var f := u.fatos.obter(fid)
		if f.is_empty():
			continue
		for x in [str(f["lugar"])] + Array(f["sujeitos"]):
			if x != "" and u.entidades.has(x) and Mapa.e_lugar(u, x) and not r.has(x):
				r[x] = "ouviu falar"
	return r


## As células do mapa que ele enxerga (o resto fica em névoa).
static func visao(u: Universo, eid: String, mapa: String) -> Dictionary:
	var vis := {}
	var con := conhecidos(u, eid)
	for x in con:
		if Mapa.pai(u, x) != mapa:
			continue
		var p := Mapa.posicao(u, x)
		if p.is_empty():
			continue
		var raio := 3 if con[x] in ["aqui", "esteve lá", "descobriu"] else 1
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				if dx * dx + dy * dy <= raio * raio + 1:
					vis[Vector2i(int(p["x"]) + dx, int(p["y"]) + dy)] = true
	return vis


## A ficha do momento: saúde, cansaço, fome, dinheiro, humor, poderes, ferimentos.
static func ficha(u: Universo, eid: String) -> Dictionary:
	var s := sessao(u, eid)
	var emo := Estado.emocoes_atuais(u, eid)
	var humor := "tranquilo"
	if not emo.is_empty():
		emo.sort_custom(func(a, b): return Estado.forca_emocao(u, eid, a) > Estado.forca_emocao(u, eid, b))
		humor = str(emo[0].get("emocao", "tranquilo"))
		if str(emo[0].get("alvo", "")) != "" and u.entidades.has(str(emo[0]["alvo"])):
			humor += " (" + _n(u, str(emo[0]["alvo"])) + ")"
	var hab: Dictionary = u.estado(eid).get("habilidades", {})
	var of := oficio(u, eid)
	var lista: Array = []
	if of != "":
		lista.append("%s: %s" % [of, _nivel(habilidade(u, eid, of))])
	for k in hab:
		if of == "" or TextUtil.normalizar(k).substr(0, 5) != TextUtil.normalizar(of).substr(0, 5):
			lista.append("%s: %s" % [k, _nivel(habilidade(u, eid, k))])
	return {"saude": Estado.saude_atual(u, eid), "cansaco": float(s.get("cansaco", 0.0)), "fome": float(s.get("fome", 0.0)),
		"dinheiro": dinheiro(u, eid), "humor": humor, "poderes": Poderes.de(u, eid).map(func(p): return _n(u, p)),
		"ferimentos": [] if Estado.saude_atual(u, eid) >= 0.95 else u.estado(eid).get("ferimentos", []).map(func(f): return str(f.get("descricao", f)) if f is Dictionary else str(f)),
		"itens": bens(u, eid)["itens"], "habilidades": lista, "oficio": of, "idade": Estado.idade(u, eid),
		"patrao": _patrao(u, eid), "vivo": Estado.vivo(u, eid)}


## Notícias locais: só o que chegou até ele, do jeito que chegou.
static func noticias(u: Universo, eid: String, limite: int = 12) -> Array:
	var r: Array = []
	var local := str(u.estado(eid).get("local", ""))
	var conhece: Dictionary = u.estado(eid).get("conhece", {})
	var todos := u.fatos.todos()
	for i in range(todos.size() - 1, -1, -1):
		var f: Dictionary = todos[i]
		if r.size() >= limite:
			break
		if not f["canon"]:
			continue
		if f["tipo"] in ["notícia", "rumor"] and f["lugar"] == local:
			var orig := u.fatos.obter(str(f["dados"].get("noticia_de", "")))
			r.append({"data": f["data"], "texto": str(f["descricao"]) if f["tipo"] == "rumor" or orig.is_empty() else str(orig["descricao"]), "boato": f["tipo"] == "rumor", "fato": f["id"]})
		elif conhece.has(f["id"]) and not f["sujeitos"].has(eid) and f["lugar"] != local and float(f["dados"].get("importancia", 0.0)) >= 0.3 and not f["tipo"] in ["criação", "posses"]:
			r.append({"data": f["data"], "texto": f["descricao"], "boato": false, "fato": f["id"]})
	return r


## Quem ele conhece e o que sente por cada um.
static func relacoes(u: Universo, eid: String) -> Array:
	var r: Array = []
	var rels: Dictionary = u.estado(eid).get("relacoes", {})
	for outro in rels:
		if not u.entidades.has(outro):
			continue
		var p := Paginas._palavra_relacao(rels[outro])
		var fam := ""
		var f: Dictionary = u.estado(eid)["familia"]
		for k in [["pais", "pai ou mãe"], ["filhos", "filho"], ["conjuges", "cônjuge"], ["mestres", "mestre"]]:
			if f[k[0]].has(outro):
				fam = k[1]
		if p == "" and fam == "":
			continue
		r.append({"id": outro, "nome": _n(u, outro), "sente": p, "laco": fam, "vivo": Estado.vivo(u, outro)})
	r.sort_custom(func(a, b): return absf(_peso_rel(rels[a["id"]])) > absf(_peso_rel(rels[b["id"]])))
	return r


static func _peso_rel(r: Dictionary) -> float:
	return float(r.get("afeto", 0)) + float(r.get("confianca", 0)) + float(r.get("raiva", 0)) + float(r.get("medo", 0))


## A cena de agora: quando, onde, como está o lugar, quem está por perto.
static func cena(u: Universo, eid: String) -> String:
	var s := sessao(u, eid)
	var data := _agora(u, s)
	var aqui := str(u.estado(eid).get("local", ""))
	var eu: bool = str(s.get("voz", "primeira")) == "primeira"
	var linhas: Array = []
	var parte: String = PARTES[int(s.get("parte", 0))]
	var est := Natureza.estacao(data) if aqui != "" else ""
	linhas.append("%s, %s%s." % [DataMundo.texto(data), parte, (", " + est) if est != "" else ""])
	if not Estado.vivo(u, eid):
		return "%s morreu. A história acabou aqui." % _n(u, eid)
	if Viagens.viajando(u, eid):
		var v: Dictionary = u.estado(eid)["viagem"]
		linhas.append(("Estou na estrada para %s; faltam %d dias." if eu else "%s está na estrada para %s; faltam %d dias.") % ([_n(u, v["para"]), int(v["chega"]) - DataMundo.ordem(data)] if eu else [_n(u, eid), _n(u, v["para"]), int(v["chega"]) - DataMundo.ordem(data)]))
		return "\n".join(linhas)
	var canto := str(s.get("canto", ""))
	linhas.append(("Estou em %s%s." if eu else _n(u, eid) + " está em %s%s.") % [_n(u, aqui), (", " + _no(canto, "na", "no")) if canto != "" else ""])
	var clima: Array = []
	for ev in Natureza.eventos_ativos(u, aqui):
		clima.append(Natureza.EVENTOS.get(ev["tipo"], {}).get("nome", ev["tipo"]))
	if not clima.is_empty():
		linhas.append("Sobre %s: %s." % [_n(u, aqui), ", ".join(clima)])
	if Guerras.lugares_em_guerra(u).has(aqui):
		linhas.append("A guerra está aqui: %s." % _n(u, Guerras.lugares_em_guerra(u)[aqui]))
	var h := Humor.de(u, aqui)
	if float(h["raiva"]) > 0.6:
		linhas.append("O povo anda com raiva.")
	elif float(h["medo"]) > 0.6:
		linhas.append("Há medo nas ruas.")
	elif float(h["alegria"]) > 0.7:
		linhas.append("A cidade está alegre.")
	var perto: Array = []
	for x in _pessoas_aqui(u, eid):
		var p := Paginas._palavra_relacao(u.estado(eid)["relacoes"].get(x, {}))
		var of := oficio(u, x)
		perto.append("%s%s%s" % [_n(u, x), (" (" + of + ")") if of != "" else "", (" — " + p) if p != "" else ""])
	if not perto.is_empty():
		linhas.append(("Por perto: %s." if perto.size() <= 8 else "Por perto, entre outros: %s.") % ", ".join(perto.slice(0, 8)))
	else:
		linhas.append("Não há ninguém por perto.")
	if float(s.get("fome", 0)) > 0.7:
		linhas.append("A fome aperta." if eu else "Está com fome.")
	if float(s.get("cansaco", 0)) > 0.7:
		linhas.append("Estou cansado." if eu else "Está cansado.")
	return "\n".join(linhas)


## Quem está ali (no canto, se houver alguém daquele ofício), numa frase.
static func _quem_esta(u: Universo, eid: String, canto: String) -> String:
	var ps := _pessoas_aqui(u, eid)
	if canto != "":
		var dono := _dono_do_canto(u, eid, canto)
		if dono != "":
			return "%s está lá, trabalhando." % _n(u, dono)
	if ps.is_empty():
		return "Não há ninguém por perto."
	var nomes: Array = ps.slice(0, 4).map(func(x): return _n(u, x))
	return "Por perto: %s%s." % [", ".join(nomes), " e outros" if ps.size() > 4 else ""]


static func _pessoas_aqui(u: Universo, eid: String) -> Array:
	var aqui := str(u.estado(eid).get("local", ""))
	var r: Array = []
	if aqui == "":
		return r
	for e in u.entidades_ativas():
		var x: String = e["id"]
		if x != eid and Estado.tem_mente(u, x) and Estado.vivo(u, x) and str(u.estado(x).get("local", "")) == aqui:
			r.append(x)
	# Quem ele conhece primeiro.
	var rels: Dictionary = u.estado(eid)["relacoes"]
	r.sort_custom(func(a, b): return int(rels.has(a)) > int(rels.has(b)))
	return r


# ---------------------------------------------------------------- ajudantes

static func _n(u: Universo, eid: String) -> String:
	return str(u.entidade(eid).get("nome", "?")) if eid != "" else "?"


static func _onde(u: Universo, eid: String) -> String:
	var l := str(u.estado(eid).get("local", ""))
	return _n(u, l) if l != "" else "algum lugar"


static func _perto(u: Universo, eid: String, outro: String) -> bool:
	return Estado.vivo(u, outro) and str(u.estado(outro).get("local", "")) != "" and u.estado(outro)["local"] == u.estado(eid).get("local", "") and not Viagens.viajando(u, outro)


static func _patrao(u: Universo, eid: String) -> String:
	var p := str(u.estado(eid).get("patrao", ""))
	return p if u.entidades.has(p) else ""


static func _pessoa_citada(u: Universo, eid: String, texto: String) -> String:
	for m in Ligador.new(u).encontrar(texto):
		var x: String = m["entidade"]
		if x != eid and Estado.tem_mente(u, x):
			return x
	return ""


static func _canto(n: String) -> String:
	var t := " " + n + " "
	for c in CANTOS:
		if t.contains(" " + c + " ") or t.contains(" " + c + ","):
			return c
	return ""


## Quem trabalha naquele canto (o ferreiro na forja), entre os que estão por perto.
static func _dono_do_canto(u: Universo, eid: String, canto: String) -> String:
	var pistas := str(CANTOS.get(canto, ""))
	if pistas == "":
		return ""
	for x in _pessoas_aqui(u, eid):
		var of := TextUtil.normalizar(oficio(u, x))
		for p in pistas.split("|"):
			if of.contains(p):
				return x
	return ""


static func _no(canto: String, fem: String, masc: String) -> String:
	if canto == "casa":
		return "para casa" if fem == "à" else "em casa"
	var nomes := {"praca": "praça", "palacio": "palácio", "estabulo": "estábulo", "poco": "poço"}
	var c: String = nomes.get(canto, canto)
	return "%s %s" % [fem if c.ends_with("a") or c.ends_with("ã") or c == "estalagem" else masc, c]


## "a nova espada de prata" → "espada de prata"; "pão" → "pao" só na chave do preço.
static func _coisa(t: String) -> String:
	var w := Array(t.strip_edges().trim_suffix(".").split(" ")).filter(func(x): return x != "")
	while not w.is_empty() and TextUtil.normalizar(w[0]) in ["um", "uma", "uns", "umas", "o", "a", "os", "as", "meu", "minha", "meus", "minhas", "seu", "sua", "novo", "nova", "de", "do", "da", "mais"]:
		w.pop_front()
	if w.is_empty():
		return ""
	if Combate.ler_numero(str(w[0])) > 0 and w.size() > 1:
		w.pop_front()
	return " ".join(w.slice(0, 4)).to_lower()


static func _com_artigo(item: String) -> String:
	var n := TextUtil.normalizar(item).split(" ")[0]
	var fem := n.ends_with("a") or n.ends_with("ade") or n.ends_with("cao") or n.ends_with("gem")
	return ("uma " if fem else "um ") + item


static func _preco(item: String) -> float:
	for k in PRECOS:
		if TextUtil.normalizar(item).contains(k):
			return float(PRECOS[k])
	return 5.0


static func _item_que_tem(u: Universo, eid: String, item: String) -> String:
	var itens: Dictionary = bens(u, eid)["itens"]
	if item != "" and itens.has(item):
		return item
	var ni := TextUtil.normalizar(item)
	for k in itens:
		var nk := TextUtil.normalizar(str(k))
		if ni != "" and (nk.contains(ni) or ni.contains(nk)):
			return k
	return ""


static func _depois(texto: String, verbos: Array) -> String:
	var n := TextUtil.normalizar(texto)
	for v in verbos:
		var vn := TextUtil.normalizar(v)
		var i := n.find(vn)
		if i >= 0:
			return texto.substr(i + vn.length()).strip_edges()
	return ""


## A fala dentro de uma ação ("pergunto a Lucas o que ele sabe do rei").
static func _fala(texto: String, alvo: String, u: Universo) -> String:
	var a := texto.find("\"")
	if a >= 0:
		var b := texto.find("\"", a + 1)
		if b > a:
			return texto.substr(a + 1, b - a - 1)
	var i := texto.find(":")
	if i >= 0:
		return texto.substr(i + 1).strip_edges()
	var nome := _n(u, alvo)
	var j := texto.find(nome)
	if j >= 0:
		var resto := texto.substr(j + nome.length()).strip_edges()
		for p in ["sobre ", "se ", "o que ", "por que ", "onde ", "quem ", "que "]:
			if resto.begins_with(p):
				return resto
		if resto.length() > 3:
			return resto
	return ""


static func _moedas(v: float) -> String:
	return "uma moeda" if int(v) == 1 else "%d moedas" % int(v)


static func _nivel(v: float) -> String:
	if v >= 0.85:
		return "mestre"
	if v >= 0.6:
		return "hábil"
	if v >= 0.35:
		return "competente"
	if v >= 0.15:
		return "aprendiz"
	return "iniciante"


static func _rng(u: Universo, s: Dictionary, chave: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s:%s:%d:%d:%s" % [u.semente(), s["quem"], DataMundo.ordem(_agora(u, s)), int(s["parte"]), chave])
	return r


## Quem viu reage: muda o que sente por quem agiu.
static func _testemunhas(u: Universo, eid: String, alvo: String, fid: String, deltas: Dictionary) -> void:
	var ops: Array = []
	var quem: Array = []
	for w in _pessoas_aqui(u, eid):
		if w == alvo:
			continue
		var lig := Estado.valor_relacao(u, w, alvo, "afeto")
		var d := deltas.duplicate()
		if lig > 0.3 and d.has("raiva"):
			d["raiva"] = float(d["raiva"]) + lig * 0.4
		ops.append({"op": "relacao", "de": w, "para": eid, "deltas": d})
		ops.append({"op": "conhecer", "quem": w, "fato": fid})
		quem.append(w)
		if quem.size() >= 6:
			break
	if ops.is_empty():
		return
	var s := sessao(u, eid)
	_registrar(u, s, eid, "testemunho", "%s viram o que %s fez." % [", ".join(quem.map(func(x): return _n(u, x))), _n(u, eid)], [quem[0], eid], 0.05, ops)
