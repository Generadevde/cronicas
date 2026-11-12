class_name RealceMundo
extends SyntaxHighlighter
## Pinta com a tinta do mundo as linhas que o mundo escreveu (as do autor ficam na tinta normal).

var u: Universo
var cid := ""


func _get_line_syntax_highlighting(linha: int) -> Dictionary:
	var te := get_text_edit()
	if te == null or u == null or not u.capitulos.has(cid):
		return {}
	var texto := te.get_line(linha)
	if texto.strip_edges() == "":
		return {}
	var lidas: Dictionary = u.capitulos[cid].get("lidas", {})
	var frases := Escrita.frases_prontas(texto + "\n")
	if frases.is_empty():
		return {}
	for f in frases:
		if str(lidas.get(Escrita.chave(f), "")) != "mundo":
			return {}
	return {0: {"color": Tema.TINTA_MUNDO}}
