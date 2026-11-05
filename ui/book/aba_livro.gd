class_name AbaLivro
extends RefCounted
## Base das abas do livro (Escrever, Wiki, Criadores...).
## Cada aba monta o conteúdo da página esquerda e da direita.

var livro         ## a tela do livro (book.gd), que cuida da navegação
var u: Universo


func _init(p_livro) -> void:
	livro = p_livro
	u = p_livro.universo


## Monta as duas páginas. 'dado' é opcional (ex.: o id a abrir direto).
func montar(_esq: VBoxContainer, _dir: VBoxContainer, _dado: String) -> void:
	pass


func rolagem(filho: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filho.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(filho)
	return s


func linha(filhos: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	for f in filhos:
		h.add_child(f)
	return h


func campo(dica: String, texto: String = "") -> LineEdit:
	var l := LineEdit.new()
	l.placeholder_text = dica
	l.text = texto
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
