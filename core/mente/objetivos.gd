class_name Objetivos
extends RefCounted
## Desejos e ambições escritos livremente na ficha viram objetivos que a mente persegue.
## O texto continua sendo o do autor ("tornar-se o maior ferreiro de Varn");
## o programa só adivinha que TIPO de esforço ele pede, para escolher as ações.

const CAMPOS_DE_DESEJO := ["desejo", "desejos", "ambicao", "ambicoes", "objetivo", "objetivos", "sonho", "sonhos", "quer", "meta", "metas"]

## Palavras-pista → que tipo de esforço o objetivo pede.
const CATEGORIAS := {
	"forca": ["forte", "guerreir", "espad", "lut", "general", "campea", "mestre", "derrot", "venc", "poder", "treina", "invencivel", "heroi", "cavaleir", "soldad", "arma"],
	"saber": ["magia", "mago", "sabio", "sabedoria", "estud", "livro", "segredo", "descobr", "ciencia", "alquim", "feitic", "conhec", "invent", "cura", "medic"],
	"riqueza": ["rico", "riqueza", "ouro", "dinheiro", "fortuna", "comerci", "loja", "negocio", "terra", "propriedade", "tesouro"],
	"afeto": ["amor", "amar", "casar", "familia", "filho", "filha", "amigo", "amizade", "proteger", "cuidar", "irma", "irmao", "pai", "mae"],
	"viagem": ["viaj", "explor", "conhecer o mundo", "aventur", "mar", "terras distantes", "fugir"],
	"poder": ["rei", "rainha", "trono", "govern", "lider", "comand", "dominar", "imperador", "conquist", "fama", "respeit", "reconhec"],
}


static func categoria(texto: String) -> String:
	var n := TextUtil.normalizar(texto)
	var melhor := "generico"
	var pontos := 0
	for cat in CATEGORIAS:
		var p := 0
		for pista in CATEGORIAS[cat]:
			if n.contains(pista):
				p += 1
		if p > pontos:
			pontos = p
			melhor = cat
	return melhor


## Lê os desejos da ficha. Devolve [{texto, tipo, alvo}] — "vingar Lucas" vira vingança.
static func da_ficha(u: Universo, eid: String) -> Array:
	var lista: Array = []
	var lig := Ligador.new(u)
	for c in u.entidade(eid).get("campos", []):
		var chave := TextUtil.normalizar(str(c["chave"])).strip_edges()
		if not CAMPOS_DE_DESEJO.any(func(k): return chave == k or chave.begins_with(k)):
			continue
		for parte in str(c["valor"]).split(";"):
			var texto := parte.strip_edges().trim_suffix(".")
			if texto == "":
				continue
			var n := TextUtil.normalizar(texto)
			if n.contains("vinga") or n.contains("vingan"):
				var mencoes := lig.encontrar(texto).filter(func(m): return m["entidade"] != eid)
				if not mencoes.is_empty():
					var x: String = mencoes[0]["entidade"]
					lista.append({"texto": texto, "tipo": "vingança", "alvo": alvo_da_vinganca(u, eid, x)})
					continue
			lista.append({"texto": texto, "tipo": texto, "alvo": ""})
	return lista


## "Vingar Lucas": se Lucas é alguém querido, o alvo é quem fez mal a ele; senão, o próprio Lucas.
static func alvo_da_vinganca(u: Universo, eid: String, x: String) -> String:
	var querido := Estado.familia_proxima(u, eid).has(x) or Estado.valor_relacao(u, eid, x, "afeto") >= 0.3
	if not querido:
		return x
	var fatos := u.fatos.sobre(x)
	fatos.reverse()
	for f in fatos:
		if not f["canon"]:
			continue
		var acao: String = f["dados"].get("acao", "")
		var s: Array = f["sujeitos"]
		if acao in ["vitoria", "morte_por", "ferimento", "traicao"] and s.size() >= 2 and s[1] == x:
			return s[0]
		if acao == "derrota" and s.size() >= 2 and s[0] == x:
			return s[1]
	return x
