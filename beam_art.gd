class_name BeamArt
extends Node2D

# Kirişin görseli: kurumuş (sarı-bal rengi) bambu kamış — boğumlar, üstte ışık,
# altta gölge, uçlarda kesik halka, bir boğumdan filizlenen yaprak.
# Yeşil ormandan ayrışsın diye yeşil değil bal rengi. Fizik şekli aynı (560x28).

const BASE := Color(0.93, 0.78, 0.43)
const SHADE := Color(0.78, 0.60, 0.29)
const HI := Color(1.0, 0.94, 0.72)
const NODE := Color(0.72, 0.54, 0.25)
const OUTLINE := Color(0.36, 0.25, 0.12)
const CUT := Color(0.98, 0.90, 0.66)
const LEAF := Color(0.42, 0.70, 0.36)

var length := 560.0
var thick := 28.0

func _draw() -> void:
	var hl := length / 2.0
	var ht := thick / 2.0
	var body := StyleBoxFlat.new()
	body.bg_color = BASE
	body.set_corner_radius_all(int(ht))
	body.set_border_width_all(3)
	body.border_color = OUTLINE
	body.anti_aliasing = true
	draw_style_box(body, Rect2(-hl, -ht, length, thick))
	draw_rect(Rect2(-hl + ht, ht - 10.0, length - thick, 6.0), SHADE)
	draw_rect(Rect2(-hl + ht, -ht + 5.0, length - thick, 4.0), HI)
	# boğumlar (ortada panda oturduğu için orta boğum yok)
	var segs := 7
	for i in range(1, segs):
		var x := -hl + length * i / segs
		if absf(x) < 30.0:
			continue
		draw_rect(Rect2(x - 3.5, -ht + 1.5, 7.0, thick - 3.0), NODE)
		draw_rect(Rect2(x - 1.0, -ht + 2.0, 2.0, thick - 4.0), Color(HI, 0.7))
		draw_rect(Rect2(x - 4.5, -ht - 1.0, 9.0, 3.0), OUTLINE)
		draw_rect(Rect2(x - 4.5, ht - 2.0, 9.0, 3.0), OUTLINE)
	# uçlarda kesik halka
	for s in [-1.0, 1.0]:
		var c := Vector2(s * (hl - 7.0), 0.0)
		ArtUtil.ellipse(self, c, 5.0, ht - 4.0, 0.0, CUT)
		ArtUtil.ellipse(self, c, 2.5, ht - 9.0, 0.0, SHADE)
	# sağdan ikinci boğumdan küçük filiz
	var bx := -hl + length * (segs - 1) / segs
	ArtUtil.leaf(self, Vector2(bx + 2.0, -ht), Vector2(0.55, -0.85).normalized(), 30.0, 6.5, LEAF)
	ArtUtil.leaf(self, Vector2(bx + 2.0, -ht), Vector2(1.0, -0.2).normalized(), 22.0, 5.0, LEAF.darkened(0.12))
