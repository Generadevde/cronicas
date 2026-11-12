class_name Leitor
extends RefCounted
## O leitor do mundo: cada frase que o autor escreve pode mudar o universo.
##   "Existe apenas uma ilha, chamada Aru, com 30 pessoas."   → a ilha e as 30 pessoas
##   "Essas pessoas precisam sobreviver."                      → comida, coleta e fome
##   "À noite, slimes começam a aparecer e atacam as pessoas." → a criatura e a ameaça
##   "Um rei cruel chamado Odo governa a vila."                → a pessoa, o cargo, o jeito
##   "O povo odeia o rei."                                     → o que todos sentem
##   "Neste mundo, quem mente perde a voz."                    → uma lei (Regras)
##   "Três dias depois…"                                       → o tempo anda
## Cada frase lida vira um fato-raiz ("Você escreveu: …") que guarda tudo o que ela
## criou; desfazer a frase desfaz o que nasceu dela (nada se perde: fica fora do canon).

const NUMEROS := {"um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8,
	"nove": 9, "dez": 10, "onze": 11, "doze": 12, "treze": 13, "quatorze": 14, "catorze": 14, "quinze": 15, "dezesseis": 16,
	"dezessete": 17, "dezoito": 18, "dezenove": 19, "vinte": 20, "trinta": 30, "quarenta": 40, "cinquenta": 50, "sessenta": 60,
	"setenta": 70, "oitenta": 80, "noventa": 90, "cem": 100, "cento": 100, "duzentos": 200, "duzentas": 200, "trezentos": 300,
	"quinhentos": 500, "mil": 1000, "algumas": 6, "alguns": 6, "poucas": 4, "poucos": 4, "dezenas": 40, "centenas": 300, "milhares": 3000}

## Lugares que se criam escrevendo (palavra → tipo).
const LUGARES := {"ilha": "ilha", "ilhota": "ilha", "arquipelago": "arquipélago", "cidade": "cidade", "vila": "vila", "vilarejo": "vilarejo",
	"aldeia": "aldeia", "povoado": "povoado", "reino": "reino", "imperio": "império", "floresta": "floresta", "montanha": "montanha",
	"castelo": "castelo", "torre": "torre", "nave": "nave", "estacao": "estação", "planeta": "planeta", "continente": "continente",
	"deserto": "deserto", "caverna": "caverna", "mina": "mina", "porto": "porto", "fortaleza": "fortaleza", "mosteiro": "mosteiro",
	"templo": "templo", "acampamento": "acampamento", "colonia": "colônia", "base": "base", "abrigo": "abrigo", "bunker": "bunker",
	"vale": "vale", "pantano": "pântano", "oasis": "oásis", "navio": "navio", "barco": "barco", "fazenda": "fazenda", "escola": "escola",
	"academia": "academia", "prisao": "prisão", "masmorra": "masmorra", "labirinto": "labirinto", "metropole": "metrópole", "capital": "capital"}

## Palavras de gente (para "30 pessoas", "200 anões mineiros", "12 tripulantes").
const GENTE := ["pessoas", "habitantes", "moradores", "humanos", "homens", "mulheres", "criancas", "sobreviventes", "colonos",
	"tripulantes", "naufragos", "refugiados", "camponeses", "aldeoes", "soldados", "guerreiros", "monges", "freiras", "pescadores",
	"mineiros", "cacadores", "marinheiros", "piratas", "cientistas", "engenheiros", "escravos", "nomades", "familias", "anoes",
	"elfos", "orcs", "gnomos", "hobbits", "magos", "bruxas", "alunos", "estudantes", "orfaos", "viajantes", "peregrinos", "nobres",
	"cavaleiros", "almas", "pessoas", "operarios", "colonizadores", "exploradores", "mercadores", "artesaos", "lenhadores", "pastores"]
const POVOS := {"anoes": "anão", "elfos": "elfo", "orcs": "orc", "gnomos": "gnomo", "hobbits": "hobbit"}
const OFICIOS_DE_GRUPO := {"pescadores": "pescador", "mineiros": "mineiro", "cacadores": "caçador", "marinheiros": "marinheiro",
	"camponeses": "camponês", "soldados": "soldado", "guerreiros": "guerreiro", "monges": "monge", "freiras": "freira", "cientistas": "cientista",
	"engenheiros": "engenheiro", "piratas": "pirata", "magos": "mago", "bruxas": "bruxa", "alunos": "aluno",
	"estudantes": "estudante", "mercadores": "mercador", "artesaos": "artesão", "lenhadores": "lenhador", "pastores": "pastor",
	"operarios": "operário", "exploradores": "exploradora", "nobres": "nobre", "cavaleiros": "cavaleiro", "aldeoes": "aldeão"}
## Ofícios de quem vive em cada tipo de lugar.
const OFICIOS_DO_LUGAR := {"ilha": ["pescador", "pescadora", "coletora", "caçador", "curandeira", "carpinteiro", "tecelã", "construtor"],
	"nave": ["piloto", "engenheira", "médico", "técnico", "cientista", "cozinheira", "navegadora", "mecânico"],
	"estacao": ["engenheiro", "técnica", "cientista", "médica", "operador", "comandante"],
	"montanha": ["mineiro", "ferreiro", "pastora", "caçador"], "floresta": ["lenhador", "caçadora", "curandeira", "coletor"],
	"cidade": ["ferreiro", "padeira", "mercador", "guarda", "tecelã", "escriba", "carpinteiro", "taverneira"],
	"vila": ["camponês", "camponesa", "lavrador", "padeira", "ferreiro", "pastor"]}

## Verbos de criaturas: aparecer e o que fazem.
const APARECER := ["aparecem", "aparecer", "surgem", "surgir", "saem", "sair", "descem", "descer", "chegam", "vem ", "emergem", "rastejam",
	"rondam", "rondar", "vagam", "invadem", "invadir", "brotam", "nascem do", "voam", "andam pela", "andam pelo"]
const EFEITOS := [["atacar", ["atacam", "atacar", "ataca ", "mordem", "devoram", "devorar", "comem as", "comem os", "matam", "matar", "cacam", "cacar", "ferem", "perseguem"]],
	["destruir", ["queimam", "queimar", "incendeiam", "destroem", "destruir", "derrubam", "arrasam", "pisoteiam"]],
	["roubar", ["roubam", "roubar", "furtam", "levam a comida", "levam comida", "comem a comida", "comem as plantacoes", "saqueiam"]],
	["levar", ["sequestram", "raptam", "levam as criancas", "levam pessoas", "levam as pessoas", "arrastam"]]]

const PAPEIS := {"rei": ["rei", 50], "rainha": ["rainha", 45], "principe": ["príncipe", 20], "princesa": ["princesa", 18], "velho": ["", 72],
	"velha": ["", 70], "homem": ["", 35], "mulher": ["", 33], "menino": ["", 10], "menina": ["", 9], "garoto": ["", 13], "garota": ["", 13],
	"jovem": ["", 19], "rapaz": ["", 20], "moca": ["", 19], "crianca": ["", 8], "capitao": ["capitão", 40], "capita": ["capitã", 40],
	"cavaleiro": ["cavaleiro", 30], "feiticeiro": ["feiticeiro", 50], "feiticeira": ["feiticeira", 45], "mago": ["mago", 55],
	"bruxa": ["bruxa", 60], "sacerdote": ["sacerdote", 50], "sacerdotisa": ["sacerdotisa", 45], "chefe": ["chefe", 45], "lider": ["líder", 40],
	"comandante": ["comandante", 45], "general": ["general", 50], "guerreiro": ["guerreiro", 28], "guerreira": ["guerreira", 27],
	"pescador": ["pescador", 40], "pescadora": ["pescadora", 35], "ferreiro": ["ferreiro", 45], "curandeira": ["curandeira", 50],
	"curandeiro": ["curandeiro", 50], "mercador": ["mercador", 40], "cientista": ["cientista", 40], "engenheiro": ["engenheiro", 38],
	"engenheira": ["engenheira", 36], "medico": ["médico", 45], "medica": ["médica", 42], "soldado": ["soldado", 25], "ladrao": ["ladrão", 25],
	"pirata": ["pirata", 35], "imperador": ["imperador", 55], "imperatriz": ["imperatriz", 50], "duque": ["duque", 50], "conde": ["conde", 50],
	"heroi": ["herói", 25], "heroina": ["heroína", 24], "cacador": ["caçador", 35], "cacadora": ["caçadora", 30], "monge": ["monge", 50]}
