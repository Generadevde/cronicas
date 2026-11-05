class_name Pendencias
extends RefCounted
## "Ainda sem efeito": tudo o que você escreveu e o mundo ainda não sabe usar.
## Nada fica escondido: cada coisa aparece aqui até você decidir — definir o
## efeito (vira lei e passa a valer sempre) ou dizer que é só descrição.
##
## Fontes: intervenções que o programa não entendeu, leis entendidas em parte,
## campos de ficha que nenhum sistema lê, frases de capítulo em dúvida e os
## pedidos do mundo (poderes narrativos que esperam você dizer o que fizeram).

## Começos de nomes de campo que algum sistema já lê.
const CAMPOS_LIDOS := ["personalid", "jeito", "gost", "valor", "hobby", "paix", "desgost", "odeia", "detesta",
	"desej", "ambic", "objetiv", "sonho", "quer", "meta", "forc", "poder", "nivel", "ki", "mana", "energia", "potenc",
	"ataque", "idade", "popula", "habitant", "morador", "clima", "habitat", "onde vive", "comport", "perigo", "dieta",
	"lingua", "idioma", "terreno", "largura", "tamanho", "extens", "area", "estado", "magia", "habilid", "dom", "dons",
	"feitic", "tecnic", "artes", "custo", "limite", "efeito", "quem pode usar", "usuario", "dono", "portador", "mestre",
	"expectativ", "longevid", "vive", "povo", "raca", "especie", "linhagem", "origem", "nacao", "reino", "terra natal",
	"naturalid", "tipo de poder", "natureza"]
## Campos que são descrição (valem como texto do mundo: wiki, pesquisa, a voz dos personagens).
const DESCRITIVOS := ["descric", "aparenc", "historia", "feito", "epoca", "nota", "apelido", "resumo", "biografia"]
## Campos que as próximas partes vão usar (não contam como pendência).
const PLANEJADOS := {
	"recurso": 6, "quem governa": 6, "governa": 6, "lider": 6, "forma de governo": 6, "governo": 6, "sede": 6,
	"aliad": 6, "inimig": 6, "riqueza": 6, "leis": 6, "oficio": 6, "profiss": 6, "cargo": 6, "moeda": 6,
	"religi": 6, "crenc": 6, "fe": 6, "exercito": 7, "tropas": 7, "o que oferece": 8, "o que cobra": 8,
	"seguidores": 8, "vontade": 8, "como age": 8, "pacto": 8,
}


static func _comeca(chave: String, lista) -> bool:
	var k := TextUtil.normalizar(chave)
	for p in lista:
		if k.begins_with(str(p)):
			return true
	return false


static func campo_tem_efeito(u: Universo, chave: String) -> bool:
	if _comeca(chave, CAMPOS_LIDOS) or _comeca(chave, DESCRITIVOS):
		return true
	if u.extra("campos_descritivos", []).has(TextUtil.normalizar(chave)):
		return true
	for r in Regras.todas(u):
		if r["ligada"] and r["quando"].get("tipo", "") == "campo" and TextUtil.normalizar(str(r["quando"]["texto"])) == TextUtil.normalizar(chave):
			return true
	return false


static func parte_planejada(chave: String) -> int:
	var k := TextUtil.normalizar(chave)
	for p in PLANEJADOS:
		if k == p or k.begins_with(p):
			return int(PLANEJADOS[p])
	return 0


## A lista do que ainda não tem efeito. Cada item: {id, tipo, titulo, texto, ...}.
static func listar(u: Universo) -> Array:
	var itens: Array = []
	for p in Poderes.pedidos(u):
		itens.append({"id": "ped:" + p["id"], "tipo": "pedido", "titulo": "Pedido do mundo", "texto": p["texto"],
			"detalhe": "Poder narrativo: o mundo não decide sozinho. O que aconteceu?", "pedido": p["id"]})
	for f in u.fatos.todos():
		if f["canon"] and f["dados"].get("sem_efeito", false) and not f["dados"].get("resolvido", false):
			itens.append({"id": "int:" + f["id"], "tipo": "intervencao", "titulo": "Intervenção sem efeito", "texto": f["descricao"],
				"detalhe": "O programa registrou, mas não sabe o que isso muda.", "fato": f["id"], "termo": str(f["dados"].get("texto", ""))})
	for r in Regras.todas(u):
		if not r.get("apagada", false) and r.get("entendida", "toda") == "parte":
			itens.append({"id": "lei:" + r["id"], "tipo": "lei", "titulo": "Lei entendida em parte", "texto": r["texto"],
				"detalhe": "\n".join(r["avisos"]), "regra": r["id"]})
	var campos := campos_sem_efeito(u)
	for chave in campos:
		var ents: Array = campos[chave]
		itens.append({"id": "campo:" + chave, "tipo": "campo", "titulo": "Campo \"%s\"" % chave,
			"texto": "Em %d ficha%s: %s" % [ents.size(), "s" if ents.size() > 1 else "", ", ".join(ents.slice(0, 4).map(func(e): return u.entidade(e)["nome"]))],
			"detalhe": "Nenhum sistema lê este campo ainda.", "chave": chave, "entidades": ents})
	for p in u.propostas:
		if p["status"] == "duvida":
			itens.append({"id": "dup:" + p["id"], "tipo": "duvida", "titulo": "Frase sem efeito", "texto": "“%s”" % p["frase"],
				"detalhe": "No capítulo \"%s\". Palavra: %s" % [u.capitulo(p["capitulo"]).get("titulo", "?"), p.get("palavra", "?")],
				"proposta": p["id"], "palavra": str(p.get("palavra", "")), "capitulo": p["capitulo"]})
	return itens


