class_name PandaArt
extends Node2D

# Kirişin ortasında oturan panda (yeni tasarım). Orijin = kirişin üst yüzü, pandanın
# oturduğu çizgi. Genişlik ±34 içinde kalır: pandaya çarpma alanı oyunun kuralı,
# görsel onunla dürüst olmalı. Ayaklar kirişin önünden sarkar.
# Çıkartma (sticker) tarzı: tüm siluetin etrafında koyu kontur, yumuşak gölge.

enum Mood { IDLE, WORRIED, HIT, HAPPY }

const INK := Color(0.17, 0.14, 0.16)
const FUR := Color(0.99, 0.98, 0.96)
const FUR_SHADE := Color(0.84, 0.84, 0.87)
const BLACK := Color(0.19, 0.17, 0.20)
const BLACK_HI := Color(0.32, 0.29, 0.33)
const BLUSH := Color(1.0, 0.52, 0.58, 0.5)
const PAD := Color(0.96, 0.72, 0.74)
const OUT := 3.0

var mood := Mood.IDLE
var look := 0.0      # -1 (sol) .. 1 (sağ): gözler bekleyen yiyeceğe bakar
var hits := 0        # pandaya çarpan yiyecek sayısı (yara bandı)
var spin := 0.0      # HIT: başının üstünde dönen yıldızların açısı
var blink := false   # göz kırpma anı (IDLE / WORRIED'da gözler kapalı çizgi)
# takılı aksesuarlar (Accessories.LIST id'leri; "" = boş yuva)
var head_item := ""
var face_item := ""
var neck_item := ""
var mouth_item := ""

func set_outfit(outfit: Dictionary) -> void:
	head_item = outfit.get("head", "")
	face_item = outfit.get("face", "")
	neck_item = outfit.get("neck", "")
	mouth_item = outfit.get("mouth", "")
	queue_redraw()

func _draw() -> void:
	var arms_up := mood == Mood.HAPPY
	var arm_l := Vector2(-31, -52) if arms_up else Vector2(-25, -27)
	var arm_r := Vector2(31, -52) if arms_up else Vector2(25, -27)
	var arm_rot := 0.6 if arms_up else 0.35
	var arm_r_rot := arm_rot if arms_up else -arm_rot

	# 1) tüm parçaların konturu (birleşik siluet)
	for e in [[Vector2(-22, -93), 11.0, 11.0, 0.0], [Vector2(22, -93), 11.0, 11.0, 0.0],
			[Vector2(0, -26), 31.0, 28.0, 0.0], [Vector2(0, -68), 31.0, 30.0, 0.0],
			[arm_l, 9.0, 15.0, -arm_rot if arms_up else arm_rot], [arm_r, 9.0, 15.0, arm_r_rot],
			[Vector2(-15, 5), 11.0, 9.0, 0.0], [Vector2(15, 5), 11.0, 9.0, 0.0]]:
		ArtUtil.ellipse(self, e[0], e[1] + OUT, e[2] + OUT, e[3], INK)

	# 2) kulaklar
	for x in [-22.0, 22.0]:
		ArtUtil.ellipse(self, Vector2(x, -93), 11, 11, 0.0, BLACK)
		ArtUtil.ellipse(self, Vector2(x, -92), 5.5, 5.5, 0.0, BLACK_HI)
	# 3) gövde: gölgeli taban + ışık alan üst-sol
	ArtUtil.ellipse(self, Vector2(0, -26), 31, 28, 0.0, FUR_SHADE)
	ArtUtil.ellipse(self, Vector2(-3, -29), 27, 24, 0.0, FUR)
	# 4) ayaklar (kirişin önünden sarkar) + pati yastıkları
	for x in [-15.0, 15.0]:
		ArtUtil.ellipse(self, Vector2(x, 5), 11, 9, 0.0, BLACK)
		ArtUtil.ellipse(self, Vector2(x, 7), 5.5, 4.0, 0.0, PAD)
	# önlük gövdenin üstünde, kolların ve kafanın altında
	if neck_item != "":
		Accessories.draw(self, neck_item)
	# 5) kollar
	ArtUtil.ellipse(self, arm_l, 9, 15, -arm_rot if arms_up else arm_rot, BLACK)
	ArtUtil.ellipse(self, arm_r, 9, 15, arm_r_rot, BLACK)
	# 6) kafa
	ArtUtil.ellipse(self, Vector2(0, -68), 31, 30, 0.0, FUR_SHADE)
	ArtUtil.ellipse(self, Vector2(-2, -70), 28.5, 27.5, 0.0, FUR)
	# 7) göz yamaları: dışa-aşağı eğik damla (pandayı şirin yapan asıl şey)
	ArtUtil.ellipse(self, Vector2(-12.5, -66), 9.0, 12.5, 0.55, BLACK)
	ArtUtil.ellipse(self, Vector2(12.5, -66), 9.0, 12.5, -0.55, BLACK)
	_eyes()
	# 8) burun, ağız, yanaklar
	ArtUtil.ellipse(self, Vector2(0, -57.5), 4.4, 3.2, 0.0, INK)
	draw_circle(Vector2(-1.2, -58.5), 1.1, Color(1, 1, 1, 0.5))
	_mouth()
	for x in [-21.0, 21.0]:
		ArtUtil.ellipse(self, Vector2(x, -56), 5.5, 3.4, 0.0, BLUSH)
	if mood == Mood.WORRIED:
		# kaşlar içte yukarı + ter damlası
		draw_line(Vector2(-19, -81), Vector2(-8, -85), INK, 2.6, true)
		draw_line(Vector2(19, -81), Vector2(8, -85), INK, 2.6, true)
		var d := Vector2(30, -78)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -9), d + Vector2(4.5, 0), d + Vector2(-4.5, 0)]), Color(0.55, 0.8, 1.0))
		draw_circle(d, 4.5, Color(0.55, 0.8, 1.0))
	if face_item != "":
		Accessories.draw(self, face_item)
	if mouth_item != "":
		Accessories.draw(self, mouth_item, arms_up)
	if hits > 0:
		_bandage()
	if head_item != "":
		Accessories.draw(self, head_item)
	if mood == Mood.HIT:
		for i in 3:
			var a := spin + TAU * i / 3.0
			ArtUtil.star(self, Vector2(0, -106) + Vector2(cos(a) * 28.0, sin(a) * 7.0), 6.5, Color(1.0, 0.84, 0.25))

