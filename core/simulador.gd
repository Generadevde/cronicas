class_name Simulador
extends RefCounted
## O relógio do mundo. Avança o tempo em passos de uma semana: as notícias viajam,
## quem fica sabendo reage, e cada mente decide o que fazer.
## Tudo que muda vira fato no banco (origem "simulacao", sempre com causa).

const PASSO_DIAS := 7

## Importância (0 a 1) de cada tipo de acontecimento: decide o que vira manchete.
const IMPORTANCIA := {
	"morte_por": 1.0, "morte": 0.9, "vitoria": 0.6, "derrota": 0.6, "casamento": 0.7, "traicao": 0.75,
	"ferimento": 0.45, "luta": 0.5, "nascimento": 0.5, "amor": 0.35, "odio": 0.35, "amizade": 0.3,
	"ensino": 0.45, "aprendizado": 0.45, "chegada": 0.2, "filiacao": 0.3, "paternidade": 0.3,
	"testemunho": 0.1, "medo": 0.3, "chegada_viagem": 0.25, "usar_poder": 0.5, "regra": 0.5, "guerra": 1.0,
}


## Avança o mundo 'dias' dias. Opções:
##   foco: [ids de lugares] — quem está nesses lugares fica parado (você está escrevendo ali)
##   parar_em_importante: bool — para assim que algo importante acontecer
##   aceitar_ecos: bool (padrão true) — ecos pendentes viram fato antes de avançar
## Devolve os ids dos fatos novos.
static func avancar(u: Universo, dias: int, opcoes: Dictionary = {}) -> Array:
	var novos: Array = []
	if opcoes.get("aceitar_ecos", true):
		for p in u.propostas.duplicate():
			# O que nasce de uma conversa espera você decidir.
			if p["status"] == "eco" and not p.has("conversa"):
				var fid := u.aceitar_proposta(p["id"])
				if fid != "":
					novos.append(fid)
	novos.append_array(preparar(u))
	var foco: Array = opcoes.get("foco", [])
	var restante := dias
	var ctrl: Dictionary = u.extra("simulacao", {"passos": 0})
	while restante > 0:
		var passo := mini(PASSO_DIAS, restante)
		restante -= passo
		# O tempo parou: o relógio não anda, só quem usou o poder (e quem ele tocou) age.
		var pausa := Motor.pausa(u)
		if not pausa.is_empty():
			passo = mini(passo, int(pausa["restante"]))
			Motor.gastar_pausa(u, passo)
			var rng_p := RandomNumberGenerator.new()
			rng_p.seed = hash(str(u.semente()) + ":pausa:" + str(DataMundo.ordem(u.relogio)) + ":" + str(int(pausa["restante"])))
			var idx_p := _indice_de_lugares(u)
			for eid in pausa["quem"]:
				if u.entidades.has(eid) and Estado.tem_mente(u, eid) and Estado.vivo(u, eid):
					novos.append_array(Decisao.decidir(u, eid, rng_p, idx_p))
			continue
		_andar_relogio(u, passo)
		ctrl["passos"] = int(ctrl.get("passos", 0)) + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(u.semente()) + ":" + str(DataMundo.ordem(u.relogio)))
		var deste_passo: Array = []
		deste_passo.append_array(Informacao.espalhar(u, rng))
		var indice := _indice_de_lugares(u)
		for eid in _mentes(u):
			if foco.has(u.estado(eid)["local"]) or Viagens.viajando(u, eid) or Motor.dormindo(u, eid) or eid == Vivencia.encarnado(u):
				continue
			if not _deve_pensar(u, eid, int(ctrl["passos"])):
				continue
			# Passos curtos (a escrita anda dia a dia): cada mente pensa na mesma medida.
			if passo < PASSO_DIAS and rng.randf() > float(passo) / PASSO_DIAS:
				continue
			deste_passo.append_array(Decisao.decidir(u, eid, rng, indice))
		for sistema in u.sistemas_de_simulacao():
			# Cada sistema tem a sua sorte (um sistema novo não muda o que os outros sorteiam).
			var rs := RandomNumberGenerator.new()
			rs.seed = hash(str(u.semente()) + ":" + str(DataMundo.ordem(u.relogio)) + ":" + str(sistema.get_global_name()))
			deste_passo.append_array(sistema.passo(u, passo, rs))
		novos.append_array(deste_passo)
		if opcoes.get("parar_em_importante", false) and deste_passo.any(func(f): return importancia(u, f) >= 0.6 or _favorito_envolvido(u, f)):
			break
	if not novos.is_empty():
		u.marcar_mudanca()
	else:
		u.marcar_mudanca()
	return novos


static func _andar_relogio(u: Universo, dias: int) -> void:
	var ordem := DataMundo.ordem(u.relogio) + dias
	var ano := int(floor(float(ordem - 1) / DataMundo.DIAS_POR_ANO))
	var dia := ordem - ano * DataMundo.DIAS_POR_ANO
	u.relogio = DataMundo.criar(ano, dia)