const CARGOS := ["rei", "rainha", "imperador", "imperatriz", "chefe", "lider", "duque", "conde", "capitao", "capita", "comandante", "general", "principe", "princesa"]
const SENTIMENTOS := {"odeia": {"raiva": 0.6}, "odeiam": {"raiva": 0.6}, "teme": {"medo": 0.6}, "temem": {"medo": 0.6}, "ama": {"afeto": 0.6},
	"amam": {"afeto": 0.6}, "adora": {"afeto": 0.6, "respeito": 0.4}, "adoram": {"afeto": 0.6, "respeito": 0.4}, "respeita": {"respeito": 0.6},
	"respeitam": {"respeito": 0.6}, "confia em": {"confianca": 0.6}, "confiam em": {"confianca": 0.6}, "despreza": {"raiva": 0.4, "respeito": -0.4},
	"desprezam": {"raiva": 0.4, "respeito": -0.4}, "inveja": {"raiva": 0.3}, "invejam": {"raiva": 0.3}}


static var _todos_lugares: Dictionary = {}


static func todos_os_lugares() -> Dictionary:
	if _todos_lugares.is_empty():
		_todos_lugares = LUGARES.duplicate()
		_todos_lugares.merge(LeitorMais.NOVOS_LUGARES)
	return _todos_lugares


# ---------------------------------------------------------------- ler uma frase

## Lê uma frase e muda o mundo. ctx: {capitulo, foco (lugar em cena)}.
## Devolve {raiz, itens: [{tipo, texto, id}], dias, entendeu, foco}.
static func ler(u: Universo, frase: String, ctx: Dictionary = {}) -> Dictionary:
	var original := LeitorMais.milhares(frase.strip_edges())
	var r := {"raiz": "", "itens": [], "dias": 0, "entendeu": false, "foco": str(ctx.get("foco", ""))}
	if original.length() < 3:
		return r
	var n := LeitorMais.por_extenso(_limpo(original))
	# Pergunta ao Livro: não muda o mundo, o Livro responde.
	if LeitorMais.eh_consulta(original, n):
		r["itens"].append({"tipo": "consulta", "texto": LeitorMais.responder(u, original), "id": ""})
		r["entendeu"] = true
		return r
	# Regra para o próprio Livro: fica guardada com as leis.
	if LeitorMais.eh_regra_do_livro(n):
		LeitorMais.guardar_regra(u, original)
		r["itens"].append({"tipo": "regra", "texto": "Regra do Livro guardada: " + original, "id": ""})
		r["entendeu"] = true
		u.marcar_mudanca()
		return r
	var raiz := _raiz(u, original, ctx)
	r["raiz"] = raiz
	var foco := str(ctx.get("foco", ""))
	# 1. Lugar.
	var citado_antes := _lugar_citado(u, original)
	var lugar := _ler_lugar(u, original, n, raiz, foco)
	var base := ""
	if lugar != "" and _nome_proprio(original) == "" and not original.contains(str(u.entidade(lugar)["nome"])):
		# Lugar novo sem nome próprio: se a frase fala de um lugar que já existe ("Kreven estava em um grande deserto"),
		# ou se é uma construção, ele pertence a esse lugar e a história não sai de lá.
		if citado_antes != "" and citado_antes != lugar:
			base = citado_antes
		elif foco != "" and TextUtil.normalizar(str(u.entidade(lugar)["tipo"])) in LeitorMais.CONSTRUCOES:
			base = foco
	if base != "":
		var tipo_l := str(u.entidade(lugar)["tipo"])
		var novo_nome := "%s de %s" % [tipo_l.substr(0, 1).to_upper() + tipo_l.substr(1), str(u.entidade(base)["nome"])]
		if LeitorMais._existe(u, novo_nome) == "":
			var cs: Array = u.entidade(lugar)["campos"].duplicate(true)
			cs.append({"chave": "fica em" if citado_antes == "" else "onde fica", "valor": str(u.entidade(base)["nome"])})
			u.editar_entidade(lugar, {"nome": novo_nome, "campos": cs})
		foco = base
		r["itens"].append({"tipo": "lugar", "texto": "%s (%s)" % [u.entidade(lugar)["nome"], u.entidade(lugar)["tipo"]], "id": lugar})
	elif lugar != "":
		foco = lugar
		r["itens"].append({"tipo": "lugar", "texto": "%s (%s)" % [u.entidade(lugar)["nome"], u.entidade(lugar)["tipo"]], "id": lugar})
	else:
		var citado := _lugar_citado(u, original)
		if citado != "":
			foco = citado
	# 1b. Regras vivas: perigos e dons que o mundo obedece (as pessoas se adaptam).
	var viva := RegrasVivas.ler(u, original, n, raiz, foco)
	if not viva.is_empty():
		r["itens"].append({"tipo": "lei", "texto": viva["texto"], "id": str(viva.get("fato", ""))})
		for c in viva.get("criados", []):
			r["itens"].append({"tipo": "lugar", "texto": "%s (%s)" % [u.entidade(c)["nome"], u.entidade(c)["tipo"]], "id": c})
		r["dias"] = tempo(n)
		r["entendeu"] = true
		r["foco"] = foco
		u.marcar_mudanca()
		return r
	# 1c. Lugar pelo nome ("na cidade de Austin", "na Profundeza").
	if lugar == "":
		lugar = LeitorMais.lugar_nomeado(u, original, n, raiz, foco)
		if lugar != "":
			foco = lugar
			r["itens"].append({"tipo": "lugar", "texto": "%s (%s)" % [u.entidade(lugar)["nome"], u.entidade(lugar)["tipo"]], "id": lugar})
	# 2. Gente.
	var gente := _ler_gente(u, original, n, raiz, foco)
	if not gente.is_empty():
		if foco == "":
			foco = gente["lugar"]
		r["itens"].append({"tipo": "gente", "texto": gente["texto"], "id": gente["lugar"]})
	# 2b. Do que o povo do lugar vive ("Seus moradores viviam da caça e da mineração").
	if gente.is_empty():
		var vida := LeitorMais.modo_de_vida(u, original, n, raiz, foco)
		if not vida.is_empty():
			r["itens"].append(vida)
	# 3. Criaturas.
	var cri := _ler_criatura(u, original, n, raiz, foco)
	if not cri.is_empty():
		r["itens"].append({"tipo": "criatura", "texto": cri["texto"], "id": cri["id"]})
	# 4. Necessidades.
	if cri.is_empty():
		for rec in _ler_necessidade(u, n, raiz, foco):
			r["itens"].append({"tipo": "recurso", "texto": rec, "id": foco})
	# 5. Pessoa com nome.
	var pessoa := _ler_pessoa(u, original, n, raiz, foco)
	if pessoa != "":
		r["itens"].append({"tipo": "pessoa", "texto": "%s (%s)" % [u.entidade(pessoa)["nome"], _descricao_curta(u, pessoa)], "id": pessoa})
	# 5b. Pessoas pelo nome, títulos ainda sem nome e o que está por vir.
	for it in LeitorMais.pessoas(u, original, n, raiz, foco):
		r["itens"].append(it)
	var vir := LeitorMais.por_vir(u, original, n, raiz, foco)
	if not vir.is_empty():
		r["itens"].append({"tipo": "por_vir", "texto": vir["texto"], "id": vir["quem"]})
	# 6. Sentimentos de um grupo ("o povo odeia o rei").
	var sent := _ler_sentimento(u, original, n, raiz, foco)
	if sent != "":
		r["itens"].append({"tipo": "sentimento", "texto": sent, "id": ""})
	# 7. Lei do universo.
	if r["itens"].is_empty() and _parece_lei(n):
		var lei := Regras.criar(u, original)
		if not lei.is_empty():
			_anotar(u, raiz, "regras", lei["id"])
			r["itens"].append({"tipo": "lei", "texto": lei["texto"] + ("" if lei.get("entendida", "") == "toda" else " (entendida em parte)"), "id": lei["id"]})
	# 7b. Ordem de criar ("Crie um mercado"); senão, a frase fica anotada como acontecimento.
	if r["itens"].is_empty():
		var feito := Consequencias.ler(u, original, n, raiz, foco)
		if feito.is_empty() and tempo(n) > 0:
			feito = {"tipo": "tempo", "texto": "O tempo passa.", "id": ""}
		if feito.is_empty():
			feito = LeitorMais.criar_por_ordem(u, original, n, raiz, foco)
		if feito.is_empty() and not ctx.get("sem_anotar", false):
			feito = LeitorMais.acontecimento(u, original, n, raiz, foco)
		if not feito.is_empty():
			r["itens"].append(feito)
	# 8. Tempo.
	r["dias"] = tempo(n)
	r["entendeu"] = not r["itens"].is_empty()
	r["foco"] = foco
	if not r["entendeu"]:
		# Nada criado: a raiz não fica no canon (não é preciso guardar uma frase que não mudou nada).
		var f := u.fatos.obter(raiz)
		if not f.is_empty() and Array(f["dados"].get("criados", [])).is_empty():
			f["dados"]["vazia"] = true
	u.marcar_mudanca()
	return r


