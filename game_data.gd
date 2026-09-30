extends Node

# Autoload "GameData": oyuncunun kalıcı durumu tek yerde — seviye, Swap hakkı,
# bambu, aksesuarlar, tema, günlük seri. user://progress.cfg'ye yazılır (eski
# sürümün [progress] level/swaps anahtarları aynen korunur, ilerleme kaybolmaz).

signal bamboo_changed(total: int)

const SAVE_PATH := "user://progress.cfg"
const SWAP_START := 3            # ilk açılışta hediye Swap hakkı
const DAILY_SWAPS := 3           # her gün Swap hakkı bu sayıya tamamlanır (üstündeyse dokunulmaz)
# Günlük seri 7 günlük döngü: 1-6. gün bambu, 7. gün Golden Crown (zaten varsa
# STREAK_DAY7 bambu). 3. ve 7. gün DAILY_SWAPS'ın üstüne +1 Swap.
const STREAK_REWARDS := [20, 30, 40, 50, 60, 80]
const STREAK_DAY7 := 100
const STREAK_BONUS_SWAP_DAYS := [3, 7]
const SUNSET_LEVEL := 14         # bu seviyeyi geçince Sunset teması açılır (ilk "Hard level")

# Seviye ödülleri
const REWARD_LEVEL := 10
const REWARD_HARD := 10
const REWARD_NO_HITS := 5
const REWARD_NO_DROPS := 5

var level := 1
var best_level := 1              # ulaşılan en yüksek seviye (tema kilidi buna bakar)
var swaps := SWAP_START
var bamboo := 0
var owned: Array = []
var outfit := {"head": "", "face": "", "neck": "", "mouth": ""}
var theme := "day"
var streak := 0
var last_day := ""               # en son oynanan gün (seri)
var claimed_day := ""            # günlük ödülün en son alındığı gün
var sunset_seen := false         # "yeni tema" kırmızı noktası görüldü mü
var is_new := true               # kayıt dosyası yoktu: ilk açılış (menü atlanır, direkt 1. seviye)

func _ready() -> void:
	load_data()
	refresh_day()

# --- kayıt ---

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	is_new = false
	level = maxi(1, int(cfg.get_value("progress", "level", 1)))
	best_level = maxi(level, int(cfg.get_value("progress", "best_level", level)))
	swaps = maxi(0, int(cfg.get_value("progress", "swaps", SWAP_START)))
	bamboo = maxi(0, int(cfg.get_value("economy", "bamboo", 0)))
	owned = cfg.get_value("economy", "owned", [])
	for slot in Accessories.SLOTS:
		var id: String = cfg.get_value("economy", slot, "")
		outfit[slot] = id if id in owned and not Accessories.get_item(id).is_empty() else ""
	theme = cfg.get_value("economy", "theme", "day")
	if theme == "sunset" and not sunset_unlocked():
		theme = "day"
	sunset_seen = cfg.get_value("economy", "sunset_seen", false)
	streak = int(cfg.get_value("daily", "streak", 0))
	last_day = cfg.get_value("daily", "last_day", "")
	claimed_day = cfg.get_value("daily", "claimed_day", "")

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "best_level", best_level)
	cfg.set_value("progress", "swaps", swaps)
	cfg.set_value("economy", "bamboo", bamboo)
	cfg.set_value("economy", "owned", owned)
	for slot in Accessories.SLOTS:
		cfg.set_value("economy", slot, outfit[slot])
	cfg.set_value("economy", "theme", theme)
	cfg.set_value("economy", "sunset_seen", sunset_seen)
	cfg.set_value("daily", "streak", streak)
	cfg.set_value("daily", "last_day", last_day)
	cfg.set_value("daily", "claimed_day", claimed_day)
	cfg.save(SAVE_PATH)
	is_new = false

# --- ilerleme ---

func set_level(n: int) -> void:
	level = maxi(1, n)
	best_level = maxi(best_level, level)
	save()