## Antes de simular: desejos escritos na ficha viram objetivos (uma vez cada).
static func preparar(u: Universo) -> Array:
	var novos: Array = []
	var preparo: Dictionary = u.extra("preparo", {})
	for eid in _mentes(u):
		# Só relê a ficha de quem mudou desde a última vez.
		var assinatura := hash(u.entidade(eid).get("campos", []))
		if int(preparo.get(eid, 0)) == assinatura:
			continue
		preparo[eid] = assinatura
		var ja := {}
		for f in u.fatos.sobre(eid):
			if f["tipo"] == "desejo da ficha":
				ja[f["dados"].get("texto", "")] = true
		for d in Objetivos.da_ficha(u, eid):
			if ja.has(d["texto"]):
				continue
			var ent := u.entidade(eid)
			var fid := registrar(u, {
				"tipo": "desejo da ficha",
				"descricao": "%s deseja: %s." % [ent["nome"], d["texto"]],
				"sujeitos": [eid] + ([d["alvo"]] if d["alvo"] != "" else []),
				"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": eid},
				"dados": {"texto": d["texto"], "importancia": 0.2,
					"mudancas": [{"op": "objetivo", "quem": eid, "tipo": d["tipo"], "alvo": d["alvo"], "forca": 0.7}]},
			})
			novos.append(fid)
	return novos


## Registra um fato da simulação e aplica as mudanças dele.
## Se não tiver causa, usa a causa de presença (o que colocou o sujeito onde está).
static func registrar(u: Universo, fato: Dictionary) -> String:
	if not fato.has("data"):
		fato["data"] = DataMundo.copiar(u.relogio)
	if not fato.has("origem"):
		fato["origem"] = {"tipo": BancoDeFatos.ORIGEM_SIMULACAO, "ref": ""}
	# Causas vazias ou que não existem são descartadas (e a causa de presença entra no lugar).
	fato["causas"] = Array(fato.get("causas", [])).filter(func(c): return str(c) != "" and u.fatos.existe(str(c)))
	if fato["origem"].get("tipo", "") == BancoDeFatos.ORIGEM_SIMULACAO and Array(fato.get("causas", [])).is_empty():
		var s: Array = fato.get("sujeitos", [])
		if not s.is_empty():
			fato["causas"] = [causa_de_presenca(u, s[0])]
	var dados: Dictionary = fato.get("dados", {})
	if not dados.has("importancia"):
		dados["importancia"] = IMPORTANCIA.get(dados.get("acao", ""), 0.2)
	fato["dados"] = dados
	var fid := u.fatos.registrar(fato)
	if fid == "":
		return ""
	var f := u.fatos.obter(fid)
	if dados.has("mudancas"):
		Mudancas.aplicar(u, dados["mudancas"], f)
	elif Extrator.ACOES.has(dados.get("acao", "")):
		AutoAtualizador.aplicar(u, fid, false)
	if not dados.get("efeito_de_lei", false):
		Regras.reagir(u, fid)
	return fid


## O fato que explica por que alguém está onde está (chegou lá, nasceu lá ou foi criado).
static func causa_de_presenca(u: Universo, eid: String) -> String:
	var local: String = u.estado(eid)["local"]
	var ids := u.fatos.ids_sobre(eid)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and (local == "" or f["lugar"] == local):
			return f["id"]
	var fc := str(u.entidade(eid).get("fato_criacao", ""))
	return fc if u.fatos.existe(fc) else u.fatos.todos()[0]["id"]


static func importancia(u: Universo, fid: String) -> float:
	return float(u.fatos.obter(fid).get("dados", {}).get("importancia", 0.2))


static func _favorito_envolvido(u: Universo, fid: String) -> bool:
	for e in u.fatos.obter(fid).get("sujeitos", []):
		if u.estado(e).get("favorito", false):
			return true
	return false


static var _cache_mentes := {"chave": "", "lista": []}


## Mentes vivas do universo (guardadas até algo mudar: entidades, fatos ou a data).
static func _mentes(u: Universo) -> Array:
	var chave := "%s|%d|%d|%d" % [u.id, u.versao, DataMundo.ordem(u.relogio), u.fatos.quantidade()]
	if _cache_mentes["chave"] == chave:
		return Array(_cache_mentes["lista"]).duplicate()
	var lista := _mentes_calc(u)
	_cache_mentes = {"chave": chave, "lista": lista}
	return lista.duplicate()


static func _mentes_calc(u: Universo) -> Array:
	var lista: Array = []
	for e in u.entidades_ativas():
		if Estado.tem_mente(u, e["id"]) and Estado.vivo(u, e["id"]) and not Motor.dormindo(u, e["id"]):
			lista.append(e["id"])
	return lista


## Níveis de detalhe: quem importa pensa toda semana; o resto, uma vez por mês.
static func _deve_pensar(u: Universo, eid: String, passo: int) -> bool:
	if detalhe(u, eid) == "alto":
		return true
	return passo % 4 == hash(eid) % 4


static func detalhe(u: Universo, eid: String) -> String:
	var s := u.estado(eid)
	if s.get("favorito", false) or not Estado.objetivos_ativos(u, eid).is_empty():
		return "alto"
	if u.indice().has(eid):
		return "alto"
	if not Estado.emocoes_atuais(u, eid).is_empty():
		return "alto"
	return "medio"


## Quem está em cada lugar: {lugar: [ids]} ("" = lugar desconhecido).
static func _indice_de_lugares(u: Universo) -> Dictionary:
	var idx := {}
	for eid in _mentes(u):
		var l: String = u.estado(eid)["local"]
		if not idx.has(l):
			idx[l] = []
		idx[l].append(eid)
	return idx


## Lugares conhecidos do universo (entidades cujo tipo parece lugar, ou onde alguém está).
static func lugares(u: Universo) -> Array:
	var lista: Array = []
	for e in u.entidades_ativas():
		if Sugestoes.categoria(e["tipo"]) == "lugar" or Mapa.e_lugar(u, e["id"]):
			lista.append(e["id"])
	for e in u.entidades_ativas():
		var l: String = u.estado(e["id"])["local"]
		if l != "" and not lista.has(l) and u.entidades.has(l):
			lista.append(l)
	return lista
