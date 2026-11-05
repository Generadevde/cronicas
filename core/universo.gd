class_name Universo
extends RefCounted
## Um universo inteiro: entidades, banco de fatos, livros, capítulos, notas.
## Toda mudança importante passa por aqui para virar fato no banco de fatos.

signal mudou

const VERSAO_FORMATO := 1

var id := ""
var nome := ""
var descricao := ""          ## texto livre: tema, tom, inspirações, regras gerais
var criado_em := ""
var atualizado_em := ""
var relogio: Dictionary = DataMundo.criar(1, 1)

var fatos := BancoDeFatos.new()
var entidades: Dictionary = {}   ## id -> entidade
var livros: Array = []           ## [{id, titulo, capitulos: [ids]}], na ordem da estante
var capitulos: Dictionary = {}   ## id -> capítulo
var notas: Array = []            ## notas privadas do autor (a simulação nunca lê)
var propostas: Array = []        ## fatos e ecos propostos, esperando o autor
var dicionario: Dictionary = {}  ## palavra ensinada pelo autor -> ação ("esmurrou" -> "vitoria")
var extras: Dictionary = {}      ## dados dos sistemas das próximas partes (mapa, regras, guerras...)

var _indice_cache: Dictionary = {}
var _indice_sujo := true


static func novo(p_nome: String, p_descricao: String = "") -> Universo:
	var u := Universo.new()
	u.id = Ids.novo("uni")
	u.nome = p_nome.strip_edges()
	u.descricao = p_descricao.strip_edges()
	u.criado_em = Time.get_datetime_string_from_system()
	u.atualizado_em = u.criado_em
	u.fatos.registrar({
		"tipo": "origem do universo",
		"descricao": "O universo \"%s\" começou a existir." % u.nome,
		"data": u.relogio,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
	})
	return u


func _avisar() -> void:
	atualizado_em = Time.get_datetime_string_from_system()
	_indice_sujo = true
	mudou.emit()


## Para os sistemas avisarem que mudaram algo (salvar e refazer o índice).
func marcar_mudanca() -> void:
	_avisar()


## Estado de simulação de uma entidade (cria os valores padrão se faltarem).
func estado(eid: String) -> Dictionary:
	if not entidades.has(eid):
		return Estado.PADRAO.duplicate(true)
	return Estado.garantir(entidades[eid])


## Dados de um sistema (cria vazio se não existir): extra("mapa"), extra("regras")...
func extra(nome: String, padrao = null) -> Variant:
	if not extras.has(nome):
		extras[nome] = padrao if padrao != null else {}
	return extras[nome]


# ---------------------------------------------------------------- propostas (texto vira fatos)

func proposta(pid: String) -> Dictionary:
	for p in propostas:
		if p["id"] == pid:
			return p
	return {}


func propostas_do_capitulo(cid: String, incluir_resolvidas: bool = false) -> Array:
	return propostas.filter(func(p):
		return p["capitulo"] == cid and (incluir_resolvidas or p["status"] in ["pendente", "duvida", "eco"]))


## Aceita uma proposta: vira fato no banco (com origem e causa) e o mundo se atualiza.
## 'ajustes' pode trocar: descricao, acao, sujeitos, lugar.
func aceitar_proposta(pid: String, ajustes: Dictionary = {}) -> String:
	var p := proposta(pid)
	if p.is_empty() or not p["status"] in ["pendente", "eco"]:
		return ""
	for k in ajustes:
		p[k] = ajustes[k]
	var eco: bool = p["status"] == "eco"
	var cap := capitulo(p["capitulo"])
	var dados := {"acao": p["acao"], "frase": p.get("frase", "")}
	if eco:
		dados["efeito"] = p.get("efeito", {})
	var causa_eco: String = p.get("causa", "")
	if eco and not fatos.obter(causa_eco).get("canon", false):
		p["status"] = "riscada"
		return ""
	var fid := fatos.registrar({
		"tipo": Extrator.ACOES.get(p["acao"], {}).get("nome", "reação" if eco else "acontecimento"),
		"descricao": p["descricao"],
		"sujeitos": p["sujeitos"],
		"lugar": p.get("lugar", ""),
		"data": cap.get("data", relogio) if not eco else fatos.obter(causa_eco).get("data", relogio),
		"causas": [causa_eco] if eco and fatos.existe(causa_eco) else [],
		"origem": {"tipo": BancoDeFatos.ORIGEM_SIMULACAO if eco else BancoDeFatos.ORIGEM_CAPITULO, "ref": p["capitulo"]},
		"canon": true,
		"dados": dados,
	})
	if fid == "":
		return ""
	p["status"] = "aceita"
	p["fato"] = fid
	AutoAtualizador.aplicar(self, fid)
	_avisar()
	return fid