static func _limpo(t: String) -> String:
	var n := TextUtil.normalizar(t)
	for ch in [",", ".", ";", "!", "?", ":", "\"", "(", ")", "—", "–"]:
		n = n.replace(ch, " ")
	while n.contains("  "):
		n = n.replace("  ", " ")
	return n.strip_edges()


static func _raiz(u: Universo, frase: String, ctx: Dictionary) -> String:
	return u.fatos.registrar({"tipo": "escrita", "descricao": "Você escreveu: \"%s\"" % frase, "sujeitos": [], "lugar": str(ctx.get("foco", "")),
		"data": DataMundo.copiar(u.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_CAPITULO, "ref": str(ctx.get("capitulo", ""))},
		"dados": {"importancia": 0.05, "frase": frase, "criados": [], "regras": [], "leitura": true}})


static func _anotar(u: Universo, raiz: String, lista: String, id: String) -> void:
	var f := u.fatos.obter(raiz)
	if not f.is_empty():
		f["dados"][lista].append(id)


## Desfaz uma frase: o que ela criou sai do mundo (fica guardado), as leis são apagadas.
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
	for rid in f["dados"].get("regras", []):
		Regras.apagar(u, rid)
		n += 1
	# Tudo o que nasceu da frase, e tudo o que isso causou, deixa de valer.
	var fila: Array = [raiz]
	for g in u.fatos.todos():
		if g["canon"] and str(g["dados"].get("povoamento", "")) == raiz:
			fila.append(g["id"])
	while not fila.is_empty():
		var atual: String = fila.pop_front()
		var g := u.fatos.obter(atual)
		if g.is_empty() or not g["canon"]:
			continue
		g["canon"] = false
		n += 1
		for c in u.fatos.consequencias(atual):
			fila.append(c["id"])
	AutoAtualizador.reconstruir(u)
	u.marcar_mudanca()
	return n


static func numero(t: String) -> int:
	var w := TextUtil.normalizar(t).strip_edges()
	if w.is_valid_int():
		return int(w)
	return int(NUMEROS.get(w, 0))


