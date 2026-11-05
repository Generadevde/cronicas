class_name Sociedades
extends RefCounted
## Sociedades: reinos, repúblicas, tribos, teocracias, guildas, colmeias… Funcionam
## como mentes coletivas: têm governo, governante, conselho, território, leis,
## religião, cultura e riqueza, e reagem ao que acontece (fome, revolta, morte do
## governante, golpe).
##
## Nada é campo fixo: uma sociedade é qualquer entidade de facção (nação, guilda,
## ordem…) ou lugar com governo na ficha. O programa lê os campos pelo começo do nome:
##   forma de governo / governo — "monarquia", "república", "teocracia", "tribo"…
##   líder / quem governa / rei / rainha / chefe — quem manda agora
##   conselho / nobres / generais — quem sustenta (ou derruba) o governante
##   território / terras / sede / capital — onde a sociedade manda
##   leis — frases em português (viram leis do universo dentro do território)
##   religião / fé / crença — e o deus, se for uma entidade
##   admiram / desprezam / tabus / costumes — a cultura (pesa na reputação)
##   impostos — "baixos", "altos"…
## O estado (governante, tipo de governo depois de uma revolução) fica em fatos.

const TIPOS := {
	"monarquia": ["reino", "imperio", "monarquia", "rei", "rainha", "imperador", "imperatriz", "principado", "ducado", "condado", "baronia", "dinastia", "coroa", "sultanato", "cla real"],
	"republica": ["republica", "democracia", "eleito", "eleicao", "senado", "federacao", "cidade-estado", "assembleia"],
	"teocracia": ["teocracia", "igreja", "templo", "sacerdot", "seita", "culto", "clero", "santo", "santa"],
	"tribo": ["tribo", "cla", "clas", "anciaos", "anciao", "chefe", "horda", "bando"],
	"colmeia": ["colmeia", "enxame", "mente coletiva", "rainha-mae"],
	"maquina": ["maquina", "ia", "inteligencia artificial", "automato", "robo", "nucleo", "algoritmo"],
	"corporacao": ["guilda", "companhia", "corporacao", "mercadores", "empresa", "banco", "consorcio", "liga mercantil"],
	"anarquia": ["anarquia", "sem governo", "ninguem governa", "comuna", "livres"],
	"ordem": ["ordem", "irmandade", "fraternidade", "conselho", "circulo", "academia", "escola"],
}
const NOMES_TIPO := {"monarquia": "monarquia", "republica": "república", "teocracia": "teocracia", "tribo": "tribo / clãs",
	"colmeia": "colmeia", "maquina": "máquina", "corporacao": "guilda / corporação", "anarquia": "anarquia", "ordem": "ordem / conselho", "outro": "governo próprio"}
## Como cada tipo escolhe o próximo governante.
const SUCESSAO := {"monarquia": "heranca", "republica": "eleicao", "teocracia": "fe", "tribo": "forca", "colmeia": "colmeia",
	"maquina": "calculo", "corporacao": "riqueza", "anarquia": "nenhuma", "ordem": "eleicao", "outro": "forca"}
## Quanto o governo aguenta uma revolta (força de repressão relativa).
const REPRESSAO := {"monarquia": 1.2, "republica": 0.7, "teocracia": 1.1, "tribo": 1.0, "colmeia": 99.0, "maquina": 99.0,
	"corporacao": 0.9, "anarquia": 0.3, "ordem": 0.9, "outro": 1.0}
const CAMPOS_LIDER := ["lider", "quem governa", "governante", "rei", "rainha", "imperador", "imperatriz", "chefe", "soberano", "regente", "presidente", "sumo"]
const CAMPOS_CONSELHO := ["conselho", "nobres", "generais", "conselheiros", "anciaos", "senadores"]
const CAMPOS_TERRITORIO := ["territorio", "terras", "dominio", "sede", "capital", "reino de", "governa"]


# ---------------------------------------------------------------- o que é uma sociedade

static func _campo(u: Universo, eid: String, prefixos: Array) -> String:
	for c in u.entidade(eid).get("campos", []):
		var k := TextUtil.normalizar(c["chave"])
		for p in prefixos:
			if k == p or k.begins_with(p):
				if str(c["valor"]).strip_edges() != "":
					return str(c["valor"])
	return ""