## Desfaz um fato aceito: ele continua guardado (nada se perde), mas deixa de ser
## canon, e o estado do mundo é reconstruído sem ele. Ecos pendentes dele são riscados.
func desfazer_proposta(pid: String) -> void:
	var p := proposta(pid)
	if p.is_empty() or p["status"] != "aceita":
		return
	var f := fatos.obter(p.get("fato", ""))
	if not f.is_empty():
		f["canon"] = false
		for eco in propostas:
			if eco.get("causa", "") == f["id"] and eco["status"] == "eco":
				eco["status"] = "riscada"
	p["status"] = "desfeita"
	AutoAtualizador.reconstruir(self)
	_avisar()


## Desfaz um fato (de qualquer origem) e tudo o que ele causou: continuam guardados,
## mas deixam de ser canon, e o mundo é reconstruído. Devolve quantos fatos saíram.
func desfazer_fato(fid: String) -> int:
	var fila: Array = [fid]
	var n := 0
	while not fila.is_empty():
		var atual: String = fila.pop_front()
		var f := fatos.obter(atual)
		if f.is_empty() or not f["canon"]:
			continue
		f["canon"] = false
		n += 1
		for c in fatos.consequencias(atual):
			fila.append(c["id"])
	for p in propostas:
		if p.get("fato", "") != "" and not fatos.obter(p["fato"]).get("canon", true) and p["status"] == "aceita":
			p["status"] = "desfeita"
	AutoAtualizador.reconstruir(self)
	_avisar()
	return n


## Até onde o autor já leu o jornal (número de sequência do último fato visto).
func jornal_lido_ate() -> int:
	return int(extra("leitura", {"jornal": 0}).get("jornal", 0))


func marcar_jornal_lido() -> void:
	extra("leitura", {})["jornal"] = fatos.para_dicionario()["seq"]
	_avisar()


## Muda a data do mundo à mão (ex.: começar no ano 412). Não é um fato: é o calendário.
func definir_relogio(data: Dictionary) -> void:
	relogio = DataMundo.copiar(data)
	_avisar()


## Sistemas das próximas partes que sabem aplicar operações próprias.
func sistemas_de_mudanca() -> Array:
	return []


## Sistemas que rodam a cada passo do relógio (natureza, sociedades...).
## Cada um tem: static func passo(u, dias, rng) -> Array de ids de fatos.
func sistemas_de_simulacao() -> Array:
	return []


## Dias de viagem entre dois lugares (-1 = não sabe; o mapa da Parte 4 responde).
func dias_de_viagem(_de: String, _para: String) -> int:
	return -1


## Semente do universo: a mesma semente e os mesmos fatos dão o mesmo mundo.
func semente() -> int:
	if not extras.has("semente"):
		extras["semente"] = abs(hash(id)) % 1000000007
	return int(extras["semente"])


func riscar_proposta(pid: String) -> void:
	var p := proposta(pid)
	if p.is_empty():
		return
	p["status"] = "riscada"
	_avisar()


## O autor ensina o que uma palavra significa. A dúvida vira proposta de verdade.
func ensinar(palavra: String, acao: String, pid: String = "") -> void:
	var chave := TextUtil.chave(palavra)
	if chave == "" or not Extrator.ACOES.has(acao):
		return
	dicionario[chave] = acao
	var p := proposta(pid)
	if not p.is_empty():
		p["status"] = "ensinada"
		Extrator.analisar(self, p["capitulo"])
	_avisar()


# ---------------------------------------------------------------- versões dos capítulos

const MAX_VERSOES := 30

## Guarda uma versão do texto do capítulo (se mudou desde a última).
func guardar_versao(cid: String) -> void:
	var cap := capitulo(cid)
	if cap.is_empty() or cap["texto"].strip_edges() == "":
		return
	if not cap.has("versoes"):
		cap["versoes"] = []
	var versoes: Array = cap["versoes"]
	if not versoes.is_empty() and versoes.back()["texto"] == cap["texto"]:
		return
	versoes.append({"quando": Time.get_datetime_string_from_system(), "texto": cap["texto"]})
	while versoes.size() > MAX_VERSOES:
		versoes.pop_front()


func restaurar_versao(cid: String, indice: int) -> void:
	var cap := capitulo(cid)
	var versoes: Array = cap.get("versoes", [])
	if indice < 0 or indice >= versoes.size():
		return
	guardar_versao(cid)
	atualizar_capitulo(cid, {"texto": versoes[indice]["texto"]})