func _eyes() -> void:
	match mood:
		Mood.HAPPY:
			for x in [-12.0, 12.0]:
				draw_arc(Vector2(x, -66), 5.0, PI * 1.12, PI * 1.88, 10, Color.WHITE, 2.8, true)
		Mood.HIT:
			for x in [-12.0, 12.0]:
				# sersem spiral
				var pts := PackedVector2Array()
				for i in 22:
					var t := i / 21.0
					pts.append(Vector2(x, -67) + Vector2.from_angle(t * TAU * 1.6) * (1.0 + t * 4.5))
				draw_polyline(pts, Color.WHITE, 1.8, true)
		_:
			if blink:
				for x in [-12.0, 12.0]:
					draw_arc(Vector2(x, -69), 5.0, PI * 0.15, PI * 0.85, 8, Color.WHITE, 2.4, true)
				return
			var big := 6.0 if mood == Mood.WORRIED else 5.6
			for x in [-12.0, 12.0]:
				draw_circle(Vector2(x, -68), big, Color.WHITE)
				var p := Vector2(x + look * 1.9, -67.5)
				draw_circle(p, 3.6, INK)
				draw_circle(p + Vector2(-1.3, -1.5), 1.4, Color.WHITE)

func _mouth() -> void:
	match mood:
		Mood.HAPPY:
			var pts := PackedVector2Array()   # yarım daire (uçları zaten kapalı)
			for i in 9:
				pts.append(Vector2(0, -53) + Vector2.from_angle(PI * i / 8.0) * 6.0)
			draw_colored_polygon(pts, INK)
			ArtUtil.ellipse(self, Vector2(0, -49.5), 3.4, 2.0, 0.0, Color(1.0, 0.5, 0.55))
		Mood.WORRIED:
			ArtUtil.ellipse(self, Vector2(0, -50.5), 3.0, 3.6, 0.0, INK)
		Mood.HIT:
			draw_arc(Vector2(0, -48), 4.5, PI * 1.15, PI * 1.85, 10, INK, 2.2, true)   # küçük somurtma
		_:
			draw_arc(Vector2(-2.6, -54), 2.6, 0.1, PI - 0.1, 8, INK, 1.8, true)
			draw_arc(Vector2(2.6, -54), 2.6, 0.1, PI - 0.1, 8, INK, 1.8, true)

# vurulunca kafada çapraz yara bandı
func _bandage() -> void:
	var c := Vector2(10, -91)
	var pts := ArtUtil.ellipse_pts(c, 11.0, 4.5, -0.5, 16)
	draw_colored_polygon(pts, Color(0.98, 0.82, 0.62))
	ArtUtil.outline(self, pts, Color(0.75, 0.55, 0.40), 1.5)
	ArtUtil.ellipse(self, c, 3.5, 3.0, -0.5, Color(0.93, 0.70, 0.52))
