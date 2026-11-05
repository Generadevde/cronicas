class_name TesteBase
extends RefCounted
## Base simples para testes: asserts que guardam a mensagem de erro.

var erros: Array = []
var arvore: SceneTree


func verdadeiro(cond: bool, msg: String = "esperava verdadeiro") -> void:
	if not cond:
		erros.append(msg)


func falso(cond: bool, msg: String = "esperava falso") -> void:
	if cond:
		erros.append(msg)


func igual(atual, esperado, msg: String = "") -> void:
	if typeof(atual) != typeof(esperado) or atual != esperado:
		erros.append("%s (esperado: %s, veio: %s)" % [msg, str(esperado), str(atual)])


## Chamado depois de cada teste (sobrescreva para limpar arquivos, nós etc.).
func limpar() -> void:
	pass