# ---------------------------------------------------------------- entidades

## Cria uma entidade. 'tipo' é texto livre ("pessoa", "dragão de gelo", "cidade flutuante"...).
## 'campos' é uma lista ordenada de {chave, valor}, também livres.
func criar_entidade(p_nome: String, tipo: String, apelidos: Array = [], campos: Array = []) -> String:
	var eid := Ids.novo("ent")
	entidades[eid] = {
		"id": eid,
		"nome": p_nome.strip_edges(),
		"tipo": tipo.strip_edges(),
		"apelidos": _limpar_apelidos(apelidos),
		"campos": _limpar_campos(campos),
		"removida": false,
	}
	var fid := fatos.registrar({
		"tipo": "criação",
		"descricao": "%s passou a existir (%s)." % [p_nome.strip_edges(), tipo.strip_edges() if tipo.strip_edges() != "" else "sem tipo"],
		"sujeitos": [eid],
		"data": relogio,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"campos": entidades[eid]["campos"].duplicate(true)},
	})
	entidades[eid]["fato_criacao"] = fid
	_avisar()
	return eid


## Edita uma entidade. Cada diferença vira um fato "alteração" com antes e depois.
## 'mudancas' pode ter: nome, tipo, apelidos, campos.
func editar_entidade(eid: String, mudancas: Dictionary) -> void:
	if not entidades.has(eid):
		return
	var ent: Dictionary = entidades[eid]
	var houve := false
	for chave in ["nome", "tipo"]:
		if mudancas.has(chave) and str(mudancas[chave]).strip_edges() != ent[chave]:
			var antes: String = ent[chave]
			ent[chave] = str(mudancas[chave]).strip_edges()
			_fato_alteracao(eid, chave, antes, ent[chave])
			houve = true
	if mudancas.has("apelidos"):
		var novos := _limpar_apelidos(mudancas["apelidos"])
		if novos != ent["apelidos"]:
			_fato_alteracao(eid, "apelidos", ", ".join(ent["apelidos"]), ", ".join(novos))
			ent["apelidos"] = novos
			houve = true
	if mudancas.has("campos"):
		var novos_campos := _limpar_campos(mudancas["campos"])
		var antigos := {}
		for c in ent["campos"]:
			antigos[c["chave"]] = c["valor"]
		var atuais := {}
		for c in novos_campos:
			atuais[c["chave"]] = c["valor"]
			if antigos.get(c["chave"], null) != c["valor"]:
				_fato_alteracao(eid, c["chave"], str(antigos.get(c["chave"], "")), c["valor"])
				houve = true
		for chave in antigos.keys():
			if not atuais.has(chave):
				_fato_alteracao(eid, chave, antigos[chave], "")
				houve = true
		if novos_campos != ent["campos"]:
			ent["campos"] = novos_campos
			houve = true
	if houve:
		_avisar()


## Remover não apaga a história: a entidade fica marcada como removida,
## para que os fatos antigos continuem apontando para algo que existiu.
func remover_entidade(eid: String) -> void:
	if not entidades.has(eid) or entidades[eid]["removida"]:
		return
	entidades[eid]["removida"] = true
	fatos.registrar({
		"tipo": "remoção",
		"descricao": "%s foi retirada do universo pelo autor." % entidades[eid]["nome"],
		"sujeitos": [eid],
		"data": relogio,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
	})
	_avisar()


func restaurar_entidade(eid: String) -> void:
	if not entidades.has(eid) or not entidades[eid]["removida"]:
		return
	entidades[eid]["removida"] = false
	fatos.registrar({
		"tipo": "restauração",
		"descricao": "%s voltou ao universo." % entidades[eid]["nome"],
		"sujeitos": [eid],
		"data": relogio,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
	})
	_avisar()


## O autor decide se uma entidade tem mente própria (sobrepõe o palpite pelo tipo).
func definir_tem_mente(eid: String, valor: bool) -> void:
	if entidades.has(eid):
		estado(eid)["tem_mente"] = valor
		_avisar()


func entidade(eid: String) -> Dictionary:
	return entidades.get(eid, {})


## Entidades ativas (não removidas), ordenadas por nome.
func entidades_ativas() -> Array:
	var lista: Array = []
	for e in entidades.values():
		if not e["removida"]:
			lista.append(e)
	lista.sort_custom(func(a, b): return TextUtil.chave(a["nome"]) < TextUtil.chave(b["nome"]))
	return lista


