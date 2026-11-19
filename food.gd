class_name Food
extends RigidBody2D

# Düşen yiyecek. Her türün yandan görünen silueti aynı zamanda çarpışma şekli:
# düz olanlar rahat istiflenir, yuvarlaklar gerçekten yuvarlanır. Zorluk,
# hangi yiyeceğin ne sıklıkla geldiğinden doğar (main.gd -> _pick_kind).

# 2026-11-19: elmadan (8) sonra yenilik yoktu → kurabiye (15, kolay), kabak (23, ağır ama oturaklı),
# pasta (35, kolay). Sona eklendi: eski tür numaraları değişmez.
enum Kind { SANDWICH, CHEESE, TOAST, PIZZA, WATERMELON, APPLE, COOKIE, PUMPKIN, CAKE }

const DATA := {
	Kind.SANDWICH:   {"mass": 1.0, "friction": 0.9},
	Kind.CHEESE:     {"mass": 0.8, "friction": 0.85},
	Kind.TOAST:      {"mass": 0.6, "friction": 0.8},
	Kind.PIZZA:      {"mass": 0.7, "friction": 0.8},
	Kind.WATERMELON: {"mass": 1.8, "friction": 0.8},   # en ağır, düz tabanlı yarım
	Kind.APPLE:      {"mass": 0.45, "friction": 0.5},  # yuvarlanır
	Kind.COOKIE:     {"mass": 0.5, "friction": 0.95},  # geniş, ince, çok tutucu: nereye konsa durur
	Kind.PUMPKIN:    {"mass": 1.2, "friction": 0.85},  # ağır (karpuz 1,8, sandviç 1,0), altı düz: iyi oturur
	Kind.CAKE:       {"mass": 0.9, "friction": 0.9},   # altı üstü düz, katlı: üstüne rahat konur
}
const APPLE_RADIUS := 16.0
const OUTLINE := Color(0.30, 0.19, 0.12)

var kind: int = Kind.SANDWICH
var golden := false:             # Panda Yarışı: üstünde altın bambu jetonu taşır
	set(v):
		golden = v
		queue_redraw()
var shape: Shape2D
var half_w := 0.0
var half_h := 0.0
var _poly := PackedVector2Array()

func setup(k: int) -> void:
	kind = k
	mass = DATA[k]["mass"]
	# Hızlı düşen/savrulan parça ince kirişi (28 px) iki fizik adımı arasında
	# "atlayıp" içinden geçebiliyordu (tünelleme) — sürekli çarpışma algılaması.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.friction = DATA[k]["friction"]
	mat.bounce = 0.02
	physics_material_override = mat

	if k == Kind.APPLE:
		# Godot'da yuvarlanma direnci yok; dönüş sönümü olmadan elma kirişin
		# ucuna kadar durmadan yuvarlanıyordu. Hâlâ yuvarlanır ama bir süre sonra durur.
		angular_damp = 3.0
		var c := CircleShape2D.new()
		c.radius = APPLE_RADIUS
		shape = c
		half_w = APPLE_RADIUS
		half_h = APPLE_RADIUS
	else:
		_poly = _polygon_for(k)
		var cps := ConvexPolygonShape2D.new()
		cps.points = _poly
		shape = cps
		for p in _poly:
			half_w = maxf(half_w, absf(p.x))
			half_h = maxf(half_h, absf(p.y))

	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	queue_redraw()

