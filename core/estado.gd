class_name Estado
extends RefCounted
## Estado de simulação de cada entidade (fica em entidade["sim"]).
## A ficha (campos livres) é o que o autor escreve; o estado é o que o mundo
## acompanha: vivo ou morto, onde está, família, relações, emoções, memórias,
## objetivos e o que a entidade sabe.

const PADRAO := {
	"vivo": true,
	"nascimento": {},
	"morte": {},
	"local": "",
	"saude": 1.0,
	"ferimentos": [],
	"reputacao": 0.0,
	"poder": 0.0,
	"familia": {"pais": [], "filhos": [], "conjuges": [], "mestres": [], "discipulos": []},
	"relacoes": {},
	"emocoes": [],
	"memorias": [],
	"objetivos": [],
	"conhece": {},
	"tracos": {},
	"diario": [],
}

## O que o autor define à mão e sobrevive à reconstrução do estado.
const CHAVES_DO_AUTOR := ["tem_mente", "tracos_autor", "poder_base", "nascimento_autor", "favorito"]

const RELACAO_PADRAO := {"afeto": 0.0, "confianca": 0.0, "respeito": 0.0, "medo": 0.0, "raiva": 0.0}


static func garantir(e: Dictionary) -> Dictionary:
	if not e.has("sim") or not (e["sim"] is Dictionary):
		e["sim"] = {}
	var s: Dictionary = e["sim"]
	for k in PADRAO:
		if not s.has(k):
			s[k] = PADRAO[k].duplicate(true) if (PADRAO[k] is Dictionary or PADRAO[k] is Array) else PADRAO[k]
	for k in PADRAO["familia"]:
		if not s["familia"].has(k):
			s["familia"][k] = []
	return s


## Tem mente própria? Pessoas e entidades conscientes sim; o autor pode mudar na ficha.
static func tem_mente(u: Universo, eid: String) -> bool:
	var e := u.entidade(eid)
	if e.is_empty():
		return false
	var s := garantir(e)
	if s.has("tem_mente"):
		return bool(s["tem_mente"])
	return Sugestoes.categoria(e.get("tipo", "")) in ["pessoa", "entidade"]


static func vivo(u: Universo, eid: String) -> bool:
	return u.estado(eid).get("vivo", true)


static func mudar(u: Universo, eid: String, chave: String, delta: float) -> void:
	if eid == "" or not u.entidades.has(eid):
		return
	var s := u.estado(eid)
	s[chave] = float(s.get(chave, 0.0)) + delta


static func relacao(u: Universo, de: String, para: String, deltas: Dictionary) -> void:
	if de == "" or para == "" or de == para or not u.entidades.has(de) or not u.entidades.has(para):
		return
	var s := u.estado(de)
	if not s["relacoes"].has(para):
		s["relacoes"][para] = RELACAO_PADRAO.duplicate()
	var r: Dictionary = s["relacoes"][para]
	for k in deltas:
		r[k] = clampf(float(r.get(k, 0.0)) + float(deltas[k]), -1.0, 1.0)


static func valor_relacao(u: Universo, de: String, para: String, chave: String) -> float:
	return float(u.estado(de)["relacoes"].get(para, {}).get(chave, 0.0))


static func ferir(u: Universo, eid: String, descricao: String, gravidade: float, fato: Dictionary) -> void:
	if eid == "" or not u.entidades.has(eid):
		return
	var s := u.estado(eid)
	s["ferimentos"].append({"descricao": descricao, "gravidade": gravidade, "fato": fato.get("id", ""),
		"data": DataMundo.copiar(fato.get("data", u.relogio))})
	s["saude"] = clampf(float(s["saude"]) - gravidade, 0.0, 1.0)


static func morrer(u: Universo, eid: String, fato: Dictionary) -> void:
	if eid == "" or not u.entidades.has(eid):
		return
	var s := u.estado(eid)
	s["vivo"] = false
	s["saude"] = 0.0
	s["morte"] = {"data": DataMundo.copiar(fato.get("data", u.relogio)), "fato": fato.get("id", "")}
	for o in s["objetivos"]:
		if o["estado"] == "ativo":
			o["estado"] = "interrompido"


static func mover(u: Universo, eid: String, lugar: String, fato: Dictionary) -> void:
	if eid == "" or lugar == "" or not u.entidades.has(eid) or eid == lugar:
		return
	var s := u.estado(eid)
	s["local"] = lugar
	s["local_desde"] = DataMundo.copiar(fato.get("data", u.relogio))


static func adicionar_vinculo(u: Universo, eid: String, tipo: String, outro: String) -> void:
	if eid == "" or outro == "" or eid == outro or not u.entidades.has(eid):
		return
	var lista: Array = u.estado(eid)["familia"][tipo]
	if not lista.has(outro):
		lista.append(outro)


