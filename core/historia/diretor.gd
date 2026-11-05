class_name Diretor
extends RefCounted
## Diretor de drama e tom do universo. Um mundo realista sozinho pode ser chato ou
## caótico demais; o diretor cuida do ritmo — calmaria, tensão crescente, clímax,
## reconstrução — e o tom decide que tipo de acontecimento tende a vir.
##  ritmo: calmo, equilibrado, intenso
##  tom: sombrio, esperançoso, trágico, épico, misto
## Ele não inventa nada do nada: só deixa os sistemas mais (ou menos) propensos, e,
## depois de anos calmos demais, acende uma faísca num conflito que já existia.

const RITMOS := {"calmo": 0.6, "equilibrado": 1.0, "intenso": 1.6}
const TONS := ["misto", "sombrio", "esperançoso", "trágico", "épico"]
## O que cada tom favorece (multiplica a chance de cada tipo de acontecimento).
const PESOS_DO_TOM := {
	"sombrio": {"epidemia": 1.8, "praga": 1.5, "seca": 1.3, "fartura": 0.6, "guerra": 1.3, "pacto": 1.6, "festa": 0.6},
	"esperançoso": {"epidemia": 0.5, "praga": 0.6, "fartura": 1.8, "guerra": 0.6, "pacto": 0.7, "festa": 1.6},
	"trágico": {"epidemia": 1.3, "guerra": 1.2, "pacto": 1.4, "morte": 1.4},
	"épico": {"guerra": 1.5, "torneio": 1.6, "invencao": 1.5, "fartura": 1.1},
}


static func config(u: Universo) -> Dictionary:
	var d: Dictionary = u.extra("diretor", {})
	if not d.has("ritmo"):
		d["ritmo"] = "equilibrado"
	if not d.has("tom"):
		d["tom"] = "misto"
	return d


static func definir(u: Universo, ritmo: String, tom: String) -> void:
	var d := config(u)
	if RITMOS.has(ritmo):
		d["ritmo"] = ritmo
	if TONS.has(tom):
		d["tom"] = tom
	u.marcar_mudanca()


## A fase de agora, pela importância do que aconteceu nos últimos meses.
static func fase(u: Universo) -> String:
	return Sociedades._lembrar(u, "fase|%d" % (DataMundo.ordem(u.relogio) / 30), func(): return _fase(u))


static func tensao(u: Universo) -> float:
	var agora := DataMundo.ordem(u.relogio)
	var t := 0.0
	var todos := u.fatos.todos()
	for i in range(todos.size() - 1, -1, -1):
		var f: Dictionary = todos[i]
		var idade := agora - DataMundo.ordem(f["data"])
		if idade > 360:
			break
		if not f["canon"] or idade < 0:
			continue
		var imp := float(f["dados"].get("importancia", 0.2))
		if imp >= 0.6:
			t += imp * (1.0 - idade / 360.0)
	return t


static func _fase(u: Universo) -> String:
	var t := tensao(u)
	var g := Guerras.ativas(u).size()
	if g > 0 or t > 8.0:
		return "clímax"
	var ultima_guerra := -99999
	for gid in Guerras.todas(u):
		ultima_guerra = maxi(ultima_guerra, int(Guerras.dados(u, gid).get("fim", -99999)))
	if DataMundo.ordem(u.relogio) - ultima_guerra < 3 * DataMundo.DIAS_POR_ANO:
		return "reconstrução"
	if t > 3.0:
		return "tensão crescente"
	return "calmaria"


## Quanto multiplicar a chance de um tipo de acontecimento (guerra, epidemia, pacto…).
static func fator(u: Universo, tipo: String) -> float:
	var c := config(u)
	var f := float(RITMOS.get(c["ritmo"], 1.0))
	if tipo in ["fartura", "festa"]:
		f = 1.0  # o ritmo não mexe no que é bom
	f *= float(PESOS_DO_TOM.get(c["tom"], {}).get(tipo, 1.0))
	match fase(u):
		"reconstrução":
			if tipo in ["guerra", "epidemia", "pacto"]:
				f *= 0.4
		"calmaria":
			if tipo in ["guerra", "pacto"]:
				f *= 1.4
		"clímax":
			if tipo == "guerra":
				f *= 0.7  # uma guerra por vez já basta
	return f


## Depois de anos calmos demais, uma faísca: um conflito que já existia esquenta.
static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("diretor_ctrl", {"t": -999, "calma_desde": DataMundo.ordem(u.relogio)})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < 90:
		return []
	ctrl["t"] = agora
	if fase(u) != "calmaria":
		ctrl["calma_desde"] = agora
		return []
	var limite: Variant = {"calmo": 12, "equilibrado": 6, "intenso": 3}.get(config(u)["ritmo"], 6) * DataMundo.DIAS_POR_ANO
	if agora - int(ctrl["calma_desde"]) < limite:
		return []
	ctrl["calma_desde"] = agora
	# O fio mais tenso (um ódio, uma rivalidade) ganha um empurrão.
	var melhor := {}
	for f in Fios.todos(u):
		if f["estado"] in ["resolvido", "abandonado"]:
			continue
		if melhor.is_empty() or float(f["forca"]) > float(melhor["forca"]):
			melhor = f
	if melhor.is_empty():
		return []
	var quem: String = melhor["quem"]
	var alvo: String = melhor["alvo"]
	var texto := "Uma faísca: %s ouviu um boato sobre %s, e o velho sentimento voltou com força." % [u.entidade(quem)["nome"], u.entidade(alvo).get("nome", "?") if alvo != "" else "o passado"]
	var ops: Array = [{"op": "objetivo_estado", "quem": quem, "tipo": melhor["tipo_obj"], "alvo": alvo, "forca": minf(1.0, float(melhor["forca"]) + 0.3)}]
	if alvo != "":
		ops.append({"op": "emocao", "quem": quem, "emocao": "raiva" if melhor["tipo"] == "vingança" else "esperanca", "forca": 0.5, "alvo": alvo})
	return [Simulador.registrar(u, {"tipo": "faísca", "descricao": texto, "sujeitos": [quem] + ([alvo] if alvo != "" else []), "causas": [str(melhor.get("fato", ""))],
		"dados": {"importancia": 0.5, "diretor": true, "mudancas": ops}})]