static func _titulo(t: String) -> String:
	var partes: Array = []
	for w in t.strip_edges().split(" ", false):
		partes.append(w if TextUtil.normalizar(w) in ["de", "do", "da", "dos", "das", "e"] and not partes.is_empty() else w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(partes)


## O nome próprio que vem depois de "chamado", "de nome" ou entre aspas.
static func _nome_proprio(original: String) -> String:
	var rx := RegEx.new()
	rx.compile("(?:chamad[oa]s?|de nome|conhecid[oa] como|batizad[oa] de)\\s+([A-ZÀ-Ý][\\wÀ-ÿ'-]*(?:\\s+(?:de |do |da |dos |das )?[A-ZÀ-Ý][\\wÀ-ÿ'-]*)*)")
	var m := rx.search(original)
	if m != null:
		return m.get_string(1).strip_edges()
	rx.compile("[\"“]([^\"”]+)[\"”]")
	m = rx.search(original)
	if m != null:
		return m.get_string(1).strip_edges()
	return ""


# ---------------------------------------------------------------- lugares

static func _lugar_citado(u: Universo, original: String) -> String:
	for m in Ligador.new(u).encontrar(original):
		if Mapa.e_lugar(u, m["entidade"]) and Mapa.especie(u, m["entidade"]) != "planeta":
			return m["entidade"]
	return ""


static func _ler_lugar(u: Universo, original: String, n: String, raiz: String, foco: String) -> String:
	var rx := RegEx.new()
	rx.compile(" (um|uma|numa|num|em uma|em um|existe uma|existe um|ha uma|ha um|havia uma|havia um|crie|construa|erga|adicione) (?:(?:um|uma|uns|umas) )?(?:(?:pequen[ao]|grande|velh[ao]|antig[ao]|enorme|remot[ao]|isolad[ao]|perdid[ao]|misterios[ao]|abandonad[ao]|so|unic[ao]|minuscul[ao]|vast[ao]) )*(%s)( espacial| flutuante| subterranea| subterraneo| voadora| voador)?(?: |$)" % "|".join(todos_os_lugares().keys()))
	var m := rx.search(n)
	var tipo := ""
	var palavra := ""
	if m != null:
		palavra = m.get_string(2)
		tipo = str(todos_os_lugares()[palavra]) + m.get_string(3)
	# "Aru é uma ilha".
	var nome := _nome_proprio(original)
	if tipo == "":
		rx.compile("^([A-ZÀ-Ý][\\wÀ-ÿ'-]*(?: [A-ZÀ-Ý][\\wÀ-ÿ'-]*)?) (?:é|era|fica|ficava) (?:um|uma) (?:\\w+ )?(\\w+)")
		var m2 := rx.search(original)
		if m2 != null and LUGARES.has(TextUtil.normalizar(m2.get_string(2))):
			palavra = TextUtil.normalizar(m2.get_string(2))
			tipo = LUGARES[palavra]
			nome = m2.get_string(1)
	if tipo == "":
		return ""
	# Nome que já existe: é o mesmo lugar.
	if nome == "":
		var rd := RegEx.new()
		rd.compile("(?i)%s(?: espacial)? (?:de |do |da )?([A-ZÀ-Ý][\\wÀ-ÿ'-]+)" % palavra)
		var md := rd.search(TextUtil.normalizar(original) if false else original)
		if md != null and not TextUtil.normalizar(md.get_string(1)) in ["com", "onde", "que"]:
			nome = md.get_string(1)
	for e in u.entidades_ativas():
		if nome != "" and TextUtil.chave(e["nome"]) == TextUtil.chave(nome):
			return ""
	var mundo := _mundo(u, raiz, n)
	var rng := Povoador._rng(u, "leitor:" + original)
	if nome == "":
		var base: String = Linguas.gerar(u, Linguas.do_lugar(u, mundo), "lugares", rng)
		nome = base
	var campos: Array = [{"chave": "descrição", "valor": original}]
	var eid := u.criar_entidade(_titulo(nome), tipo, [], campos, [raiz])
	_anotar(u, raiz, "criados", eid)
	# No mapa do mundo, com o terreno que a frase pede.
	var sozinha := n.contains(" apenas ") or n.contains(" so existe ") or n.contains(" uma unica ") or n.contains(" no meio do oceano") or n.contains(" no meio do mar")
	# Onde: a frase pode dizer ("ao norte de Aru", "perto de Brasa", "na costa", "nas montanhas").
	var onde := onde_fica(u, original, n, mundo, nome, foco, rng)
	var pos: Vector2i = onde["pos"]
	if str(onde["pai"]) != mundo:
		Mapa.colocar(u, eid, str(onde["pai"]), pos.x, pos.y, false)
		if Mapa.PALAVRAS_TERRENO.has(palavra):
			Mapa.pintar(u, str(onde["pai"]), pos.x, pos.y, Mapa.PALAVRAS_TERRENO[palavra])
		var f0 := u.fatos.obter(raiz)
		if not f0.is_empty():
			f0["sujeitos"].append(eid)
			f0["lugar"] = eid
		return eid
	if palavra in ["ilha", "ilhota", "arquipelago"]:
		if sozinha:
			for y in Mapa.LINHAS:
				for x in Mapa.COLS:
					Mapa.pintar(u, mundo, x, y, "agua")
		var raio := 2.0 if palavra != "arquipelago" else 3.0
		if sozinha:
			# O mundo é só a ilha: o mapa mostra a ilha de perto (uns 90 km de mar e terra).
			raio = 6.0
			var cm: Array = u.entidade(mundo)["campos"].duplicate(true)
			if u.valor_campo(mundo, "largura") == "":
				cm.append({"chave": "largura", "valor": "90 km"})
				u.editar_entidade(mundo, {"campos": cm})
		var ruido := FastNoiseLite.new()
		ruido.seed = hash(original)
		ruido.frequency = 0.18
		var alcance := int(raio) + 3
		for dy in range(-alcance, alcance + 1):
			for dx in range(-alcance * 2, alcance * 2 + 1):
				var d := Vector2(dx * 0.55, dy).length()
				var borda := raio * (1.0 + 0.35 * ruido.get_noise_2d(pos.x + dx, pos.y + dy))
				if d <= borda:
					var t := "campo" if d > borda - 1.0 else ("colina" if d < raio * 0.25 and sozinha else "floresta")
					Mapa.pintar(u, mundo, pos.x + dx, pos.y + dy, t)
				elif d <= borda + 1.2 and not sozinha:
					Mapa.pintar(u, mundo, pos.x + dx, pos.y + dy, "agua")
	elif Mapa.PALAVRAS_TERRENO.has(palavra):
		# Uma floresta, uma montanha, um deserto: uma mancha do terreno, não um ponto só.
		var ter: String = Mapa.PALAVRAS_TERRENO[palavra]
		var rui := FastNoiseLite.new()
		rui.seed = hash(original)
		rui.frequency = 0.3
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				if Vector2(dx * 0.7, dy).length() <= 1.8 + rui.get_noise_2d(pos.x + dx, pos.y + dy) and Mapa.terreno_em(u, mundo, clampi(pos.x + dx, 0, Mapa.COLS - 1), clampi(pos.y + dy, 0, Mapa.LINHAS - 1)) != "agua":
					Mapa.pintar(u, mundo, pos.x + dx, pos.y + dy, ter)
		Mapa.pintar(u, mundo, pos.x, pos.y, ter)
	else:
		# O chão de uma vila, de uma torre: só terreno de terra ("costa" e "rio" dizem onde, não pintam água).
		for w in TextUtil.palavras(n):
			if Mapa.PALAVRAS_TERRENO.has(w) and Mapa.PALAVRAS_TERRENO[w] != "agua":
				Mapa.pintar(u, mundo, pos.x, pos.y, Mapa.PALAVRAS_TERRENO[w])
				break
	Mapa.colocar(u, eid, mundo, pos.x, pos.y, false)
	var f := u.fatos.obter(raiz)
	if not f.is_empty():
		f["sujeitos"].append(eid)
		f["lugar"] = eid
	return eid


## O mundo onde as coisas escritas ficam: o primeiro planeta, ou um mundo novo.
static func _mundo(u: Universo, raiz: String, n: String) -> String:
	for e in u.entidades_ativas():
		if Mapa.especie(u, e["id"]) == "planeta" and Mapa.pai(u, e["id"]) == "":
			return e["id"]
	var nave := n.contains(" nave ") or n.contains(" espaco ") or n.contains(" estacao espacial")
	var eid := u.criar_entidade("O Espaço" if nave else "O Mundo", "mundo", [], [{"chave": "descrição", "valor": "Onde acontece o que você escreve."}], [raiz])
	_anotar(u, raiz, "criados", eid)
	Mapa.colocar(u, eid, "", Mapa.COLS / 2, Mapa.LINHAS / 2, false)
	if nave:
		for y in Mapa.LINHAS:
			for x in Mapa.COLS:
				Mapa.pintar(u, eid, x, y, "vazio")
	return eid


const DIRECOES := {"nordeste": Vector2i(1, -1), "noroeste": Vector2i(-1, -1), "sudeste": Vector2i(1, 1), "sudoeste": Vector2i(-1, 1),
	"norte": Vector2i(0, -1), "sul": Vector2i(0, 1), "leste": Vector2i(1, 0), "oeste": Vector2i(-1, 0), "oriente": Vector2i(1, 0), "ocidente": Vector2i(-1, 0)}


## Onde fica o que a frase cria: {pai, pos}.
##   "ao norte de Aru", "a leste de Brasa" → do lado de lá, a uns 4 quadros;
##   "perto de", "ao lado de", "junto a" → colado; "longe de" → bem longe;
##   "na costa", "na praia", "no litoral" → terra encostada no mar;
##   "nas montanhas", "na floresta", "no deserto" → num quadro desse terreno;
##   "em Brasa", "dentro de Brasa" (uma cidade) → dentro dela, no mapa dela.
static func onde_fica(u: Universo, original: String, n: String, mundo: String, nome_novo: String, foco: String, rng: RandomNumberGenerator) -> Dictionary:
	var ref := ""
	for m in Ligador.new(u).encontrar(original):
		var x: String = m["entidade"]
		if TextUtil.chave(u.entidade(x)["nome"]) == TextUtil.chave(nome_novo) or not Mapa.no_mapa(u, x) or Mapa.especie(u, x) in ["planeta", "cosmico"]:
			continue
		ref = x
		break
	# "na ilha", "da vila" sem nome: o lugar da cena.
	if ref == "" and foco != "" and Mapa.no_mapa(u, foco):
		for w in [" da ilha", " na ilha", " da vila", " na vila", " da cidade", " na cidade", " do vale", " no vale", " da aldeia", " na aldeia", " do reino", " no reino"]:
			if n.contains(w):
				ref = foco
	var dir := Vector2i.ZERO
	for d in DIRECOES:
		if n.contains(" " + d):
			dir = DIRECOES[d]
			break
	var dist := 4
	if n.contains(" longe"):
		dist = 9
	elif n.contains(" perto") or n.contains(" ao lado") or n.contains(" junto") or n.contains(" vizinh") or n.contains(" encostad"):
		dist = 2
	var costa := n.contains(" costa") or n.contains(" praia") or n.contains(" litoral") or n.contains(" beira mar") or n.contains(" beira do mar") or n.contains(" orla")
	var terreno := ""
	for w in TextUtil.palavras(n):
		if Mapa.PALAVRAS_TERRENO.has(w) and not w in ["mar", "costa", "praia", "baia", "rio", "lago", "lagoa"]:
			terreno = Mapa.PALAVRAS_TERRENO[w]
	var pai := mundo
	var base := Vector2i(-1, -1)
	if ref != "":
		var dentro := Mapa.especie(u, ref) in ["povoado", "construcao"] and (n.contains(" em " + TextUtil.normalizar(u.entidade(ref)["nome"])) or n.contains(" dentro d"))
		if dentro and dir == Vector2i.ZERO:
			return {"pai": ref, "pos": _livre_perto(u, ref, Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2) + Vector2i(rng.randi() % 9 - 4, rng.randi() % 5 - 2))}
		if dentro:
			return {"pai": ref, "pos": _livre_perto(u, ref, Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2) + Vector2i(dir.x * 10, dir.y * 5))}
		pai = Mapa.pai(u, ref)
		var p := Mapa.posicao(u, ref)
		base = Vector2i(int(p["x"]), int(p["y"]))
		# Uma ilha (ou outro lugar grande desenhado no mapa): "em Aru" fica dentro da terra dela.
		var grande := Mapa.especie(u, ref) in ["natural", "regiao"]
		if dir == Vector2i.ZERO and not costa and terreno == "":
			var off := Vector2i(rng.randi() % 5 - 2, rng.randi() % 3 - 1) if grande else Vector2i(dist * (1 if rng.randf() < 0.5 else -1), rng.randi() % 3 - 1)
			return {"pai": pai, "pos": _livre_perto(u, pai, base + off, true)}
		if dir != Vector2i.ZERO and not costa:
			var d := dist
			return {"pai": pai, "pos": _livre_perto(u, pai, base + Vector2i(dir.x * d * 2, dir.y * d), true)}
	else:
		var fp := Mapa.posicao(u, foco) if foco != "" else {}
		if not fp.is_empty() and Mapa.pai(u, foco) == mundo:
			base = Vector2i(int(fp["x"]), int(fp["y"]))
	if costa:
		var c := _costa(u, pai, base, dir)
		if c.x >= 0:
			return {"pai": pai, "pos": _livre_perto(u, pai, c)}
	if terreno != "":
		var cel := Mapa.celulas_livres(u, pai, [terreno])
		if not cel.is_empty():
			var alvo := base if base.x >= 0 else Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2)
			if dir != Vector2i.ZERO:
				alvo += Vector2i(dir.x * 12, dir.y * 6)
			cel.sort_custom(func(a, b): return Vector2(a - alvo).length() < Vector2(b - alvo).length())
			return {"pai": pai, "pos": cel[0]}
	if base.x >= 0 and dir != Vector2i.ZERO:
		return {"pai": pai, "pos": _livre_perto(u, pai, base + Vector2i(dir.x * dist * 2, dir.y * dist), true)}
	return {"pai": pai, "pos": _posicao_livre(u, pai, rng)}