func use_swap() -> void:
	swaps = maxi(0, swaps - 1)
	save()

func add_swaps(n: int) -> void:
	swaps += n
	save()

# Seviye sonu ödülü: [[yazı, miktar], ...] (kazanma kartında satır satır gösterilir).
static func level_rewards(hard: bool, panda_hits: int, drops: int) -> Array:
	var r := [["Level complete", REWARD_LEVEL]]
	if hard:
		r.append(["Hard level", REWARD_HARD])
	if panda_hits == 0:
		r.append(["No panda hits", REWARD_NO_HITS])
	if drops == 0:
		r.append(["No drops", REWARD_NO_DROPS])
	return r

# --- bambu ve aksesuarlar ---

func add_bamboo(n: int) -> void:
	bamboo += n
	save()
	bamboo_changed.emit(bamboo)

func can_buy(id: String) -> bool:
	var a := Accessories.get_item(id)
	return not a.is_empty() and not Accessories.is_streak_item(a) and id not in owned and bamboo >= a["price"]

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	bamboo -= Accessories.get_item(id)["price"]
	owned.append(id)
	outfit[Accessories.get_item(id)["slot"]] = id
	save()
	bamboo_changed.emit(bamboo)
	return true

func is_worn(id: String) -> bool:
	return id != "" and id in outfit.values()

# Sahip olunan parçayı giy; zaten giyiliyse çıkar.
func toggle_wear(id: String) -> void:
	if id not in owned:
		return
	var slot: String = Accessories.get_item(id)["slot"]
	outfit[slot] = "" if outfit[slot] == id else id
	save()

# --- temalar ---

func sunset_unlocked() -> bool:
	return best_level > SUNSET_LEVEL

func theme_unlocked(t: String) -> bool:
	return t == "day" or (t == "sunset" and sunset_unlocked())

func set_theme(t: String) -> void:
	if theme_unlocked(t):
		theme = t
		save()

func new_theme_badge() -> bool:
	return sunset_unlocked() and not sunset_seen

# --- günlük seri ---

static func today() -> String:
	return Time.get_date_string_from_system()   # yerel tarih (gece yarısı oyuncunun saatine göre)

static func _days_between(a: String, b: String) -> int:
	var ua := Time.get_unix_time_from_datetime_string(a + "T12:00:00")
	var ub := Time.get_unix_time_from_datetime_string(b + "T12:00:00")
	return roundi((ub - ua) / 86400.0)

# Uygulama açıkken gün dönebilir: menü her açıldığında da çağrılır.
func refresh_day() -> void:
	var t := today()
	if last_day == t:
		return
	if last_day != "" and _days_between(last_day, t) == 1:
		streak += 1
	else:
		streak = 1
	last_day = t
	if not is_new:
		save()

func daily_available() -> bool:
	return claimed_day != today()

# Serinin 7 günlük döngüdeki günü (1..7).
func streak_day() -> int:
	return (maxi(streak, 1) - 1) % 7 + 1

func daily_preview() -> Dictionary:
	var day := streak_day()
	var r := {"day": day, "bamboo": 0, "crown": false, "extra_swaps": 0}
	if day == 7:
		if "crown" in owned:
			r["bamboo"] = STREAK_DAY7
		else:
			r["crown"] = true
	else:
		r["bamboo"] = STREAK_REWARDS[day - 1]
	if day in STREAK_BONUS_SWAP_DAYS:
		r["extra_swaps"] = 1
	r["refill"] = maxi(0, DAILY_SWAPS - swaps)   # bugün tamamlanacak Swap sayısı
	return r

func claim_daily() -> Dictionary:
	var r := daily_preview()
	if not daily_available():
		return r
	swaps = maxi(swaps, DAILY_SWAPS) + r["extra_swaps"]
	if r["crown"]:
		owned.append("crown")
		outfit["head"] = "crown"
	bamboo += r["bamboo"]
	claimed_day = today()
	save()
	bamboo_changed.emit(bamboo)
	return r