static func eh_sociedade(u: Universo, eid: String) -> bool:
	var e := u.entidade(eid)
	if e.is_empty() or e["removida"]:
		return false
	if _campo(u, eid, ["forma de governo", "governo"] + CAMPOS_LIDER) != "":
		return true
	if Sugestoes.categoria(e["tipo"]) == "faccao":
		return true
	var t := TextUtil.normalizar(e["tipo"])
	for w in ["reino", "imperio", "republica", "nacao", "tribo", "teocracia", "principado", "ducado", "condado", "cidade-estado", "colmeia"]:
		if t.contains(w):
			return true
	return false


static var _memo: Dictionary = {}


## Guarda um cálculo até o mundo mudar (entidades, fichas ou mapa).
static func _lembrar(u: Universo, chave: String, calc: Callable) -> Variant:
	var k := "%s|%d|%s" % [u.id, u.versao, chave]
	if _memo.has(k):
		return _memo[k]
	if _memo.size() > 5000:
		_memo.clear()
	var v = calc.call()
	_memo[k] = v
	return v


static func todas(u: Universo) -> Array:
	return _lembrar(u, "todas", func(): return u.entidades_ativas().filter(func(e): return eh_sociedade(u, e["id"])).map(func(e): return e["id"]))


## Tipo de governo: o que a revolução mudou (estado) ou o que a ficha diz.
static func tipo(u: Universo, sid: String) -> String:
	var mudado := str(u.estado(sid).get("tipo_governo", ""))
	if mudado != "":
		return mudado
	var texto := TextUtil.normalizar(_campo(u, sid, ["forma de governo", "governo"]) + " " + u.entidade(sid).get("tipo", ""))
	for t in TIPOS:
		for w in TIPOS[t]:
			if (" " + texto + " ").contains(" " + w) :
				return t
	return "outro"


## Lugares onde a sociedade manda (com tudo o que fica dentro deles).
static func territorio(u: Universo, sid: String) -> Array:
	return _lembrar(u, "terr|" + sid, func(): return _territorio(u, sid))


static func territorio_base(u: Universo, sid: String) -> Array:
	return _lembrar(u, "base|" + sid, func(): return _base(u, sid))


static func _base(u: Universo, sid: String) -> Array:
	var base: Array = []
	if Mapa.e_lugar(u, sid) and Mapa.especie(u, sid) != "":
		base.append(sid)
	var txt := _campo(u, sid, CAMPOS_TERRITORIO)
	if txt != "":
		for m in Ligador.new(u).encontrar(txt):
			if Mapa.e_lugar(u, m["entidade"]) and not base.has(m["entidade"]):
				base.append(m["entidade"])
	return base


static func _territorio(u: Universo, sid: String) -> Array:
	var base: Array = []
	if Mapa.e_lugar(u, sid) and Mapa.especie(u, sid) != "":
		base.append(sid)
	var txt := _campo(u, sid, CAMPOS_TERRITORIO)
	if txt != "":
		for m in Ligador.new(u).encontrar(txt):
			if Mapa.e_lugar(u, m["entidade"]) and not base.has(m["entidade"]):
				base.append(m["entidade"])
	var tudo: Array = base.duplicate()
	for b in base:
		for d in Mapa.descendentes(u, b):
			if not tudo.has(d):
				tudo.append(d)
	return tudo


## A sociedade que manda num lugar (a mais próxima, de dentro para fora).
static func de_lugar(u: Universo, lugar: String) -> String:
	if lugar == "":
		return ""
	return _lembrar(u, "de|" + lugar + "|" + _tipos_mudados(u), func(): return _de_lugar(u, lugar))


static func _tipos_mudados(u: Universo) -> String:
	var t := ""
	for sid in todas(u):
		t += str(u.estado(sid).get("tipo_governo", ""))
	return t


static func _de_lugar(u: Universo, lugar: String) -> String:
	var cadeia: Array = [lugar] + Mapa.ancestrais(u, lugar)
	var melhor := ""
	var melhor_nivel := 999
	for governa in [true, false]:
		for sid in todas(u):
			# Guildas e ordens não governam lugares (só se não houver outro governo).
			if governa == (tipo(u, sid) in ["corporacao", "ordem"]):
				continue
			for b in territorio_base(u, sid):
				var i := cadeia.find(b)
				if i >= 0 and i < melhor_nivel:
					melhor = sid
					melhor_nivel = i
		if melhor != "":
			return melhor
	return melhor


