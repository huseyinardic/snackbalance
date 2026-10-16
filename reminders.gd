class_name Reminders
extends Node

# Yerel bildirim (NotificationScheduler eklentisi, yalnız Android). Chameleon Dash'teki
# sistemin Snack Balance hali: üç aday arasından EN ERKEN geleni kurulur, hep tek bekleyen
# bildirim var (oyun açılınca / hediye alınınca / arka plana geçince yeniden planlanır):
#   - race_soon: Panda Yarışı'nın bitmesine ~3 sa kala (yarışta puanı varsa)
#   - race_over: yarış bittiğinde (puanı varsa) — sonuç ve ödül
#   - daily:     bugünün hediyesi alınmadıysa ve saat 18'den önceyse bugün 19:00, değilse yarın 19:00
# Bildirim yalnız 10:00–21:00 arası (yerel) gelir; gece düşen an kaydırılır.
# Oyuncu açmazsa başka bildirim gelmez (günde en fazla 1, görmezden gelinince susar).
# İzin (Android 13+): ilk günlük hediye alınınca hediye panelinde sorulur ("Remind me"),
# evet derse sistem penceresi açılır. En fazla MAX_ASKS kez, aralarında ASK_GAP_DAYS gün.
# Yalnız oyunun kendisiyle ilgili mesajlar (Play: bildirimde başka uygulama reklamı yok).
# Analitik: notif_prompt {answer}, notif_permission {result}, notif_open {kind}.

const REMIND_ID := 7201
const CHANNEL_ID := "reminders"
const HOUR := 19
const DAY_START := 10
const DAY_END := 21
const SAVE_PATH := "user://reminders.cfg"
const MAX_ASKS := 2
const ASK_GAP_DAYS := 3
const SWAP_UNLOCK_LEVEL := 5      # main.gd ile aynı

var _ns: NotificationScheduler = null
var _ready_ok := false

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton(NotificationScheduler.PLUGIN_SINGLETON_NAME):
		return
	_ns = NotificationScheduler.new()
	add_child(_ns)
	_ns.initialization_completed.connect(_on_initialized)
	_ns.notification_opened.connect(func(d: NotificationData):
		var cd := d.get_custom_data()
		Analytics.log_event("notif_open", {"kind": cd.get_string_property("kind") if cd else ""}))
	_ns.post_notifications_permission_granted.connect(func(_p):
		Analytics.log_event("notif_permission", {"result": "granted"})
		refresh())
	_ns.post_notifications_permission_denied.connect(func(_p):
		Analytics.log_event("notif_permission", {"result": "denied"}))
	_ns.initialize()

func _on_initialized() -> void:
	_ready_ok = true
	_ns.create_notification_channel(NotificationChannel.new()
		.set_id(CHANNEL_ID)
		.set_name("Rewards & races")
		.set_description("Daily gift and Panda Race reminders")
		.set_importance(NotificationChannel.Importance.DEFAULT))
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		refresh()

# Bekleyen bildirimi iptal edip duruma göre yenisini kurar.
func refresh() -> void:
	if not _ready_ok:
		return
	_ns.cancel(REMIND_ID)
	if GameData.is_new or GameData.level < 2 or not _ns.has_post_notifications_permission():
		return
	var p := _plan()
	if p.is_empty():
		return
	var delay: int = int(p["at"]) - _now()
	var cd := CustomData.new()
	cd.set_string_property("kind", p["kind"])
	if OS.is_debug_build():           # telefonda hızlı deneme: 30 sn sonra gelen örnek (release'de yok)
		_ns.schedule(NotificationData.new().set_id(REMIND_ID + 1).set_channel_id(CHANNEL_ID)
			.set_title("[debug] " + p["title"]).set_content(p["text"] + " (in %d min)" % (delay / 60))
			.set_large_icon_name("notif_large").set_custom_data(cd).set_delay(30))
	_ns.schedule(NotificationData.new()
		.set_id(REMIND_ID)
		.set_channel_id(CHANNEL_ID)
		.set_title(p["title"])
		.set_content(p["text"])
		.set_large_icon_name("notif_large")
		.set_custom_data(cd)
		.set_delay(maxi(60, delay)))

# --- plan ---