static func _polygon_for(k: int) -> PackedVector2Array:
	match k:
		Kind.SANDWICH:   # köşeleri kırpılmış yassı dikdörtgen, 76x34
			return PackedVector2Array([
				Vector2(-38, -11), Vector2(-35, -17), Vector2(35, -17), Vector2(38, -11),
				Vector2(38, 13), Vector2(35, 17), Vector2(-35, 17), Vector2(-38, 13)])
		Kind.CHEESE:     # peynir kalıbı, 56x32
			return PackedVector2Array([
				Vector2(-28, -13), Vector2(-25, -16), Vector2(25, -16), Vector2(28, -13),
				Vector2(28, 16), Vector2(-28, 16)])
		Kind.TOAST:      # klasik tost dilimi silueti, 56x54 (dışbükey olmalı — fizik motoru şartı)
			return PackedVector2Array([
				Vector2(-24, 27), Vector2(24, 27), Vector2(28, -12), Vector2(22, -24),
				Vector2(10, -27), Vector2(-10, -27), Vector2(-22, -24), Vector2(-28, -12)])
		Kind.PIZZA:      # ucu yukarıda dilim, tabanı düz — üstüne koymak zor
			return PackedVector2Array([Vector2(-32, 20), Vector2(32, 20), Vector2(0, -30)])
		Kind.COOKIE:     # geniş, ince yuvarlak bisküvi (yandan), 64x18
			return PackedVector2Array([
				Vector2(-32, -5), Vector2(-29, -9), Vector2(29, -9), Vector2(32, -5),
				Vector2(32, 5), Vector2(29, 9), Vector2(-29, 9), Vector2(-32, 5)])
		Kind.PUMPKIN:    # basık yuvarlak kabak, altı düz (oturur), 64x42
			var pk := PackedVector2Array()
			for i in 13:                                  # üst yarım: sağdan sola yay
				var a := PI * float(i) / 12.0
				pk.append(Vector2(32.0 * cos(a), -1.0 - 21.0 * sin(a)))
			pk.append_array(PackedVector2Array([Vector2(-29, 12), Vector2(-20, 20), Vector2(20, 20), Vector2(29, 12)]))
			return pk
		Kind.CAKE:       # katlı pasta dilimi (yandan), 56x36
			return PackedVector2Array([
				Vector2(-28, -15), Vector2(-25, -18), Vector2(25, -18), Vector2(28, -15),
				Vector2(28, 18), Vector2(-28, 18)])
		Kind.WATERMELON: # kesik yüzü altta yarım karpuz (kubbe), 68x34
			var pts := PackedVector2Array()
			for i in 11:
				var a := PI * float(i) / 10.0
				pts.append(Vector2(34.0 * cos(a), 17.0 - 34.0 * sin(a)))
			return pts
	return PackedVector2Array()

func _draw() -> void:
	paint(self, kind)
	if golden:
		Race.coin(self, Vector2(half_w * 0.5, -half_h - 6.0), 12.0)

