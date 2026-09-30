class_name Accessories

# Panda aksesuarları: katalog + çizimler. Dört yuva var: "head" (baş), "face"
# (yüz), "neck" (boyun), "mouth" (ağız); her yuvada aynı anda bir parça takılır. Parçalar
# bambuyla (GameData.bamboo) alınır; Golden Crown satılmaz, 7 günlük serinin
# ödülüdür. Çizimler PandaArt'ın kendi koordinatlarında (orijin = oturma çizgisi,
# kafa merkezi (0, -68)) ve onun sticker tarzında: koyu kontur, düz renk, parıltı.
# Oyunda panda küçük — ayrıntı yerine kalın, okunur şekiller.

const LIST := [
	{"id": "sprig", "name": "Bamboo Snack", "slot": "mouth", "price": 80},
	{"id": "bow", "name": "Red Bow", "slot": "head", "price": 150},
	{"id": "bib", "name": "Bib", "slot": "neck", "price": 250},
	{"id": "shades", "name": "Sunglasses", "slot": "face", "price": 350},
	{"id": "cap", "name": "Cap", "slot": "head", "price": 500},
	{"id": "headphones", "name": "Headphones", "slot": "head", "price": 700},
	{"id": "chef", "name": "Chef Hat", "slot": "head", "price": 1000},
	# satın alınamaz: 7 günlük seri ödülü (GameData.claim_daily)
	{"id": "crown", "name": "Golden Crown", "slot": "head", "price": 0, "streak": true},
]
const SLOTS := ["head", "face", "neck", "mouth"]

const INK := Color(0.17, 0.14, 0.16)
const OUT := 2.6

static func get_item(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}

static func is_streak_item(a: Dictionary) -> bool:
	return a.get("streak", false)

# Henüz alınmamış en ucuz parça (kazanma kartındaki "sıradaki hedef"); yoksa {}.
static func next_goal(owned: Array) -> Dictionary:
	var best := {}
	for a in LIST:
		if a["id"] in owned or is_streak_item(a):
			continue
		if best.is_empty() or a["price"] < best["price"]:
			best = a
	return best

# arms_up: panda kollarını kaldırmış (sevinç) — elde tutulan parça o an ağızda kalır.
static func draw(ci: CanvasItem, id: String, arms_up: bool = false) -> void:
	match id:
		"sprig": _sprig_mouth(ci) if arms_up else _sprig_held(ci)
		"bow": _bow(ci)
		"bib": _bib(ci)
		"shades": _shades(ci)
		"cap": _cap(ci)
		"headphones": _headphones(ci)
		"chef": _chef(ci)
		"crown": _crown(ci)

# --- yardımcılar ---