## Terra encostada no mar, perto de 'base' e do lado de 'dir'.
static func _costa(u: Universo, de: String, base: Vector2i, dir: Vector2i) -> Vector2i:
	var g := Mapa.terreno(u, de)
	var melhor := Vector2i(-1, -1)
	var melhor_v := INF
	var alvo := base if base.x >= 0 else Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2)
	alvo += Vector2i(dir.x * 20, dir.y * 10)
	for y in Mapa.LINHAS:
		for x in Mapa.COLS:
			if g[y][x] in ["agua", "vazio"]:
				continue
			var junto := false
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Variant = Vector2i(x, y) + v
				if q.x >= 0 and q.y >= 0 and q.x < Mapa.COLS and q.y < Mapa.LINHAS and g[q.y][q.x] == "agua":
					junto = true
			if not junto:
				continue
			var d := Vector2(Vector2i(x, y) - alvo).length() + (0.0 if base.x < 0 else Vector2(Vector2i(x, y) - base).length() * 0.6)
			if d < melhor_v:
				melhor_v = d
				melhor = Vector2i(x, y)
	return melhor


## O quadro livre mais perto de 'c' (sem ninguém em cima; em terra, se pedido).
static func _livre_perto(u: Universo, de: String, c: Vector2i, terra: bool = false) -> Vector2i:
	var ocupados := {}
	for x in Mapa.filhos(u, de):
		var p := Mapa.posicao(u, x)
		ocupados[Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))] = true
	var g := Mapa.terreno(u, de)
	var alvo := Vector2i(clampi(c.x, 1, Mapa.COLS - 2), clampi(c.y, 1, Mapa.LINHAS - 2))
	for r in range(0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := alvo + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= Mapa.COLS or q.y >= Mapa.LINHAS or ocupados.has(q):
					continue
				if terra and g[q.y][q.x] in ["agua", "vazio"]:
					continue
				return q
	return alvo


static func _posicao_livre(u: Universo, mundo: String, rng: RandomNumberGenerator) -> Vector2i:
	var ocupados: Array = Mapa.filhos(u, mundo).map(func(x): var p := Mapa.posicao(u, x); return Vector2i(int(p.get("x", 0)), int(p.get("y", 0))))
	if ocupados.is_empty():
		return Vector2i(Mapa.COLS / 2, Mapa.LINHAS / 2)
	for tentativa in 60:
		var c := Vector2i(4 + rng.randi() % (Mapa.COLS - 8), 3 + rng.randi() % (Mapa.LINHAS - 6))
		if ocupados.all(func(o): return Vector2(c - o).length() >= 6.0):
			return c
	return Vector2i(rng.randi() % Mapa.COLS, rng.randi() % Mapa.LINHAS)


# ---------------------------------------------------------------- gente

static func _ler_gente(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var rx := RegEx.new()
	rx.compile(" (\\d+|%s) ([a-z]+)(?: ([a-z]+))?" % "|".join(NUMEROS.keys()))
	for m in rx.search_all(n):
		var grupo := m.get_string(2)
		var extra := m.get_string(3)
		if not (grupo in GENTE or (grupo.ends_with("s") and extra in GENTE)):
			continue
		if not grupo in GENTE:
			var t := grupo
			grupo = extra
			extra = t
		if extra in ["ate", "que", "em", "na", "no", "nas", "nos", "de", "do", "da", "e", "com", "sem", "para", "por", "quando", "antes", "depois", "ja", "nao"]:
			extra = ""
		var qtd := numero(m.get_string(1))
		if qtd <= 0 or qtd > 1000000:
			continue
		var lugar := foco if foco != "" else _lugar_citado(u, original)
		if lugar == "":
			lugar = _lugar_padrao(u, raiz, n)
		return _povoar(u, lugar, qtd, grupo, extra, raiz)
	return {}


## Quando a frase não diz onde: um povoado para a gente morar.
static func _lugar_padrao(u: Universo, raiz: String, n: String) -> String:
	var mundo := _mundo(u, raiz, n)
	var rng := Povoador._rng(u, "padrao")
	var eid := u.criar_entidade(Linguas.gerar(u, Linguas.do_lugar(u, mundo), "lugares", rng), "povoado", [], [], [raiz])
	_anotar(u, raiz, "criados", eid)
	var pos := _posicao_livre(u, mundo, rng)
	Mapa.colocar(u, eid, mundo, pos.x, pos.y, false)
	return eid


static func _povoar(u: Universo, lugar: String, qtd: int, grupo: String, extra: String, raiz: String) -> Dictionary:
	var rng := Povoador._rng(u, "gente:%s:%d" % [lugar, qtd])
	var lingua := Linguas.do_lugar(u, lugar)
	var povo: String = POVOS.get(grupo, POVOS.get(extra, ""))
	var oficio_do_grupo: String = OFICIOS_DE_GRUPO.get(grupo, OFICIOS_DE_GRUPO.get(extra, ""))
	var tipo_l := TextUtil.normalizar(u.entidade(lugar)["tipo"])
	var oficios: Array = []
	for k in OFICIOS_DO_LUGAR:
		if tipo_l.contains(k):
			oficios = OFICIOS_DO_LUGAR[k]
	if oficios.is_empty():
		oficios = Povoador.OFICIOS_COMUNS
	var individuos := mini(qtd, 60)
	var criados: Array = []
	var familia_nome := ""
	for i in individuos:
		if i % 4 == 0:
			familia_nome = Linguas.gerar(u, lingua, "sobrenomes", rng)
		var faixa := rng.randf()
		var idade := 18 + rng.randi() % 38
		if faixa < 0.15 and grupo in ["pessoas", "habitantes", "moradores", "familias", "colonos", "sobreviventes", "naufragos", "refugiados", "aldeoes", "camponeses"]:
			idade = 4 + rng.randi() % 11
		elif faixa > 0.88:
			idade = 58 + rng.randi() % 20
		# Os ofícios típicos do lugar aparecem todos antes de se repetirem.
		var adultos_antes := criados.filter(func(x): return Estado.idade(u, x) >= 12).size()
		var tipico: String = oficios[adultos_antes] if adultos_antes < oficios.size() else oficios[rng.randi() % oficios.size()]
		var of: String = oficio_do_grupo if oficio_do_grupo != "" and idade >= 14 else ("criança" if idade < 12 else tipico)
		var nome := "%s %s" % [Linguas.gerar(u, lingua, "pessoas", rng), familia_nome]
		var eid := Povoador._pessoa(u, nome, idade, of, rng, lugar, raiz, "")
		if povo != "":
			var campos: Array = u.entidade(eid)["campos"].duplicate(true)
			campos.append({"chave": "povo", "valor": povo})
			u.editar_entidade(eid, {"campos": campos})
		criados.append(eid)
	# A população inteira fica na ficha do lugar.
	var cl: Array = u.entidade(lugar)["campos"].duplicate(true)
	cl.append({"chave": "população", "valor": str(qtd)})
	if povo != "":
		cl.append({"chave": "povo", "valor": povo})
	u.editar_entidade(lugar, {"campos": cl})
	# O povo nasce sob as leis do mundo: já adaptado aos perigos, já com os dons do lugar.
	RegrasVivas.ao_povoar(u, lugar, raiz)
	var palavra := grupo.replace("criancas", "crianças").replace("anoes", "anões").replace("aldeoes", "aldeões").replace("orfaos", "órfãos").replace("naufragos", "náufragos").replace("artesaos", "artesãos").replace("operarios", "operários").replace("nomades", "nômades")
	var texto := "%d %s%s em %s" % [qtd, palavra, (" " + extra) if extra != "" and not extra in GENTE else "", u.entidade(lugar)["nome"]]
	if qtd > individuos:
		texto += " (%d com nome e história)" % individuos
	return {"lugar": lugar, "texto": texto, "criados": criados}


## Onde está a gente de quem a frase fala: o lugar da cena, se mora alguém ali; senão,
## o lugar mais habitado por perto (a caverna recém-escrita não tem gente; a ilha tem).
static func lugar_da_gente(u: Universo, foco: String) -> String:
	if foco == "" or not Ameacas._pessoas(u, foco).is_empty():
		return foco
	# Primeiro os vizinhos no mesmo mapa (o mais habitado); depois quem está acima, se não for o mundo todo.
	var cand: Array = []
	var mapa := Mapa.pai(u, foco)
	for x in Mapa.filhos(u, mapa):
		var n := Ameacas._pessoas(u, x).size()
		if n > 0 and x != foco:
			cand.append([x, n])
	if not cand.is_empty():
		cand.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		return cand[0][0]
	for a in Mapa.ancestrais(u, foco):
		if Mapa.especie(u, a) in ["planeta", "cosmico"]:
			break
		if not Ameacas._pessoas(u, a).is_empty():
			return a
	return foco


# ---------------------------------------------------------------- criaturas

static func _ler_criatura(u: Universo, original: String, n: String, raiz: String, foco: String) -> Dictionary:
	var efeito := ""
	var pos_efeito := -1
	for par in EFEITOS:
		for w in par[1]:
			var i := n.find(" " + w)
			if i >= 0 and (pos_efeito < 0 or i < pos_efeito):
				efeito = par[0]
				pos_efeito = i
	var pos_aparece := -1
	for w in APARECER:
		var i := n.find(" " + w)
		if i >= 0 and (pos_aparece < 0 or i < pos_aparece):
			pos_aparece = i
	if efeito == "" and pos_aparece < 0:
		return {}
	var corte := pos_aparece if pos_aparece >= 0 and (pos_efeito < 0 or pos_aparece < pos_efeito) else pos_efeito
	# Quem: as palavras antes do verbo, sem tempo, artigos e "começam a".
	var antes := n.substr(0, corte).strip_edges()
	for w in [" comecam a", " comecaram a", " passam a", " passaram a", " costumam", " voltam a", " continuam a", " ainda", " sempre", " tambem"]:
		antes = antes.replace(w, "")
	var pal: Array = Array(antes.split(" ", false))
	var tempo_w := ["a", "noite", "de", "toda", "todo", "todas", "todos", "as", "noites", "o", "inverno", "verao", "dia", "dias", "quando", "chove",
		"na", "no", "lua", "cheia", "vez", "em", "quando", "ao", "anoitecer", "entardecer", "madrugada", "durante", "os", "uns", "umas", "e", "entao",
		"depois", "disso", "ali", "la", "aqui", "dali", "estranhos", "estranhas", "novos", "novas", "mais", "primavera", "outono"]
	var sujeito: Array = []
	for w in pal:
		if w in tempo_w and sujeito.is_empty():
			continue
		if w in ["que", "onde", "e"] and not sujeito.is_empty():
			sujeito = []
			continue
		sujeito.append(w)
	if sujeito.is_empty():
		return {}
	# Número na frente ("três dragões", "dezenas de goblins").
	var base := 3.0
	if numero(str(sujeito[0])) > 0 and sujeito.size() > 1:
		base = float(numero(str(sujeito[0])))
		sujeito.pop_front()
		if not sujeito.is_empty() and sujeito[0] == "de":
			sujeito.pop_front()
	if sujeito.is_empty():
		return {}
	var nome_pl_n := " ".join(sujeito.slice(0, 3))
	var primeira: String = sujeito[0]
	# Se o sujeito é gente (as pessoas, os soldados) ou alguém com nome, não é criatura.
	if primeira in GENTE or primeira in ["ele", "ela", "eles", "elas", "todos", "ninguem", "alguem", "voce", "eu", "nos", "povo", "o", "a"]:
		return {}
	for m in Ligador.new(u).encontrar(original):
		if TextUtil.normalizar(m["texto"]).contains(primeira) and Estado.tem_mente(u, m["entidade"]):
			return {}
	if not primeira.ends_with("s") and not (efeito != "" and pos_aparece >= 0):
		return {}
	var nome_pl := Regras._original_de(original, nome_pl_n)
	var sing := _singular(nome_pl.split(" ")[0])
	var nome_especie := sing.substr(0, 1).to_upper() + sing.substr(1)
	var quando := "sempre"
	for par in [[" a noite", "noite"], [" de noite", "noite"], [" toda noite", "noite"], [" todas as noites", "noite"], [" ao anoitecer", "noite"], [" na madrugada", "noite"],
			[" de dia", "dia"], [" durante o dia", "dia"], [" inverno", "inverno"], [" verao", "verao"], [" primavera", "primavera"], [" outono", "outono"],
			[" lua cheia", "lua"], [" as vezes", "raro"], [" de vez em quando", "raro"], [" raramente", "raro"], [" quando chove", "raro"]]:
		if n.contains(par[0]):
			quando = par[1]
			break
	if efeito == "":
		efeito = "rondar"
	var alvo := "as pessoas"
	for par in [[" as casas", "as casas"], [" as plantacoes", "as plantações"], [" o gado", "o gado"], [" as criancas", "as crianças"], [" os viajantes", "os viajantes"], [" a comida", "a comida"]]:
		if n.contains(par[0]):
			alvo = par[1]
	if n.contains(" muitos ") or n.contains(" hordas ") or n.contains(" centenas ") or n.contains(" enxames "):
		base = maxf(base, 15.0)
	var lugar := _lugar_citado(u, original)
	if lugar == "" or Ameacas._pessoas(u, lugar).is_empty():
		lugar = lugar_da_gente(u, foco if lugar == "" else lugar)
	if lugar == "":
		for e in u.entidades_ativas():
			if Mapa.e_lugar(u, e["id"]) and not Ameacas._pessoas(u, e["id"]).is_empty():
				lugar = e["id"]
				break
	if lugar == "":
		return {}
	# A espécie (uma entidade só, mesmo que a frase volte a falar dela).
	var especie := ""
	for e in u.entidades_ativas():
		if TextUtil.chave(e["nome"]) == TextUtil.chave(nome_especie) or TextUtil.chave(e["nome"]) == TextUtil.chave(nome_pl.split(" ")[0]):
			especie = e["id"]
	if especie == "":
		var plural_nome := nome_pl.split(" ")[0]
		plural_nome = plural_nome.substr(0, 1).to_upper() + plural_nome.substr(1)
		especie = u.criar_entidade(nome_especie, "criatura", [plural_nome] if TextUtil.chave(plural_nome) != TextUtil.chave(nome_especie) else [], [{"chave": "descrição", "valor": original}, {"chave": "força", "valor": "%.1f" % Ameacas.forca_de(sing, n)}], [raiz])
		_anotar(u, raiz, "criados", especie)
	var dados := {"lugar": lugar, "quando": quando, "efeito": efeito, "alvo": alvo, "forca": Ameacas.forca_de(sing, n), "base": base, "pop": base,
		"plural": nome_pl.to_lower(), "fato": raiz, "defesas": {}}
	var fid := Simulador.registrar(u, {"tipo": "ameaça", "descricao": "%s passaram a aparecer em %s." % [Conversa._maiuscula(nome_pl.to_lower()), u.entidade(lugar)["nome"]],
		"sujeitos": [especie, lugar], "lugar": lugar, "causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
		"dados": {"importancia": 0.5, "povoamento": raiz, "mudancas": [{"op": "ameaca", "quem": especie, "dados": dados}]}})
	return {"id": especie, "texto": "%s: %s" % [nome_especie, Ameacas.resumo(u, especie).split(" Ataques:")[0]], "fato": fid}


static func _singular(p: String) -> String:
	var w := p.to_lower()
	for par in [["oes", "ão"], ["ões", "ão"], ["aes", "ão"], ["ães", "ão"], ["eis", "el"], ["ais", "al"], ["res", "r"], ["zes", "z"], ["ns", "m"], ["ses", "s"]]:
		if w.ends_with(par[0]) and w.length() > par[0].length() + 1:
			return w.substr(0, w.length() - par[0].length()) + par[1]
	if w.ends_with("s") and w.length() > 3:
		return w.substr(0, w.length() - 1)
	return w


# ---------------------------------------------------------------- necessidades

static func _ler_necessidade(u: Universo, n: String, raiz: String, foco: String) -> Array:
	var lugar := lugar_da_gente(u, foco)
	if lugar == "":
		return []
	var pedidos: Array = []  # [nome, reserva, fonte]
	if n.contains(" sobreviver") or n.contains(" sobrevivencia") or n.contains(" sobrevivem"):
		pedidos.append(["comida", 10.0, "coleta"])
	var rx := RegEx.new()
	rx.compile("(?:precisa|precisam|precisavam|necessitam|dependem) (?:de |d[eoa]s? )(\\w+)")
	for m in rx.search_all(n):
		pedidos.append([_recurso(m.get_string(1)), 10.0, "coleta"])
	rx.compile("(?:o|a|os|as) (\\w+) (?:esta|estao|estava|estavam) (?:acabando|no fim|terminando|quase no fim)")
	for m in rx.search_all(n):
		pedidos.append([_recurso(m.get_string(1)), 6.0, "coleta" if _recurso(m.get_string(1)) in ["comida", "agua", "lenha"] else "nenhuma"])
	rx.compile("(?:falta|faltam|pouc[ao]s?|escass[ao]s?) (?:de )?(\\w+)|(?:o|a) (\\w+) (?:e|era) escass")
	for m in rx.search_all(n):
		var w := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
		if w in ["comida", "agua", "oxigenio", "ar", "lenha", "remedio", "remedios", "combustivel", "energia", "alimento", "alimentos", "racao", "racoes"]:
			pedidos.append([_recurso(w), 5.0, "coleta" if _recurso(w) in ["comida", "agua", "lenha"] else "nenhuma"])
	var feitos: Array = []
	var ja := Recursos.de(u, lugar)
	for p in pedidos:
		var nome: String = p[0]
		if nome == "" or ja.has(nome) or feitos.has(nome):
			continue
		var rende := Recursos.rendimento(u, lugar)
		var fonte: String = p[2]
		if rende <= 0.0 and fonte == "coleta":
			fonte = "nenhuma"
		Simulador.registrar(u, {"tipo": "necessidade", "descricao": "Em %s, %s passou a ser contada." % [u.entidade(lugar)["nome"], Recursos._palavra(nome)],
			"sujeitos": [lugar], "lugar": lugar, "causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"},
			"dados": {"importancia": 0.2, "povoamento": raiz, "recurso": nome, "mudancas": [{"op": "recurso", "quem": lugar, "nome": nome,
				"dados": {"reserva": p[1], "fonte": fonte, "rende": rende, "alerta": ""}}]}})
		feitos.append(nome)
	return feitos.map(func(x): return "%s em %s: reserva para %d dias%s" % [Conversa._maiuscula(Recursos._palavra(x)), u.entidade(lugar)["nome"], int(Recursos.de(u, lugar)[x]["reserva"]),
		" (sem de onde tirar mais)" if str(Recursos.de(u, lugar)[x]["fonte"]) == "nenhuma" else ", vem do que conseguem juntar"])


static func _recurso(w: String) -> String:
	match w:
		"comida", "alimento", "alimentos", "racao", "racoes", "comer", "mantimentos", "suprimentos":
			return "comida"
		"agua":
			return "agua"
		"oxigenio", "ar":
			return "oxigenio"
		"remedio", "remedios":
			return "remedio"
	return w if w.length() > 2 and not w in ["sobreviver", "ajuda", "voce", "ele", "ela", "eles", "elas", "todos"] else ""


# ---------------------------------------------------------------- pessoas com nome

static func _ler_pessoa(u: Universo, original: String, n: String, raiz: String, foco: String) -> String:
	var nome := ""
	var papel := ""
	var rx := RegEx.new()
	# "um rei cruel chamado Odo", "uma velha curandeira chamada Nana"
	rx.compile(" (?:um|uma|o|a) ((?:\\w+ ){0,2}?)(%s)((?: \\w+){0,2}?) (?:chamad[oa]|de nome|conhecid[oa] como)" % "|".join(PAPEIS.keys()))
	var m := rx.search(n)
	if m != null:
		papel = m.get_string(2)
		nome = _nome_proprio(original)
	if nome == "":
		# "Mira, a pescadora, …" ou "Mira, uma jovem pescadora, …"
		var ro := RegEx.new()
		ro.compile("^([A-ZÀ-Ý][\\wÀ-ÿ'-]+(?: [A-ZÀ-Ý][\\wÀ-ÿ'-]+)?), (?:o|a|um|uma) ((?:\\w+ ){0,2}?)(\\w+)[ ,]")
		var mo := ro.search(original)
		if mo != null and PAPEIS.has(TextUtil.normalizar(mo.get_string(3))):
			nome = mo.get_string(1)
			papel = TextUtil.normalizar(mo.get_string(3))
	if nome == "" or papel == "":
		return ""
	for e in u.entidades_ativas():
		if TextUtil.chave(e["nome"]) == TextUtil.chave(nome):
			return ""
	var p: Array = PAPEIS[papel]
	var lugar := foco if foco != "" else _lugar_citado(u, original)
	var campos: Array = [{"chave": "idade", "valor": "%d anos" % int(p[1])}]
	if str(p[0]) != "":
		campos.append({"chave": "cargo" if papel in CARGOS else "ofício", "valor": str(p[0]) + ((" de " + u.entidade(lugar)["nome"]) if papel in CARGOS and lugar != "" else "")})
	# O jeito: adjetivos da frase ("cruel", "sábio", "medroso").
	var jeito: Array = []
	for w in TextUtil.palavras(n):
		for pista in Personalidade.PISTAS:
			if w.begins_with(pista) and not jeito.has(w):
				jeito.append(w)
	if not jeito.is_empty():
		campos.append({"chave": "personalidade", "valor": " e ".join(jeito)})
	campos.append({"chave": "descrição", "valor": original})
	var eid := u.criar_entidade(nome, "pessoa", [], campos, [raiz])
	_anotar(u, raiz, "criados", eid)
	if lugar != "":
		Simulador.registrar(u, {"tipo": "presença", "descricao": "%s está em %s." % [nome, u.entidade(lugar)["nome"]], "sujeitos": [eid, lugar], "lugar": lugar,
			"causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": 0.1, "povoamento": raiz, "mudancas": [{"op": "mover", "quem": eid, "lugar": lugar}]}})
		if papel in CARGOS:
			var cl: Array = u.entidade(lugar)["campos"].duplicate(true)
			cl.append({"chave": "quem governa", "valor": nome})
			u.editar_entidade(lugar, {"campos": cl})
	return eid