static func membros(u: Universo, sid: String) -> Array:
	return _lembrar(u, "membros|%s|%d" % [sid, DataMundo.ordem(u.relogio) / 30], func(): return _membros(u, sid))


static func _membros(u: Universo, sid: String) -> Array:
	var terr := territorio(u, sid)
	var nome := TextUtil.chave(u.entidade(sid)["nome"])
	var lista: Array = []
	for e in u.entidades_ativas():
		if not Estado.tem_mente(u, e["id"]) or not Estado.vivo(u, e["id"]):
			continue
		if terr.has(u.estado(e["id"])["local"]):
			lista.append(e["id"])
			continue
		for c in e["campos"]:
			if nome != "" and TextUtil.chave(c["valor"]).contains(nome):
				lista.append(e["id"])
				break
	return lista


# ---------------------------------------------------------------- governante e conselho

static func lider(u: Universo, sid: String) -> String:
	var s := u.estado(sid)
	if s.has("lider"):
		return str(s["lider"])
	var txt := _campo(u, sid, CAMPOS_LIDER)
	if txt == "":
		return ""
	var achadas := pessoas_no_texto(u, txt)
	return achadas[0] if not achadas.is_empty() else ""


## Pessoas citadas num texto: pelo nome inteiro, pelo apelido ou só pelo primeiro nome.
static func pessoas_no_texto(u: Universo, txt: String) -> Array:
	return _lembrar(u, "pessoas|" + txt, func():
		var lista: Array = []
		for m in Ligador.new(u).encontrar(txt):
			if Sugestoes.categoria(u.entidade(m["entidade"]).get("tipo", "")) in ["pessoa", "entidade", "criatura"] and not lista.has(m["entidade"]):
				lista.append(m["entidade"])
		for parte in txt.replace(" e ", ",").split(",", false):
			var k := TextUtil.chave(parte)
			if k == "":
				continue
			for e in u.entidades_ativas():
				if lista.has(e["id"]) or not Sugestoes.categoria(e["tipo"]) in ["pessoa", "entidade", "criatura"]:
					continue
				var primeiro := TextUtil.chave(str(e["nome"]).split(" ", false)[0]) if str(e["nome"]) != "" else ""
				if primeiro == k or TextUtil.chave(e["nome"]) == k:
					lista.append(e["id"])
					break
		return lista)


static func conselho(u: Universo, sid: String) -> Array:
	return _lembrar(u, "conselho|%s|%d|%s" % [sid, DataMundo.ordem(u.relogio) / 30, lider(u, sid)], func(): return _conselho(u, sid))


static func _conselho(u: Universo, sid: String) -> Array:
	var lista: Array = []
	var txt := _campo(u, sid, CAMPOS_CONSELHO)
	if txt != "":
		for p in pessoas_no_texto(u, txt):
			if Estado.tem_mente(u, p) and Estado.vivo(u, p) and not lista.has(p):
				lista.append(p)
	if lista.is_empty():
		var l := lider(u, sid)
		var candidatos := membros(u, sid).filter(func(m): return m != l and Estado.idade(u, m) != -1 and Estado.idade(u, m) >= 18 or m != l and Estado.idade(u, m) == -1)
		candidatos.sort_custom(func(a, b): return _peso_politico(u, a) > _peso_politico(u, b))
		lista = candidatos.slice(0, 3)
	return lista


static func _peso_politico(u: Universo, eid: String) -> float:
	return Estado.poder(u, eid) + float(u.estado(eid)["reputacao"]) * 0.5 + float(Personalidade.tracos(u, eid)["ambicao"])


## Quanto alguém do conselho é leal ao governante (0 a 1).
static func lealdade(u: Universo, quem: String, l: String) -> float:
	if l == "" or not u.entidades.has(l):
		return 0.5
	var t := Personalidade.tracos(u, quem)
	var v := 0.45 + float(t["lealdade"]) * 0.35 - float(t["ambicao"]) * 0.25
	v += Estado.valor_relacao(u, quem, l, "afeto") * 0.3 + Estado.valor_relacao(u, quem, l, "respeito") * 0.3
	v -= Estado.valor_relacao(u, quem, l, "raiva") * 0.5
	if Estado.familia_proxima(u, quem).has(l):
		v += 0.15
	return clampf(v, 0.0, 1.0)


