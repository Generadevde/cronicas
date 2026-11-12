class_name LeitorMais
extends RefCounted
## Complementos do Leitor para a escrita "por cima":
##   - números como se escreve ("3.700", "três mil e setecentos");
##   - lugares pelo nome ("na cidade de Austin", "na Profundeza");
##   - pessoas pelo nome ("John Black passou…", "o imperador Valen");
##   - títulos ainda sem nome ("o imperador") — o Livro pergunta quem é;
##   - o que ainda está por vir ("até a chegada do imperador").

const CENTENAS := {"quatrocentos": 400, "quatrocentas": 400, "seiscentos": 600, "seiscentas": 600, "setecentos": 700, "setecentas": 700,
	"oitocentos": 800, "oitocentas": 800, "novecentos": 900, "novecentas": 900, "trezentas": 300, "quinhentas": 500, "milhao": 1000000, "milhoes": 1000000}
const VAGOS := ["um", "uma", "algumas", "alguns", "poucas", "poucos", "dezenas", "centenas", "milhares"]
## Palavras que começam frase com maiúscula e não são nome de ninguém.
const INICIOS := ["o", "a", "os", "as", "um", "uma", "uns", "umas", "no", "na", "nos", "nas", "em", "de", "do", "da", "dos", "das", "ao", "aos",
	"quando", "enquanto", "depois", "antes", "entao", "mas", "porem", "contudo", "e", "ou", "se", "como", "por", "para", "com", "sem", "ate",
	"existe", "existem", "havia", "ha", "houve", "era", "eram", "foi", "foram", "essa", "esse", "essas", "esses", "esta", "este", "estas", "estes",
	"aquela", "aquele", "aquelas", "aqueles", "isso", "isto", "aquilo", "ele", "ela", "eles", "elas", "seu", "sua", "seus", "suas", "meu", "minha",
	"todo", "toda", "todos", "todas", "cada", "nenhum", "nenhuma", "ninguem", "alguem", "algo", "tudo", "nada", "quem", "que", "qual", "onde",
	"naquela", "naquele", "nessa", "nesse", "nesta", "neste", "la", "aqui", "ali", "hoje", "ontem", "amanha", "agora", "logo", "ja", "nunca",
	"sempre", "talvez", "assim", "apenas", "so", "somente", "muito", "muitos", "muitas", "pouco", "durante", "apos", "desde", "sob", "sobre",
	"entre", "contra", "crie", "cria", "mostre", "descreva", "explique", "entre", "faca", "nao", "sim", "dias", "anos", "meses", "passaram",
	"passou", "certo", "certa", "dizem", "conta", "naquele", "pela", "pelo", "numa", "num", "duas", "dois", "tres", "mil", "cem", "seus", "la"]
const VERBO := "(ou|eu|iu|ava|ia|inha|ara|era|foi|e|esta|estava|tem|tinha|vive|vivia|quer|queria|sabe|sabia|pode|podia|precisa|precisava|se|nao|nunca|sempre|ja|ainda|tambem|so)$"


# ---------------------------------------------------------------- números

## "3.700" → "3700" (o ponto de milhar não é fim de frase).
static func milhares(texto: String) -> String:
	var rx := RegEx.new()
	rx.compile("(\\d)\\.(\\d{3})(?!\\d)")
	var t := texto
	while rx.search(t) != null:
		t = rx.sub(t, "$1$2", true)
	return t


static func _valor(w: String) -> int:
	if CENTENAS.has(w):
		return int(CENTENAS[w])
	if VAGOS.has(w):
		return 0
	return int(Leitor.NUMEROS.get(w, 0))


## Números por extenso com mais de uma palavra viram algarismos ("tres mil e setecentos" → "3700").
static func por_extenso(n: String) -> String:
	var ws := n.strip_edges().split(" ", false)
	var saida: Array = []
	var i := 0
	while i < ws.size():
		var j := i
		var total := 0
		var atual := 0
		var qtd := 0
		while j < ws.size():
			var w: String = ws[j]
			var v := _valor(w)
			if w == "um" and j + 1 < ws.size() and ws[j + 1] in ["mil", "milhao"]:
				v = 1
			if v > 0:
				if v >= 1000:
					total += maxi(atual, 1) * v
					atual = 0
				else:
					atual += v
				qtd += 1
				j += 1
			elif w == "e" and qtd > 0 and j + 1 < ws.size() and _valor(ws[j + 1]) > 0:
				j += 1
			else:
				break
		if qtd >= 2:
			saida.append(str(total + atual))
			i = j
		else:
			saida.append(ws[i])
			i += 1
	return " " + " ".join(saida) + " "


