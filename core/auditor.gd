class_name Auditor
extends RefCounted
## Confere a integridade do universo. Primeira versão (Parte 1):
## - causas que não existem
## - ciclos de causa (A causa B que causa A)
## - fatos da simulação sem causa (consequência sem origem válida)
## - causa que acontece DEPOIS do efeito
## - fatos que citam entidades que não existem


## Devolve uma lista de problemas: {tipo, fato, mensagem}.
static func auditar(universo: Universo) -> Array:
	var problemas: Array = []
	var fatos := universo.fatos.todos()
	var mapa := {}
	for f in fatos:
		mapa[f["id"]] = f

	for f in fatos:
		var id: String = f["id"]
		for c in f["causas"]:
			if not mapa.has(c):
				problemas.append(_p("causa_inexistente", id, "A causa '%s' não existe." % c))
			elif DataMundo.ordem(mapa[c]["data"]) > DataMundo.ordem(f["data"]):
				problemas.append(_p("causa_depois_do_efeito", id,
					"A causa acontece em %s, depois do efeito (%s)." % [
						DataMundo.texto(mapa[c]["data"]), DataMundo.texto(f["data"])]))
		if f["origem"].get("tipo", "") == BancoDeFatos.ORIGEM_SIMULACAO and f["causas"].is_empty():
			problemas.append(_p("sem_origem", id, "Fato da simulação sem nenhuma causa."))
		for e in f["sujeitos"]:
			if not universo.entidades.has(e):
				problemas.append(_p("entidade_inexistente", id, "Cita uma entidade que não existe: '%s'." % e))
		if f["lugar"] != "" and not universo.entidades.has(f["lugar"]):
			problemas.append(_p("entidade_inexistente", id, "O lugar '%s' não existe." % f["lugar"]))

	for ciclo_id in _fatos_em_ciclo(mapa):
		problemas.append(_p("ciclo", ciclo_id, "Este fato faz parte de um ciclo de causas (causa a si mesmo)."))
	return problemas


static func _p(tipo: String, fato: String, mensagem: String) -> Dictionary:
	return {"tipo": tipo, "fato": fato, "mensagem": mensagem}


## Busca em profundidade com três cores para achar ciclos.
static func _fatos_em_ciclo(mapa: Dictionary) -> Array:
	var cor := {}  # 0 branco, 1 cinza (na pilha), 2 preto (terminado)
	var em_ciclo := {}
	for inicio in mapa.keys():
		if cor.get(inicio, 0) != 0:
			continue
		var pilha: Array = [[inicio, 0]]
		var caminho: Array = []
		while not pilha.is_empty():
			var topo: Array = pilha.back()
			var id: String = topo[0]
			if topo[1] == 0:
				cor[id] = 1
				caminho.append(id)
			var causas: Array = mapa[id]["causas"]
			if topo[1] < causas.size():
				var prox: String = causas[topo[1]]
				topo[1] += 1
				if not mapa.has(prox):
					continue
				var c: int = cor.get(prox, 0)
				if c == 0:
					pilha.append([prox, 0])
				elif c == 1:
					var pos := caminho.find(prox)
					for k in range(pos, caminho.size()):
						em_ciclo[caminho[k]] = true
			else:
				cor[id] = 2
				caminho.pop_back()
				pilha.pop_back()
	return em_ciclo.keys()