static func _blob(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	ArtUtil.outline(ci, pts, INK, OUT)

static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	ArtUtil.ellipse(ci, c, rx + OUT, ry + OUT, rot, INK)
	ArtUtil.ellipse(ci, c, rx, ry, rot, col)

# Yuvarlak köşeli dikdörtgen noktaları.
static func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(r.size.x - rad, r.size.y - rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for k in 4:
		for i in 5:
			pts.append(cs[k] + Vector2.from_angle(-PI / 2.0 + PI / 2.0 * (k + i / 4.0)) * rad)
	return pts

# --- parçalar ---

static func _lf(ci: CanvasItem, base: Vector2, dir: Vector2, l: float, w: float) -> void:
	ArtUtil.leaf(ci, base - dir * 2.0, dir, l + 4.5, w + 2.4, INK)
	ArtUtil.leaf(ci, base, dir, l, w, Color(0.42, 0.76, 0.30))
	ci.draw_line(base + dir * 3.0, base + dir * l * 0.7, Color(0.62, 0.88, 0.45), 1.4, true)

# Bambu atıştırmalığı: panda = bambu yiyen hayvan, oyunun adındaki "Snack".
# Kol yerinde kalır; çubuk çapraz durur, alt ucu sağ patide, üst ucu ağızda,
# yapraklar ağzın yanından taşar. Yapraklar belirgin — çıplak çubuk sigara gibi okunmasın.
static func _sprig_held(ci: CanvasItem) -> void:
	var bot := Vector2(31, -9)
	var top := Vector2(-6, -52)
	ci.draw_line(bot, top, INK, 11.0, true)
	ci.draw_line(bot, top, Color(0.5, 0.78, 0.32), 6.5, true)
	var n := (top - bot).normalized().orthogonal()
	ci.draw_line(bot + n * 1.6, top + n * 1.6, Color(0.72, 0.92, 0.5), 1.8, true)
	for t in [0.22, 0.55]:
		var p := bot.lerp(top, t)
		ci.draw_line(p - n * 5.5, p + n * 5.5, INK, 4.0, true)
		ci.draw_line(p - n * 4.0, p + n * 4.0, Color(0.3, 0.55, 0.2), 2.2, true)
	_lf(ci, top, Vector2(-0.95, -0.3), 19.0, 6.2)
	_lf(ci, top, Vector2(-0.8, 0.4), 15.0, 5.0)
	# pati çubuğun alt ucunu kavrar (kolun ucu, çubuğun üstünde)
	var paw := Vector2(27, -14)
	ArtUtil.ellipse(ci, paw, 8.5 + PandaArt.OUT, 7.5 + PandaArt.OUT, -0.35, INK)
	ArtUtil.ellipse(ci, paw, 8.5, 7.5, -0.35, PandaArt.BLACK)
	ArtUtil.ellipse(ci, paw + Vector2(-2.5, -2.5), 3.0, 2.2, -0.35, PandaArt.BLACK_HI)

# Sevinirken (kollar havada) çubuk ağızda yatay.
static func _sprig_mouth(ci: CanvasItem) -> void:
	var a := Vector2(-10, -50)
	var b := Vector2(36, -60)
	ci.draw_line(a, b, INK, 9.0, true)
	ci.draw_line(a, b, Color(0.5, 0.78, 0.32), 5.0, true)
	ci.draw_line(a + Vector2(0, -1.5), b + Vector2(0, -1.5), Color(0.72, 0.92, 0.5), 1.6, true)
	for t in [0.3, 0.72]:
		var p := a.lerp(b, t)
		ci.draw_line(p + Vector2(-1, -5), p + Vector2(1, 5), Color(0.3, 0.55, 0.2), 2.6, true)
	_lf(ci, b, Vector2(0.6, -0.8), 20.0, 6.5)
	_lf(ci, b, Vector2(1.0, 0.05), 17.0, 5.5)

# Sol kulağın yanında kırmızı fiyonk (beyaz puantiyeli).
static func _bow(ci: CanvasItem) -> void:
	var c := Vector2(-14, -99)
	var red := Color(0.93, 0.25, 0.33)
	for s in [-1.0, 1.0]:
		var loop := PackedVector2Array([c, c + Vector2(s * 15, -11).rotated(-0.3), c + Vector2(s * 19, 1).rotated(-0.3),
			c + Vector2(s * 14, 9).rotated(-0.3)])
		_blob(ci, loop, red)
		ci.draw_circle(c + Vector2(s * 12, -1).rotated(-0.3), 2.2, Color(1, 1, 1, 0.9))
	ci.draw_circle(c, 5.5 + OUT, INK)
	ci.draw_circle(c, 5.5, Color(0.80, 0.16, 0.24))
	ci.draw_circle(c + Vector2(-1.5, -1.8), 1.6, Color(1, 1, 1, 0.6))

# Boyuna bağlı beyaz önlük: kırmızı kenar, ortasında kalp. Kafanın ve kolların
# altında çizilir (PandaArt sırası), üst kenarı çenenin altına girer.
static func _bib(ci: CanvasItem) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-18, -46))
	pts.append(Vector2(18, -46))
	for i in 13:
		var a := PI * i / 12.0
		pts.append(Vector2(0, -44) + Vector2(cos(a) * 18.0, sin(a) * 31.0))
	_blob(ci, pts, Color(1.0, 0.99, 0.97))
	var rim := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		rim.append(Vector2(0, -44) + Vector2(cos(a) * 14.0, sin(a) * 26.5))
	ci.draw_polyline(rim, Color(0.93, 0.3, 0.33), 3.0, true)
	var h := Vector2(0, -27)
	ci.draw_circle(h + Vector2(-3, -2), 3.4, Color(0.93, 0.3, 0.33))
	ci.draw_circle(h + Vector2(3, -2), 3.4, Color(0.93, 0.3, 0.33))
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-6.3, -1), h + Vector2(6.3, -1), h + Vector2(0, 6.5)]),
		Color(0.93, 0.3, 0.33))

# Göz yamalarının üstüne koyu güneş gözlüğü, çapraz parıltı.
static func _shades(ci: CanvasItem) -> void:
	ci.draw_line(Vector2(-22, -70), Vector2(-31, -74), INK, 3.5, true)
	ci.draw_line(Vector2(22, -70), Vector2(31, -74), INK, 3.5, true)
	ci.draw_line(Vector2(-4, -70), Vector2(4, -70), INK, 4.0, true)
	for s in [-1.0, 1.0]:
		var c := Vector2(s * 12.5, -67.5)
		_oval(ci, c, 11.0, 8.8, 0.0, Color(0.14, 0.12, 0.22))
		ArtUtil.ellipse(ci, c + Vector2(0, 3), 8.5, 4.5, 0.0, Color(0.36, 0.22, 0.45, 0.8))
		ci.draw_line(c + Vector2(-6, -1), c + Vector2(-1, -6), Color(1, 1, 1, 0.75), 2.4, true)
		ci.draw_line(c + Vector2(2, 3), c + Vector2(5, 0), Color(1, 1, 1, 0.45), 1.8, true)