## Escolhe o próximo governante pelo jeito da sociedade.
static func sucessor(u: Universo, sid: String, antigo: String) -> String:
	var modo: String = SUCESSAO.get(tipo(u, sid), "forca")
	var lei := TextUtil.normalizar(_campo(u, sid, ["sucess"]))
	if lei.contains("heran") or lei.contains("filh") or lei.contains("sangue"):
		modo = "heranca"
	elif lei.contains("elei") or lei.contains("voto") or lei.contains("escolh"):
		modo = "eleicao"
	elif lei.contains("forca") or lei.contains("duelo") or lei.contains("combate"):
		modo = "forca"
	if modo == "nenhuma":
		return ""
	var vivos := func(lista: Array) -> Array:
		return lista.filter(func(x): return x != antigo and u.entidades.has(x) and Estado.vivo(u, x) and not u.entidade(x)["removida"])
	if modo == "heranca" and antigo != "":
		var fam: Dictionary = u.estado(antigo)["familia"]
		var filhos: Array = vivos.call(fam["filhos"])
		filhos.sort_custom(func(a, b): return Estado.idade(u, a) > Estado.idade(u, b))
		var adultos := filhos.filter(func(f): return Estado.idade(u, f) >= 16 or Estado.idade(u, f) < 0)
		if not adultos.is_empty():
			return adultos[0]
		if not filhos.is_empty():
			return filhos[0]  # criança no trono (com regente, na história)
		var conj: Array = vivos.call(fam["conjuges"])
		if not conj.is_empty():
			return conj[0]
	var candidatos: Array = vivos.call(conselho(u, sid))
	if candidatos.is_empty():
		candidatos = vivos.call(membros(u, sid))
	if candidatos.is_empty():
		return ""
	match modo:
		"eleicao":
			candidatos.sort_custom(func(a, b): return Reputacao.opiniao(u, sid, a) + Personalidade.tracos(u, a)["sociabilidade"] * 0.3 > Reputacao.opiniao(u, sid, b) + Personalidade.tracos(u, b)["sociabilidade"] * 0.3)
		"fe":
			candidatos.sort_custom(func(a, b): return Personalidade.tracos(u, a)["lealdade"] + Personalidade.tracos(u, a)["prudencia"] > Personalidade.tracos(u, b)["lealdade"] + Personalidade.tracos(u, b)["prudencia"])
		"calculo":
			candidatos.sort_custom(func(a, b): return Personalidade.tracos(u, a)["prudencia"] + Personalidade.tracos(u, a)["curiosidade"] > Personalidade.tracos(u, b)["prudencia"] + Personalidade.tracos(u, b)["curiosidade"])
		_:
			candidatos.sort_custom(func(a, b): return _peso_politico(u, a) > _peso_politico(u, b))
	return candidatos[0]


static func _fato(u: Universo, sid: String, tipo_f: String, texto: String, imp: float, causas: Array, ops: Array, sujeitos: Array = [], lugar: String = "") -> String:
	var cs: Array = causas.filter(func(c): return c != "" and u.fatos.existe(c))
	if cs.is_empty():
		var fc: String = u.entidade(sid).get("fato_criacao", "")
		if u.fatos.existe(fc):
			cs = [fc]
	return Simulador.registrar(u, {
		"tipo": tipo_f, "descricao": texto, "sujeitos": [sid] + sujeitos.filter(func(x): return x != "" and x != sid),
		"lugar": lugar, "causas": cs, "dados": {"importancia": imp, "sociedade": sid, "mudancas": ops},
	})


static func _n(u: Universo, eid: String) -> String:
	return u.entidade(eid).get("nome", "?")


# ---------------------------------------------------------------- o passo da política

