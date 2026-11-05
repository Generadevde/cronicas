class_name Linguas
extends RefCounted
## Línguas do universo: cada uma aprende o jeito dos nomes a partir de exemplos
## escritos pelo autor (sons, começos, finais) e gera nomes novos no mesmo estilo.
## Fica em extras["linguas"] = {nome: {pessoas: [...], lugares: [...], sobrenomes: [...]}}.

const PADRAO := "Comum"

## Exemplos de partida, só para o universo não começar mudo. O autor troca à vontade.
const EXEMPLOS_PADRAO := {
	"pessoas": ["Daren", "Lucas", "Mira", "Orvan", "Kai", "Elara", "Tomas", "Iria", "Bastian", "Selene",
		"Aldo", "Nara", "Corvin", "Lia", "Marek", "Edda", "Rowan", "Tessa", "Galen", "Ilsa"],
	"lugares": ["Varn", "Kresk", "Aldra", "Morvale", "Dunhal", "Esterra", "Brenna", "Cairn", "Velmor",
		"Tharos", "Lindar", "Ostrava", "Pellin", "Rhunel", "Sarth", "Ulmar"],
	"sobrenomes": ["Ferro", "Valebrum", "Corvo", "Pedralta", "Dunmar", "Ventor", "Salgado", "Marrow",
		"Ashby", "Quellen"],
}

const ORDEM := 2


static func todas(u: Universo) -> Dictionary:
	var l: Dictionary = u.extra("linguas", {})
	if l.is_empty():
		l[PADRAO] = EXEMPLOS_PADRAO.duplicate(true)
	return l


static func nomes(u: Universo) -> Array:
	var lista: Array = todas(u).keys()
	lista.sort()
	return lista


## Cria ou atualiza uma língua. Vira fato do autor.
static func definir(u: Universo, nome: String, exemplos: Dictionary) -> void:
	nome = nome.strip_edges()
	if nome == "":
		return
	var l := todas(u)
	var nova := not l.has(nome)
	var dado: Dictionary = l.get(nome, {"pessoas": [], "lugares": [], "sobrenomes": []})
	for k in ["pessoas", "lugares", "sobrenomes"]:
		if exemplos.has(k):
			dado[k] = _limpar(exemplos[k])
	l[nome] = dado
	u.fatos.registrar({
		"tipo": "língua",
		"descricao": ("Surgiu a língua %s." if nova else "A língua %s foi revista pelo autor.") % nome,
		"data": DataMundo.copiar(u.relogio),
		"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "linguas"},
		"dados": {"importancia": 0.1, "lingua": nome},
	})
	u.marcar_mudanca()


static func _limpar(lista) -> Array:
	var r: Array = []
	var itens: Array = lista if lista is Array else str(lista).replace("\n", ",").split(",")
	for i in itens:
		var t := str(i).strip_edges()
		if t != "" and not r.has(t):
			r.append(t)
	return r


## Língua de um lugar (campo "língua"/"idioma" na ficha dele ou de onde ele fica).
static func do_lugar(u: Universo, lugar: String) -> String:
	var l := todas(u)
	var cadeia: Array = ([lugar] if lugar != "" else []) + Mapa.ancestrais(u, lugar)
	for c in cadeia:
		for campo in ["língua", "lingua", "idioma"]:
			var v := u.valor_campo(c, campo).strip_edges()
			for nome in l:
				if v != "" and TextUtil.chave(v).contains(TextUtil.chave(nome)):
					return nome
	return PADRAO if l.has(PADRAO) else (l.keys()[0] if not l.is_empty() else PADRAO)


## Gera um nome. 'tipo': "pessoas", "lugares" ou "sobrenomes".
static func gerar(u: Universo, lingua: String, tipo: String, rng: RandomNumberGenerator, evitar: Array = []) -> String:
	var l := todas(u)
	var dado: Dictionary = l.get(lingua, l.get(PADRAO, EXEMPLOS_PADRAO))
	var exemplos: Array = dado.get(tipo, [])
	if exemplos.size() < 3:
		exemplos = exemplos + dado.get("pessoas", []) + dado.get("lugares", [])
	if exemplos.size() < 3:
		exemplos = EXEMPLOS_PADRAO[tipo] if EXEMPLOS_PADRAO.has(tipo) else EXEMPLOS_PADRAO["pessoas"]
	var usados := {}
	for e in u.entidades.values():
		usados[TextUtil.chave(e["nome"])] = true
	for e in exemplos:
		usados[TextUtil.chave(e)] = true
	for e in evitar:
		usados[TextUtil.chave(str(e))] = true
	var modelo := _modelo(exemplos)
	var min_len := 99
	var max_len := 0
	for e in exemplos:
		min_len = mini(min_len, e.length())
		max_len = maxi(max_len, e.length())
	for tentativa in 40:
		var n := _cadeia(modelo, rng, maxi(3, min_len), max_len + 2)
		if n != "" and not usados.has(TextUtil.chave(n)):
			return n
	# Sem sorte: junta começo de um exemplo com fim de outro.
	var a: String = exemplos[rng.randi() % exemplos.size()]
	var b: String = exemplos[rng.randi() % exemplos.size()]
	return (a.substr(0, maxi(2, a.length() / 2)) + b.substr(b.length() / 2)).capitalize()


static func _modelo(exemplos: Array) -> Dictionary:
	var m := {}
	for e in exemplos:
		var palavra := "^".repeat(ORDEM) + str(e).to_lower() + "$"
		for i in range(palavra.length() - ORDEM):
			var chave := palavra.substr(i, ORDEM)
			var prox := palavra[i + ORDEM]
			if not m.has(chave):
				m[chave] = []
			m[chave].append(prox)
	return m


static func _cadeia(m: Dictionary, rng: RandomNumberGenerator, min_len: int, max_len: int) -> String:
	var atual := "^".repeat(ORDEM)
	var saida := ""
	for i in 30:
		var opcoes: Array = m.get(atual, [])
		if opcoes.is_empty():
			break
		var c: String = opcoes[rng.randi() % opcoes.size()]
		if c == "$":
			if saida.length() >= min_len:
				break
			# curto demais: tenta continuar com outra letra
			var outras := opcoes.filter(func(x): return x != "$")
			if outras.is_empty():
				break
			c = outras[rng.randi() % outras.size()]
		saida += c
		atual = (atual + c).substr(1, ORDEM) if ORDEM > 1 else c
		if saida.length() >= max_len:
			break
	if saida.length() < min_len:
		return ""
	return saida.substr(0, 1).to_upper() + saida.substr(1)
