class_name BambooBackdrop
extends Node2D

# Oyunun arkasındaki dünya: gökyüzü geçişi, güneş parıltısı, uzakta soluk bambular,
# arkada tepe, kenarlarda yakın (koyu) bambular, önde çimenli zemin — kütük bunun
# üstüne oturur. Ortadaki sütun (yiyeceklerin düştüğü alan) sade tutulur, renkler
# yiyeceklerden hep soluk: hiçbir yiyecek zeminde kaybolmasın.

const GROUND_TOP := 1062.0   # zeminin ortadaki yüksekliği (kütük tabanı ~1080)
const OVERDRAW := 400.0      # oyun kamerası yaklaşınca ekran dışı da görünebilir: o kadar taşırarak çiz

const MOODS := {
	"day": {
		"sky": [Color(0.58, 0.82, 0.95), Color(0.78, 0.92, 0.93), Color(0.90, 0.97, 0.86)],
		"sun": Color(1.0, 0.99, 0.88, 0.75), "sun_pos": Vector2(590, 150), "sun_r": 330.0,
		"far": Color(0.68, 0.85, 0.76), "far_node": Color(0.60, 0.79, 0.69), "far_leaf": Color(0.64, 0.83, 0.70),
		"hill": Color(0.70, 0.86, 0.60),
		"mid": Color(0.44, 0.69, 0.44), "mid_node": Color(0.34, 0.57, 0.35), "mid_leaf": Color(0.38, 0.64, 0.38),
		"ground": Color(0.53, 0.77, 0.37), "ground_hi": Color(0.68, 0.87, 0.47), "ground_dark": Color(0.44, 0.67, 0.30),
		"flowers": [Color(1, 1, 1), Color(1.0, 0.86, 0.36), Color(1.0, 0.66, 0.74)],
		"blanket": false,
	},
	"sunset": {
		"sky": [Color(0.55, 0.47, 0.74), Color(0.98, 0.66, 0.58), Color(1.0, 0.86, 0.64)],
		"sun": Color(1.0, 0.85, 0.52, 0.85), "sun_pos": Vector2(470, 860), "sun_r": 420.0,
		"far": Color(0.80, 0.56, 0.60), "far_node": Color(0.72, 0.49, 0.54), "far_leaf": Color(0.78, 0.53, 0.58),
		"hill": Color(0.72, 0.56, 0.50),
		"mid": Color(0.42, 0.30, 0.40), "mid_node": Color(0.33, 0.22, 0.31), "mid_leaf": Color(0.38, 0.26, 0.36),
		"ground": Color(0.55, 0.62, 0.33), "ground_hi": Color(0.72, 0.74, 0.42), "ground_dark": Color(0.45, 0.52, 0.27),
		"flowers": [Color(1.0, 0.95, 0.85), Color(1.0, 0.78, 0.40), Color(1.0, 0.62, 0.62)],
		"blanket": true,
	},
}

@export var mood := "day"
var _sky: GradientTexture2D
var _glow: GradientTexture2D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build()

# Tema değişince (menüdeki Themes) gökyüzü/parıltı dokuları yeniden kurulur.
func set_mood(m: String) -> void:
	if not MOODS.has(m):
		return
	mood = m
	_build()
	queue_redraw()

func _build() -> void:
	var m: Dictionary = MOODS[mood]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray(m["sky"])
	_sky = GradientTexture2D.new()
	_sky.gradient = g
	_sky.fill_from = Vector2(0.5, 0.0)
	_sky.fill_to = Vector2(0.5, 1.0)
	_sky.width = 4
	_sky.height = 256
	var sg := Gradient.new()
	var sun: Color = m["sun"]
	sg.colors = PackedColorArray([sun, Color(sun, sun.a * 0.35), Color(sun, 0.0)])
	sg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_glow = GradientTexture2D.new()
	_glow.gradient = sg
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128

# Tepe, kütüğün (pivot x=360) altında zirve yapar — geniş ekranda da kütük tepede kalsın.
func ground_y(x: float) -> float:
	var t := (x - 360.0) / 360.0
	return GROUND_TOP + 34.0 * t * t