static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for sid in todas(u):
		sincronizar_leis(u, sid)
		var t := tipo(u, sid)
		var l := lider(u, sid)
		# 1) O governante morreu, sumiu ou nunca houve um: sucessão.
		if l == "" or not u.entidades.has(l) or not Estado.vivo(u, l) or u.entidade(l)["removida"]:
			if t == "anarquia":
				continue
			if l == "" and u.estado(sid).get("sem_governante", false):
				continue
			var novo := sucessor(u, sid, l)
			var causa := _fato_da_morte(u, l)
			if novo == "":
				if not u.estado(sid).get("sem_governante", false):
					novos.append(_fato(u, sid, "crise de sucessão", "%s ficou sem governante." % _n(u, sid), 0.7, [causa],
						[{"op": "definir", "quem": sid, "chave": "sem_governante", "valor": true}]))
				continue
			var texto := "%s passou a governar %s." % [_n(u, novo), _n(u, sid)]
			if l != "":
				texto = "%s sucedeu %s como governante de %s." % [_n(u, novo), _n(u, l), _n(u, sid)]
			novos.append(_fato(u, sid, "sucessão", texto, 0.75 if l != "" else 0.4, [causa],
				[{"op": "definir", "quem": sid, "chave": "lider", "valor": novo},
				 {"op": "definir", "quem": sid, "chave": "sem_governante", "valor": false},
				 {"op": "mudar", "quem": novo, "chave": "reputacao", "delta": 0.5}], [novo, l]))
			continue
		# 2) Golpe: alguém do conselho, pouco leal e ambicioso, tenta tomar o poder.
		if t in ["colmeia", "maquina"] or rng.randf() > dias / 30.0:
			continue
		for c in conselho(u, sid):
			if c == l:
				continue
			var lea := lealdade(u, c, l)
			var amb := float(Personalidade.tracos(u, c)["ambicao"])
			if lea < 0.25 and amb > 0.6 and rng.randf() < 0.04 * (1.0 - lea) * amb:
				novos.append_array(golpe(u, sid, c, l, rng))
				break
	return novos


static func _fato_da_morte(u: Universo, eid: String) -> String:
	if eid == "" or not u.entidades.has(eid):
		return ""
	var m: Dictionary = u.estado(eid).get("morte", {})
	return str(m.get("fato", ""))


## Alguém tenta tomar o poder. A força dele contra a do governante e de quem é leal.
static func golpe(u: Universo, sid: String, quem: String, l: String, rng: RandomNumberGenerator) -> Array:
	var apoio := 0.0
	var defesa := Estado.poder(u, l) * 0.5 + 0.5
	for c in conselho(u, sid):
		if c == quem or c == l:
			continue
		if lealdade(u, c, l) < 0.4:
			apoio += Estado.poder(u, c) * 0.3 + 0.3
		else:
			defesa += Estado.poder(u, c) * 0.3 + 0.3
	var forca := Estado.poder(u, quem) * 0.5 + 0.5 + apoio
	var chance := forca / (forca + defesa * float(REPRESSAO.get(tipo(u, sid), 1.0)))
	var tentativa := _fato(u, sid, "golpe", "%s tentou tomar o poder de %s em %s." % [_n(u, quem), _n(u, l), _n(u, sid)], 0.85,
		[Simulador.causa_de_presenca(u, quem)], [{"op": "relacao", "de": l, "para": quem, "deltas": {"raiva": 0.7, "confianca": -0.8}}], [quem, l])
	var ids: Array = [tentativa]
	if rng.randf() < chance:
		var morre := rng.randf() < 0.4
		var ops: Array = [{"op": "definir", "quem": sid, "chave": "lider", "valor": quem}]
		if morre:
			ops.append({"op": "morrer", "quem": l})
		else:
			ops.append({"op": "marca", "quem": l, "marca": "deposto"})
		ids.append(_fato(u, sid, "golpe vitorioso", "%s derrubou %s%s e passou a governar %s." % [_n(u, quem), _n(u, l), " e o matou" if morre else "", _n(u, sid)],
			0.95, [tentativa], ops, [quem, l]))
	else:
		var morre2 := rng.randf() < 0.5
		ids.append(_fato(u, sid, "golpe fracassado", "O golpe de %s falhou; %s %s." % [_n(u, quem), _n(u, quem), "foi executado" if morre2 else "fugiu e virou traidor"],
			0.85, [tentativa], [{"op": "morrer", "quem": quem}] if morre2 else [{"op": "marca", "quem": quem, "marca": "traidor"}], [quem, l]))
	return ids.filter(func(x): return x != "")