# Yiyeceğin görseli (çıkartma tarzı: koyu kontur, üstte ışık, altta gölge);
# HUD'daki küçük ilerleme simgeleri de bunu kullanır (çağıran draw_set_transform ile ölçekler).
static func paint(ci: CanvasItem, k: int) -> void:
	var pts := _polygon_for(k)
	match k:
		Kind.SANDWICH:
			ci.draw_colored_polygon(pts, Color(0.86, 0.64, 0.34))
			ci.draw_rect(Rect2(-35, -16, 70, 9), Color(0.96, 0.80, 0.52))    # üst ekmek
			ci.draw_rect(Rect2(-31, -15, 50, 2.5), Color(1, 1, 1, 0.45))     # ışık
			for sx in [-20.0, -4.0, 12.0]:
				ci.draw_circle(Vector2(sx, -12), 1.3, Color(1.0, 0.95, 0.8))  # susam
			ci.draw_rect(Rect2(-37, -7, 74, 6), Color(0.47, 0.78, 0.32))     # marul
			for sx in range(-36, 36, 8):
				ci.draw_circle(Vector2(sx + 4, -1.5), 2.2, Color(0.47, 0.78, 0.32))
			ci.draw_rect(Rect2(-35, -1, 70, 5), Color(0.92, 0.30, 0.27))     # domates
			ci.draw_rect(Rect2(-36, 4, 72, 4), Color(1.0, 0.84, 0.32))       # peynir
			ci.draw_rect(Rect2(-35, 8, 70, 8), Color(0.96, 0.80, 0.52))      # alt ekmek
			ci.draw_rect(Rect2(-35, 13, 70, 3), Color(0.80, 0.58, 0.30))     # alt gölge
		Kind.CHEESE:
			ci.draw_colored_polygon(pts, Color(1.0, 0.82, 0.30))
			ci.draw_rect(Rect2(-28, 9, 56, 7), Color(0.95, 0.70, 0.20))      # yan yüz gölgesi
			ci.draw_rect(Rect2(-24, -14, 36, 2.5), Color(1, 1, 1, 0.5))
			for h in [[Vector2(-14, -3), 5.0], [Vector2(8, 4), 6.0], [Vector2(17, -8), 3.5], [Vector2(-4, 10), 3.0]]:
				ci.draw_circle(h[0], h[1], Color(0.90, 0.64, 0.16))
				ci.draw_circle(h[0] + Vector2(-0.8, -0.8), h[1] * 0.55, Color(0.96, 0.74, 0.24))
		Kind.TOAST:
			ci.draw_colored_polygon(pts, Color(0.76, 0.49, 0.23))            # kabuk
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p * 0.8 + Vector2(0, 1))
			ci.draw_colored_polygon(inner, Color(0.98, 0.87, 0.62))
			ci.draw_arc(Vector2(0, -3), 14.0, PI * 1.15, PI * 1.6, 8, Color(1, 1, 1, 0.5), 2.5, true)
			ci.draw_circle(Vector2(6, 6), 2.0, Color(0.9, 0.75, 0.5))
			ci.draw_circle(Vector2(-8, 10), 1.6, Color(0.9, 0.75, 0.5))
		Kind.PIZZA:
			ci.draw_colored_polygon(pts, Color(1.0, 0.82, 0.36))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, 14), Vector2(26, 14), Vector2(0, -24)]), Color(1.0, 0.72, 0.30))
			# kenar hamuru: üçgenin içinde kalan yamuk (dikdörtgen köşelerden taşıyordu)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-26.9, 12), Vector2(26.9, 12), Vector2(32, 20), Vector2(-32, 20)]), Color(0.84, 0.57, 0.28))
			ci.draw_line(Vector2(-25, 13.5), Vector2(25, 13.5), Color(0.95, 0.72, 0.42), 2.5)
			for pt in [Vector2(-10, 4), Vector2(9, 2), Vector2(0, -11)]:
				ci.draw_circle(pt, 5.0, Color(0.85, 0.25, 0.21))             # sucuk
				ci.draw_circle(pt + Vector2(-1.4, -1.4), 1.6, Color(1, 0.6, 0.55))
		Kind.WATERMELON:
			ci.draw_colored_polygon(pts, Color(0.25, 0.62, 0.30))            # kabuk
			for sx in [-22.0, -7.0, 8.0, 23.0]:
				ci.draw_line(Vector2(sx * 0.85, -12.0 + absf(sx) * 0.4), Vector2(sx, 9), Color(0.16, 0.45, 0.20), 4.0, true)
			ci.draw_arc(Vector2(-4, 12), 24.0, PI * 1.2, PI * 1.5, 10, Color(1, 1, 1, 0.35), 3.0, true)
			ci.draw_rect(Rect2(-33, 10, 66, 3), Color(0.95, 0.97, 0.86))      # beyaz iç kabuk
			ci.draw_rect(Rect2(-33, 13, 66, 4), Color(0.95, 0.33, 0.36))      # kesik kırmızı yüz
			for sx in [-18.0, -6.0, 6.0, 18.0]:
				ci.draw_rect(Rect2(sx - 1, 14, 2, 2), Color(0.2, 0.12, 0.1))  # çekirdek
		Kind.COOKIE:
			ci.draw_colored_polygon(pts, Color(0.86, 0.60, 0.32))
			ci.draw_rect(Rect2(-30, -8, 60, 6), Color(0.94, 0.72, 0.42))          # üst yüz
			ci.draw_rect(Rect2(-26, -7.5, 34, 2), Color(1, 1, 1, 0.45))           # ışık
			for ch in [Vector2(-19, -4), Vector2(-6, 1), Vector2(8, -3), Vector2(20, 2), Vector2(-14, 4)]:
				ci.draw_circle(ch, 2.6, Color(0.36, 0.20, 0.12))                      # çikolata parçası
			ci.draw_rect(Rect2(-30, 5, 60, 3), Color(0.72, 0.47, 0.22))           # alt gölge
		Kind.PUMPKIN:
			# beş şişkin dilim: görünen siluet dilimlerin birleşimi (üstü ve yanları dilim dilim kabarık),
			# altı düz kesik; çarpışma şekli dışbükey gövde (pts). Dilim araları koyu oluk, üstte çukur + sap.
			var lobes: Array = []
			for lb in [[-21.0, 10.5, 17.5], [21.0, 10.5, 17.5], [-11.0, 12.0, 20.0], [11.0, 12.0, 20.0], [0.0, 12.5, 21.0]]:
				var lobe := PackedVector2Array()
				for i in 28:
					var a := TAU * float(i) / 28.0
					lobe.append(Vector2(lb[0] + lb[1] * cos(a), 0.8 + lb[2] * sin(a)))
				var cut := Geometry2D.intersect_polygons(lobe, PackedVector2Array([Vector2(-40, -40), Vector2(40, -40), Vector2(40, 20), Vector2(-40, 20)]))
				if not cut.is_empty():
					lobes.append(cut[0])
			var body: PackedVector2Array = lobes[4]             # birleşim ortadan dışa (her dilim öncekine değer)
			for lb in [lobes[2], lobes[3], lobes[0], lobes[1]]:
				var m := Geometry2D.merge_polygons(body, lb)
				if not m.is_empty():
					body = m[0]
			ci.draw_colored_polygon(body, Color(0.84, 0.40, 0.09))
			for lb in lobes:
				ci.draw_colored_polygon(lb, Color(0.97, 0.57, 0.17))
				var edge := PackedVector2Array(lb)
				edge.append(lb[0])
				ci.draw_polyline(edge, Color(0.80, 0.36, 0.07), 1.6, true)
			for hl in [Vector2(-2, -7), Vector2(12, -5), Vector2(-14, -4)]:            # parlaklık
				ci.draw_arc(hl, 6.5, PI * 1.05, PI * 1.5, 6, Color(1.0, 0.82, 0.55, 0.65), 2.4, true)
			for part in Geometry2D.intersect_polygons(PackedVector2Array([Vector2(-34, 15), Vector2(34, 15), Vector2(34, 22), Vector2(-34, 22)]), body):
				ci.draw_colored_polygon(part, Color(0.78, 0.35, 0.07, 0.55))             # alt gölge
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -19), Vector2(0, -21.5), Vector2(6, -19), Vector2(0, -17.5)]), Color(0.70, 0.30, 0.06))  # çukur
			var bo := PackedVector2Array(body)
			bo.append(body[0])
			ci.draw_polyline(bo, OUTLINE, 2.5, true)
			var stem := PackedVector2Array([Vector2(-3.5, -18.5), Vector2(3, -18.5), Vector2(4, -24), Vector2(8.5, -29),
				Vector2(5.5, -32), Vector2(0.5, -27), Vector2(-2.5, -23)])
			ci.draw_colored_polygon(stem, Color(0.56, 0.78, 0.58))
			ci.draw_line(Vector2(0.5, -20), Vector2(4.5, -28), Color(0.42, 0.64, 0.46), 1.6, true)
			var so := PackedVector2Array(stem)
			so.append(stem[0])
			ci.draw_polyline(so, OUTLINE, 2.2, true)
			return                                         # kendi dış çizgisi var (gövde değil siluet)
		Kind.CAKE:
			ci.draw_colored_polygon(pts, Color(0.98, 0.86, 0.60))                # pandispanya
			ci.draw_rect(Rect2(-28, -2, 56, 4), Color(1.0, 0.98, 0.94))           # krema
			ci.draw_rect(Rect2(-28, 2, 56, 3), Color(0.90, 0.30, 0.40))           # reçel
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-28, -15), Vector2(-25, -18), Vector2(25, -18), Vector2(28, -15), Vector2(28, -9), Vector2(-28, -9)]), Color(0.98, 0.62, 0.72))
			ci.draw_rect(Rect2(-24, -17, 30, 2.2), Color(1, 1, 1, 0.5))           # ışık
			for sp in [[Vector2(-18, -13), Color(0.4, 0.7, 1.0)], [Vector2(-6, -12), Color(1.0, 0.9, 0.3)], [Vector2(7, -14), Color(0.5, 0.85, 0.45)], [Vector2(18, -12), Color(1, 1, 1)]]:
				ci.draw_rect(Rect2(sp[0] - Vector2(2.5, 1), Vector2(5, 2)), sp[1])    # şeker serpme
			ci.draw_rect(Rect2(-28, 14, 56, 4), Color(0.86, 0.68, 0.40))          # alt gölge
		Kind.APPLE:
			var r := APPLE_RADIUS
			ci.draw_circle(Vector2.ZERO, r, Color(0.90, 0.24, 0.22))
			ci.draw_circle(Vector2(2, 3), r * 0.8, Color(0.80, 0.17, 0.17))
			ci.draw_circle(Vector2(-1, -1), r * 0.78, Color(0.92, 0.27, 0.24))
			ci.draw_circle(Vector2(-5, -6), r * 0.26, Color(1, 1, 1, 0.55))
			ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, OUTLINE, 2.5, true)
			ci.draw_rect(Rect2(-1.5, -r - 6, 3, 8), Color(0.42, 0.28, 0.16))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(2, -r - 4), Vector2(14, -r - 10), Vector2(10, -r + 2)]), Color(0.36, 0.68, 0.30))
			return
	ArtUtil.outline(ci, pts, OUTLINE, 2.5)
