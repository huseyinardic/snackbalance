class_name RaceBoard
extends Control

# Panda Yarışı sıralaması (menü paneli ve seviye sonu kartı). Satır: sıra (ilk üç madalya
# rengi), hayvan yüzü, isim, ilk üçün ödülü, puan (altın bambu jetonu).
#   set_rows: menü — ilk 10 + (gerideyse) "..." ve oyuncunun satırı.
#   set_window: seviye sonu — oyuncunun yeni sırasının çevresindeki 7 satır; k 0 -> 1
#     ilerledikçe oyuncunun satırı eski yerinden yeni yerine kayar, geçtiği rakipler
#     birer sıra aşağı iner, puanı sayarak artar.

const ROW := 50.0
const WINDOW := 7
const MEDAL_COLS := [Color(1.0, 0.8, 0.22), Color(0.78, 0.8, 0.86), Color(0.85, 0.55, 0.3)]

var rows: Array = []      # {name, color, you, passed, score0, score1, i0, i1} (i: pencere içi satır no) ya da {gap}
var top := 0              # pencerenin ilk satırının sıra no'su - 1
var k := 1.0:
	set(v):
		k = v
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func set_rows(all: Array) -> void:
	rows = []
	top = 0
	k = 1.0
	var you := 0
	for i in all.size():
		if all[i]["you"]:
			you = i
		if i < 10:
			rows.append(_row(all[i], i, i, all[i]["score"]))
	if you >= 10:
		rows.append({"gap": true, "i0": 10, "i1": 10})
		var r := _row(all[you], 11, 11, all[you]["score"])
		r["rank"] = you + 1
		rows.append(r)
	custom_minimum_size = Vector2(600, ROW * rows.size())
	queue_redraw()

# old_all / new_all: Race.standings() oyuncunun puanı eklenmeden önce ve sonra.
func set_window(old_all: Array, new_all: Array) -> void:
	rows = []
	var n := new_all.size()
	var new_you := _you_index(new_all)
	top = clampi(new_you - WINDOW / 2, 0, maxi(0, n - WINDOW))
	var old_index := {}
	for i in old_all.size():
		old_index[old_all[i]["name"]] = i
	var you_row := {}
	var you_old: int = old_index.get("You", new_you) - top
	for j in range(top, mini(n, top + WINDOW + 1)):      # +1: geçilip aşağı kayan satır
		var r: Dictionary = new_all[j]
		var oi: int = old_index.get(r["name"], j)
		var old_score: int = old_all[oi]["score"]
		var row := _row(r, oi - top, j - top, old_score)
		if r["you"]:
			row["i0"] = mini(you_old, WINDOW)            # uzaktan gelse de pencerenin hemen altından girer
			you_row = row
		else:
			row["passed"] = oi - top < you_old and j - top > oi - top
			rows.append(row)
	if not you_row.is_empty():
		rows.append(you_row)                              # en üstte çizilsin
	custom_minimum_size = Vector2(600, ROW * WINDOW)
	k = 0.0

func _you_index(all: Array) -> int:
	for i in all.size():
		if all[i]["you"]:
			return i
	return 0

func _row(r: Dictionary, i0: int, i1: int, score0: int) -> Dictionary:
	return {"name": r["name"], "color": r["color"], "you": r["you"], "passed": false, "score0": score0,
		"score1": r["score"], "i0": i0, "i1": i1}

func _draw() -> void:
	var e := ease(k, -2.2)          # yumuşak başla, yumuşak dur
	# oyuncunun satırı yukarı kayar; geçilen rakip, oyuncu tam üstünden geçerken bir sıra iner
	var you_pos := 0.0
	for r in rows:
		if r.get("you", false):
			you_pos = lerpf(r["i0"], r["i1"], e)
	for r in rows:
		var fi: float = r["i1"]
		if r.get("you", false):
			fi = you_pos
		elif r.get("passed", false):
			fi = r["i0"] + clampf(r["i0"] + 1.0 - you_pos, 0.0, 1.0)
		var y := fi * ROW
		if y < -ROW or y > size.y:
			continue
		if r.get("gap", false):
			draw_string(UiKit.BOLD, Vector2(0, y + 34), "...", HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.5, 0.45, 0.4))
			continue
		var rank: int = r.get("rank", top + roundi(fi) + 1)
		var score := roundi(lerpf(r["score0"], r["score1"], clampf(k * 1.4, 0.0, 1.0)))
		_draw_row(y, r, rank, score)

func _draw_row(y: float, r: Dictionary, rank: int, score: int) -> void:
	var you: bool = r["you"]
	if you:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.9, 0.6)
		sb.border_color = UiKit.GOLD.darkened(0.15)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(18)
		sb.shadow_color = Color(0, 0, 0, 0.18 if k < 1.0 else 0.0)
		sb.shadow_size = 8
		draw_style_box(sb, Rect2(0, y + 2, size.x, ROW - 4))
	var cy := y + ROW / 2.0
	if rank <= 3:
		draw_circle(Vector2(28, cy), 17.0, UiKit.INK)
		draw_circle(Vector2(28, cy), 14.5, MEDAL_COLS[rank - 1])
	draw_string(UiKit.BOLD, Vector2(4, cy + 9), str(rank), HORIZONTAL_ALIGNMENT_CENTER, 48, 24, UiKit.INK)
	_face(Vector2(80, cy), r["color"], you)
	draw_string(UiKit.BOLD, Vector2(110, cy + 10), r["name"], HORIZONTAL_ALIGNMENT_LEFT, 260, 28,
		UiKit.INK if you else Color(0.3, 0.27, 0.25))
	if rank <= 3:
		if rank == 1:
			draw_set_transform(Vector2(388, cy + 21.0 * 0.8), 0.0, Vector2(0.8, 0.8))
			Accessories.draw(self, Race.MEDAL)
			draw_set_transform(Vector2.ZERO)
		UiKit.bamboo(self, Vector2(416, cy), 28.0)
		draw_string(UiKit.BOLD, Vector2(434, cy + 8), str(Race.PRIZES[rank - 1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(0.4, 0.55, 0.25))
	draw_string(UiKit.BOLD, Vector2(size.x - 124, cy + 10), str(score), HORIZONTAL_ALIGNMENT_RIGHT, 84, 30, UiKit.INK)
	Race.coin(self, Vector2(size.x - 20, cy), 12.0)

# Hayvan yüzü: renkli daire, iki kulak, gözler; oyuncu = panda yüzü.
func _face(c: Vector2, col: Color, you: bool) -> void:
	var ink := UiKit.INK
	var face := Color(0.99, 0.98, 0.96) if you else col
	var ear := ink if you else col.darkened(0.25)
	for x in [-12.0, 12.0]:
		draw_circle(c + Vector2(x, -13), 7.5, ink)
		draw_circle(c + Vector2(x, -13), 5.5, ear)
	draw_circle(c, 18.0, ink)
	draw_circle(c, 15.5, face)
	if you:
		for x in [-6.0, 6.0]:
			draw_circle(c + Vector2(x, -1), 4.5, ink)
	for x in [-6.0, 6.0]:
		draw_circle(c + Vector2(x, -1), 2.2, Color.WHITE if you else ink)
	draw_circle(c + Vector2(0, 6), 2.2, ink)
