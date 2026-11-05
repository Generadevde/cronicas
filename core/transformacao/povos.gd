class_name Povos
extends RefCounted
## Povos em movimento e ideias que mudam o mundo.
##  • Migrações: fome, guerra ou peste longas fazem um povo inteiro se mudar; as
##    culturas se misturam e o lugar que recebe fica tenso.
##  • Revoluções: ideias novas nascem de gente curiosa e estudada, se espalham, e
##    quando muitos acreditam e o povo está com raiva, o governo cai ou se reinventa.
##  • Romance e família: casamentos entre casas governantes viram alianças; ciúmes
##    criam inimigos; famílias se dividem.
##  • Contato entre mundos e colonização: com técnica (ou magia) bastante, povos de
##    planetas diferentes se encontram — e fundam colônias, que um dia se rebelam.

const IDEIAS := [
	{"nome": "ninguém deve ter rei", "muda_para": "republica", "contra": ["monarquia", "teocracia"]},
	{"nome": "os deuses não governam os homens", "muda_para": "republica", "contra": ["teocracia"]},
	{"nome": "o povo precisa de um soberano forte", "muda_para": "monarquia", "contra": ["republica", "anarquia"]},
	{"nome": "nenhum governo é justo", "muda_para": "anarquia", "contra": ["monarquia", "republica", "teocracia", "corporacao"]},
]


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("povos_ctrl", {"t": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < 90:
		return []
	ctrl["t"] = agora
	var novos: Array = []
	novos.append_array(_migracoes(u, rng))
	novos.append_array(_ideias(u, rng))
	novos.append_array(_romance(u, rng))
	novos.append_array(_mundos(u, rng))
	return novos.filter(func(x): return x != "")


# ---------------------------------------------------------------- migrações

static func _migracoes(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var guerra := Guerras.lugares_em_guerra(u)
	for e in u.entidades_ativas():
		var l: String = e["id"]
		if Mapa.especie(u, l) != "povoado" or not Natureza.tem_natureza(u, l) or Motor.adormecido(u, l):
			continue
		var reg := Natureza.de(u, l)
		var al: Dictionary = reg["alertas"]
		var aperto := 0.0
		var causa := ""
		if float(reg["comida"]) < 0.4:
			aperto += 0.5
			causa = str(al.get("fome_fato", ""))
		if guerra.has(l) and u.estado(l).has("ocupado_por"):
			aperto += 0.4
			causa = Guerras._ultimo_fato(u, guerra[l]) if causa == "" else causa
		if Natureza.eventos_ativos(u, l).any(func(ev): return ev["tipo"] == "epidemia"):
			aperto += 0.3
		if aperto < 0.7 or float(reg["pop"]) < 200 or al.get("exodo", false) or rng.randf() > 0.3:
			continue
		var destino := Natureza._destino_com_comida(u, l)
		if destino == "" or destino == l:
			continue
		al["exodo"] = true
		var vai := float(reg["pop"]) * 0.4
		reg["pop"] = float(reg["pop"]) - vai
		var regd := Natureza.de(u, destino)
		regd["pop"] = float(regd["pop"]) + vai
		var hd := Humor.de(u, destino)
		hd["raiva"] = clampf(float(hd["raiva"]) + 0.12, 0.0, 1.0)
		var ops: Array = []
		for m in Natureza._mentes_em(u, l):
			if rng.randf() < 0.4:
				ops.append({"op": "mover", "quem": m, "lugar": destino})
		var lingua_a := Linguas.do_lugar(u, l)
		var lingua_b := Linguas.do_lugar(u, destino)
		var mistura := " As línguas %s e %s começam a se misturar." % [lingua_a, lingua_b] if lingua_a != lingua_b and lingua_a != "" and lingua_b != "" else ""
		var c: Array = [causa] if u.fatos.existe(causa) else [Natureza._ultimo_fato_natural(u, l)]
		novos.append(Simulador.registrar(u, {"tipo": "migração de um povo", "lugar": destino, "sujeitos": [l, destino],
			"causas": c, "descricao": "O povo de %s migrou em massa para %s (cerca de %s pessoas), e a chegada gerou tensão.%s" % [e["nome"], u.entidade(destino)["nome"], Paginas._numero(vai), mistura],
			"dados": {"importancia": 0.7, "mudancas": ops}}))
	return novos


# ---------------------------------------------------------------- ideias e revoluções

static func ideia_de(u: Universo, eid: String) -> String:
	for m in Pecas.marcas(u, eid):
		if str(m).begins_with("acredita que "):
			return str(m).trim_prefix("acredita que ")
	return ""


static func _ideias(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for sid in Sociedades.todas(u):
		var t := Sociedades.tipo(u, sid)
		var membros := Sociedades.membros(u, sid)
		if membros.size() < 4:
			continue
		var possiveis: Array = IDEIAS.filter(func(i): return i["contra"].has(t))
		if possiveis.is_empty():
			continue
		# Nasce: alguém curioso (ou de uma escola) começa a defender a ideia.
		var crentes := {}
		for m in membros:
			var ideia := ideia_de(u, m)
			if ideia != "":
				crentes[ideia] = int(crentes.get(ideia, 0)) + 1
		if crentes.is_empty():
			for m in membros:
				var tr := Personalidade.tracos(u, m)
				if float(tr["curiosidade"]) > 0.7 and float(tr["coragem"]) > 0.5 and rng.randf() < 0.03 + (0.05 if not Tecnicas.de(u, m).is_empty() else 0.0):
					var idn: Dictionary = possiveis[rng.randi() % possiveis.size()]
					novos.append(Simulador.registrar(u, {"tipo": "ideia nova", "sujeitos": [m, sid], "lugar": u.estado(m)["local"], "causas": [Simulador.causa_de_presenca(u, m)],
						"descricao": "%s começou a defender, em %s, que %s." % [u.entidade(m)["nome"], u.entidade(u.estado(m)["local"]).get("nome", "?"), idn["nome"]],
						"dados": {"importancia": 0.45, "ideia": idn["nome"], "mudancas": [{"op": "marca", "quem": m, "marca": "acredita que " + idn["nome"]}]}}))
					break
			continue
		# Espalha: quem tem raiva do governo ouve.
		for ideia in crentes:
			var ops: Array = []
			for m in membros:
				if ideia_de(u, m) != "":
					continue
				var lugar := str(u.estado(m)["local"])
				var raiva := float(Humor.de(u, lugar)["raiva"]) if lugar != "" and Natureza.tem_natureza(u, lugar) else 0.2
				if rng.randf() < 0.1 + raiva * 0.3:
					ops.append({"op": "marca", "quem": m, "marca": "acredita que " + ideia})
			var origem := _fato_da_ideia(u, sid, ideia)
			if not ops.is_empty():
				novos.append(Simulador.registrar(u, {"tipo": "ideia se espalha", "sujeitos": [sid] + ops.map(func(o): return o["quem"]), "causas": [origem],
					"descricao": "A ideia de que %s ganhou %d adepto%s em %s." % [ideia, ops.size(), "" if ops.size() == 1 else "s", u.entidade(sid)["nome"]],
					"dados": {"importancia": 0.3, "mudancas": ops}}))
			# Revolução: muitos acreditam e o povo está com raiva.
			var total := int(crentes[ideia]) + ops.size()
			var raiva_media := 0.0
			var n := 0
			for l in Sociedades.territorio(u, sid):
				if Mapa.especie(u, l) == "povoado" and Natureza.tem_natureza(u, l):
					raiva_media += float(Humor.de(u, l)["raiva"])
					n += 1
			raiva_media = raiva_media / maxf(1.0, n)
			if total >= membros.size() * 0.4 and raiva_media >= 0.4 and rng.randf() < 0.5:
				var idn2: Dictionary = IDEIAS.filter(func(i): return i["nome"] == ideia)[0]
				var lider_rev := ""
				for m in membros:
					if ideia_de(u, m) == ideia and (lider_rev == "" or float(u.estado(m).get("reputacao", 0.0)) > float(u.estado(lider_rev).get("reputacao", 0.0))):
						lider_rev = m
				var ops2: Array = [{"op": "definir", "quem": sid, "chave": "tipo_governo", "valor": idn2["muda_para"]}]
				if idn2["muda_para"] != "anarquia" and lider_rev != "":
					ops2.append({"op": "definir", "quem": sid, "chave": "lider", "valor": lider_rev})
					ops2.append({"op": "definir", "quem": sid, "chave": "sem_governante", "valor": false})
				var antigo := Sociedades.lider(u, sid)
				if antigo != "" and antigo != lider_rev:
					ops2.append({"op": "marca", "quem": antigo, "marca": "deposto"})
				novos.append(Simulador.registrar(u, {"tipo": "revolução", "sujeitos": [sid, lider_rev, antigo], "causas": [origem],
					"descricao": "Revolução em %s: a ideia de que %s venceu, e %s virou %s%s." % [u.entidade(sid)["nome"], ideia, u.entidade(sid)["nome"],
						Sociedades.NOMES_TIPO.get(idn2["muda_para"], idn2["muda_para"]), (", com %s à frente" % u.entidade(lider_rev)["nome"]) if lider_rev != "" and idn2["muda_para"] != "anarquia" else ""],
					"dados": {"importancia": 0.9, "mudancas": ops2}}))
	return novos


static func _fato_da_ideia(u: Universo, sid: String, ideia: String) -> String:
	var ids := u.fatos.ids_sobre(sid)
	for i in range(ids.size() - 1, -1, -1):
		var f := u.fatos.obter(ids[i])
		if f["canon"] and f["tipo"] in ["ideia nova", "ideia se espalha"] and (str(f["dados"].get("ideia", "")) == ideia or f["descricao"].contains(ideia)):
			return f["id"]
	return str(u.entidade(sid).get("fato_criacao", ""))


# ---------------------------------------------------------------- romance e família

static func _romance(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var casas := {}
	for sid in Sociedades.todas(u):
		var l := Sociedades.lider(u, sid)
		if l != "" and u.entidades.has(l):
			casas[l] = sid
			for f in u.estado(l)["familia"]["filhos"]:
				casas[f] = sid
	var vistos := {}
	for a in Simulador._mentes(u):
		for b in u.estado(a)["familia"]["conjuges"]:
			var chave := "%s|%s" % ([a, b] if a < b else [b, a])
			if vistos.has(chave):
				continue
			vistos[chave] = true
			# Casamento entre casas governantes de sociedades diferentes vira aliança.
			if casas.has(a) and casas.has(b) and casas[a] != casas[b]:
				var sa: String = casas[a]
				var sb: String = casas[b]
				if not u.estado(sa).get("aliados", []).has(sb):
					novos.append(Simulador.registrar(u, {"tipo": "aliança por casamento", "sujeitos": [sa, sb, a, b], "causas": [Familia._casamento(u, a, b)],
						"descricao": "O casamento de %s e %s uniu %s e %s numa aliança." % [u.entidade(a)["nome"], u.entidade(b)["nome"], u.entidade(sa)["nome"], u.entidade(sb)["nome"]],
						"dados": {"importancia": 0.65, "mudancas": [{"op": "aliar", "a": sa, "b": sb}]}}))
			# Ciúme: o cônjuge tem afeto forte por outra pessoa.
			for par in [[a, b], [b, a]]:
				var quem: String = par[0]
				var conj: String = par[1]
				if not u.entidades.has(conj) or not Estado.vivo(u, conj):
					continue
				for outro in u.estado(conj)["relacoes"]:
					if outro == quem or Estado.familia_proxima(u, conj).has(outro):
						continue
					# Ciúme é de amor, não de amizade: o cônjuge ama outra pessoa.
					if not Estado.emocoes_atuais(u, conj).any(func(em): return em["emocao"] == "amor" and em["alvo"] == outro and float(em["forca_atual"]) >= 0.4):
						continue
					if u.estado(quem).has("ciume_" + outro) or Estado.valor_relacao(u, quem, outro, "raiva") >= 0.4 or rng.randf() > 0.05:
						continue
					novos.append(Simulador.registrar(u, {"tipo": "ciúme", "sujeitos": [quem, outro, conj], "lugar": u.estado(quem)["local"], "causas": [Simulador.causa_de_presenca(u, conj)],
						"descricao": "%s ficou com ciúmes de %s, por causa de %s." % [u.entidade(quem)["nome"], u.entidade(outro)["nome"], u.entidade(conj)["nome"]],
						"dados": {"importancia": 0.4, "mudancas": [{"op": "relacao", "de": quem, "para": outro, "deltas": {"raiva": 0.5}},
							{"op": "definir", "quem": quem, "chave": "ciume_" + outro, "valor": true},
							{"op": "emocao", "quem": quem, "emocao": "ciume", "forca": 0.6, "alvo": outro}]}}))
					break
	# Famílias que se dividem: irmãos que se odeiam.
	for a in Simulador._mentes(u):
		for p in u.estado(a)["familia"]["pais"]:
			if not u.entidades.has(p):
				continue
			for irmao in u.estado(p)["familia"]["filhos"]:
				if irmao <= a or not Estado.vivo(u, irmao):
					continue
				if Estado.valor_relacao(u, a, irmao, "raiva") >= 0.7 and Estado.valor_relacao(u, irmao, a, "raiva") >= 0.5 and not u.estado(a).has("rompeu_" + irmao):
					novos.append(Simulador.registrar(u, {"tipo": "família dividida", "sujeitos": [a, irmao, p], "causas": [Guerras._fato_entre(u, a, irmao)],
						"descricao": "%s e %s romperam: a família de %s se dividiu." % [u.entidade(a)["nome"], u.entidade(irmao)["nome"], u.entidade(p)["nome"]],
						"dados": {"importancia": 0.5, "mudancas": [{"op": "definir", "quem": a, "chave": "rompeu_" + irmao, "valor": true}]}}))
	return novos


static func aplicar_op(u: Universo, op: Dictionary, fato: Dictionary) -> bool:
	if str(op.get("op", "")) == "aliar":
		for par in [[str(op.get("a", "")), str(op.get("b", ""))], [str(op.get("b", "")), str(op.get("a", ""))]]:
			if u.entidades.has(par[0]):
				var l: Array = u.estado(par[0]).get("aliados", [])
				if not l.has(par[1]):
					l.append(par[1])
				u.estado(par[0])["aliados"] = l
		return true
	return false


# ---------------------------------------------------------------- mundos

static func planeta_de(u: Universo, lugar: String) -> String:
	for c in [lugar] + Mapa.ancestrais(u, lugar):
		if u.entidades.has(c) and Mapa.especie(u, c) == "planeta":
			return c
	return ""


static func _mundos(u: Universo, rng: RandomNumberGenerator) -> Array:
	var leis := Cosmos.leis(u)
	var alcance := maxf(float(leis["tecnologia"]), float(leis["magia"]) * 0.9)
	if alcance < 0.75:
		return []
	var novos: Array = []
	var por_planeta := {}
	for sid in Sociedades.todas(u):
		var p := planeta_de(u, Guerras._sede(u, sid))
		if p != "":
			por_planeta[p] = Array(por_planeta.get(p, [])) + [sid]
	var planetas: Array = u.entidades_ativas().filter(func(e): return Mapa.especie(u, e["id"]) == "planeta").map(func(e): return e["id"])
	var meio := "naves" if float(leis["tecnologia"]) >= float(leis["magia"]) * 0.9 else "portais"
	# Primeiro contato entre planetas habitados.
	var contatos: Dictionary = u.extra("contatos", {})
	for p1 in por_planeta:
		for p2 in por_planeta:
			if p1 >= p2 or contatos.has(p1 + "|" + p2) or rng.randf() > 0.1 * alcance:
				continue
			contatos[p1 + "|" + p2] = true
			var a: String = por_planeta[p1][0]
			var b: String = por_planeta[p2][0]
			var hostil := float(Personalidade.tracos(u, Sociedades.lider(u, a))["ambicao"]) > 0.7 if Sociedades.lider(u, a) != "" else false
			var fid := Simulador.registrar(u, {"tipo": "primeiro contato", "sujeitos": [a, b, p1, p2], "causas": [str(u.entidade(a).get("fato_criacao", ""))],
				"descricao": "Primeiro contato: por %s, o povo de %s (%s) encontrou o de %s (%s)." % [meio, u.entidade(p1)["nome"], u.entidade(a)["nome"], u.entidade(p2)["nome"], u.entidade(b)["nome"]],
				"dados": {"importancia": 0.9, "mudancas": []}})
			novos.append(fid)
			if hostil:
				var g := Guerras.declarar(u, a, b, "conquista de outro mundo", [fid])
				if g != "":
					novos.append(Guerras.dados(u, g)["declaracao"])
	# Colonização: um planeta vazio perto de quem tem alcance.
	for p in planetas:
		if por_planeta.has(p) or u.estado(p).has("colonizado") or rng.randf() > 0.05 * alcance:
			continue
		var metropole := ""
		for pp in por_planeta:
			metropole = por_planeta[pp][0]
			break
		if metropole == "":
			break
		var nome: Variant = "Nova " + u.entidade(Guerras._sede(u, metropole)).get("nome", "Colônia") if Guerras._sede(u, metropole) != "" else "Colônia"
		var col := u.criar_entidade(nome, "colônia", [], [{"chave": "população", "valor": "300"}, {"chave": "fundada por", "valor": u.entidade(metropole)["nome"]}],
			[str(u.entidade(metropole).get("fato_criacao", ""))])
		var livres := Mapa.celulas_livres(u, p, ["campo", "planicie", "floresta", "colina"])
		if not livres.is_empty():
			var c: Vector2i = livres[rng.randi() % livres.size()]
			Mapa.colocar(u, col, p, c.x, c.y, false)
		var ops: Array = [{"op": "dono", "lugar": col, "sid": metropole}, {"op": "definir", "quem": p, "chave": "colonizado", "valor": metropole}]
		var colonos: Array = Sociedades.membros(u, metropole).filter(func(m): return float(Personalidade.tracos(u, m)["curiosidade"]) > 0.6).slice(0, 3)
		for m in colonos:
			ops.append({"op": "mover", "quem": m, "lugar": col})
		novos.append(Simulador.registrar(u, {"tipo": "colonização", "lugar": col, "sujeitos": [metropole, col, p] + colonos, "causas": [str(u.entidade(col).get("fato_criacao", ""))],
			"descricao": "%s fundou uma colônia em %s: %s." % [u.entidade(metropole)["nome"], u.entidade(p)["nome"], nome],
			"dados": {"importancia": 0.8, "mudancas": ops}}))
	# Colônias que se rebelam contra a terra natal.
	for e in u.entidades_ativas():
		var col2: String = e["id"]
		var dono := str(e.get("sim", {}).get("dono", ""))
		if dono == "" or TextUtil.normalizar(e["tipo"]) != "colonia" or u.estado(col2).get("independente", false):
			continue
		var anos := (DataMundo.ordem(u.relogio) - DataMundo.ordem(u.fatos.obter(str(e.get("fato_criacao", ""))).get("data", u.relogio))) / float(DataMundo.DIAS_POR_ANO)
		if anos < 20 or rng.randf() > 0.05:
			continue
		var rep := u.criar_entidade("República de " + e["nome"], "república", [], [{"chave": "forma de governo", "valor": "república"}, {"chave": "território", "valor": e["nome"]}],
			[str(e.get("fato_criacao", ""))])
		var fid2 := Simulador.registrar(u, {"tipo": "independência", "lugar": col2, "sujeitos": [rep, dono, col2], "causas": [str(e.get("fato_criacao", ""))],
			"descricao": "%s declarou independência de %s e virou a %s." % [e["nome"], u.entidade(dono)["nome"], u.entidade(rep)["nome"]],
			"dados": {"importancia": 0.85, "mudancas": [{"op": "dono", "lugar": col2, "sid": rep}, {"op": "definir", "quem": col2, "chave": "independente", "valor": true}]}})
		novos.append(fid2)
		if float(Personalidade.tracos(u, Sociedades.lider(u, dono))["orgulho"]) > 0.6 if Sociedades.lider(u, dono) != "" else false:
			var g2 := Guerras.declarar(u, dono, rep, "retomar a colônia", [fid2])
			if g2 != "":
				novos.append(Guerras.dados(u, g2)["declaracao"])
	return novos