static func ligar_familia(u: Universo, pai_ou_mae: String, filho: String) -> void:
	adicionar_vinculo(u, pai_ou_mae, "filhos", filho)
	adicionar_vinculo(u, filho, "pais", pai_ou_mae)
	relacao(u, filho, pai_ou_mae, {"afeto": 0.6, "confianca": 0.4})
	relacao(u, pai_ou_mae, filho, {"afeto": 0.7, "confianca": 0.4})


## Pais, filhos, cônjuges e irmãos (filhos dos mesmos pais).
static func familia_proxima(u: Universo, eid: String) -> Array:
	if eid == "" or not u.entidades.has(eid):
		return []
	var f: Dictionary = u.estado(eid)["familia"]
	var lista: Array = []
	for k in ["pais", "filhos", "conjuges"]:
		for x in f[k]:
			if not lista.has(x):
				lista.append(x)
	for p in f["pais"]:
		for irmao in u.estado(p)["familia"]["filhos"]:
			if irmao != eid and not lista.has(irmao):
				lista.append(irmao)
	return lista


static func conhecer(u: Universo, eid: String, fid: String) -> void:
	if eid == "" or not u.entidades.has(eid):
		return
	u.estado(eid)["conhece"][fid] = true


static func conhece(u: Universo, eid: String, fid: String) -> bool:
	return u.estado(eid)["conhece"].has(fid)


## Quem testemunhou passa a conhecer os fatos do mesmo capítulo.
static func conhecer_capitulo(u: Universo, eid: String, fato_testemunho: Dictionary) -> void:
	var cap: String = fato_testemunho["origem"].get("ref", "")
	for f in u.fatos.todos():
		if f["origem"].get("ref", "") == cap and f["origem"].get("tipo", "") == BancoDeFatos.ORIGEM_CAPITULO:
			conhecer(u, eid, f["id"])


## Este personagem testemunhou (no mesmo capítulo) o fato dado?
static func testemunhou_no_capitulo(u: Universo, eid: String, fato: Dictionary) -> bool:
	var cap: String = fato["origem"].get("ref", "")
	for f in u.fatos.sobre(eid):
		if f["dados"].get("acao", "") == "testemunho" and f["origem"].get("ref", "") == cap:
			return true
	for p in u.propostas:
		if p["status"] == "pendente" and p["acao"] == "testemunho" and p["capitulo"] == cap and p["sujeitos"].has(eid):
			return true
	return false


static func emocionar(u: Universo, eid: String, emocao: String, forca: float, alvo: String, fid: String) -> void:
	if eid == "" or emocao == "" or not u.entidades.has(eid):
		return
	var lista: Array = u.estado(eid)["emocoes"]
	for e in lista:
		if e["emocao"] == emocao and e["alvo"] == alvo:
			e["forca"] = clampf(maxf(float(e["forca"]), forca) + 0.1, 0.0, 1.0)
			e["fato"] = fid
			return
	lista.append({"emocao": emocao, "forca": clampf(forca, 0.0, 1.0), "alvo": alvo, "fato": fid,
		"desde": DataMundo.copiar(u.relogio)})


static func lembrar(u: Universo, eid: String, fid: String, peso: float) -> void:
	if eid == "" or not u.entidades.has(eid):
		return
	var lista: Array = u.estado(eid)["memorias"]
	for m in lista:
		if m["fato"] == fid:
			m["peso"] = maxf(float(m["peso"]), peso)
			return
	lista.append({"fato": fid, "peso": peso})
	conhecer(u, eid, fid)


## Objetivos nascem de emoções fortes ou do autor. 'tipo' é texto livre.
static func adicionar_objetivo(u: Universo, eid: String, tipo: String, alvo: String, forca: float, fid: String) -> Dictionary:
	if eid == "" or not u.entidades.has(eid):
		return {}
	var lista: Array = u.estado(eid)["objetivos"]
	for o in lista:
		if o["tipo"] == tipo and o["alvo"] == alvo and o["estado"] == "ativo":
			o["forca"] = maxf(float(o["forca"]), forca)
			return o
	var o := {"id": Ids.novo("obj"), "tipo": tipo, "alvo": alvo, "forca": forca, "fato": fid,
		"progresso": 0.0, "estado": "ativo", "passo": 0, "desde": DataMundo.copiar(u.relogio)}
	lista.append(o)
	return o


static func esfriar(u: Universo, eid: String, emocao: String, alvo: String, quanto: float) -> void:
	if not u.entidades.has(eid):
		return
	var lista: Array = u.estado(eid)["emocoes"]
	for e in lista.duplicate():
		if (emocao == "" or e["emocao"] == emocao) and (alvo == "" or e["alvo"] == alvo):
			e["forca"] = float(e["forca"]) - quanto
			if e["forca"] <= 0.05:
				lista.erase(e)