# Adaylardan en erken geleni: {kind, at (unix), title, text} ya da {}.
func _plan() -> Dictionary:
	var c: Array = [_plan_daily()]
	if Race.unlocked() and GameData.race_start > 0 and GameData.race_points > 0 and not Race.is_over():
		var end: int = GameData.race_start + Race.DURATION
		var soon := _race_soon_time(end)
		if soon > 0:
			c.append({"kind": "race_soon", "at": soon,
				"title": "Panda Race ends in %d hours! 🏁" % maxi(1, roundi((end - soon) / 3600.0)),
				"text": "Win a few more levels to climb the leaderboard!"})
		c.append({"kind": "race_over", "at": _daytime_after(end),
			"title": "The Panda Race is over! 🏅",
			"text": "See where you finished and claim your prize."})
	var best: Dictionary = {}
	for p: Dictionary in c:
		if best.is_empty() or int(p["at"]) < int(best["at"]):
			best = p
	return best

func _plan_daily() -> Dictionary:
	var t := _now()
	var today_19 := _local_midnight(t) + HOUR * 3600
	if GameData.daily_available() and t < today_19 - 3600:
		var r := GameData.daily_preview()
		return {"kind": "daily", "at": today_19, "title": "Your daily gift is waiting 🎁",
			"text": "Claim +%d bamboo before the day ends!" % r["bamboo"] if not r["crown"]
				else "The Golden Crown is waiting for your panda! 👑"}
	# yarın: seri bugün oynandıysa bir artar
	var s: int = GameData.streak + 1 if GameData.last_day == GameData.today() else 1
	var day: int = (s - 1) % 7 + 1
	var at := today_19 + 86400
	if day == 7 and "crown" not in GameData.owned:
		return {"kind": "daily", "at": at, "title": "Day 7: the Golden Crown is waiting! 👑",
			"text": "Come back and dress up your panda."}
	var bamboo: int = GameData.STREAK_DAY7 if day == 7 else GameData.STREAK_REWARDS[day - 1]
	if s >= 3:
		return {"kind": "daily", "at": at, "title": "Don't lose your %d-day streak! 🔥" % (s - 1),
			"text": "Day %d gift: +%d bamboo 🎋" % [s, bamboo]}
	var swaps := " and fresh Swaps" if GameData.level >= SWAP_UNLOCK_LEVEL else ""
	return {"kind": "daily", "at": at, "title": "Your daily gift is ready 🎁",
		"text": "+%d bamboo%s are waiting!" % [bamboo, swaps]}

# Bitişten ~3 sa önce, gündüz saatine denk gelen ve en az 1 sa sonraki an (yoksa 0).
func _race_soon_time(end: int) -> int:
	for back_h in [3.0, 2.5, 3.5, 2.0, 4.0, 1.5, 5.0, 6.0]:
		var t: int = end - int(back_h * 3600.0)
		if t > _now() + 3600 and _is_daytime(t):
			return t
	return 0

# t gündüzse t; değilse sonraki 10:00.
func _daytime_after(t: int) -> int:
	if _is_daytime(t):
		return t
	var h := _local_hour(t)
	var next_10 := _local_midnight(t) + DAY_START * 3600
	return next_10 if h < DAY_START else next_10 + 86400

# --- yerel saat (Race.now() test için kaydırılabilir; yerel gün GameData ile aynı temel) ---

func _now() -> int:
	return Race.now()

func _bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func _local_hour(t: int) -> int:
	return int(posmod(t + _bias(), 86400) / 3600)

func _local_midnight(t: int) -> int:
	return t - posmod(t + _bias(), 86400)

func _is_daytime(t: int) -> bool:
	var h := _local_hour(t)
	return h >= DAY_START and h < DAY_END

# --- izin sorusu ---

# Hediye panelinde sorulsun mu: izin yoksa, sorma hakkı kaldıysa ve son sorudan beri yeterli gün geçtiyse.
func should_ask() -> bool:
	if not _ready_ok or _ns.has_post_notifications_permission():
		return false
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var asks := int(cfg.get_value("ask", "count", 0))
	var last := int(cfg.get_value("ask", "last_unix", 0))
	return asks < MAX_ASKS and int(Time.get_unix_time_from_system()) - last >= ASK_GAP_DAYS * 86400

# Panelin cevabı. Evet: sistem izin penceresi (sonucu sinyalle gelir, verilirse refresh).
func answer(yes: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("ask", "count", int(cfg.get_value("ask", "count", 0)) + 1)
	cfg.set_value("ask", "last_unix", int(Time.get_unix_time_from_system()))
	cfg.save(SAVE_PATH)
	Analytics.log_event("notif_prompt", {"answer": "yes" if yes else "no"})
	if yes and _ns:
		_ns.request_post_notifications_permission()
