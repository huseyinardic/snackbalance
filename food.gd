class_name Food
extends RigidBody2D

# Düşen yiyecek. Her türün yandan görünen silueti aynı zamanda çarpışma şekli:
# düz olanlar rahat istiflenir, yuvarlaklar gerçekten yuvarlanır. Zorluk,
# hangi yiyeceğin ne sıklıkla geldiğinden doğar (main.gd -> _pick_kind).

enum Kind { SANDWICH, CHEESE, TOAST, PIZZA, WATERMELON, APPLE }

const DATA := {
	Kind.SANDWICH:   {"mass": 1.0, "friction": 0.9},
	Kind.CHEESE:     {"mass": 0.8, "friction": 0.85},
	Kind.TOAST:      {"mass": 0.6, "friction": 0.8},
	Kind.PIZZA:      {"mass": 0.7, "friction": 0.8},
	Kind.WATERMELON: {"mass": 1.8, "friction": 0.8},   # en ağır, düz tabanlı yarım
	Kind.APPLE:      {"mass": 0.45, "friction": 0.5},  # yuvarlanır
}
const APPLE_RADIUS := 16.0

var kind: int = Kind.SANDWICH
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
		Kind.WATERMELON: # kesik yüzü altta yarım karpuz (kubbe), 68x34
			var pts := PackedVector2Array()
			for i in 11:
				var a := PI * float(i) / 10.0
				pts.append(Vector2(34.0 * cos(a), 17.0 - 34.0 * sin(a)))
			return pts
	return PackedVector2Array()

func _draw() -> void:
	paint(self, kind)

# Yiyeceğin görseli; HUD'daki küçük ilerleme simgeleri de bunu kullanır
# (çağıran draw_set_transform ile ölçekler).
static func paint(ci: CanvasItem, k: int) -> void:
	var pts := _polygon_for(k)
	match k:
		Kind.SANDWICH:
			ci.draw_colored_polygon(pts, Color(0.80, 0.58, 0.30))
			ci.draw_rect(Rect2(-35, -16, 70, 9), Color(0.93, 0.76, 0.48))   # üst ekmek
			ci.draw_rect(Rect2(-37, -7, 74, 6), Color(0.45, 0.75, 0.30))    # marul
			ci.draw_rect(Rect2(-35, -1, 70, 5), Color(0.88, 0.28, 0.25))    # domates
			ci.draw_rect(Rect2(-36, 4, 72, 4), Color(0.98, 0.82, 0.30))     # peynir
			ci.draw_rect(Rect2(-35, 8, 70, 8), Color(0.93, 0.76, 0.48))     # alt ekmek
		Kind.CHEESE:
			ci.draw_colored_polygon(pts, Color(0.98, 0.80, 0.30))
			for h in [[Vector2(-14, -3), 5.0], [Vector2(8, 6), 6.0], [Vector2(15, -8), 3.5], [Vector2(-5, 10), 3.0]]:
				ci.draw_circle(h[0], h[1], Color(0.90, 0.66, 0.18))
		Kind.TOAST:
			ci.draw_colored_polygon(pts, Color(0.72, 0.46, 0.22))           # kabuk
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p * 0.8 + Vector2(0, 1))
			ci.draw_colored_polygon(inner, Color(0.96, 0.84, 0.60))
		Kind.PIZZA:
			ci.draw_colored_polygon(pts, Color(0.98, 0.80, 0.36))
			ci.draw_rect(Rect2(-32, 13, 64, 7), Color(0.80, 0.55, 0.28))      # kenar hamuru
			for pt in [Vector2(-10, 4), Vector2(9, 2), Vector2(0, -12)]:
				ci.draw_circle(pt, 5.0, Color(0.82, 0.24, 0.20))              # sucuk
		Kind.WATERMELON:
			ci.draw_colored_polygon(pts, Color(0.18, 0.50, 0.22))           # kabuk
			for sx in [-18.0, 0.0, 18.0]:
				ci.draw_line(Vector2(sx * 0.9, -14.0 + absf(sx) * 0.45), Vector2(sx, 10), Color(0.12, 0.36, 0.15), 3.0)
			ci.draw_rect(Rect2(-33, 11, 66, 2), Color(0.93, 0.95, 0.85))      # beyaz iç kabuk
			ci.draw_rect(Rect2(-33, 13, 66, 4), Color(0.90, 0.30, 0.32))      # kesik kırmızı yüz
		Kind.APPLE:
			ci.draw_circle(Vector2.ZERO, APPLE_RADIUS, Color(0.86, 0.22, 0.21))
			ci.draw_circle(Vector2(-4.8, -5.6), APPLE_RADIUS * 0.28, Color(1, 1, 1, 0.25))
			ci.draw_rect(Rect2(-2, -APPLE_RADIUS - 6, 4, 8), Color(0.42, 0.28, 0.16))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(2, -APPLE_RADIUS - 4), Vector2(14, -APPLE_RADIUS - 10), Vector2(10, -APPLE_RADIUS + 2)
			]), Color(0.30, 0.62, 0.28))
