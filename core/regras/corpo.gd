class_name Corpo
extends RefCounted
## Corpo e vida: quanto tempo cada um vive, a força que muda com a idade,
## a morte natural e as cicatrizes. A idade vem do nascimento (ou da ficha) e
## das leis que fazem envelhecer; a expectativa de vida vem da ficha, do povo
## ou de uma lei ("os elfos vivem 700 anos").

const EXPECTATIVA_PADRAO := 70.0
const CAMPOS_POVO := ["povo", "raça", "raca", "espécie", "especie", "linhagem"]


static var _cache: Dictionary = {}


## Anos que alguém costuma viver (guardado enquanto a ficha e as leis não mudam).
static func expectativa(u: Universo, eid: String) -> float:
	var chave := "%s|%s|%d|%d|%d" % [u.id, eid, hash(u.entidade(eid).get("campos", [])), Regras.todas(u).size(), hash(Cosmos.leis(u).get("expectativa", 0))]
	if _cache.has(chave):
		return _cache[chave]
	if _cache.size() > 4000:
		_cache.clear()
	var v := _calcular(u, eid)
	_cache[chave] = v
	return v


static func _calcular(u: Universo, eid: String) -> float:
	var v := _anos_do_campo(u, eid)
	if v > 0:
		return v
	# O povo / a raça / a espécie (uma entidade citada na ficha).
	var lig: Ligador = null
	for c in u.entidade(eid).get("campos", []):
		if TextUtil.normalizar(c["chave"]) in CAMPOS_POVO.map(func(x): return TextUtil.normalizar(x)):
			if lig == null:
				lig = Ligador.new(u)
			for m in lig.encontrar(c["valor"]):
				var vp := _anos_do_campo(u, m["entidade"])
				if vp > 0:
					return vp
	var lei := Regras.expectativa_por_lei(u, eid)
	if lei > 0:
		return lei
	var padrao := float(Cosmos.leis(u).get("expectativa", EXPECTATIVA_PADRAO))
	return padrao


static func _anos_do_campo(u: Universo, eid: String) -> float:
	for campo in ["expectativa de vida", "expectativa", "vive", "longevidade"]:
		var t := u.valor_campo(eid, campo)
		if t != "":
			var n := Combate.ler_numero(t)
			if n > 0:
				return n
	return -1.0


## Quanto a idade pesa na força: cresce até a juventude, cai na velhice.
static func fator_idade(u: Universo, eid: String) -> float:
	var idade := Estado.idade(u, eid)
	if idade < 0:
		return 1.0
	var e := expectativa(u, eid)
	var x := float(idade) / e
	var maturidade := minf(0.25 * e, 18.0 + 0.05 * e)  # povos longevos não demoram séculos para crescer
	if idade < maturidade:
		return lerpf(0.15, 1.0, float(idade) / maturidade)
	if x < 0.6:
		return 1.0
	return lerpf(1.0, 0.45, clampf((x - 0.6) / 0.5, 0.0, 1.0))


## Chance de morrer de velhice num ano.
static func risco_anual(idade: float, e: float) -> float:
	if idade < e * 0.6:
		return 0.0
	return clampf(0.35 * exp((idade - e) / (e * 0.12)), 0.0, 0.7)


## A cada passo: morte natural de quem é velho (vira fato, com o nascimento de causa).
static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for e in u.entidades_ativas():
		var eid: String = e["id"]
		if not Estado.tem_mente(u, eid) or not Estado.vivo(u, eid) or Motor.dormindo(u, eid):
			continue
		var idade_d := Estado.idade_em_dias(u, eid)
		if idade_d < 0:
			continue
		var anos := idade_d / 360.0
		var p := risco_anual(anos, expectativa(u, eid)) * dias / 360.0
		if p <= 0.0 or rng.randf() >= p:
			continue
		var causa := ""
		for f in u.fatos.sobre(eid):
			if f["canon"] and (f["tipo"] == "nascimento" or f["dados"].get("acao", "") == "nascimento"):
				causa = f["id"]
				break
		if causa == "":
			causa = str(e.get("fato_criacao", ""))
		var fid := Simulador.registrar(u, {
			"tipo": "morte natural", "descricao": ("%s morreu de velhice, aos %d anos." if anos >= expectativa(u, eid) * 0.75 else "%s morreu de uma doença, aos %d anos.") % [e["nome"], int(anos)],
			"sujeitos": [eid], "lugar": u.estado(eid)["local"], "causas": [causa] if u.fatos.existe(causa) else [],
			"dados": {"acao": "morte", "importancia": 0.8, "mudancas": [{"op": "morrer", "quem": eid}]},
		})
		if fid != "":
			novos.append(fid)
	return novos


## Ferimentos graves que já sararam viram cicatrizes.
static func cicatrizes(u: Universo, eid: String) -> Array:
	var lista: Array = []
	var agora := DataMundo.ordem(u.relogio)
	for f in u.estado(eid)["ferimentos"]:
		if float(f.get("gravidade", 0)) >= 0.3 and agora - DataMundo.ordem(f.get("data", u.relogio)) > 120:
			lista.append(str(f.get("descricao", "ferimento")))
	return lista
