extends Node2D

# Basit oturan panda — Beam'in child'ı, kendi başına fizik nesnesi değil,
# sadece kirişle birlikte döner. Taban (ayakların bastığı çizgi) kendi
# orijininde (y=0) ki Beam üstüne konumlandırması kolay olsun.

var hits := 0

func set_hits(n: int) -> void:
	hits = n
	queue_redraw()
	if n > 0:
		var t := create_tween()
		t.tween_property(self, "rotation", 0.12, 0.05)
		t.tween_property(self, "rotation", -0.12, 0.08)
		t.tween_property(self, "rotation", 0.0, 0.06)

func _draw() -> void:
	var body_col := Color(0.97, 0.96, 0.93)
	var patch_col := Color(0.12, 0.11, 0.10)
	var ink := Color(0.08, 0.07, 0.07)

	# gövde (oturur, taban basık)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, -16), Vector2(-30, -40), Vector2(-14, -52), Vector2(14, -52),
		Vector2(30, -40), Vector2(34, -16), Vector2(24, 0), Vector2(-24, 0)
	]), body_col)

	# kulaklar
	draw_circle(Vector2(-24, -50), 11, patch_col)
	draw_circle(Vector2(24, -50), 11, patch_col)

	# göz yamaları (panda deseni)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, -32), Vector2(-8, -34), Vector2(-8, -20), Vector2(-24, -18)
	]), patch_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -34), Vector2(24, -32), Vector2(24, -18), Vector2(8, -20)
	]), patch_col)

	# göz akı + bebek
	draw_circle(Vector2(-15, -27), 5.0, Color.WHITE)
	draw_circle(Vector2(15, -27), 5.0, Color.WHITE)
	draw_circle(Vector2(-14, -26), 2.4, ink)
	draw_circle(Vector2(16, -26), 2.4, ink)

	# burun
	draw_circle(Vector2(0, -14), 3.5, ink)

	# vuruş: yanaklar kızarır, üstte kırmızı şişlik çıkar
	if hits > 0:
		draw_circle(Vector2(-27, -21), 6.0, Color(1, 0.35, 0.35, 0.55))
		draw_circle(Vector2(27, -21), 6.0, Color(1, 0.35, 0.35, 0.55))
		draw_circle(Vector2(8, -53), 9.0, Color(0.86, 0.22, 0.2))
		draw_circle(Vector2(5, -56), 3.0, Color(1, 0.7, 0.65, 0.8))