## Uma revolta num lugar contra a sociedade que manda ali. Chamada pelo Humor.
static func revolta(u: Universo, sid: String, lugar: String, causa: String, raiva: float, rng: RandomNumberGenerator) -> Dictionary:
	var t := tipo(u, sid) if sid != "" else "anarquia"
	var l := lider(u, sid) if sid != "" else ""
	# Quem lidera a revolta: alguém do lugar, corajoso e com raiva, que não é o governante.
	var gente := Natureza._mentes_em(u, lugar).filter(func(m): return m != l)
	gente.sort_custom(func(a, b): return _vontade_de_revoltar(u, a, l) > _vontade_de_revoltar(u, b, l))
	var cabeca: String = gente[0] if not gente.is_empty() else ""
	var pop := float(Natureza.de(u, lugar)["pop"]) if Natureza.tem_natureza(u, lugar) else 500.0
	var forca_rebelde := raiva * pow(maxf(pop, 50.0) / 1000.0, 0.3) * (1.0 + (float(Personalidade.tracos(u, cabeca)["coragem"]) if cabeca != "" else 0.3))
	var riqueza := Economia.riqueza(u, sid) if sid != "" else 0.0
	var lea := 0.0
	var cons := conselho(u, sid) if sid != "" else []
	for c in cons:
		lea += lealdade(u, c, l)
	lea = lea / cons.size() if not cons.is_empty() else 0.4
	var forca_gov := (0.4 + lea) * (1.0 + log(1.0 + maxf(riqueza, 0.0)) * 0.3) * float(REPRESSAO.get(t, 1.0)) * (0.6 if l == "" else 1.0)
	var chance := forca_rebelde / (forca_rebelde + forca_gov)
	var nome_l := _n(u, lugar)
	var inicio := _fato(u, sid if sid != "" else lugar, "revolta", "O povo de %s se revoltou%s%s." % [nome_l, (" contra " + _n(u, l)) if l != "" else "", (", liderado por " + _n(u, cabeca)) if cabeca != "" else ""],
		0.9, [causa], [], [cabeca, l], lugar)
	var ids: Array = [inicio]
	var venceu := rng.randf() < chance
	if venceu:
		var ops: Array = []
		var texto := ""
		if sid == "":
			texto = "A revolta tomou %s." % nome_l
		else:
			var novo_tipo := t
			if cabeca != "":
				var tc := Personalidade.tracos(u, cabeca)
				if t == "monarquia" and float(tc["empatia"]) + float(tc["sociabilidade"]) > 1.1 and rng.randf() < 0.5:
					novo_tipo = "republica"
				elif t == "republica" and float(tc["ambicao"]) > 0.7 and rng.randf() < 0.4:
					novo_tipo = "monarquia"
				ops.append({"op": "definir", "quem": sid, "chave": "lider", "valor": cabeca})
				ops.append({"op": "definir", "quem": sid, "chave": "sem_governante", "valor": false})
				ops.append({"op": "mudar", "quem": cabeca, "chave": "reputacao", "delta": 1.0})
			else:
				ops.append({"op": "definir", "quem": sid, "chave": "sem_governante", "valor": true})
			if novo_tipo != t:
				ops.append({"op": "definir", "quem": sid, "chave": "tipo_governo", "valor": novo_tipo})
			if l != "":
				ops.append({"op": "marca", "quem": l, "marca": "deposto"})
				if rng.randf() < 0.3:
					ops.append({"op": "morrer", "quem": l})
			texto = "A revolta derrubou o governo de %s%s" % [_n(u, sid), (": %s passou a governar" % _n(u, cabeca)) if cabeca != "" else ""]
			if novo_tipo != t:
				texto += ", e %s virou %s" % [_n(u, sid), NOMES_TIPO.get(novo_tipo, novo_tipo)]
			texto += "."
		ids.append(_fato(u, sid if sid != "" else lugar, "queda do governo", texto, 1.0, [inicio], ops, [cabeca, l], lugar))
	else:
		var ops2: Array = []
		if cabeca != "":
			if rng.randf() < 0.4:
				ops2.append({"op": "morrer", "quem": cabeca})
			else:
				ops2.append({"op": "ferir", "quem": cabeca, "descricao": "ferido na revolta", "gravidade": 0.35})
				ops2.append({"op": "marca", "quem": cabeca, "marca": "rebelde"})
		for m in Natureza._mentes_em(u, lugar):
			ops2.append({"op": "emocao", "quem": m, "emocao": "medo", "forca": 0.5, "alvo": l})
		ids.append(_fato(u, sid if sid != "" else lugar, "revolta esmagada", "A revolta em %s foi esmagada%s." % [nome_l, (" por " + _n(u, l)) if l != "" else ""],
			0.85, [inicio], ops2, [cabeca, l], lugar))
	return {"fatos": ids.filter(func(x): return x != ""), "venceu": venceu}


