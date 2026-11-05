class_name Motor
extends RefCounted
## Poderes que mudam as regras do motor. No formato de livro tudo é possível, e a
## simulação respeita o que a história diz:
##  • parar o tempo — o mundo inteiro realmente pausa, menos quem usou e quem ele tocar;
##  • sono eterno — um lugar sai da simulação até a maldição ser quebrada;
##  • apagar da existência — alguém deixa de existir (e quase ninguém lembra);
##  • ver o futuro — o vidente consulta a própria simulação (numa cópia do mundo);
##  • viagem ao passado — abre um galho da linha do tempo; você decide qual vira canon.
## Tudo isso são peças de efeito (leis, poderes, preços de pacto) e fatos com causa.


# ---------------------------------------------------------------- operações

static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	match str(op.get("op", "")):
		"pausar":
			var quem: Array = Array(op.get("quem", [])).filter(func(x): return x != "")
			u.extras["pausa"] = {"fato": fato.get("id", ""), "quem": quem, "dias": int(op.get("dias", 7))}
			return true
		"adormecer":
			var l := str(op.get("lugar", ""))
			if u.entidades.has(l):
				u.estado(l)["adormecido"] = fato.get("id", "")
				u.versao += 1
			return true
		"despertar":
			var l2 := str(op.get("lugar", ""))
			if u.entidades.has(l2):
				u.estado(l2).erase("adormecido")
				u.versao += 1
			return true
		"apagar":
			var q := str(op.get("quem", ""))
			if u.entidades.has(q):
				Estado.morrer(u, q, fato)
				u.estado(q)["apagado"] = true
				# Quem conhecia esquece que ele existiu (sobra uma sensação estranha).
				for e in u.entidades_ativas():
					var rel: Dictionary = u.estado(e["id"]).get("relacoes", {})
					rel.erase(q)
			return true
		"prever":
			# Só calcula na primeira vez; ao reconstruir o mundo, a visão já está no fato.
			if not fato.get("dados", {}).has("previsao") and fato.has("id"):
				var dias := int(op.get("dias", 360))
				fato["dados"]["previsao"] = prever(u, dias)
				fato["dados"]["previsao_ate"] = DataMundo.ordem(u.relogio) + dias
			return true
		"galho":
			if fato.has("id") and not fato.get("dados", {}).has("galho"):
				fato["dados"]["galho"] = {"anos": int(op.get("anos", 10)), "aberto": false}
				fato["dados"]["sem_efeito"] = true
				fato["dados"]["texto"] = "viagem ao passado"
			return true
	return false


# ---------------------------------------------------------------- consultas

## A pausa em curso: {fato, quem, dias (que faltam)} ou {}.
static func pausa(u: Universo) -> Dictionary:
	var p: Dictionary = u.extra("pausa", {})
	if p.is_empty() or not u.fatos.obter(str(p.get("fato", ""))).get("canon", false):
		return {}
	var gasto := int(u.extra("pausa_gasta", {}).get(str(p["fato"]), 0))
	if gasto >= int(p["dias"]):
		return {}
	var r := p.duplicate()
	r["restante"] = int(p["dias"]) - gasto
	return r


static func gastar_pausa(u: Universo, dias: int) -> void:
	var p := pausa(u)
	if p.is_empty():
		return
	var g: Dictionary = u.extra("pausa_gasta", {})
	g[str(p["fato"])] = int(g.get(str(p["fato"]), 0)) + dias


## O lugar (ou um lugar que o contém) está sob sono eterno?
static func adormecido(u: Universo, lugar: String) -> bool:
	if lugar == "" or not u.entidades.has(lugar):
		return false
	# Quase sempre ninguém dorme: confere a lista (guardada até o mundo mudar) antes de subir o mapa.
	var dormem: Array = Sociedades._lembrar(u, "adormecidos", func():
		return u.entidades_ativas().filter(func(e): return e.get("sim", {}).has("adormecido")).map(func(e): return e["id"]))
	if dormem.is_empty():
		return false
	if u.estado(lugar).has("adormecido"):
		return true
	for a in Mapa.ancestrais(u, lugar):
		if u.entidades.has(a) and u.estado(a).has("adormecido"):
			return true
	return false


static func dormindo(u: Universo, eid: String) -> bool:
	return adormecido(u, str(u.estado(eid).get("local", "")))


# ---------------------------------------------------------------- ver o futuro

## Roda a simulação numa cópia do mundo e devolve o que vai acontecer de importante.
## A cópia usa a mesma semente: se ninguém mudar nada, a visão se cumpre.
static func prever(u: Universo, dias: int = 360) -> Array:
	var copia := Universo.de_dicionario(u.para_dicionario().duplicate(true))
	copia.id = u.id + "~visao"
	var antes := copia.fatos.quantidade()
	Simulador.avancar(copia, dias, {"aceitar_ecos": false})
	var visao: Array = []
	for f in copia.fatos.todos():
		if int(f["seq"]) <= antes or not f["canon"]:
			continue
		if float(f["dados"].get("importancia", 0.0)) >= 0.7 and not f["tipo"] in ["notícia", "rumor"]:
			visao.append({"data": f["data"], "descricao": f["descricao"]})
	return visao.slice(0, 12)


# ---------------------------------------------------------------- viagem ao passado

## Abre um galho: uma cópia do universo voltada para a data escolhida. Os fatos de depois
## continuam guardados no galho, mas fora do canon (nada se perde). Devolve o novo universo.
static func galho(u: Universo, data: Dictionary, nome: String = "") -> Universo:
	var copia := Universo.de_dicionario(u.para_dicionario().duplicate(true))
	copia.id = Ids.novo("uni")
	copia.nome = nome if nome != "" else "%s — galho de %s" % [u.nome, DataMundo.texto(data)]
	var limite := DataMundo.ordem(data)
	for f in copia.fatos.todos():
		if DataMundo.ordem(f["data"]) > limite and f["canon"]:
			f["canon"] = false
			f["dados"]["fora_do_galho"] = true
	copia.relogio = DataMundo.copiar(data)
	copia.extras.erase("noticias_ctrl")
	copia.extras.erase("pausa")
	AutoAtualizador.reconstruir(copia)
	copia.marcar_mudanca()
	return copia