func valor_campo(eid: String, chave: String) -> String:
	for c in entidades.get(eid, {}).get("campos", []):
		if TextUtil.chave(c["chave"]) == TextUtil.chave(chave):
			return c["valor"]
	return ""


func _fato_alteracao(eid: String, campo: String, antes: String, depois: String) -> void:
	var nome_ent: String = entidades[eid]["nome"]
	var descricao_txt := ""
	if antes == "":
		descricao_txt = "%s: \"%s\" passou a ser %s." % [nome_ent, campo, depois]
	elif depois == "":
		descricao_txt = "%s: \"%s\" deixou de constar (era %s)." % [nome_ent, campo, antes]
	else:
		descricao_txt = "%s: \"%s\" mudou de %s para %s." % [nome_ent, campo, antes, depois]
	fatos.registrar({
		"tipo": "alteração",
		"descricao": descricao_txt,
		"sujeitos": [eid],
		"data": relogio,
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": ""},
		"dados": {"campo": campo, "antes": antes, "depois": depois},
	})


static func _limpar_apelidos(apelidos) -> Array:
	var lista: Array = []
	var fonte: Array = []
	if apelidos is String:
		fonte = Array(apelidos.split(","))
	else:
		fonte = apelidos
	for a in fonte:
		var t := str(a).strip_edges()
		if t != "" and not lista.has(t):
			lista.append(t)
	return lista


static func _limpar_campos(campos: Array) -> Array:
	var lista: Array = []
	var vistas := {}
	for c in campos:
		var chave := str(c.get("chave", "")).strip_edges()
		var valor := str(c.get("valor", "")).strip_edges()
		if chave == "" or vistas.has(TextUtil.chave(chave)):
			continue
		vistas[TextUtil.chave(chave)] = true
		lista.append({"chave": chave, "valor": valor})
	return lista


# ---------------------------------------------------------------- livros e capítulos

func criar_livro(titulo: String) -> String:
	var lid := Ids.novo("liv")
	livros.append({"id": lid, "titulo": titulo.strip_edges(), "capitulos": []})
	_avisar()
	return lid


func livro(lid: String) -> Dictionary:
	for l in livros:
		if l["id"] == lid:
			return l
	return {}


func renomear_livro(lid: String, titulo: String) -> void:
	var l := livro(lid)
	if not l.is_empty() and titulo.strip_edges() != "":
		l["titulo"] = titulo.strip_edges()
		_avisar()


## Apaga um livro e os capítulos dele. O texto vai para as notas do autor,
## para nunca perder nada escrito sem querer.
func apagar_livro(lid: String) -> void:
	var l := livro(lid)
	if l.is_empty():
		return
	for cid in l["capitulos"].duplicate():
		apagar_capitulo(cid)
	livros.erase(l)
	_avisar()


func mover_livro(lid: String, delta: int) -> void:
	var l := livro(lid)
	var i := livros.find(l)
	var j := clampi(i + delta, 0, livros.size() - 1)
	if i < 0 or i == j:
		return
	livros.remove_at(i)
	livros.insert(j, l)
	_avisar()


func criar_capitulo(lid: String, titulo: String) -> String:
	var l := livro(lid)
	if l.is_empty():
		return ""
	var cid := Ids.novo("cap")
	capitulos[cid] = {
		"id": cid,
		"livro": lid,
		"titulo": titulo.strip_edges(),
		"texto": "",
		"data": DataMundo.copiar(relogio),
		"canon": true,
		"marcado": false,
		"criado_em": Time.get_datetime_string_from_system(),
		"atualizado_em": Time.get_datetime_string_from_system(),
	}
	l["capitulos"].append(cid)
	_avisar()
	return cid


func capitulo(cid: String) -> Dictionary:
	return capitulos.get(cid, {})


## Atualiza campos do capítulo: titulo, texto, data, canon, marcado.
func atualizar_capitulo(cid: String, mudancas: Dictionary) -> void:
	if not capitulos.has(cid):
		return
	var cap: Dictionary = capitulos[cid]
	var houve := false
	for chave in ["titulo", "texto", "canon", "marcado"]:
		if mudancas.has(chave) and cap[chave] != mudancas[chave]:
			cap[chave] = mudancas[chave]
			houve = true
	if mudancas.has("data"):
		var nova := DataMundo.copiar(mudancas["data"])
		if nova != cap["data"]:
			cap["data"] = nova
			houve = true
	if houve:
		cap["atualizado_em"] = Time.get_datetime_string_from_system()
		_avisar()