# ---------------------------------------------------------------- lugares pelo nome

static func _existe(u: Universo, nome: String) -> String:
	var k := TextUtil.chave(nome)
	for e in u.entidades_ativas():
		if TextUtil.chave(e["nome"]) == k:
			return e["id"]
		for a in e.get("apelidos", []):
			if TextUtil.chave(str(a)) == k:
				return e["id"]
	return ""


## "na cidade de Austin", "o reino de Sal", "na Profundeza", "seguiu para Orla".
static func lugar_nomeado(u: Universo, original: String, n: String, raiz: String, foco: String) -> String:
	var rx := RegEx.new()
	rx.compile("([\\wÀ-ÿ]+) (?:de |do |da |dos |das )?([A-ZÀ-Ý][\\wÀ-ÿ'-]*(?: (?:d[aeo]s? )?[A-ZÀ-Ý][\\wÀ-ÿ'-]*)?)")
	for m in rx.search_all(original):
		var palavra := TextUtil.normalizar(m.get_string(1))
		if not Leitor.todos_os_lugares().has(palavra):
			continue
		var nome := m.get_string(2)
		if _existe(u, nome) != "":
			return ""
		var eid := Leitor._ler_lugar(u, "Uma %s chamada %s. %s" % [palavra, nome, original], " uma " + palavra + n, raiz, foco)
		if eid != "":
			_descricao(u, eid, original)
		return eid
	rx.compile("(?:^|\\s)(?:[Nn][ao]s?|[Ee]m|[Pp]ara|[Aa]té|rumo a|chegou a|chegaram a|chegou em|voltou a|voltou para|partiu para|foi para|fugiu para) ([A-ZÀ-Ý][\\wÀ-ÿ'-]+(?: [A-ZÀ-Ý][\\wÀ-ÿ'-]+)?)")
	var m2 := rx.search(original)
	if m2 == null:
		return ""
	var nome2 := m2.get_string(1)
	if _existe(u, nome2) != "" or TextUtil.normalizar(nome2) in INICIOS:
		return ""
	var mundo := Leitor._mundo(u, raiz, n)
	var rng := Povoador._rng(u, "lugar:" + nome2)
	var id := u.criar_entidade(nome2, "lugar", [], [{"chave": "descrição", "valor": original}], [raiz])
	Leitor._anotar(u, raiz, "criados", id)
	var pos := Leitor._posicao_livre(u, mundo, rng)
	Mapa.colocar(u, id, mundo, pos.x, pos.y, false)
	return id


static func _descricao(u: Universo, eid: String, original: String) -> void:
	var cs: Array = u.entidade(eid)["campos"].duplicate(true)
	for c in cs:
		if c["chave"] == "descrição":
			c["valor"] = original
	u.editar_entidade(eid, {"campos": cs})


# ---------------------------------------------------------------- pessoas pelo nome

static func _criar_pessoa(u: Universo, nome: String, papel: String, original: String, raiz: String, lugar: String) -> String:
	var campos: Array = []
	if papel != "" and Leitor.PAPEIS.has(papel):
		var p: Array = Leitor.PAPEIS[papel]
		campos.append({"chave": "idade", "valor": "%d anos" % int(p[1])})
		if str(p[0]) != "":
			campos.append({"chave": "cargo" if papel in Leitor.CARGOS else "ofício", "valor": str(p[0]) + ((" de " + u.entidade(lugar)["nome"]) if papel in Leitor.CARGOS and lugar != "" else "")})
	campos.append({"chave": "descrição", "valor": original})
	# O primeiro nome vale como apelido ("John" é John Black), se ninguém mais o usa.
	var apelidos: Array = []
	var partes := nome.split(" ", false)
	if partes.size() > 1 and _existe(u, partes[0]) == "":
		apelidos.append(partes[0])
	var eid := u.criar_entidade(nome, "pessoa", apelidos, campos, [raiz])
	Leitor._anotar(u, raiz, "criados", eid)
	if lugar != "":
		Simulador.registrar(u, {"tipo": "presença", "descricao": "%s está em %s." % [nome, u.entidade(lugar)["nome"]], "sujeitos": [eid, lugar], "lugar": lugar,
			"causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": 0.1, "povoamento": raiz, "mudancas": [{"op": "mover", "quem": eid, "lugar": lugar}]}})
	return eid


## Quem já tem este cargo ("o imperador").
static func _com_cargo(u: Universo, titulo: String) -> String:
	var k := TextUtil.normalizar(titulo)
	for e in u.entidades_ativas():
		if e["tipo"] != "pessoa":
			continue
		var c := TextUtil.normalizar(u.valor_campo(e["id"], "cargo"))
		if c == k or c.begins_with(k + " "):
			return e["id"]
	return ""