static func _vontade_de_revoltar(u: Universo, eid: String, l: String) -> float:
	var t := Personalidade.tracos(u, eid)
	return float(t["coragem"]) + float(t["ambicao"]) * 0.6 + Estado.valor_relacao(u, eid, l, "raiva") + float(t["impulsividade"]) * 0.3


# ---------------------------------------------------------------- leis da sociedade

## As leis escritas na ficha da sociedade viram leis do universo que só valem no território.
## Algumas frases têm sentido próprio: "magia é proibida", "impostos altos".
static func sincronizar_leis(u: Universo, sid: String) -> void:
	var txt := _campo(u, sid, ["leis", "lei"])
	var feitas: Dictionary = u.estado(sid).get("leis_feitas", {})
	if txt == "":
		return
	for frase in txt.replace(";", ".").split(".", false):
		var f := frase.strip_edges()
		if f == "" or feitas.has(f):
			continue
		var n := TextUtil.normalizar(f)
		var texto := f
		var rx := RegEx.new()
		rx.compile("(magia|feiticaria|bruxaria|necromancia|[a-z ]+) (?:e |esta |sao )?(?:proibid|crime|banid|ilegal)")
		var m := rx.search(n)
		if m != null and not n.contains("impost"):
			var oque := m.get_string(1).strip_edges()
			var gatilho := "usa magia" if oque in ["magia", "feiticaria", "bruxaria"] else ("usa " + oque)
			texto = "Quem %s em %s é perseguido e vira fugitivo" % [gatilho, _n(u, sid)]
		var r := Regras.criar(u, texto)
		if not r.is_empty():
			# A lei só vale dentro do território da sociedade.
			if m != null and not n.contains("impost"):
				r["efeitos"] = [{"peca": "marca", "marca": "fugitivo", "alvo": "sujeito", "texto": "vira fugitivo"},
					{"peca": "emocao", "emocao": "medo", "forca": 0.5, "alvo": "sujeito", "texto": "sente medo"}]
				r["entendida"] = "toda"
				r["avisos"] = []
			for lugar in territorio(u, sid).slice(0, 1):
				r["se"].append({"tipo": "em", "lugar": lugar})
			r["sociedade"] = sid
		feitas[f] = r.get("id", "")
	u.estado(sid)["leis_feitas"] = feitas


static func imposto(u: Universo, sid: String) -> float:
	var t := TextUtil.normalizar(_campo(u, sid, ["impost", "tribut"]) + " " + _campo(u, sid, ["leis", "lei"]))
	if t.contains("sem impost") or t.contains("nenhum impost") or t.contains("isent"):
		return 0.0
	if t.contains("altos") or t.contains("pesad") or t.contains("abusiv") or t.contains("alto"):
		return 0.15
	if t.contains("baixo") or t.contains("leve"):
		return 0.03
	return 0.07


## Governantes ao longo do tempo (a dinastia), a partir dos fatos.
static func historia_do_governo(u: Universo, sid: String) -> Array:
	var lista: Array = []
	var inicial := ""
	var txt := _campo(u, sid, CAMPOS_LIDER)
	if txt != "":
		var ps := pessoas_no_texto(u, txt)
		if not ps.is_empty():
			inicial = ps[0]
	if inicial != "":
		lista.append({"quem": inicial, "desde": {}, "como": "na ficha"})
	for f in u.fatos.sobre(sid):
		if not f["canon"]:
			continue
		for op in f["dados"].get("mudancas", []):
			if op.get("op", "") == "definir" and op.get("quem", "") == sid and op.get("chave", "") == "lider":
				lista.append({"quem": op["valor"], "desde": f["data"], "como": f["tipo"], "fato": f["id"]})
	return lista


## Nome da casa (dinastia) de alguém: o sobrenome.
static func casa(u: Universo, eid: String) -> String:
	var partes: PackedStringArray = str(u.entidade(eid).get("nome", "")).split(" ", false)
	return partes[partes.size() - 1] if partes.size() > 1 else ""
