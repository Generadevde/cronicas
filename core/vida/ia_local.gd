class_name IALocal
extends RefCounted
## A IA local: só é carregada quando usada (um programa externo, chamado na hora) e
## só dá voz. O que o personagem sabe, sente e decide vem do banco de fatos; a IA
## recebe esse material e apenas reescreve a fala no jeito dele, sem inventar fatos.
##
## Configuração (em user://config.cfg, seção "ia"):
##   comando = caminho do executável (ex.: llama-cli, do llama.cpp)
##   modelo  = caminho do arquivo do modelo (.gguf)
## Sem isso, as conversas usam respostas montadas a partir de modelos de frase.

const ARQUIVO := "user://config.cfg"


static func config() -> Dictionary:
	var c := ConfigFile.new()
	if c.load(ARQUIVO) != OK:
		return {}
	return {"comando": str(c.get_value("ia", "comando", "")), "modelo": str(c.get_value("ia", "modelo", "")), "ligada": bool(c.get_value("ia", "ligada", true))}


static func salvar_config(comando: String, modelo: String, ligada: bool = true) -> void:
	var c := ConfigFile.new()
	c.load(ARQUIVO)
	c.set_value("ia", "comando", comando)
	c.set_value("ia", "modelo", modelo)
	c.set_value("ia", "ligada", ligada)
	c.save(ARQUIVO)


static func disponivel() -> bool:
	var c := config()
	return not c.is_empty() and c["ligada"] and c["comando"] != "" and FileAccess.file_exists(c["comando"]) and (c["modelo"] == "" or FileAccess.file_exists(c["modelo"]))


## O pedido que vai para a IA: quem é o personagem, o que ele sabe (só isso), o que
## sente por quem pergunta, e o que a fala precisa dizer (ou esconder).
static func montar_pedido(u: Universo, eid: String, pergunta: String, base: String, sabe: Array, tom: String) -> String:
	var e := u.entidade(eid)
	var linhas: Array = []
	linhas.append("Você é %s, personagem de um livro. Responda em português, em primeira pessoa, com no máximo três frases." % e["nome"])
	linhas.append("Seu jeito: %s. Tom desta resposta: %s." % [Personalidade.resumo(Personalidade.tracos(u, eid)), tom])
	linhas.append("Você só sabe isto (não invente nada além):")
	for f in sabe.slice(0, 15):
		linhas.append("- " + str(f))
	linhas.append("Pergunta: \"%s\"" % pergunta)
	linhas.append("O que a sua resposta precisa dizer (reescreva com a sua voz, sem acrescentar fatos): %s" % base)
	return "\n".join(linhas)


## Dá voz a uma fala. Se a IA não estiver configurada (ou falhar), devolve a base.
static func voz(u: Universo, eid: String, pergunta: String, base: String, sabe: Array, tom: String) -> String:
	if not disponivel():
		return base
	var c := config()
	var pedido := montar_pedido(u, eid, pergunta, base, sabe, tom)
	var args: Array = []
	if c["modelo"] != "":
		args.append_array(["-m", c["modelo"]])
	args.append_array(["-n", "120", "--temp", "0.7", "-no-cnv", "-p", pedido])
	var saida: Array = []
	var codigo := OS.execute(c["comando"], PackedStringArray(args), saida, true)
	if codigo != 0 or saida.is_empty():
		return base
	var texto := str(saida[0])
	var i := texto.find(pedido)
	if i >= 0:
		texto = texto.substr(i + pedido.length())
	texto = texto.strip_edges()
	return texto if texto != "" else base