## Devolve os itens da margem: [{tipo, texto, id}].
static func pessoas(u: Universo, original: String, n: String, raiz: String, foco: String) -> Array:
	var itens: Array = []
	var rx := RegEx.new()
	# "o imperador Valen", "a rainha Isolda de Sal".
	rx.compile("(?:^|\\s)[OoAa] ([\\wÀ-ÿ]+) ([A-ZÀ-Ý][\\wÀ-ÿ'-]+(?: [A-ZÀ-Ý][\\wÀ-ÿ'-]+)?)")
	for m in rx.search_all(original):
		var papel := TextUtil.normalizar(m.get_string(1))
		var nome := m.get_string(2)
		if not Leitor.PAPEIS.has(papel) or _existe(u, nome) != "":
			continue
		var titulo := str(Leitor.PAPEIS[papel][0])
		var sem_nome := _com_cargo(u, titulo) if titulo != "" else ""
		if sem_nome != "" and u.valor_campo(sem_nome, "nome") == "ainda sem nome":
			# O título que estava sem nome ganha o nome.
			var cs: Array = u.entidade(sem_nome)["campos"].filter(func(c): return c["chave"] != "nome")
			u.editar_entidade(sem_nome, {"nome": nome, "campos": cs, "apelidos": [titulo]})
			itens.append({"tipo": "pessoa", "texto": "%s é %s %s" % [nome, m.get_string(0).strip_edges().substr(0, 1).to_lower(), titulo], "id": sem_nome})
			continue
		var eid := _criar_pessoa(u, nome, papel, original, raiz, foco)
		itens.append({"tipo": "pessoa", "texto": "%s (%s)" % [nome, Leitor._descricao_curta(u, eid)], "id": eid})
	# "Leptuna, a rainha do inverno, …" ou "Leptuna a rainha do inverno …": o nome ganha o título.
	rx.compile("([A-ZÀ-Ý][\\wÀ-ÿ'-]+(?: [A-ZÀ-Ý][\\wÀ-ÿ'-]+)?),? (?:a|o) ([\\wÀ-ÿ]+)((?: d[aeo]s? [\\wÀ-ÿ]+)?)")
	for ma in rx.search_all(original):
		var papel_a := TextUtil.normalizar(ma.get_string(2))
		var nome_a := ma.get_string(1)
		if not Leitor.PAPEIS.has(papel_a) or str(Leitor.PAPEIS[papel_a][0]) == "" or TextUtil.normalizar(nome_a.get_slice(" ", 0)) in INICIOS:
			continue
		var cargo_a := str(Leitor.PAPEIS[papel_a][0]) + ma.get_string(3)
		var ja := _existe(u, nome_a)
		if ja == "":
			ja = _criar_pessoa(u, nome_a, "", original, raiz, "")
			itens.append({"tipo": "pessoa", "texto": "%s (%s)" % [nome_a, cargo_a], "id": ja})
		var csa: Array = u.entidade(ja)["campos"].filter(func(c): return c["chave"] != "cargo")
		csa.append({"chave": "cargo", "valor": cargo_a})
		u.editar_entidade(ja, {"campos": csa})
	# Nome composto em qualquer ponto da frase: "apenas Gregorio R. Tunt poderia salvá-los".
	rx.compile("(?<![\\wÀ-ÿ])([A-ZÀ-Ý][\\wÀ-ÿ'-]+(?: (?:[A-Z]\\. |d[aeo]s? )?[A-ZÀ-Ý][\\wÀ-ÿ'-]+)+)")
	for mc in rx.search_all(original):
		var nome_c := mc.get_string(1)
		var primeiro_c := TextUtil.normalizar(nome_c.get_slice(" ", 0))
		if primeiro_c in INICIOS or Leitor.todos_os_lugares().has(primeiro_c) or Leitor.PAPEIS.has(primeiro_c) or _existe(u, nome_c) != "":
			continue
		var antes_c := TextUtil.normalizar(original.substr(0, mc.get_start()).strip_edges())
		var ultima_c := antes_c.get_slice(" ", antes_c.get_slice_count(" ") - 1)
		if ultima_c in ["de", "do", "da", "em", "no", "na", "para", "a", "ate"] or Leitor.todos_os_lugares().has(ultima_c) or Leitor.PAPEIS.has(ultima_c):
			continue
		var eid_c := _criar_pessoa(u, nome_c, "", original, raiz, "")
		itens.append({"tipo": "pessoa", "texto": "%s (pessoa nova)" % nome_c, "id": eid_c})
	# Nome no começo da frase: "John Black passou…", "Kai soube…".
	rx.compile("^([A-ZÀ-Ý][\\wÀ-ÿ'-]+)((?: (?:d[aeo]s? )?[A-ZÀ-Ý][\\wÀ-ÿ'-]+){0,2})[ ,]+([\\wÀ-ÿ]+)")
	var mi := rx.search(original)
	if mi != null:
		var primeiro := TextUtil.normalizar(mi.get_string(1))
		var nome2 := (mi.get_string(1) + mi.get_string(2)).strip_edges()
		var composto := mi.get_string(2) != ""
		var rv := RegEx.new()
		rv.compile(VERBO)
		var parece := composto or rv.search(TextUtil.normalizar(mi.get_string(3))) != null
		if not primeiro in INICIOS and not Leitor.LUGARES.has(primeiro) and not Leitor.PAPEIS.has(primeiro) and parece and _existe(u, nome2) == "" and nome2.length() >= 2:
			var eid2 := _criar_pessoa(u, nome2, "", original, raiz, foco)
			itens.append({"tipo": "pessoa", "texto": "%s (pessoa nova)" % nome2, "id": eid2})
	# Título sem nome: "o imperador", "a rainha".
	for cargo in Leitor.CARGOS:
		var titulo2 := str(Leitor.PAPEIS[cargo][0])
		var rt := RegEx.new()
		rt.compile(" (o|a|do|da|ao|pelo|pela) %s " % cargo)
		var mt := rt.search(n)
		if mt == null or _com_cargo(u, titulo2) != "":
			continue
		var artigo := "a" if mt.get_string(1) in ["a", "da", "pela"] else "o"
		var nome3 := "%s %s" % [artigo.to_upper(), titulo2.substr(0, 1).to_upper() + titulo2.substr(1)]
		if _existe(u, nome3) != "":
			continue
		var cargo3 := titulo2
		var onde3 := Leitor._lugar_citado(u, original)
		if onde3 == "":
			onde3 = foco
		# Só é "o rei de Kreven" (e mora lá) se a frase disser; "a chegada do imperador" não o põe na cidade.
		if onde3 != "" and not n.contains(" %s de %s " % [cargo, TextUtil.normalizar(str(u.entidade(onde3)["nome"]))]):
			onde3 = ""
		if onde3 != "":
			cargo3 = "%s de %s" % [titulo2, str(u.entidade(onde3)["nome"])]
		var eid3 := u.criar_entidade(nome3, "pessoa", [titulo2], [{"chave": "idade", "valor": "%d anos" % int(Leitor.PAPEIS[cargo][1])},
			{"chave": "cargo", "valor": cargo3}, {"chave": "nome", "valor": "ainda sem nome"}, {"chave": "descrição", "valor": original}], [raiz])
		Leitor._anotar(u, raiz, "criados", eid3)
		if onde3 != "":
			Simulador.registrar(u, {"tipo": "presença", "descricao": "%s está em %s." % [nome3, u.entidade(onde3)["nome"]], "sujeitos": [eid3, onde3], "lugar": onde3,
				"causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": 0.1, "povoamento": raiz, "mudancas": [{"op": "mover", "quem": eid3, "lugar": onde3}]}})
		itens.append({"tipo": "pergunta", "texto": "Quem é %s %s? Ainda não tem nome." % [artigo, titulo2], "id": eid3})
	return itens