func apagar_capitulo(cid: String) -> void:
	if not capitulos.has(cid):
		return
	var cap: Dictionary = capitulos[cid]
	if cap["texto"].strip_edges() != "":
		criar_nota("Capítulo apagado: %s" % cap["titulo"], cap["texto"])
	var l := livro(cap["livro"])
	if not l.is_empty():
		l["capitulos"].erase(cid)
	capitulos.erase(cid)
	_avisar()


func mover_capitulo(cid: String, delta: int) -> void:
	var cap := capitulo(cid)
	if cap.is_empty():
		return
	var lista: Array = livro(cap["livro"])["capitulos"]
	var i := lista.find(cid)
	var j := clampi(i + delta, 0, lista.size() - 1)
	if i == j:
		return
	lista.remove_at(i)
	lista.insert(j, cid)
	_avisar()


func capitulos_marcados() -> Array:
	var lista: Array = []
	for l in livros:
		for cid in l["capitulos"]:
			if capitulos[cid]["marcado"]:
				lista.append(capitulos[cid])
	return lista


# ---------------------------------------------------------------- notas privadas

func criar_nota(titulo: String, texto: String = "") -> String:
	var nid := Ids.novo("not")
	notas.append({
		"id": nid, "titulo": titulo.strip_edges(), "texto": texto,
		"atualizada": Time.get_datetime_string_from_system(),
	})
	_avisar()
	return nid


func nota(nid: String) -> Dictionary:
	for n in notas:
		if n["id"] == nid:
			return n
	return {}


func atualizar_nota(nid: String, titulo: String, texto: String) -> void:
	var n := nota(nid)
	if n.is_empty() or (n["titulo"] == titulo and n["texto"] == texto):
		return
	n["titulo"] = titulo
	n["texto"] = texto
	n["atualizada"] = Time.get_datetime_string_from_system()
	_avisar()


func apagar_nota(nid: String) -> void:
	var n := nota(nid)
	if not n.is_empty():
		notas.erase(n)
		_avisar()


# ---------------------------------------------------------------- índice automático

## Para cada entidade, em quais capítulos ela aparece (pelo nome ou apelidos).
## Devolve {id_entidade: [ids de capítulos na ordem da estante]}.
func indice() -> Dictionary:
	if not _indice_sujo:
		return _indice_cache
	var ligador := Ligador.new(self)
	var idx := {}
	for l in livros:
		for cid in l["capitulos"]:
			var vistos := {}
			for m in ligador.encontrar(capitulos[cid]["texto"]):
				if vistos.has(m["entidade"]):
					continue
				vistos[m["entidade"]] = true
				if not idx.has(m["entidade"]):
					idx[m["entidade"]] = []
				idx[m["entidade"]].append(cid)
	_indice_cache = idx
	_indice_sujo = false
	return idx


# ---------------------------------------------------------------- salvar e carregar

func para_dicionario() -> Dictionary:
	return {
		"formato": VERSAO_FORMATO,
		"id": id,
		"nome": nome,
		"descricao": descricao,
		"criado_em": criado_em,
		"atualizado_em": atualizado_em,
		"relogio": relogio,
		"entidades": entidades,
		"livros": livros,
		"capitulos": capitulos,
		"notas": notas,
		"propostas": propostas,
		"dicionario": dicionario,
		"extras": extras,
		"fatos": fatos.para_dicionario(),
	}


static func de_dicionario(d: Dictionary) -> Universo:
	var u := Universo.new()
	u.id = str(d.get("id", Ids.novo("uni")))
	u.nome = str(d.get("nome", "Sem nome"))
	u.descricao = str(d.get("descricao", ""))
	u.criado_em = str(d.get("criado_em", ""))
	u.atualizado_em = str(d.get("atualizado_em", ""))
	u.relogio = DataMundo.copiar(d.get("relogio", {}))
	u.entidades = d.get("entidades", {})
	for e in u.entidades.values():
		e["removida"] = bool(e.get("removida", false))
		e["apelidos"] = Array(e.get("apelidos", []))
		e["campos"] = Array(e.get("campos", []))
	u.livros = d.get("livros", [])
	u.capitulos = d.get("capitulos", {})
	for c in u.capitulos.values():
		c["data"] = DataMundo.copiar(c.get("data", {}))
		c["canon"] = bool(c.get("canon", true))
		c["marcado"] = bool(c.get("marcado", false))
	u.notas = d.get("notas", [])
	u.propostas = d.get("propostas", [])
	u.dicionario = d.get("dicionario", {})
	u.extras = d.get("extras", {})
	u.fatos.carregar_dicionario(d.get("fatos", {}))
	Persistencia.normalizar_numeros(u)
	return u