## Muda o estado de um objetivo: concluido, abandonado, interrompido, ou avança o passo/progresso.
static func mudar_objetivo(u: Universo, eid: String, tipo: String, alvo: String, op: Dictionary) -> void:
	if not u.entidades.has(eid):
		return
	for o in u.estado(eid)["objetivos"]:
		if o["tipo"] == tipo and o["alvo"] == alvo and o["estado"] == "ativo":
			if op.has("estado"):
				o["estado"] = str(op["estado"])
			if op.has("passo"):
				o["passo"] = int(op["passo"])
			if op.has("progresso"):
				o["progresso"] = clampf(float(o["progresso"]) + float(op["progresso"]), 0.0, 1.0)
			if op.has("forca"):
				o["forca"] = clampf(float(op["forca"]), 0.0, 1.0)
			return


## Traços de personalidade vão de 0 a 1 e mudam devagar com a vida.
static func ajustar_traco(u: Universo, eid: String, traco: String, delta: float) -> void:
	if not u.entidades.has(eid) or traco == "":
		return
	var t: Dictionary = u.estado(eid)["tracos"]
	t[traco] = clampf(float(t.get(traco, 0.5)) + delta, 0.0, 1.0)


static func anotar(u: Universo, eid: String, texto: String, fato: Dictionary) -> void:
	if not u.entidades.has(eid) or texto == "":
		return
	var d: Array = u.estado(eid)["diario"]
	d.append({"data": DataMundo.copiar(fato.get("data", u.relogio)), "texto": texto, "fato": fato.get("id", "")})
	while d.size() > 200:
		d.pop_front()


static func objetivos_ativos(u: Universo, eid: String) -> Array:
	return u.estado(eid)["objetivos"].filter(func(o): return o["estado"] == "ativo")


## Força de uma emoção HOJE: emoções esfriam com o tempo, mais devagar em quem é rancoroso.
## (Calculado na hora a partir da data em que surgiu: não precisa virar fato a cada dia.)
static func forca_emocao(u: Universo, eid: String, e: Dictionary) -> float:
	var dias := DataMundo.ordem(u.relogio) - DataMundo.ordem(e.get("desde", u.relogio))
	if dias <= 0:
		return float(e["forca"])
	var rancor: float = float(Personalidade.tracos(u, eid).get("rancor", 0.5))
	var meia_vida := 45.0 + rancor * 700.0
	if e["emocao"] in ["luto"]:
		meia_vida = 200.0
	elif e["emocao"] in ["amor", "gratidao"]:
		meia_vida = 900.0
	return float(e["forca"]) * pow(0.5, float(dias) / meia_vida)


## Emoções que ainda pesam (força atual >= 0.08), da mais forte para a mais fraca.
static func emocoes_atuais(u: Universo, eid: String) -> Array:
	var lista: Array = []
	for e in u.estado(eid)["emocoes"]:
		var f := forca_emocao(u, eid, e)
		if f >= 0.08:
			var c: Dictionary = e.duplicate()
			c["forca_atual"] = f
			lista.append(c)
	lista.sort_custom(func(a, b): return a["forca_atual"] > b["forca_atual"])
	return lista


static func emocao_por(u: Universo, eid: String, alvo: String, emocoes: Array) -> float:
	var maior := 0.0
	for e in emocoes_atuais(u, eid):
		if e["alvo"] == alvo and e["emocao"] in emocoes:
			maior = maxf(maior, float(e["forca_atual"]))
	return maior


## Saúde hoje: ferimentos saram com o tempo (uns 100 dias para sarar do zero).
static func saude_atual(u: Universo, eid: String) -> float:
	var s := u.estado(eid)
	if not s["vivo"]:
		return 0.0
	var saude: float = float(s["saude"])
	if s["ferimentos"].is_empty():
		return saude
	var ultimo: Dictionary = s["ferimentos"].back()
	var dias := DataMundo.ordem(u.relogio) - DataMundo.ordem(ultimo.get("data", u.relogio))
	return clampf(saude + maxf(0, dias) * 0.01, 0.0, 1.0)


## Idade em anos, se a data de nascimento for conhecida (-1 se não).
static func idade(u: Universo, eid: String) -> int:
	var n: Dictionary = u.estado(eid)["nascimento"]
	if n.is_empty():
		return -1
	return int((DataMundo.ordem(u.relogio) - DataMundo.ordem(n)) / DataMundo.DIAS_POR_ANO)


## Poder atual (escala livre do universo): base escrita na ficha + o que treinou.
static func poder(u: Universo, eid: String) -> float:
	var s := u.estado(eid)
	return maxf(0.01, float(s.get("poder_base", Combate.poder_da_ficha(u, eid))) + float(s["poder"]))
