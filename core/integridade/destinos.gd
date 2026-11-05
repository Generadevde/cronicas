class_name Destinos
extends RefCounted
## Destinos do autor: metas marcadas por você ("Daren encontra Kai antes do ano 420")
## que o mundo tenta alcançar de forma natural, sem forçar. O destino não cria o
## acontecimento: só deixa as mentes mais inclinadas (um desejo, uma viagem, um
## sentimento). Quando o destino se cumpre, vira fato (com a causa real); se o prazo
## passa, também vira fato — o mundo tentou e não deu.

const VERBOS := {
	"encontra": ["encontra", "encontrar", "conhece", "reencontra", "se encontram"],
	"mata": ["mata", "matar", "derrota", "vence", "derruba"],
	"casa": ["casa com", "se casa com", "casar com", "se casam", "ama"],
	"governa": ["governa", "vira rei", "vira rainha", "toma o trono", "assume o trono", "reina"],
}


static func todos(u: Universo) -> Array:
	return u.extra("destinos", [])


## Marca um destino escrito. Devolve o destino (ou {} se não entendeu).
static func marcar(u: Universo, texto: String) -> Dictionary:
	var n := " " + TextUtil.normalizar(texto) + " "
	var verbo := ""
	for v in VERBOS:
		for w in VERBOS[v]:
			if n.contains(" " + w + " "):
				verbo = v
	var nomes: Array = Ligador.new(u).encontrar(texto).map(func(m): return m["entidade"])
	var ano := -1
	var rx := RegEx.new()
	rx.compile("(antes d[oe]|ate o|ate) ano (\\d+)")
	var m := rx.search(n)
	if m != null:
		ano = int(m.get_string(2))
	if verbo == "" or nomes.is_empty():
		return {}
	var d := {"id": Ids.novo("dst"), "texto": texto.strip_edges(), "verbo": verbo, "quem": nomes[0], "alvo": nomes[1] if nomes.size() > 1 else "",
		"ate": ano, "estado": "aberto", "marcado_em": DataMundo.ordem(u.relogio)}
	todos(u).append(d)
	u.marcar_mudanca()
	return d


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for d in todos(u):
		if d["estado"] != "aberto":
			continue
		var cumpriu := _cumprido(u, d)
		if cumpriu != "":
			d["estado"] = "cumprido"
			novos.append(Simulador.registrar(u, {"tipo": "destino cumprido", "descricao": "Cumpriu-se o destino: %s" % d["texto"], "sujeitos": [d["quem"]] + ([d["alvo"]] if d["alvo"] != "" else []),
				"causas": [cumpriu], "dados": {"importancia": 0.6, "destino": d["id"], "mudancas": []}}))
			continue
		if int(d["ate"]) > 0 and int(u.relogio["ano"]) >= int(d["ate"]):
			d["estado"] = "falhou"
			novos.append(Simulador.registrar(u, {"tipo": "destino falhou", "descricao": "O destino não se cumpriu: %s" % d["texto"], "sujeitos": [d["quem"]] + ([d["alvo"]] if d["alvo"] != "" else []),
				"causas": [Fios._ultimo_fato(u, d["quem"])], "origem": {"tipo": BancoDeFatos.ORIGEM_SISTEMA, "ref": "destinos"}, "dados": {"importancia": 0.3, "mudancas": []}}))
			continue
		var empurrao := _empurrar(u, d, dias, rng)
		if empurrao != "":
			novos.append(empurrao)
	return novos.filter(func(x): return x != "")


## O que cumpre o destino (o fato), ou "".
static func _cumprido(u: Universo, d: Dictionary) -> String:
	var quem: String = d["quem"]
	var alvo: String = d["alvo"]
	var desde := int(d["marcado_em"])
	match str(d["verbo"]):
		"encontra":
			if alvo != "" and Estado.vivo(u, quem) and Estado.vivo(u, alvo) and str(u.estado(quem).get("local", "")) != "" and u.estado(quem)["local"] == u.estado(alvo).get("local", "") and not Viagens.viajando(u, quem):
				return Fios._ultimo_fato(u, quem)
		"mata":
			for f in u.fatos.sobre(alvo):
				if f["canon"] and DataMundo.ordem(f["data"]) >= desde and f["sujeitos"].size() > 1 and f["sujeitos"][0] == quem and f["dados"].get("acao", "") in ["morte_por", "vitoria"]:
					return f["id"]
				if f["canon"] and DataMundo.ordem(f["data"]) >= desde and f["tipo"] == "luta" and f["sujeitos"].has(quem) and not Estado.vivo(u, alvo):
					return f["id"]
		"casa":
			if u.estado(quem)["familia"]["conjuges"].has(alvo):
				return Familia._casamento(u, quem, alvo)
		"governa":
			for sid in Sociedades.todas(u):
				if Sociedades.lider(u, sid) == quem and (alvo == "" or alvo == sid or Sociedades.territorio_base(u, sid).has(alvo)):
					return Fios._ultimo_fato(u, sid)
	return ""


## O empurrão natural (uma vez por mês, de leve): um desejo, uma viagem, um sentimento.
static func _empurrar(u: Universo, d: Dictionary, dias: int, rng: RandomNumberGenerator) -> String:
	var quem: String = d["quem"]
	var alvo: String = d["alvo"]
	if not Estado.vivo(u, quem) or rng.randf() > dias / 30.0 * 0.5:
		return ""
	var ops: Array = []
	var texto := ""
	match str(d["verbo"]):
		"encontra":
			if alvo == "" or Viagens.viajando(u, quem) or not Estado.vivo(u, alvo):
				return ""
			var destino := str(u.estado(alvo).get("local", ""))
			var de := str(u.estado(quem).get("local", ""))
			if destino == "" or destino == de:
				return ""
			ops = Viagens.ops_de_ida(u, quem, de, destino)
			texto = "%s sentiu vontade de ir a %s." % [u.entidade(quem)["nome"], u.entidade(destino)["nome"]]
		"mata":
			ops = [{"op": "objetivo", "quem": quem, "tipo": "vingança", "alvo": alvo, "forca": 0.8}]
			texto = "%s não tira %s da cabeça." % [u.entidade(quem)["nome"], u.entidade(alvo).get("nome", "?")]
		"casa":
			ops = [{"op": "relacao", "de": quem, "para": alvo, "deltas": {"afeto": 0.15}}, {"op": "relacao", "de": alvo, "para": quem, "deltas": {"afeto": 0.15}}]
			texto = "%s e %s se aproximaram um pouco mais." % [u.entidade(quem)["nome"], u.entidade(alvo).get("nome", "?")]
		"governa":
			ops = [{"op": "mudar", "quem": quem, "chave": "reputacao", "delta": 0.2}, {"op": "traco", "quem": quem, "traco": "ambicao", "delta": 0.05}]
			texto = "%s ganhou fama e ambição." % u.entidade(quem)["nome"]
	if ops.is_empty():
		return ""
	return Simulador.registrar(u, {"tipo": "destino em curso", "descricao": texto, "sujeitos": [quem] + ([alvo] if alvo != "" else []),
		"causas": [Fios._ultimo_fato(u, quem)], "dados": {"importancia": 0.15, "destino": d["id"], "mudancas": ops}})
