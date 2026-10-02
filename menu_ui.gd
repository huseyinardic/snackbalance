class_name MenuUi
extends Control

# Ana menü (UI CanvasLayer'da, oyun sahnesinin üstünde). Arkada canlı sahne
# var: main.gd kamerayı pandaya yaklaştırır, panda menünün vitrini olur.
#   üstte başlık + bambu sayacı, altta büyük PLAY, en altta Wardrobe / Themes / Daily.
# Paneller (gardırop, temalar, günlük ödül) bu Control'ün içinde açılır; arkadaki
# Blocker dokunuşları yutar, boşluğa dokunmak paneli kapatır.

signal play_pressed
signal outfit_preview(outfit: Dictionary)   # gardıropta deneme: main pandaya uygular
signal theme_picked(mood: String)

const SWAP_UNLOCK_LEVEL := 5     # main.gd ile aynı: Swap'tan önce günlük Swap satırı gösterilmez

var _title: VBoxContainer
var _pill: BambooPill
var _gear: UiKit.Btn
var _settings: Control
var _privacy: UiKit.Btn
var _toggles := {}   # ayar adı -> düğme
var _level_label: Label
var _play: UiKit.Btn
var _btn_wardrobe: UiKit.Btn
var _btn_themes: UiKit.Btn
var _btn_daily: UiKit.Btn
var _wardrobe: Control
var _themes: Control
var _daily: Control
var _cells: Array = []
var _selected := ""
var _action: UiKit.Btn
var _item_name: Label
var _theme_cards: Array = []
var _day_cells: Array = []
var _daily_sub: Label
var _daily_info: Label
var _claim: UiKit.Btn

