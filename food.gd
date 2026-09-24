extends RigidBody2D

# Düşen yiyecek. Fizik çarpışma şekli her zaman basit bir daire (kararlılık
# için) — görsel farklı olabilir. main.gd bunu freeze=true olarak spawn eder,
# script ile düz aşağı indirir; LandingTrigger'a girince freeze=false yapar.

enum Kind { APPLE, WATERMELON, PIZZA }

var kind: int = Kind.APPLE
var radius: float = 16.0

func _draw() -> void:
	match kind:
		Kind.APPLE:
			_draw_apple()
		Kind.WATERMELON:
			_draw_watermelon()
		Kind.PIZZA:
			_draw_pizza()

func _draw_apple() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.86, 0.22, 0.21))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.35), radius * 0.28, Color(1, 1, 1, 0.25))
	draw_rect(Rect2(-2, -radius - 6, 4, 8), Color(0.42, 0.28, 0.16))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -radius - 4), Vector2(14, -radius - 10), Vector2(10, -radius + 2)
	]), Color(0.30, 0.62, 0.28))

func _draw_watermelon() -> void:
	var rind := PackedVector2Array([
		Vector2(0, -radius), Vector2(radius * 0.95, radius * 0.7), Vector2(-radius * 0.95, radius * 0.7)
	])
	draw_colored_polygon(rind, Color(0.20, 0.55, 0.24))
	var inner := PackedVector2Array([
		Vector2(0, -radius * 0.72), Vector2(radius * 0.72, radius * 0.62), Vector2(-radius * 0.72, radius * 0.62)
	])
	draw_colored_polygon(inner, Color(0.88, 0.24, 0.28))
	for pt in [Vector2(-8, 4), Vector2(4, 10), Vector2(10, -2), Vector2(-2, 14)]:
		draw_circle(pt, 1.6, Color(0.1, 0.1, 0.08))

func _draw_pizza() -> void:
	var p := PackedVector2Array([
		Vector2(0, -radius), Vector2(radius * 0.95, radius * 0.7), Vector2(-radius * 0.95, radius * 0.7)
	])
	draw_colored_polygon(p, Color(0.93, 0.76, 0.42))
	for pt in [Vector2(-6, -2), Vector2(6, 6), Vector2(0, 14), Vector2(10, -8)]:
		draw_circle(pt, 3.2, Color(0.82, 0.24, 0.2))