## {chave: [entidades]} dos campos que nenhum sistema lê (e que não são planejados).
static func campos_sem_efeito(u: Universo) -> Dictionary:
	var r := {}
	for e in u.entidades_ativas():
		for c in e["campos"]:
			var k: String = str(c["chave"]).strip_edges()
			if k == "" or str(c["valor"]).strip_edges() == "" or campo_tem_efeito(u, k) or parte_planejada(k) > 0:
				continue
			if not r.has(k):
				r[k] = []
			r[k].append(e["id"])
	return r


## {chave: parte} dos campos que as próximas partes vão usar (para mostrar à parte).
static func campos_planejados(u: Universo) -> Dictionary:
	var r := {}
	for e in u.entidades_ativas():
		for c in e["campos"]:
			var n := parte_planejada(str(c["chave"]))
			if n > 0 and str(c["valor"]).strip_edges() != "":
				r[str(c["chave"])] = n
	return r


# ---------------------------------------------------------------- resolver

## Define o efeito de um item escrevendo. Vira lei (vale daqui em diante) e,
## quando faz sentido, já acontece agora para o que estava pendente.
static func definir(u: Universo, item: Dictionary, efeito: String) -> Dictionary:
	efeito = efeito.strip_edges()
	if efeito == "":
		return {}
	match str(item["tipo"]):
		"pedido":
			Poderes.responder_pedido(u, item["pedido"], efeito)
			return {"ok": true}
		"intervencao":
			var termo: String = item.get("termo", "")
			var lei := Regras.criar(u, "%s → %s" % [termo, efeito])
			var f := u.fatos.obter(item["fato"])
			f["dados"]["resolvido"] = true
			if not lei.is_empty():
				Regras.disparar(u, lei, {"sujeito": "", "outro": "", "lugar": f["lugar"]}, item["fato"])
			u.marcar_mudanca()
			return lei
		"lei":
			return Regras.reescrever(u, item["regra"], efeito)
		"campo":
			var lei2 := Regras.criar_de_campo(u, item["chave"], efeito)
			Regras.passo(u, 0, null)
			return lei2
		"duvida":
			var palavra: String = item.get("palavra", "")
			var p := u.proposta(item["proposta"])
			var termo2 := palavra if palavra != "" else _sem_nomes(u, p.get("frase", ""))
			var lei3 := Regras.criar(u, "%s → %s" % [termo2, efeito])
			if not p.is_empty():
				p["status"] = "ensinada"
				Extrator.analisar(u, p["capitulo"])
			return lei3
	return {}


## Diz que o item é só descrição (uma decisão sua, que fica registrada).
static func so_descricao(u: Universo, item: Dictionary) -> void:
	match str(item["tipo"]):
		"intervencao":
			var f := u.fatos.obter(item["fato"])
			f["dados"]["resolvido"] = true
			f["dados"]["so_descricao"] = true
		"campo":
			var lista: Array = u.extra("campos_descritivos", [])
			var k := TextUtil.normalizar(item["chave"])
			if not lista.has(k):
				lista.append(k)
		"duvida":
			u.riscar_proposta(item["proposta"])
		"pedido":
			Poderes.responder_pedido(u, item["pedido"], "")
		"lei":
			pass
	u.fatos.registrar({
		"tipo": "decisão do autor", "descricao": "O autor decidiu que \"%s\" é só descrição." % item.get("chave", item.get("texto", "")),
		"data": DataMundo.copiar(u.relogio), "origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "pendencias"},
		"dados": {"importancia": 0.05},
	})
	u.marcar_mudanca()


static func _sem_nomes(u: Universo, frase: String) -> String:
	var t := frase
	for m in Ligador.new(u).encontrar(frase):
		t = t.replace(frase.substr(m["inicio"], m["fim"] - m["inicio"]), "")
	return t.strip_edges().trim_suffix(".")