# Bambu sayacı: koyu hap içinde bambu simgesi + sayı; artınca sayarak yükselir.
class BambooPill extends Control:
	var shown := 0.0:
		set(v):
			shown = v
			queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.2, 0.1, 0.45)
		sb.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(sb, Rect2(Vector2(20, 6), size - Vector2(20, 12)))
		UiKit.bamboo(self, Vector2(34, size.y / 2.0), 62.0)
		var t := str(int(round(shown)))
		draw_string_outline(UiKit.BOLD, Vector2(62, size.y / 2.0 + 13), t, HORIZONTAL_ALIGNMENT_CENTER, size.x - 76, 38, 8, UiKit.OUTLINE)
		draw_string(UiKit.BOLD, Vector2(62, size.y / 2.0 + 13), t, HORIZONTAL_ALIGNMENT_CENTER, size.x - 76, 38, Color.WHITE)
	func set_value(v: int, animate: bool) -> void:
		if animate:
			create_tween().tween_property(self, "shown", float(v), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			pivot_offset = size / 2.0
			scale = Vector2(1.15, 1.15)
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
		else:
			shown = v

# Gardırop hücresi: mini panda o parçayı takmış halde + fiyat / durum.
class ItemCell extends UiKit.Btn:
	var item: Dictionary
	var selected := false
	var panda: PandaArt
	func setup(a: Dictionary) -> void:
		item = a
		panda = PandaArt.new()
		panda.position = Vector2(size.x / 2.0, 126)
		panda.scale = Vector2(0.82, 0.82)
		var o := {}
		o[a["slot"]] = a["id"]
		panda.set_outfit(o)
		add_child(panda)
	func _draw() -> void:
		var owned: bool = item["id"] in GameData.owned
		var worn := GameData.is_worn(item["id"])
		var press := 3.0 if _down != -2 else 0.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.86, 0.95, 0.82) if owned else Color(0.95, 0.93, 0.86)
		sb.set_corner_radius_all(22)
		sb.border_color = UiKit.GOLD.darkened(0.1) if selected else Color(0.8, 0.76, 0.66)
		sb.set_border_width_all(6 if selected else 3)
		draw_style_box(sb, Rect2(0, press, size.x, size.y))
		panda.position.y = 126 + press
		var y := size.y - 14.0 + press
		if worn:
			_tag("Wearing", UiKit.GREEN.darkened(0.25), y)
		elif owned:
			_tag("Owned", Color(0.4, 0.45, 0.4), y)
		elif Accessories.is_streak_item(item):
			_tag("Day 7", Color(0.85, 0.55, 0.1), y)
		else:
			var t := str(item["price"])
			var tw := UiKit.BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			var x := (size.x - tw - 34.0) / 2.0
			UiKit.bamboo(self, Vector2(x + 13, y - 10), 34.0)
			var col := UiKit.INK if GameData.bamboo >= item["price"] else Color(0.6, 0.5, 0.45)
			draw_string(UiKit.BOLD, Vector2(x + 34, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)
	func _tag(t: String, col: Color, y: float) -> void:
		draw_string(UiKit.BOLD, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, col)

# Tema kartı: temanın renkleriyle küçük manzara; kilitliyse karartılmış + kilit + koşul.
class ThemeCard extends UiKit.Btn:
	var mood := "day"
	var title := ""
	func _draw() -> void:
		var m: Dictionary = BambooBackdrop.MOODS[mood]
		var unlocked := GameData.theme_unlocked(mood)
		var sel := GameData.theme == mood
		var press := 3.0 if _down != -2 else 0.0
		var r := Rect2(0, press, size.x, size.y - 60)
		var sky: Array = m["sky"]
		var bands := 24
		for i in bands:
			var t := float(i) / bands
			var col: Color = sky[0].lerp(sky[1], t * 2.0) if t < 0.5 else sky[1].lerp(sky[2], (t - 0.5) * 2.0)
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t, r.size.x, r.size.y / bands + 1.0), col)
		draw_circle(r.position + Vector2(r.size.x * 0.68, r.size.y * (0.22 if mood == "day" else 0.62)), 26.0, m["sun"])
		for x in [0.18, 0.84]:
			draw_rect(Rect2(r.position.x + r.size.x * x - 8.0, r.position.y, 16.0, r.size.y), m["mid"])
		var hill := ArtUtil.ellipse_pts(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.86), r.size.x * 0.7, r.size.y * 0.2)
		for i in hill.size():
			hill[i] = Vector2(clampf(hill[i].x, r.position.x, r.end.x), minf(hill[i].y, r.end.y))
		draw_colored_polygon(hill, m["hill"])
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.84, r.size.x, r.size.y * 0.16), m["ground"])
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.set_corner_radius_all(20)
		frame.border_color = UiKit.GOLD if sel else UiKit.INK
		frame.set_border_width_all(8 if sel else 4)
		frame.corner_detail = 8
		# köşeleri yuvarlatmak için dış kenarı panel rengiyle ört
		var mask := StyleBoxFlat.new()
		mask.draw_center = false
		mask.border_color = UiKit.PANEL
		mask.set_border_width_all(14)
		mask.set_corner_radius_all(34)
		mask.expand_margin_left = 14
		mask.expand_margin_right = 14
		mask.expand_margin_top = 14
		mask.expand_margin_bottom = 14
		draw_style_box(mask, r)
		if not unlocked:
			draw_rect(r.grow(-2), Color(0.1, 0.1, 0.15, 0.55))
			UiKit.lock(self, r.get_center() + Vector2(0, -24), 56.0)
			draw_string(UiKit.BOLD, Vector2(0, r.get_center().y + 44), "Beat level %d" % GameData.SUNSET_LEVEL,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color.WHITE)
		draw_style_box(frame, r)
		var label := title + ("  ✓" if sel else "")
		draw_string(UiKit.BOLD, Vector2(0, size.y - 14 + press), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32,
			UiKit.INK if unlocked else Color(0.45, 0.42, 0.4))

# Günlük seri hücresi: gün, ödül, geçmiş günler tik, bugün altın çerçeve.
class DayCell extends Control:
	var day := 1
	var amount := 0
	var crown := false
	var state := 0      # 0 gelecek, 1 alındı, 2 bugün (alınabilir), 3 bugün (alındı)
	var pulse: Tween
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var today := state >= 2
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.93, 0.7) if today else (Color(0.86, 0.95, 0.82) if state == 1 else Color(0.95, 0.93, 0.86))
		sb.set_corner_radius_all(16)
		sb.border_color = UiKit.GOLD.darkened(0.15 * glow) if today else Color(0.8, 0.76, 0.66)
		sb.set_border_width_all(5 if today else 3)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_string(UiKit.BOLD, Vector2(0, 28), "Day %d" % day, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UiKit.INK)
		var c := Vector2(size.x / 2.0, size.y * 0.55)
		if crown:
			draw_set_transform(c - Vector2(2, -108) * 1.25, 0.0, Vector2(1.25, 1.25))
			Accessories.draw(self, "crown")
			draw_set_transform(Vector2.ZERO)
		else:
			UiKit.bamboo(self, c, 40.0)
			draw_string(UiKit.BOLD, Vector2(0, size.y - 12), str(amount), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, UiKit.INK)
		if state == 1 or state == 3:
			draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(1, 1, 1, 0.45))
			draw_polyline(PackedVector2Array([c + Vector2(-14, 0), c + Vector2(-4, 10), c + Vector2(16, -12)]),
				UiKit.GREEN.darkened(0.2), 7.0, true)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_home()
	_wardrobe = _build_wardrobe()
	_themes = _build_themes()
	_daily = _build_daily()
	_settings = _build_settings()
	GameData.bamboo_changed.connect(func(v: int): _pill.set_value(v, true))
	_apply_top_inset()