func _draw() -> void:
	var m: Dictionary = MOODS[mood]
	var vs := get_viewport_rect().size
	var x0 := -OVERDRAW
	var x1 := vs.x + OVERDRAW
	draw_texture_rect(_sky, Rect2(x0, -OVERDRAW, x1 - x0, vs.y + OVERDRAW), false)
	var r: float = m["sun_r"]
	draw_texture_rect(_glow, Rect2(m["sun_pos"] - Vector2(r, r), Vector2(r, r) * 2.0), false)

	# uzak bambular (soluk; ortada iki tane daha da soluk)
	var far := [[38.0, 16.0, 1], [104.0, 13.0, 2], [168.0, 15.0, 3], [548.0, 15.0, 4], [612.0, 13.0, 5], [684.0, 17.0, 6]]
	for s in far:
		_stalk(s[0], s[1], m["far"], m["far_node"], m["far_leaf"], 34.0, s[2], 1.0 if s[0] < 360 else -1.0)
	for s in [[292.0, 11.0, 7], [436.0, 11.0, 8]]:
		_stalk(s[0], s[1], Color(m["far"], 0.55), Color(m["far_node"], 0.55), Color(m["far_leaf"], 0.55), 28.0, s[2], 1.0)

	# arkadaki tepe
	var hill := PackedVector2Array()
	for i in 41:
		var x := lerpf(x0, x1, i / 40.0)
		hill.append(Vector2(x, 1000.0 + 22.0 * sin(x * 0.011 + 0.8) + 14.0 * sin(x * 0.027)))
	hill.append(Vector2(x1, vs.y))
	hill.append(Vector2(x0, vs.y))
	draw_colored_polygon(hill, m["hill"])

	# yakın bambular (sadece kenarlarda, yaprakları içe uzanır)
	for s in [[-4.0, 30.0, 11, 1.0], [54.0, 24.0, 12, 1.0], [668.0, 24.0, 13, -1.0], [726.0, 30.0, 14, -1.0]]:
		_stalk(s[0], s[1], m["mid"], m["mid_node"], m["mid_leaf"], 56.0, s[2], s[3])

	# zemin: çimenli yamaç, üstte açık kenar
	var gp := PackedVector2Array()
	var rim := PackedVector2Array()
	# (geniş ekranda yamaç kenarlarda ekranın altına inebilir: y'ler ekran içinde
	# tutulur, yoksa çokgen kendini keser ve çizilmez)
	for i in 41:
		var x := lerpf(x0, x1, i / 40.0)
		gp.append(Vector2(x, minf(ground_y(x), vs.y - 1.0)))
		rim.append(Vector2(x, minf(ground_y(x) + 4.0, vs.y - 1.0)))
	gp.append(Vector2(x1, vs.y))
	gp.append(Vector2(x0, vs.y))
	draw_colored_polygon(gp, m["ground"])
	draw_polyline(rim, m["ground_hi"], 8.0, true)
	# alt kısım biraz koyu: derinlik
	for k in 3:
		var band := PackedVector2Array()
		var off := 90.0 + k * 45.0
		for i in 41:
			var x := lerpf(x0, x1, i / 40.0)
			band.append(Vector2(x, minf(ground_y(x) + off, vs.y - 1.0)))
		band.append(Vector2(x1, vs.y))
		band.append(Vector2(x0, vs.y))
		draw_colored_polygon(band, Color(m["ground_dark"], 0.35))

	if m["blanket"]:
		_blanket()

	# çim öbekleri ve çiçekler
	_rng.seed = 77
	for i in 16:
		var x := _rng.randf_range(10.0, vs.x - 10.0)
		if absf(x - vs.x / 2.0) < 70.0:
			continue
		var y := ground_y(x) + _rng.randf_range(10.0, 150.0)
		_tuft(Vector2(x, y), m["ground_dark"] if i % 2 == 0 else m["ground_hi"])
	var flowers: Array = m["flowers"]
	for i in 9:
		var x := _rng.randf_range(20.0, vs.x - 20.0)
		if absf(x - vs.x / 2.0) < 90.0:
			continue
		_flower(Vector2(x, ground_y(x) + _rng.randf_range(18.0, 170.0)), flowers[i % flowers.size()])

func _stalk(x: float, w: float, col: Color, node_col: Color, leaf_col: Color, leaf_len: float, seed: int, inward: float) -> void:
	_rng.seed = seed * 131
	var bottom := ground_y(x) + 10.0
	draw_rect(Rect2(x - w / 2.0, -OVERDRAW, w, bottom + OVERDRAW), col)
	draw_rect(Rect2(x - w / 2.0 + w * 0.2, -OVERDRAW, w * 0.16, bottom + OVERDRAW), Color(1, 1, 1, 0.12 * col.a))
	var y := bottom - _rng.randf_range(70.0, 130.0)
	while y > -OVERDRAW:
		draw_rect(Rect2(x - w / 2.0 - 1.5, y - 2.5, w + 3.0, 5.0), node_col)
		if _rng.randf() < 0.6:
			var side := inward if _rng.randf() < 0.75 else -inward
			for j in 3:
				var dir := Vector2(side, -0.35 + j * 0.42).normalized()
				ArtUtil.leaf(self, Vector2(x + side * w * 0.4, y), dir, leaf_len * _rng.randf_range(0.8, 1.15), leaf_len * 0.17, leaf_col)
		y -= _rng.randf_range(125.0, 175.0)

func _tuft(p: Vector2, col: Color) -> void:
	for a in [-0.45, 0.0, 0.4]:
		var tip := p + Vector2(a * 18.0, -14.0 - absf(a) * -6.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), tip]), col)

func _flower(p: Vector2, col: Color) -> void:
	for i in 5:
		draw_circle(p + Vector2.from_angle(TAU * i / 5.0) * 4.0, 3.2, col)
	draw_circle(p, 2.6, Color(1.0, 0.8, 0.3) if col != Color(1.0, 0.86, 0.36) else Color(0.95, 0.55, 0.2))

# gün batımı: kütüğün altında kareli piknik örtüsü
func _blanket() -> void:
	var tl := Vector2(236, 1070)
	var tr := Vector2(484, 1070)
	var br := Vector2(540, 1138)
	var bl := Vector2(180, 1138)
	var cols := 8
	var rows := 3
	for r in rows:
		for c in cols:
			var u0 := float(c) / cols
			var u1 := float(c + 1) / cols
			var v0 := float(r) / rows
			var v1 := float(r + 1) / rows
			var q := PackedVector2Array([_bl(tl, tr, br, bl, u0, v0), _bl(tl, tr, br, bl, u1, v0),
				_bl(tl, tr, br, bl, u1, v1), _bl(tl, tr, br, bl, u0, v1)])
			draw_colored_polygon(q, Color(0.86, 0.27, 0.27) if (r + c) % 2 == 0 else Color(0.98, 0.94, 0.88))
	ArtUtil.outline(self, PackedVector2Array([tl, tr, br, bl]), Color(0.55, 0.18, 0.18, 0.6), 2.0)

func _bl(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2, u: float, v: float) -> Vector2:
	return tl.lerp(tr, u).lerp(bl.lerp(br, u), v)
