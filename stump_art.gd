class_name StumpArt
extends Node2D

# Pivot'un altındaki kütük (yeni tasarım): tabanda toprağa yayılan kökler, soldan
# ışık sağda gölge, dalgalı kabuk çizgileri, üst kesitte halkalar ve yosun, zemine
# düşen yumuşak gölge. Tamamen görsel — dengeyi etkilemez.

const BARK := Color(0.55, 0.37, 0.22)
const BARK_DARK := Color(0.42, 0.27, 0.15)
const BARK_HI := Color(0.66, 0.47, 0.29)
const LINE := Color(0.40, 0.26, 0.14)
const CUT := Color(0.93, 0.76, 0.52)
const RING := Color(0.80, 0.60, 0.38)
const MOSS := Color(0.47, 0.68, 0.32)
const INK := Color(0.28, 0.17, 0.09)

func _draw() -> void:
	# zemine düşen gölge
	ArtUtil.ellipse(self, Vector2(4, 128), 84.0, 11.0, 0.0, Color(0, 0, 0, 0.16))
	var trunk := PackedVector2Array([
		Vector2(-45, 14), Vector2(45, 14), Vector2(42, 60), Vector2(45, 98), Vector2(55, 116),
		Vector2(70, 129), Vector2(46, 127), Vector2(30, 132), Vector2(10, 128), Vector2(-12, 132),
		Vector2(-32, 127), Vector2(-52, 131), Vector2(-68, 128), Vector2(-55, 115), Vector2(-45, 98), Vector2(-42, 60)])
	draw_colored_polygon(trunk, BARK)
	# sağ tarafta gölge, solda ışık şeridi
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, 14), Vector2(45, 14), Vector2(42, 60), Vector2(45, 98), Vector2(55, 116),
		Vector2(70, 129), Vector2(46, 127), Vector2(30, 132), Vector2(24, 100), Vector2(20, 60)]), BARK_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-36, 16), Vector2(-26, 16), Vector2(-25, 60), Vector2(-28, 104), Vector2(-38, 106), Vector2(-34, 60)]), BARK_HI)
	# dalgalı kabuk çizgileri
	for fx in [-0.5, -0.12, 0.26, 0.6]:
		var pts := PackedVector2Array()
		for i in 9:
			var y := 26.0 + i * 11.0
			pts.append(Vector2(45.0 * fx + sin(i * 1.3 + fx * 5.0) * 2.5, y))
		draw_polyline(pts, LINE, 3.0, true)
	ArtUtil.outline(self, trunk, INK, 3.0)
	# üst kesit
	var top := ArtUtil.ellipse_pts(Vector2(0, 14), 45.0, 12.0, 0.0, 32)
	draw_colored_polygon(top, CUT)
	for k in [0.66, 0.36]:
		var ring := ArtUtil.ellipse_pts(Vector2(0, 14), 45.0 * k, 12.0 * k, 0.0, 28)
		ArtUtil.outline(self, ring, RING, 2.2)
	ArtUtil.outline(self, top, INK, 3.0)
	# yosun
	for m in [[Vector2(-38, 16), 9.0, 4.0], [Vector2(-30, 21), 6.0, 3.0], [Vector2(40, 18), 6.0, 3.0]]:
		ArtUtil.ellipse(self, m[0], m[1], m[2], 0.0, MOSS)