# --- ana ekran ---

func _build_home() -> void:
	_title = VBoxContainer.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 118.0
	_title.offset_bottom = 330.0
	_title.add_theme_constant_override("separation", -26)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := UiKit.label("Snack", UiKit.BOLD, 104, Color.WHITE)
	var t2 := UiKit.label("Balance", UiKit.BOLD, 112, UiKit.GOLD)
	for l in [t1, t2]:
		l.add_theme_constant_override("outline_size", 22)
		l.add_theme_color_override("font_outline_color", Color(0.2, 0.3, 0.16))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
		l.add_theme_constant_override("shadow_offset_y", 7)
		_title.add_child(l)
	add_child(_title)

	_pill = BambooPill.new()
	_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pill.offset_left = -236.0
	_pill.offset_right = -20.0
	_pill.offset_top = 26.0
	_pill.offset_bottom = 96.0
	add_child(_pill)

	# sol üstte Ayarlar (müzik, ses, titreşim; AB'de reklam gizlilik seçenekleri)
	_gear = UiKit.btn("", Color(0.36, 0.6, 0.34), 76, 76, 26, _open_settings, UiKit.gear)
	_gear.icon_size = 70.0
	_gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_gear.offset_left = 20.0
	_gear.offset_right = 96.0
	_gear.offset_top = 24.0
	_gear.offset_bottom = 100.0
	add_child(_gear)
	Ads.consent_ready.connect(refresh)

	_level_label = UiKit.label("", UiKit.BOLD, 38, Color.WHITE)
	_level_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_level_label.offset_top = -410.0
	_level_label.offset_bottom = -362.0
	add_child(_level_label)

	_play = UiKit.btn("PLAY", UiKit.GREEN, 400, 128, 60, func(): play_pressed.emit(), UiKit.play)
	_play.icon_size = 72.0
	_play.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_play.offset_left = -200.0
	_play.offset_right = 200.0
	_play.offset_top = -356.0
	_play.offset_bottom = -228.0
	add_child(_play)
	var pulse := create_tween().set_loops()
	_play.pivot_offset = Vector2(200, 64)
	pulse.tween_property(_play, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_play, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	var defs := [["Wardrobe", UiKit.wardrobe, _open_wardrobe, Color(0.98, 0.55, 0.62)],
		["Themes", UiKit.landscape, _open_themes, UiKit.BLUE],
		["Daily", UiKit.gift, _open_daily, UiKit.ORANGE]]
	var btns := []
	for i in defs.size():
		var b := UiKit.Btn.new()
		b.circle = true
		b.text = defs[i][0]
		b.font_size = 28
		b.icon = defs[i][1]
		b.icon_size = 64.0
		b.on_tap = defs[i][2]
		b.color = defs[i][3]
		b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		b.offset_left = -56.0 + (i - 1) * 190.0
		b.offset_right = 56.0 + (i - 1) * 190.0
		b.offset_top = -198.0
		b.offset_bottom = -52.0
		add_child(b)
		btns.append(b)
	_btn_wardrobe = btns[0]
	_btn_themes = btns[1]
	_btn_daily = btns[2]

# Açılış: main.gd kamerayı pandaya yaklaştırırken çağırır.
func open(show_daily: bool) -> void:
	visible = true
	for p in [_wardrobe, _themes, _daily, _settings]:
		p.visible = false
	GameData.refresh_day()
	refresh()
	_pill.set_value(GameData.bamboo, false)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	if show_daily and GameData.daily_available():
		_open_daily()

func close() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func(): visible = false)