# ---------------------------------------------------------------- o que está por vir

## "até a chegada do imperador", "antes da vinda de Kai": fica marcado como por vir.
static func por_vir(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var rx := RegEx.new()
	rx.compile(" (?:ate|antes d)a? ?(?:a )?(chegada|vinda|volta|retorno) d[eoa]s? ")
	var m := rx.search(n)
	if m == null:
		# "Leptuna estava chegando", "Kai está a caminho", "o exército se aproxima".
		var vindo := false
		for w in [" estava chegando", " esta chegando", " estavam chegando", " estava a caminho", " esta a caminho", " se aproxima", " se aproximava", " estava vindo", " esta vindo", " vinha vindo"]:
			if n.contains(w):
				vindo = true
		if not vindo or foco == "":
			return {}
		for mm in Ligador.new(u).encontrar(original):
			var e2: Dictionary = u.entidade(str(mm["entidade"]))
			if e2.is_empty() or e2["tipo"] != "pessoa" or str(u.estado(e2["id"]).get("local", "")) == foco:
				continue
			var t2 := "A chegada de %s a %s ainda está por vir." % [e2["nome"], u.entidade(foco)["nome"]]
			u.extra("por_vir", []).append({"quem": e2["id"], "lugar": foco, "raiz": raiz, "texto": t2, "feito": false})
			return {"texto": t2, "quem": e2["id"]}
		return {}
	var resto := n.substr(m.get_end()).strip_edges()
	var quem := ""
	for e in u.entidades_ativas():
		if e["tipo"] != "pessoa":
			continue
		var nomes: Array = [e["nome"]] + e.get("apelidos", [])
		for nm in nomes:
			var k := TextUtil.normalizar(str(nm))
			if k.begins_with("o ") or k.begins_with("a "):
				k = k.substr(2)
			if resto.begins_with(k):
				quem = e["id"]
	if quem == "" or foco == "":
		return {}
	var texto := "A %s de %s a %s ainda está por vir." % [m.get_string(1), u.entidade(quem)["nome"], u.entidade(foco)["nome"]]
	var lista: Array = u.extra("por_vir", [])
	lista.append({"quem": quem, "lugar": foco, "raiz": raiz, "texto": texto, "feito": false})
	return {"texto": texto, "quem": quem}


static func pendentes(u: Universo) -> Array:
	var r: Array = []
	for p in u.extra("por_vir", []):
		if p.get("feito", false) or not u.fatos.existe(str(p["raiz"])) or not u.fatos.obter(str(p["raiz"]))["canon"]:
			continue
		if u.entidade(str(p["quem"])).is_empty() or str(u.estado(str(p["quem"])).get("local", "")) == str(p["lugar"]):
			continue
		r.append(p)
	return r


## O mundo traz o que estava por vir: vira fato, com a frase como causa.
static func cumprir(u: Universo, p: Dictionary) -> String:
	p["feito"] = true
	var q: Dictionary = u.entidade(str(p["quem"]))
	var l: Dictionary = u.entidade(str(p["lugar"]))
	var fid := Simulador.registrar(u, {"tipo": "chegada", "descricao": "%s chegou a %s." % [q["nome"], l["nome"]], "sujeitos": [q["id"], l["id"]], "lugar": l["id"],
		"causas": [str(p["raiz"])], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
		"dados": {"importancia": 0.7, "mudancas": [{"op": "mover", "quem": q["id"], "lugar": l["id"]}]}})
	u.marcar_mudanca()
	return fid


# ---------------------------------------------------------------- consultas, regras do Livro, criar por ordem, acontecimentos

const CONSULTAS := ["mostre", "mostrar", "descreva", "explique", "localize", "compare", "liste", "listar", "quais", "qual", "quem", "onde", "quantos",
	"quantas", "como", "por que", "porque", "o que", "diga", "conte", "resuma", "detalhe", "indique", "informe", "verifique", "analise", "avalie", "calcule", "identifique"]
const REGRAS_DO_LIVRO := ["nao transforme", "nao invente", "nao altere", "nao mude", "nao crie", "nao apague", "nao deixe", "nunca ", "sempre ", "quando eu disser",
	"quando eu escrever", "quando eu pedir", "se eu disser", "se eu escrever", "se eu pedir", "mantenha", "preserve", "respeite", "trate ", "considere", "lembre",
	"registre", "guarde", "use ", "evite", "priorize", "pergunte", "avise", "separe", "diferencie", "marque", "nao "]
const CRIAR := ["crie", "cria", "criar", "construa", "adicione", "erga", "desenvolva", "funde", "faca", "gere", "invente", "coloque", "ponha", "estabeleca",
	"introduza", "inclua", "projete", "monte", "forme", "plante", "defina", "organize", "expanda", "transforme", "conecte"]
const NOVOS_LUGARES := {"regiao": "região", "planicie": "planície", "lago": "lago", "lagoa": "lagoa", "canion": "cânion", "peninsula": "península", "tundra": "tundra",
	"taiga": "taiga", "recife": "recife", "manguezal": "manguezal", "savana": "savana", "pradaria": "pradaria", "praia": "praia", "falesia": "falésia", "rio": "rio",
	"ponte": "ponte", "mercado": "mercado", "casa": "casa", "casas": "casas", "praca": "praça", "moinho": "moinho", "bairro": "bairro", "muralha": "muralha",
	"canal": "canal", "ruina": "ruína", "ruinas": "ruínas", "distrito": "distrito", "estrada": "estrada", "provincia": "província", "territorio": "território",
	"vulcao": "vulcão", "geleira": "geleira", "selva": "selva", "bosque": "bosque", "colina": "colina", "passagem": "passagem", "tunel": "túnel", "cordilheira": "cordilheira",
	"baia": "baía", "golfo": "golfo", "estreito": "estreito", "delta": "delta", "cachoeira": "cachoeira", "nascente": "nascente", "area": "área", "zona": "zona",
	"biblioteca": "biblioteca", "taverna": "taverna", "estalagem": "estalagem", "hospital": "hospital", "oficina": "oficina", "forja": "forja", "armazem": "armazém",
	"celeiro": "celeiro", "santuario": "santuário", "catedral": "catedral", "igreja": "igreja", "palacio": "palácio", "quartel": "quartel", "arena": "arena",
	"cemiterio": "cemitério", "farol": "farol", "observatorio": "observatório", "laboratorio": "laboratório", "universidade": "universidade", "rota": "rota",
	"fronteira": "fronteira", "posto": "posto", "cais": "cais", "estaleiro": "estaleiro", "aqueduto": "aqueduto", "poco": "poço", "jardim": "jardim", "campo": "campo",
	"plantacao": "plantação", "pomar": "pomar", "vinhedo": "vinhedo", "pedreira": "pedreira", "tribunal": "tribunal", "banco": "banco", "feira": "feira", "pais": "país",
	"nacao": "nação", "ducado": "ducado", "condado": "condado", "republica": "república", "bioma": "bioma", "ecossistema": "ecossistema", "costa": "costa", "mar": "mar",
	"oceano": "oceano", "ambiente": "ambiente", "assentamento": "assentamento", "comunidade": "comunidade"}
## Construções e pedaços de um lugar: nascem dentro do lugar em cena e não tiram a história de lá.
const CONSTRUCOES := ["ponte", "mercado", "casa", "casas", "praca", "moinho", "bairro", "muralha", "canal", "distrito", "estrada", "passagem", "tunel", "biblioteca",
	"taverna", "estalagem", "hospital", "oficina", "forja", "armazem", "celeiro", "santuario", "catedral", "igreja", "palacio", "quartel", "arena", "cemiterio", "farol",
	"observatorio", "laboratorio", "universidade", "posto", "cais", "estaleiro", "aqueduto", "poco", "jardim", "plantacao", "pomar", "vinhedo", "pedreira", "tribunal",
	"banco", "feira"]
const GENTE_UNICA := ["viajante", "morador", "moradora", "comerciante", "aventureiro", "aventureira", "explorador", "exploradora", "artesao", "artesa", "campones",
	"camponesa", "nobre", "espiao", "espia", "mensageiro", "mensageira", "estrangeiro", "estrangeira", "sabio", "sabia", "profeta", "ladra", "assassino", "assassina",
	"guarda", "juiz", "juiza", "professor", "professora", "aprendiz", "inventor", "inventora", "personagem", "pessoa", "lider", "governante", "herdeiro", "herdeira",
	"mercenario", "mercenaria", "bardo", "alquimista", "ferreira", "cozinheiro", "cozinheira", "marinheiro", "navegador", "navegadora", "diplomata", "embaixador",
	"embaixadora", "conselheiro", "conselheira", "rebelde", "eremita", "orfao", "orfa", "anciao", "ancia", "detetive", "investigador", "investigadora"]
const GRAVES := ["terremoto", "enchente", "seca", "praga", "peste", "epidemia", "incendio", "erupcao", "vulcao", "avalanche", "tsunami", "furacao", "guerra", "invasao",
	"fome", "massacre", "golpe", "revolta", "rebeliao", "morte", "assassin", "nevasca", "tempestade", "colapso", "desastre", "catastrofe", "destru"]


static func _comeca_com(n: String, lista: Array) -> bool:
	var t := n.strip_edges() + " "
	for p in lista:
		if t.begins_with(str(p).strip_edges() + " "):
			return true
	return false


static func eh_consulta(original: String, n: String) -> bool:
	return original.strip_edges().ends_with("?") or _comeca_com(n, CONSULTAS)


static func eh_regra_do_livro(n: String) -> bool:
	return _comeca_com(n, REGRAS_DO_LIVRO) and (n.contains(" eu ") or n.contains(" hipotese") or n.contains(" fato") or n.contains(" canon") or n.contains(" historia")
		or n.contains(" personagem") or n.contains(" simula") or n.contains(" contradic") or n.contains(" possibilidade") or n.contains(" informac") or n.contains(" mundo")
		or n.contains(" universo") or n.contains(" regra") or n.contains(" evento") or n.contains(" causa") or n.contains(" consequenc") or n.contains(" detalhe"))


## O Livro responde com o que o universo já sabe.
static func responder(u: Universo, original: String) -> String:
	var partes: Array = []
	var vistos := {}
	for m in Ligador.new(u).encontrar(original):
		var eid := str(m["entidade"])
		if vistos.has(eid):
			continue
		vistos[eid] = true
		var e: Dictionary = u.entidade(eid)
		var d := u.valor_campo(eid, "descrição")
		partes.append("%s (%s)%s" % [e["nome"], e["tipo"], (": " + d) if d != "" else ""])
	if partes.is_empty():
		for r in Pesquisa.buscar(u, original, 3):
			partes.append(str(r.get("titulo", r.get("nome", ""))) + ((": " + str(r.get("trecho", ""))) if str(r.get("trecho", "")) != "" else ""))
	if partes.is_empty():
		return "O universo ainda não tem nada escrito sobre isso."
	return "\n".join(partes.slice(0, 4))


static func guardar_regra(u: Universo, original: String) -> void:
	var lista: Array = u.extra("regras_do_livro", [])
	if not lista.has(original):
		lista.append(original)


## "Crie um mercado no centro da cidade", "Adicione um viajante": nasce uma coisa do tipo que a frase disser (texto livre).
static func criar_por_ordem(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var rx := RegEx.new()
	rx.compile("^ (?:%s|existe|existem|ha|havia|surgiu|surge|nasceu|apareceu) (?:(?:um|uma|uns|umas|o|a|os|as|novo|nova|novos|novas|outro|outra|mais|varios|varias|alguns|algumas) )*([a-z]+)((?: (?:de|do|da|dos|das|para|com) [a-z]+| [a-z]+)?)" % "|".join(CRIAR))
	var m := rx.search(n)
	if m == null:
		return {}
	var palavra := m.get_string(1)
	if palavra.length() < 3 or palavra in INICIOS:
		return {}
	var rng := Povoador._rng(u, "ordem:" + original)
	var lugar := foco if foco != "" else Leitor._lugar_citado(u, original)
	if palavra in GENTE_UNICA or Leitor.PAPEIS.has(palavra):
		var lingua := Linguas.do_lugar(u, lugar if lugar != "" else Leitor._mundo(u, raiz, n))
		var nome: String = Linguas.gerar(u, lingua, "pessoas", rng)
		var eid := u.criar_entidade(nome, "pessoa", [], [{"chave": "ofício", "valor": palavra}, {"chave": "descrição", "valor": original}], [raiz])
		Leitor._anotar(u, raiz, "criados", eid)
		if lugar != "":
			Simulador.registrar(u, {"tipo": "presença", "descricao": "%s está em %s." % [nome, u.entidade(lugar)["nome"]], "sujeitos": [eid, lugar], "lugar": lugar,
				"causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": 0.1, "povoamento": raiz, "mudancas": [{"op": "mover", "quem": eid, "lugar": lugar}]}})
		return {"tipo": "pessoa", "texto": "%s (%s)" % [nome, palavra], "id": eid}
	var frase_nome := (palavra + m.get_string(2)).strip_edges()
	var nome2 := frase_nome.substr(0, 1).to_upper() + frase_nome.substr(1)
	if lugar != "":
		nome2 += " de " + str(u.entidade(lugar)["nome"])
	if _existe(u, nome2) != "":
		return {}
	var campos: Array = [{"chave": "descrição", "valor": original}]
	if lugar != "":
		campos.append({"chave": "fica em", "valor": str(u.entidade(lugar)["nome"])})
	var id := u.criar_entidade(nome2, palavra, [], campos, [raiz])
	Leitor._anotar(u, raiz, "criados", id)
	return {"tipo": "coisa", "texto": "%s (%s)" % [nome2, palavra], "id": id}


## O que não cria nada, mas acontece: vira fato do autor, com lugar, data e quem aparece na frase.
static func acontecimento(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var sujeitos: Array = []
	for m in Ligador.new(u).encontrar(original):
		if not sujeitos.has(m["entidade"]):
			sujeitos.append(m["entidade"])
	var imp := 0.35
	for g in GRAVES:
		if n.contains(" " + g):
			imp = 0.65
	var fid := Simulador.registrar(u, {"tipo": "acontecimento", "descricao": original, "sujeitos": sujeitos, "lugar": foco, "causas": [raiz],
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": imp, "anotado": true}})
	return {"tipo": "acontecimento", "texto": "Anotado como acontecimento" + ((" em " + str(u.entidade(foco)["nome"])) if foco != "" else ""), "id": fid}


## "Seus moradores viviam da caça e da mineração": o lugar em cena passa a viver disso.
## Se ainda não mora ninguém lá, o mundo inventa um povo (e diz que inventou).
static func modo_de_vida(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var rx := RegEx.new()
	rx.compile(" (?:seus|suas|os|as|o|a|seu|sua) (moradores|habitantes|povo|gente|pessoas|aldeoes|cidadaos|familias|homens|mulheres)(?: (?:de|da|do) [a-z]+)? (?:viv|sobreviv|se sustent|depend|trabalh)[a-z]* (?:d[aeo]s?|com|n[ao]s?|em) (.+)$")
	var m := rx.search(n)
	if m == null:
		return {}
	var lugar := Leitor._lugar_citado(u, original)
	if lugar == "":
		lugar = foco
	if lugar == "":
		return {}
	var partes: Array = []
	for pedaco in m.get_string(2).strip_edges().split(" e ", false):
		var t: String = pedaco.strip_edges()
		for pre in ["de ", "da ", "do ", "das ", "dos ", "a ", "o "]:
			if t.begins_with(pre):
				t = t.substr(pre.length())
		if t != "":
			partes.append(t)
	if partes.is_empty():
		return {}
	var do_que := " e ".join(partes)
	# De volta com os acentos que o autor escreveu.
	for w in original.replace(",", " ").replace(".", " ").split(" ", false):
		var wn := TextUtil.normalizar(w)
		if wn != w.to_lower() and wn.length() > 2:
			do_que = (" " + do_que + " ").replace(" " + wn + " ", " " + w.to_lower() + " ").strip_edges()
	var cs: Array = u.entidade(lugar)["campos"].filter(func(c): return c["chave"] != "vive de")
	cs.append({"chave": "vive de", "valor": do_que})
	u.editar_entidade(lugar, {"campos": cs})
	var nome := str(u.entidade(lugar)["nome"])
	var texto := "%s vive de %s" % [nome, do_que]
	if Ameacas._pessoas(u, lugar).is_empty():
		var povo := Leitor._povoar(u, lugar, 300, "moradores", "", raiz)
		if not povo.is_empty():
			texto += ". Ainda não morava ninguém lá: o mundo pôs uns 300 moradores (escreva o número se quiser outro)"
	return {"tipo": "gente", "texto": texto + ".", "id": lugar}


## As células do mapa de 'de' que o autor já escreveu: em volta de cada lugar criado e o terreno pintado perto deles.
## (Uma célula fora do mapa marca "nada escrito ainda", para o mapa não mostrar o que o mundo inventou.)
static func escrito_no_mapa(u: Universo, de: String) -> Dictionary:
	var r := {Vector2i(-1, -1): true}
	var centros: Array = []
	for f in Mapa.filhos(u, de):
		var p: Dictionary = Mapa.posicao(u, str(f))
		if p.is_empty():
			continue
		var c := Vector2i(int(p["x"]), int(p["y"]))
		centros.append(c)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dy * dy <= 5:
					r[c + Vector2i(dx, dy)] = true
	for k in Mapa.dados(u)["pintura"].get(de, {}):
		var partes: PackedStringArray = str(k).split(",")
		if partes.size() != 2:
			continue
		var cel := Vector2i(int(partes[0]), int(partes[1]))
		for c2 in centros:
			if Vector2(cel - c2).length() <= 6.5:
				r[cel] = true
				break
	return r


## "Kreven estava em um grande deserto": o terreno em volta do lugar passa a ser esse.
static func terreno_em_volta(u: Universo, base: String, novo: String, n: String) -> void:
	var tipo := TextUtil.normalizar(str(u.entidade(novo)["tipo"]))
	if not Mapa.PALAVRAS_TERRENO.has(tipo) or not Mapa.TERRENOS.has(str(Mapa.PALAVRAS_TERRENO[tipo])):
		return
	var pai := Mapa.pai(u, base)
	var p: Dictionary = Mapa.posicao(u, base)
	if pai == "" or p.is_empty():
		return
	var grande := n.contains(" grande ") or n.contains(" vast") or n.contains(" imens") or n.contains(" enorme ") or n.contains(" sem fim")
	var raio := 5 if grande else 3
	var cx := int(p["x"])
	var cy := int(p["y"])
	var celulas := 0
	for dy in range(-raio, raio + 1):
		for dx in range(-raio, raio + 1):
			var x := cx + dx
			var y := cy + dy
			if dx * dx + dy * dy <= raio * raio + 1 and x >= 0 and x < Mapa.COLS and y >= 0 and y < Mapa.LINHAS:
				if Mapa.pintar(u, pai, x, y, str(Mapa.PALAVRAS_TERRENO[tipo])):
					celulas += 1
	# O lugar novo (o deserto) fica marcado ao lado, não num canto qualquer do mundo.
	var nx := clampi(cx + 1, 0, Mapa.COLS - 1)
	var ny := clampi(cy - 1, 0, Mapa.LINHAS - 1)
	if Mapa.em(u, pai, nx, ny) == "":
		Mapa.colocar(u, novo, pai, nx, ny, false)
