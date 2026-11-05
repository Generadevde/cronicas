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
	u.fatos.carregar_dicionario(d.get("fatos", {}))
	return u
