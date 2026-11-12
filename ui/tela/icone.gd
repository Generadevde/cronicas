class_name Icone
extends Control
## Ícones de traço, desenhados em código (numa grade 24×24), na cor da tinta do tema.

const TRACOS := {
	"universo": [[4, 5, 6, 3, 19, 3, 19, 19, 6, 19, 4, 21, 4, 5], [9, 7, 15, 7], [9, 11, 15, 11]],
	"mapa": [[3, 6, 9, 4, 15, 6, 21, 4, 21, 18, 15, 20, 9, 18, 3, 20, 3, 6], [9, 4, 9, 18], [15, 6, 15, 20]],
	"tempo": [[3, 12, 21, 12], [7, 10, 5, 12, 7, 14, 9, 12, 7, 10], [14, 10, 12, 12, 14, 14, 16, 12, 14, 10], [7, 10, 7, 5], [14, 14, 14, 19]],
	"leis": [[12, 3, 12, 21], [5, 7, 19, 7], [5, 7, 3, 13, 7, 13, 5, 7], [19, 7, 17, 13, 21, 13, 19, 7], [8, 21, 16, 21]],
	"laboratorio": [[5, 19, 19, 5], [15, 5, 19, 5, 19, 9], [5, 5, 19, 19], [5, 9, 5, 5, 9, 5]],
	"perguntar": [[12, 3, 18, 5, 21, 12, 18, 19, 12, 21, 6, 19, 3, 12, 6, 5, 12, 3], [9.5, 9.5, 12, 7.5, 14.5, 9.5, 12, 12.5, 12, 14], [12, 16.5, 12, 17.5]],
	"viver": [[12, 4, 15, 7, 12, 10, 9, 7, 12, 4], [5, 21, 7, 14, 12, 12, 17, 14, 19, 21]],
	"opcoes": [[4, 7, 20, 7], [4, 12, 20, 12], [4, 17, 20, 17], [8, 5, 8, 9], [15, 10, 15, 14], [10, 15, 10, 19]],
	"estante": [[4, 4, 4, 20], [8, 4, 8, 20], [4, 4, 8, 4], [4, 20, 8, 20], [11, 6, 11, 20, 15, 20, 15, 6, 11, 6], [17, 8, 21, 7, 22, 19, 18, 20, 17, 8]],
	"foco": [[4, 9, 4, 4, 9, 4], [15, 4, 20, 4, 20, 9], [20, 15, 20, 20, 15, 20], [9, 20, 4, 20, 4, 15]],
}

var nome := ""
var cor := Color.WHITE


func _init(p_nome: String = "", p_cor: Color = Color.WHITE, lado: float = 26.0) -> void:
	nome = p_nome
	cor = p_cor
	custom_minimum_size = Vector2(lado, lado)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var e := minf(size.x, size.y) / 24.0
	var o := (size - Vector2(24, 24) * e) / 2.0
	for t in TRACOS.get(nome, []):
		var pts := PackedVector2Array()
		for i in range(0, t.size(), 2):
			pts.append(o + Vector2(float(t[i]), float(t[i + 1])) * e)
		draw_polyline(pts, cor, maxf(1.6 * e, 1.2), true)