# Önden görünen şapka: kubbe + siperlik, tepede düğme, önde küçük bambu yaprağı.
static func _cap(ci: CanvasItem) -> void:
	var blue := Color(0.25, 0.55, 0.95)
	var dome := PackedVector2Array()
	for i in 15:
		var a := PI + PI * i / 14.0
		dome.append(Vector2(0, -91) + Vector2(cos(a) * 26.0, sin(a) * 19.0))
	_blob(ci, dome, blue)
	ArtUtil.ellipse(ci, Vector2(-9, -102), 8.0, 4.5, -0.4, Color(1, 1, 1, 0.3))
	ci.draw_line(Vector2(0, -110), Vector2(0, -92), Color(0.16, 0.4, 0.78), 2.0, true)
	ci.draw_circle(Vector2(0, -110), 3.4 + 1.8, INK)
	ci.draw_circle(Vector2(0, -110), 3.4, blue)
	ArtUtil.leaf(ci, Vector2(7, -97), Vector2(0.9, -0.45), 12.0, 4.0, Color(1, 1, 1, 0.95))
	var visor := PackedVector2Array()
	for i in 15:
		var a := PI * i / 14.0
		visor.append(Vector2(0, -91) + Vector2(cos(a) * 30.0, sin(a) * 8.0))
	visor.append(Vector2(-30, -91))
	_blob(ci, visor, Color(0.17, 0.42, 0.82))

# Pembe kulaklık: tepeden geçen bant, yanlarda kulaklıklar.
static func _headphones(ci: CanvasItem) -> void:
	var c := Vector2(0, -70)
	ci.draw_arc(c, 36.0, PI * 1.06, PI * 1.94, 28, INK, 10.0, true)
	ci.draw_arc(c, 36.0, PI * 1.06, PI * 1.94, 28, Color(0.36, 0.33, 0.42), 5.0, true)
	for s in [-1.0, 1.0]:
		var p := Vector2(s * 33.0, -67.0)
		_oval(ci, p, 9.0, 14.0, 0.0, Color(0.98, 0.45, 0.62))
		ArtUtil.ellipse(ci, p + Vector2(-s * 3.0, 0), 4.0, 9.5, 0.0, Color(0.85, 0.3, 0.48))
		ArtUtil.ellipse(ci, p + Vector2(s * 2.5, -6), 2.5, 4.0, 0.0, Color(1, 1, 1, 0.55))

# Aşçı şapkası: bant + kabarık tepe (yemek oyununun imza parçası).
static func _chef(ci: CanvasItem) -> void:
	var puffs := [[Vector2(-15, -108), 11.5], [Vector2(15, -108), 11.5], [Vector2(0, -117), 14.0],
		[Vector2(-7, -104), 10.0], [Vector2(7, -104), 10.0]]
	for p in puffs:
		ci.draw_circle(p[0], p[1] + OUT, INK)
	var band := _rrect(Rect2(-19, -102, 38, 14), 5.0)
	for p in puffs:
		ci.draw_circle(p[0], p[1], Color(0.88, 0.88, 0.91))
	for p in puffs:
		ci.draw_circle(p[0] + Vector2(-1.5, -1.5), p[1] - 2.0, Color(1.0, 1.0, 1.0))
	ci.draw_colored_polygon(band, Color(0.97, 0.97, 0.98))
	ArtUtil.outline(ci, band, INK, OUT)
	for x in [-9.0, 0.0, 9.0]:
		ci.draw_line(Vector2(x, -99), Vector2(x, -91), Color(0.84, 0.84, 0.88), 1.4, true)

# Altın taç (seri ödülü): üç sivri uç, taşlar, hafif yana yatık. (draw_set_transform
# kullanmaz: simge olarak başka bir dönüşümün içinde de çizilebilsin.)
static func _crown(ci: CanvasItem) -> void:
	var xf := Transform2D(0.14, Vector2(2, -99))
	var gold := Color(1.0, 0.80, 0.22)
	var pts := PackedVector2Array()
	for p in [Vector2(-18, 4), Vector2(-21, -17), Vector2(-9, -7), Vector2(0, -22), Vector2(9, -7), Vector2(21, -17), Vector2(18, 4)]:
		pts.append(xf * p)
	_blob(ci, pts, gold)
	var band := PackedVector2Array()
	for p in [Vector2(-18, -2), Vector2(18, -2), Vector2(18, 4), Vector2(-18, 4)]:
		band.append(xf * p)
	ci.draw_colored_polygon(band, Color(0.92, 0.62, 0.12))
	for t in [Vector2(-21, -17), Vector2(0, -22), Vector2(21, -17)]:
		ci.draw_circle(xf * t, 3.4 + 1.8, INK)
		ci.draw_circle(xf * t, 3.4, gold)
	ci.draw_circle(xf * Vector2(0, -6), 3.8, Color(0.9, 0.2, 0.3))
	ci.draw_circle(xf * Vector2(-10, -3.5), 2.6, Color(0.3, 0.6, 1.0))
	ci.draw_circle(xf * Vector2(10, -3.5), 2.6, Color(0.3, 0.6, 1.0))
	ci.draw_line(xf * Vector2(-14, -11), xf * Vector2(-12, -3), Color(1, 1, 1, 0.6), 2.0, true)