# Paneller açıksa önce onları kapatır (Android geri tuşu). false = kapatacak panel yoktu.
func back() -> bool:
	if _wardrobe.visible:
		_close_wardrobe()
		return true
	for p in [_themes, _daily, _settings]:
		if p.visible:
			_close_panel(p)
			return true
	return false

func refresh() -> void:
	_level_label.text = "Level %d" % GameData.level
	_btn_daily.badge = GameData.daily_available()
	_btn_themes.badge = GameData.new_theme_badge()
	var goal := Accessories.next_goal(GameData.owned)
	_btn_wardrobe.badge = not goal.is_empty() and GameData.bamboo >= goal["price"]
	for b in [_btn_daily, _btn_themes, _btn_wardrobe]:
		b.queue_redraw()

# --- panel iskeleti ---

func _panel(height: float, bottom_sheet: bool, on_close: Callable) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var block := UiKit.Blocker.new()
	block.color = Color(0, 0, 0, 0.12 if bottom_sheet else 0.45)
	block.on_tap = on_close
	root.add_child(block)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiKit.panel_style())
	if bottom_sheet:
		card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		card.offset_left = 14.0
		card.offset_right = -14.0
		card.offset_top = -height
		card.offset_bottom = 30.0
	else:
		card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		card.offset_left = -320.0
		card.offset_right = 320.0
		card.offset_top = -height / 2.0
		card.offset_bottom = height / 2.0
	root.add_child(card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_bottom", 50 if bottom_sheet else 26)
	margin.add_child(box)
	card.add_child(margin)
	# başlık satırı: ortada başlık, sağda kapatma düğmesi
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 64)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var x := UiKit.btn("", UiKit.RED, 64, 64, 30, on_close, UiKit.close)
	x.icon_size = 60.0
	x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	x.offset_left = -64.0
	x.offset_right = 0.0
	x.offset_bottom = 64.0
	head.add_child(x)
	add_child(root)
	return [root, box, head]

func _panel_title(head: Control, text: String) -> void:
	var l := UiKit.ink_label(text, UiKit.BOLD, 46)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(l)
	head.move_child(l, 0)

func _show_panel(p: Control, from_bottom: bool) -> void:
	p.visible = true
	var card: Control = p.get_child(1)
	p.get_child(0).modulate.a = 0.0
	create_tween().tween_property(p.get_child(0), "modulate:a", 1.0, 0.2)
	if from_bottom:
		var y := card.position.y
		card.position.y = y + 500.0
		create_tween().tween_property(card, "position:y", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.7, 0.7)
		create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_panel(p: Control) -> void:
	p.visible = false
	refresh()

# --- gardırop ---

func _build_wardrobe() -> Control:
	var parts := _panel(640.0, true, _close_wardrobe)
	var box: VBoxContainer = parts[1]
	_panel_title(parts[2], "Wardrobe")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for a in Accessories.LIST:
		var c := ItemCell.new()
		c.custom_minimum_size = Vector2(150, 188)
		c.size = c.custom_minimum_size
		c.setup(a)
		var id: String = a["id"]
		c.sound = ""
		c.on_tap = func():
			_select_item(id)
			Sfx.play("equip")   # deneme: kumaş "fıp" + pop
		grid.add_child(c)
		_cells.append(c)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_item_name = UiKit.ink_label("", UiKit.BOLD, 34)
	_item_name.custom_minimum_size = Vector2(250, 0)
	_item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_item_name)
	_action = UiKit.btn("", UiKit.GREEN, 340, 96, 38, _on_action)
	_action.sound = ""   # kendi sesi: satın alma ya da giyme
	row.add_child(_action)
	box.add_child(row)
	return parts[0]

func _open_wardrobe() -> void:
	_selected = ""
	for slot in Accessories.SLOTS:
		if GameData.outfit[slot] != "":
			_selected = GameData.outfit[slot]
			break
	if _selected == "":
		var goal := Accessories.next_goal(GameData.owned)
		_selected = goal.get("id", Accessories.LIST[0]["id"])
	_show_panel(_wardrobe, true)
	_select_item(_selected)

func _close_wardrobe() -> void:
	outfit_preview.emit(GameData.outfit.duplicate())   # denenen ama alınmayan parça çıkar
	_close_panel(_wardrobe)