static func _descricao_curta(u: Universo, eid: String) -> String:
	var partes: Array = []
	for k in ["cargo", "ofício", "personalidade"]:
		var v := u.valor_campo(eid, k)
		if v != "":
			partes.append(v)
	return ", ".join(partes) if not partes.is_empty() else "pessoa"


# ---------------------------------------------------------------- sentimentos

static func _ler_sentimento(u: Universo, original: String, n: String, raiz: String, foco: String) -> String:
	var verbo := ""
	var deltas := {}
	for v in SENTIMENTOS:
		if n.contains(" " + v + " "):
			verbo = v
			deltas = SENTIMENTOS[v]
	if verbo == "":
		return ""
	var i := n.find(" " + verbo + " ")
	var antes := n.substr(0, i)
	var depois := n.substr(i + verbo.length() + 2)
	var grupo := antes.contains("povo") or antes.contains("todos") or antes.contains("pessoas") or antes.contains("moradores") or antes.contains("habitantes") \
		or antes.contains("aldeoes") or antes.contains("camponeses") or antes.contains("tripula") or antes.contains("soldados") or antes.contains("criancas")
	# O alvo: alguém com nome, ou um papel ("o rei", "a capitã").
	var alvo := ""
	for m in Ligador.new(u).encontrar(original):
		if Estado.tem_mente(u, m["entidade"]) and TextUtil.normalizar(original).find(TextUtil.normalizar(m["texto"])) > i - 2:
			alvo = m["entidade"]
	if alvo == "":
		for papel in CARGOS:
			if depois.begins_with("o " + papel) or depois.begins_with("a " + papel) or depois.begins_with(papel):
				for e in u.entidades_ativas():
					if TextUtil.normalizar(u.valor_campo(e["id"], "cargo")).begins_with(TextUtil.normalizar(str(PAPEIS[papel][0]))):
						alvo = e["id"]
	if alvo == "":
		return ""
	var quem: Array = []
	if grupo:
		var lugar := foco if foco != "" else str(u.estado(alvo).get("local", ""))
		quem = Ameacas._pessoas(u, lugar).filter(func(x): return x != alvo)
	else:
		for m in Ligador.new(u).encontrar(original):
			if Estado.tem_mente(u, m["entidade"]) and m["entidade"] != alvo:
				quem.append(m["entidade"])
				break
	if quem.is_empty():
		return ""
	var ops: Array = []
	for q in quem:
		ops.append({"op": "relacao", "de": q, "para": alvo, "deltas": deltas})
		if deltas.has("raiva"):
			ops.append({"op": "emocao", "quem": q, "emocao": "raiva", "forca": float(deltas["raiva"]), "alvo": alvo})
	Simulador.registrar(u, {"tipo": "sentimento", "descricao": Conversa._maiuscula(original.trim_suffix(".")) + ".", "sujeitos": [quem[0], alvo], "lugar": foco,
		"causas": [raiz], "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "escrita"}, "dados": {"importancia": 0.3, "povoamento": raiz, "mudancas": ops}})
	var v := verbo
	if quem.size() > 1 and not v.ends_with("am") and not v.ends_with("em"):
		v = v.replace("confia em", "confiam em") if v.begins_with("confia") else (v.substr(0, v.length() - 1) + ("em" if v.ends_with("e") else "am"))
	return "%s %s %s" % ["%d pessoas" % quem.size() if quem.size() > 1 else u.entidade(quem[0])["nome"], v, u.entidade(alvo)["nome"]]


# ---------------------------------------------------------------- leis e tempo

static func _parece_lei(n: String) -> bool:
	var t := n.strip_edges()
	for p in ["neste mundo", "nesse mundo", "neste universo", "aqui ", "quem ", "todo aquele", "toda vez", "sempre que", "a cada ", "todos que", "todo mundo que"]:
		if t.begins_with(p):
			return true
	return t.contains("->") or t.contains("→")


## Quantos dias a frase faz passar ("no dia seguinte", "três anos depois").
static func tempo(n: String) -> int:
	var t := " " + n.strip_edges() + " "
	var rx := RegEx.new()
	rx.compile(" (\\d+|%s) (dias?|semanas?|mes|meses|anos?|decadas?|seculos?) (?:depois|mais tarde|se passaram|passaram|se passou|apos)" % "|".join(NUMEROS.keys()))
	var m := rx.search(t)
	var unidades := {"dia": 1, "dias": 1, "semana": 7, "semanas": 7, "mes": 30, "meses": 30, "ano": 360, "anos": 360, "decada": 3600, "decadas": 3600, "seculo": 36000, "seculos": 36000}
	if m != null:
		return mini(numero(m.get_string(1)) * int(unidades[m.get_string(2)]), 36000)
	rx.compile(" (?:passaram-se|passaram se|passou-se|se passaram|depois de) (\\d+|%s) (dias?|semanas?|mes|meses|anos?|decadas?|seculos?)" % "|".join(NUMEROS.keys()))
	m = rx.search(t)
	if m != null:
		return mini(numero(m.get_string(1)) * int(unidades[m.get_string(2)]), 36000)
	for par in [[" no dia seguinte", 1], [" na manha seguinte", 1], [" na noite seguinte", 1], [" ao amanhecer", 1], [" dias depois", 3], [" alguns dias", 3],
			[" semanas depois", 21], [" meses depois", 90], [" anos depois", 1080], [" muito tempo depois", 1800], [" uma semana depois", 7],
			[" um mes depois", 30], [" um ano depois", 360], [" naquele inverno", 30], [" o tempo passou", 30], [" com o tempo", 30]]:
		if t.contains(par[0]):
			return int(par[1])
	return 0
