class_name ArtUtil

# Prosedürel çizim yardımcıları (panda, kiriş, kütük, zemin, yiyecekler ortak kullanır).

static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, seg: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, rot), col)

# Sivri uçlu, ortası dolgun yaprak.
static func leaf(ci: CanvasItem, base: Vector2, dir: Vector2, length: float, width: float, col: Color) -> void:
	var n := dir.orthogonal()
	var pts := PackedVector2Array()
	const STEPS := 7
	for i in STEPS + 1:
		var t := float(i) / STEPS
		pts.append(base + dir * length * t + n * width * sin(PI * t) * (1.0 - 0.35 * t))
	for i in range(STEPS - 1, 0, -1):
		var t := float(i) / STEPS
		pts.append(base + dir * length * t - n * width * sin(PI * t) * (1.0 - 0.35 * t))
	ci.draw_colored_polygon(pts, col)

static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)

# Kapalı çokgenin dış çizgisi.
static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	ci.draw_polyline(p, col, w, true)