func _select_item(id: String) -> void:
	_selected = id
	var a := Accessories.get_item(id)
	var o: Dictionary = GameData.outfit.duplicate()
	if not GameData.is_worn(id):
		o[a["slot"]] = id           # dene: pandanın üstünde göster
	outfit_preview.emit(o)
	_item_name.text = a["name"]
	var owned: bool = id in GameData.owned
	_action.enabled = true
	_action.icon = Callable()
	if owned and GameData.is_worn(id):
		_action.text = "Take off"
		_action.color = UiKit.BLUE
	elif owned:
		_action.text = "Wear"
		_action.color = UiKit.GREEN
	elif Accessories.is_streak_item(a):
		_action.text = "7-day streak"
		_action.enabled = false
	elif GameData.bamboo >= a["price"]:
		_action.text = "Buy  %d" % a["price"]
		_action.color = UiKit.GREEN
		_action.icon = UiKit.bamboo
	else:
		_action.text = "Need %d more" % (a["price"] - GameData.bamboo)
		_action.enabled = false
	_action.queue_redraw()
	for c in _cells:
		c.selected = c.item["id"] == id
		c.queue_redraw()

func _on_action() -> void:
	var id := _selected
	if id in GameData.owned:
		GameData.toggle_wear(id)
		Sfx.play("equip")
		outfit_preview.emit(GameData.outfit.duplicate())
	elif GameData.buy(id):
		Analytics.log_event("item_purchased", {"item": id, "price": Accessories.get_item(id)["price"], "level": GameData.level})
		GameData.vibrate(40)
		Sfx.play("buy")
		outfit_preview.emit(GameData.outfit.duplicate())
		_celebrate(_action)
	_select_item(id)
	# giy/çıkar sonrası deneme: seçili parça giyili değilse yine üstünde görünsün
	if id in GameData.owned and not GameData.is_worn(id):
		outfit_preview.emit(GameData.outfit.duplicate())

func _celebrate(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- temalar ---

func _build_themes() -> Control:
	var parts := _panel(560.0, false, func(): _close_panel(_themes))
	var box: VBoxContainer = parts[1]
	_panel_title(parts[2], "Themes")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	for d in [["day", "Day"], ["sunset", "Sunset"]]:
		var c := ThemeCard.new()
		c.mood = d[0]
		c.title = d[1]
		c.custom_minimum_size = Vector2(250, 390)
		var t: String = d[0]
		c.on_tap = func(): _pick_theme(t)
		row.add_child(c)
		_theme_cards.append(c)
	return parts[0]

func _open_themes() -> void:
	if GameData.sunset_unlocked() and not GameData.sunset_seen:
		GameData.sunset_seen = true
		GameData.save()
	for c in _theme_cards:
		c.queue_redraw()
	_show_panel(_themes, false)

func _pick_theme(t: String) -> void:
	if not GameData.theme_unlocked(t):
		return
	GameData.set_theme(t)
	Analytics.log_event("theme_selected", {"theme": t})
	theme_picked.emit(t)
	for c in _theme_cards:
		c.queue_redraw()

# --- günlük ödül ---

func _build_daily() -> Control:
	var parts := _panel(600.0, false, func(): _close_panel(_daily))
	var box: VBoxContainer = parts[1]
	_panel_title(parts[2], "Daily Reward")
	_daily_sub = UiKit.ink_label("", UiKit.BOLD, 30, Color(0.85, 0.45, 0.1))
	box.add_child(_daily_sub)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for d in 7:
		var c := DayCell.new()
		c.day = d + 1
		c.custom_minimum_size = Vector2(130, 118)
		grid.add_child(c)
		_day_cells.append(c)
	_daily_info = UiKit.ink_label("", UiKit.MED, 28, Color(0.3, 0.3, 0.3))
	_daily_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_daily_info)
	_claim = UiKit.btn("CLAIM", UiKit.GREEN, 360, 100, 44, _on_claim)
	_claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_claim)
	return parts[0]

func _open_daily() -> void:
	_refresh_daily()
	_show_panel(_daily, false)

