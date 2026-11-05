class_name TextUtil
extends RefCounted
## Utilidades de texto: normalização sem acento, distância entre palavras,
## trechos de contexto. Tudo em português, pensando em nomes inventados.

const _ACENTOS := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i",
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u",
	"ç": "c", "ñ": "n", "ý": "y", "ÿ": "y",
}


## Minúsculas e sem acento, mantendo o MESMO comprimento do texto original
## (cada caractere vira exatamente um caractere). Isso permite usar as posições
## encontradas no texto normalizado direto no texto original.
static func normalizar(texto: String) -> String:
	var minusc := texto.to_lower()
	if minusc.length() != texto.length():
		# Caso raro (letras especiais que mudam de tamanho): troca caractere a caractere.
		minusc = ""
		for i in texto.length():
			var c := texto[i].to_lower()
			minusc += c[0] if c.length() > 0 else texto[i]
	var saida := ""
	for i in minusc.length():
		var c: String = minusc[i]
		saida += _ACENTOS.get(c, c)
	return saida


## Normaliza e junta espaços repetidos (para comparar nomes e consultas).
static func chave(texto: String) -> String:
	var n := normalizar(texto.strip_edges())
	while n.contains("  "):
		n = n.replace("  ", " ")
	return n


static func eh_letra(c: String) -> bool:
	if c.is_empty():
		return false
	var u := c.unicode_at(0)
	if (u >= 48 and u <= 57) or (u >= 65 and u <= 90) or (u >= 97 and u <= 122):
		return true
	return u >= 192 and u != 215 and u != 247


## Divide em palavras (só letras e números).
static func palavras(texto: String) -> PackedStringArray:
	var lista := PackedStringArray()
	var atual := ""
	for i in texto.length():
		var c: String = texto[i]
		if eh_letra(c):
			atual += c
		elif atual != "":
			lista.append(atual)
			atual = ""
	if atual != "":
		lista.append(atual)
	return lista


## Distância de edição (Levenshtein) entre duas palavras.
static func distancia(a: String, b: String) -> int:
	if a == b:
		return 0
	if a.is_empty():
		return b.length()
	if b.is_empty():
		return a.length()
	var anterior := PackedInt32Array()
	anterior.resize(b.length() + 1)
	for j in b.length() + 1:
		anterior[j] = j
	for i in range(1, a.length() + 1):
		var atual := PackedInt32Array()
		atual.resize(b.length() + 1)
		atual[0] = i
		for j in range(1, b.length() + 1):
			var custo := 0 if a[i - 1] == b[j - 1] else 1
			atual[j] = mini(mini(atual[j - 1] + 1, anterior[j] + 1), anterior[j - 1] + custo)
		anterior = atual
	return anterior[b.length()]


## Quantos erros de digitação aceitamos para uma palavra desse tamanho.
static func tolerancia(tamanho: int) -> int:
	if tamanho >= 8:
		return 2
	if tamanho >= 4:
		return 1
	return 0


## Trecho do texto em volta de uma posição, para mostrar em resultados.
static func trecho(texto: String, posicao: int, raio: int = 60) -> String:
	var ini := maxi(0, posicao - raio)
	var fim := mini(texto.length(), posicao + raio)
	var t := texto.substr(ini, fim - ini).replace("\n", " ").strip_edges()
	if ini > 0:
		t = "…" + t
	if fim < texto.length():
		t += "…"
	return t


## Escapa texto para RichTextLabel com BBCode.
static func escapar_bbcode(texto: String) -> String:
	return texto.replace("[", "[lb]")
