class_name Familia
extends RefCounted
## Gerações: casais têm filhos, que herdam o sobrenome, um pouco do jeito dos pais
## e as inimizades da família. Junto com a sucessão (Sociedades) e a morte natural
## (Corpo), as dinastias sobem e caem sozinhas.
##
## Para o mundo não encher de gente sem história, filhos com mente própria nascem
## mais em famílias que importam (governantes, citados nos capítulos, acompanhados).

const MAX_MENTES := 260
const MAX_FILHOS := 6


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var mentes := Simulador._mentes(u)
	if mentes.size() >= MAX_MENTES:
		return novos
	var governantes := {}
	for sid in Sociedades.todas(u):
		governantes[Sociedades.lider(u, sid)] = true
	var vistos := {}
	for a in mentes:
		var conj: Array = u.estado(a)["familia"]["conjuges"]
		for b in conj:
			var par := [a, b]
			par.sort()
			var chave := "%s|%s" % par
			if vistos.has(chave) or not u.entidades.has(b) or not Estado.vivo(u, b):
				continue
			vistos[chave] = true
			if u.estado(a)["local"] != u.estado(b)["local"] or Viagens.viajando(u, a) or Viagens.viajando(u, b):
				continue
			if not _fertil(u, a) or not _fertil(u, b):
				continue
			var filhos: Array = u.estado(a)["familia"]["filhos"].filter(func(f): return u.estado(b)["familia"]["filhos"].has(f))
			if filhos.size() >= MAX_FILHOS:
				continue
			var notavel: bool = governantes.has(a) or governantes.has(b) or u.indice().has(a) or u.indice().has(b) \
				or u.estado(a).get("favorito", false) or u.estado(b).get("favorito", false)
			var chance := (0.2 if notavel else 0.05) * dias / 360.0 * (1.0 - filhos.size() * 0.12)
			if rng.randf() < chance:
				var fid := nascer(u, a, b, rng)
				if fid != "":
					novos.append(fid)
	return novos


static func _fertil(u: Universo, eid: String) -> bool:
	var idade := Estado.idade(u, eid)
	if idade < 0:
		return false
	var e := Corpo.expectativa(u, eid)
	return idade >= 18 and float(idade) <= maxf(40.0, e * 0.6)


## Nasce um filho de A e B. Devolve o id do fato do nascimento.
static func nascer(u: Universo, a: String, b: String, rng: RandomNumberGenerator) -> String:
	var lugar: String = u.estado(a)["local"]
	var lingua := Linguas.do_lugar(u, lugar)
	var sobrenome := Sociedades.casa(u, a)
	var nome := Linguas.gerar(u, lingua, "pessoas", rng) + ((" " + sobrenome) if sobrenome != "" else "")
	# O jeito: um traço de cada um dos pais e, às vezes, algo novo.
	var tracos: Array = []
	for p in [a, b]:
		var w: Array = Array(TextUtil.palavras(u.valor_campo(p, "personalidade"))).filter(func(x): return x.length() > 3 and not x in ["muito", "pouco", "mas"])
		if not w.is_empty():
			tracos.append(w[rng.randi() % w.size()])
	if rng.randf() < 0.5 or tracos.is_empty():
		tracos.append(Povoador.TRACOS[rng.randi() % Povoador.TRACOS.size()])
	var causa := _casamento(u, a, b)
	var filho := u.criar_entidade(nome, "pessoa", [], [{"chave": "personalidade", "valor": " e ".join(tracos)}], [causa] if u.fatos.existe(causa) else [])
	var ops: Array = [{"op": "nascer", "quem": filho, "lugar": lugar}, {"op": "familia", "pai": a, "filho": filho}, {"op": "familia", "pai": b, "filho": filho}]
	# Inimizades da família passam para a nova geração (mais fracas).
	for p in [a, b]:
		var rels: Dictionary = u.estado(p)["relacoes"]
		for outro in rels:
			if float(rels[outro].get("raiva", 0.0)) >= 0.6 and outro != filho:
				ops.append({"op": "relacao", "de": filho, "para": outro, "deltas": {"raiva": float(rels[outro]["raiva"]) * 0.4}})
	return Simulador.registrar(u, {
		"tipo": "nascimento", "descricao": "Nasceu %s, filho de %s e %s, em %s." % [nome, u.entidade(a)["nome"], u.entidade(b)["nome"], u.entidade(lugar).get("nome", "?")],
		"sujeitos": [filho, a, b], "lugar": lugar, "causas": [causa] if u.fatos.existe(causa) else [],
		"dados": {"acao": "nascimento", "importancia": 0.45, "mudancas": ops},
	})


static func _casamento(u: Universo, a: String, b: String) -> String:
	var ids := u.fatos.ids_sobre(a)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and (f["tipo"] == "casamento" or f["dados"].get("acao", "") == "casamento") and f["sujeitos"].has(b):
			return f["id"]
	return Simulador.causa_de_presenca(u, a)