func _refresh_daily() -> void:
	var p := GameData.daily_preview()
	var today: int = p["day"]
	var can := GameData.daily_available()
	_daily_sub.text = "Day %d in a row!" % GameData.streak if GameData.streak > 1 else "Come back every day!"
	for c in _day_cells:
		var d: int = c.day
		c.crown = d == 7 and "crown" not in GameData.owned
		c.amount = GameData.STREAK_DAY7 if d == 7 else GameData.STREAK_REWARDS[d - 1]
		if d < today:
			c.state = 1
		elif d == today:
			c.state = 2 if can else 3
		else:
			c.state = 0
		c.queue_redraw()
		if c.pulse:
			c.pulse.kill()
			c.pulse = null
		if c.state == 2:
			c.pulse = create_tween().set_loops()
			c.pulse.tween_property(c, "glow", 1.0, 0.5)
			c.pulse.tween_property(c, "glow", 0.0, 0.5)
	var lines := []
	if GameData.level >= SWAP_UNLOCK_LEVEL:
		var n: int = maxi(GameData.swaps, GameData.DAILY_SWAPS) + p["extra_swaps"]
		lines.append("Swaps refilled: %d" % n if p["extra_swaps"] == 0 else "Swaps refilled + 1 bonus: %d" % n)
	if p["crown"]:
		lines.append("Today: Golden Crown!")
	_daily_info.text = "\n".join(lines) if can else "Come back tomorrow for more!"
	_claim.enabled = can
	_claim.text = "CLAIM" if can else "CLAIMED"
	_claim.queue_redraw()

func _on_claim() -> void:
	if not GameData.daily_available():
		return
	var r := GameData.claim_daily()
	Analytics.log_event("daily_claimed", {"day": r["day"], "streak": GameData.streak})
	GameData.vibrate(40)
	Sfx.play("buy")
	if r["crown"]:
		outfit_preview.emit(GameData.outfit.duplicate())
	_refresh_daily()
	_celebrate(_claim)
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_callback(func():
		if _daily.visible:
			_close_panel(_daily))

# --- ayarlar ---

func _build_settings() -> Control:
	var parts := _panel(560.0, false, func(): _close_panel(_settings))
	var box: VBoxContainer = parts[1]
	_panel_title(parts[2], "Settings")
	for d in [["music", "Music"], ["sfx", "Sounds"], ["vibration", "Vibration"]]:
		var key: String = d[0]
		var b := UiKit.btn("", UiKit.GREEN, 400, 92, 36, func(): _toggle(key))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.set_meta("label", d[1])
		box.add_child(b)
		_toggles[key] = b
	# AB'de zorunlu: reklam onayını sonradan değiştirme (Ads.privacy_options_required)
	_privacy = UiKit.btn("Privacy", Color(0.45, 0.55, 0.45), 400, 84, 32, func(): Ads.show_privacy_options())
	_privacy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_privacy)
	return parts[0]

func _open_settings() -> void:
	_refresh_settings()
	_show_panel(_settings, false)

func _toggle(key: String) -> void:
	match key:
		"music":
			GameData.music_on = not GameData.music_on
			Sfx.apply_settings()
		"sfx":
			GameData.sfx_on = not GameData.sfx_on
		"vibration":
			GameData.vibration_on = not GameData.vibration_on
			GameData.vibrate(40)
	GameData.save()
	_refresh_settings()

func _refresh_settings() -> void:
	var state := {"music": GameData.music_on, "sfx": GameData.sfx_on, "vibration": GameData.vibration_on}
	for key in _toggles:
		var b: UiKit.Btn = _toggles[key]
		b.text = "%s: %s" % [b.get_meta("label"), "On" if state[key] else "Off"]
		b.color = UiKit.GREEN if state[key] else UiKit.GREY
		b.queue_redraw()
	_privacy.visible = Ads.privacy_options_required()
	# kart yüksekliği: Privacy yalnız AB'de görünür, yoksa altta boşluk kalmasın
	var card: Control = _settings.get_child(1)
	var h := 540.0 if _privacy.visible else 440.0
	card.offset_top = -h / 2.0
	card.offset_bottom = h / 2.0

# Çentikli telefonlarda üst öğeleri durum çubuğunun altına it.
func _apply_top_inset() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var inset: float = float(safe.position.y) * get_viewport_rect().size.y / float(win.y)
	if inset <= 0.0:
		return
	for c: Control in [_pill, _gear]:
		c.offset_top += inset
		c.offset_bottom += inset
	_title.offset_top += inset
	_title.offset_bottom += inset
