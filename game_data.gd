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
const STREAK_BONUS_SWAP_DAYS := [3, 7]  # haftanın 3. ve 7. günü (her hafta)
# 7. günden sonra yol sürer (2026-11-19): 8–14. gün STREAK_WEEK2, 15. günden sonra her gün
# STREAK_LATE, her 7. gün (14, 21, 28…) STREAK_BIG. Haftalık: 1. hafta 380 (taçla), 2. hafta 650,
# sonra 680. Aksesuarlar toplam 3.030 bambu: her gün dönen oyuncu ~4–5 haftada hepsini alır.
const STREAK_WEEK2 := [50, 60, 70, 80, 90, 100]
const STREAK_LATE := 80
const STREAK_BIG := 200
const SUNSET_LEVEL := 14         # bu seviyeyi geçince Sunset teması açılır (ilk "Hard level")

# Seviye ödülleri
const REWARD_LEVEL := 10
const REWARD_HARD := 10
const REWARD_NO_HITS := 5
const REWARD_NO_DROPS := 5
const CHAPTER_SIZE := 10          # menüdeki bölüm şeridi: 10 seviye
const CHAPTER_CHEST := 50         # bölümün son seviyesini kazanınca sandık (bambu)
# Galibiyet serisi: art arda kazanılan seviye. Kaybedince sıfırlanır, "Continue" reklamı
# korur. Kazanma ödülüne tavanlı bonus (indeks = bu galibiyetle ulaşılan seri; 5+ = son
# değer) — tüm ödülü katlamak ekonomiyi bozardı. Rozet/uyarılar bonus başlayınca görünür.
const WIN_STREAK_BONUS := [0, 0, 5, 10, 15, 20]
const WIN_STREAK_SHOW := 2

var level := 1
var best_level := 1              # ulaşılan en yüksek seviye (tema kilidi buna bakar)
var swaps := SWAP_START
var bamboo := 0
var owned: Array = []
var outfit := {"head": "", "face": "", "neck": "", "mouth": ""}
var theme := "day"
var streak := 0
var win_streak := 0              # art arda kazanılan seviye (günlük giriş serisi "streak"ten ayrı)
var race_id := 0                 # Panda Yarışı (race.gd): kaçıncı yarış, başlangıcı, puanı
var race_start := 0              # unix sn; 0 = henüz yarış yok
var race_points := 0
var race_streak := 0             # yarış başladıktan sonra art arda kazanılan seviye: yarış çarpanı bundan
                                 # (genel seriden değil: 1-4'ü art arda geçen yeni oyuncu yarışa x8 giriyordu)
var _race_streak_lost := 0       # kayıpta sıfırlanan yarış serisi (Continue geri yazar)
var race_seen := false           # yarış paneli (tanıtım) bir kez açıldı mı
var last_day := ""               # en son oynanan gün (seri)
var claimed_day := ""
var wins_today := 0               # gün içindeki galibiyet ("yarın" sözü 3.'sünde)
var wins_date := ""
const PROMISE_WINS := 3            # günlük ödülün en son alındığı gün
var sunset_seen := false         # "yeni tema" kırmızı noktası görüldü mü
var tutorial_done := false      # ilk seviyedeki sürükle-bırak eli artık gösterilmez
var panda_tip_done := false     # 2. seviyedeki "Not on the panda!" uyarısı artık gösterilmez
var apples_seen := 0             # oyuncunun önüne gelen elma sayısı (Swap dersi 2. elmada)
var swap_taught := false         # Swap bir kez zorla öğretildi (2026-11-16)
var is_new := true               # kayıt dosyası yoktu: ilk açılış (menü atlanır, direkt 1. seviye)
var music_on := true
var sfx_on := true
var vibration_on := true

func _ready() -> void:
	I18n.setup()                     # çeviriler ilk iş: sonraki her metin telefonun dilinde
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
	# alanın olmadığı eski kayıtlar: 1. seviyeyi geçmiş oyuncu oyunu zaten biliyor
	tutorial_done = cfg.get_value("progress", "tutorial_done", best_level > 1)
	panda_tip_done = cfg.get_value("progress", "panda_tip_done", best_level > 2)
	apples_seen = maxi(0, int(cfg.get_value("progress", "apples_seen", 0)))
	# alanın olmadığı eski kayıt: elma bölümlerini (8-9) geçmiş oyuncuya ders yeniden gösterilmez
	swap_taught = cfg.get_value("progress", "swap_taught", best_level >= 10)
	swaps = maxi(0, int(cfg.get_value("progress", "swaps", SWAP_START)))
	win_streak = maxi(0, int(cfg.get_value("progress", "win_streak", 0)))
	race_id = int(cfg.get_value("race", "id", 0))
	race_start = int(cfg.get_value("race", "start", 0))
	race_points = maxi(0, int(cfg.get_value("race", "points", 0)))
	race_streak = maxi(0, int(cfg.get_value("race", "streak", 0)))
	race_seen = cfg.get_value("race", "seen", false)
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
	wins_today = int(cfg.get_value("daily", "wins_today", 0))
	wins_date = str(cfg.get_value("daily", "wins_date", ""))
	music_on = cfg.get_value("settings", "music", true)
	sfx_on = cfg.get_value("settings", "sfx", true)
	vibration_on = cfg.get_value("settings", "vibration", true)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "best_level", best_level)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "panda_tip_done", panda_tip_done)
	cfg.set_value("progress", "apples_seen", apples_seen)
	cfg.set_value("progress", "swap_taught", swap_taught)
	cfg.set_value("progress", "swaps", swaps)
	cfg.set_value("progress", "win_streak", win_streak)
	cfg.set_value("race", "id", race_id)
	cfg.set_value("race", "start", race_start)
	cfg.set_value("race", "points", race_points)
	cfg.set_value("race", "streak", race_streak)
	cfg.set_value("race", "seen", race_seen)
	cfg.set_value("economy", "bamboo", bamboo)
	cfg.set_value("economy", "owned", owned)
	for slot in Accessories.SLOTS:
		cfg.set_value("economy", slot, outfit[slot])
	cfg.set_value("economy", "theme", theme)
	cfg.set_value("economy", "sunset_seen", sunset_seen)
	cfg.set_value("daily", "streak", streak)
	cfg.set_value("daily", "last_day", last_day)
	cfg.set_value("daily", "claimed_day", claimed_day)
	cfg.set_value("daily", "wins_today", wins_today)
	cfg.set_value("daily", "wins_date", wins_date)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	cfg.set_value("settings", "vibration", vibration_on)
	cfg.save(SAVE_PATH)
	is_new = false

func vibrate(ms: int) -> void:
	if vibration_on:
		Input.vibrate_handheld(ms)

# --- ilerleme ---

func complete_tutorial() -> void:
	if tutorial_done:
		return
	tutorial_done = true
	save()

func complete_panda_tip() -> void:
	if panda_tip_done:
		return
	panda_tip_done = true
	save()

func set_level(n: int) -> void:
	level = maxi(1, n)
	best_level = maxi(best_level, level)
	save()

static func win_streak_bonus(n: int) -> int:
	return WIN_STREAK_BONUS[clampi(n, 0, WIN_STREAK_BONUS.size() - 1)]

func add_win() -> void:
	win_streak += 1
	race_streak += 1
	save()

# Kaybedince seri hemen sıfırlanır (kart açıkken uygulama kapatılsa da kaybolur);
# Continue dönen değeri restore_win_streak ile geri yazar.
func break_win_streak() -> int:
	var lost := win_streak
	_race_streak_lost = race_streak
	if lost > 0 or race_streak > 0:
		win_streak = 0
		race_streak = 0
		save()
	return lost

func restore_win_streak(n: int) -> void:
	win_streak = maxi(win_streak, n)
	race_streak = maxi(race_streak, _race_streak_lost)
	save()

# --- Panda Yarışı ---

func start_race(at: int) -> void:
	race_id += 1
	race_start = at
	race_points = 0
	race_streak = 0
	save()

func add_race_points(n: int) -> void:
	race_points += n
	save()

# Biten yarışın ödülü (Race.prize sonucu): bambu, 1.lik madalyası giyilir; yeni yarış başlar.
func claim_race(prize: Dictionary, next_start: int) -> void:
	if prize["medal"] and Race.MEDAL not in owned:
		owned.append(Race.MEDAL)
		outfit["neck"] = Race.MEDAL
	bamboo += prize["bamboo"]
	start_race(next_start)
	bamboo_changed.emit(bamboo)

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
	return not a.is_empty() and not Accessories.is_reward_item(a) and id not in owned and bamboo >= a["price"]

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
	# Hedgy gibi cezasız (2026-11-19): gün atlanırsa seri sıfırlanmaz, yol bekler (sıradaki gün)
	if last_day != "":
		streak += 1
	else:
		streak = 1
	last_day = t
	if not is_new:
		save()

# Gün içinde kazanılan seviye (kazanma kartında "yarın" sözünün zamanı).
func count_win() -> int:
	if wins_date != today():
		wins_date = today()
		wins_today = 0
	wins_today += 1
	save()
	return wins_today

# Kazanma kartındaki söz: bugünkü hediye alınmadıysa "bekliyor", alındıysa yarınki.
func promise_text() -> String:
	if daily_available():
		return "Your daily gift is waiting 🎁"
	var day := streak + 1
	if crown_day(day):
		return "Tomorrow: the Golden Crown! 👑"
	return tr("Tomorrow: +%d bamboo 🎋") % reward_for(day)

func daily_available() -> bool:
	return claimed_day != today()

# Serinin 7 günlük döngüdeki günü (1..7).
func streak_day() -> int:
	return (maxi(streak, 1) - 1) % 7 + 1

# Hediye yolunun d. gününün bambusu (1'den başlar, sonsuz).
static func reward_for(d: int) -> int:
	if d <= STREAK_REWARDS.size():
		return STREAK_REWARDS[d - 1]
	if d == 7:
		return STREAK_DAY7
	if d <= 7 + STREAK_WEEK2.size():
		return STREAK_WEEK2[d - 8]
	return STREAK_BIG if d % 7 == 0 else STREAK_LATE

# Taç: ilk 7. gün (ya da taç hâlâ yoksa sonraki her 7. gün).
func crown_day(d: int) -> bool:
	return d % 7 == 0 and "crown" not in owned

func daily_preview() -> Dictionary:
	var day := maxi(streak, 1)                    # yolun günü (7'de bitmez)
	var r := {"day": day, "bamboo": 0, "crown": false, "extra_swaps": 0}
	if crown_day(day):
		r["crown"] = true
	else:
		r["bamboo"] = reward_for(day)
	if (day - 1) % 7 + 1 in STREAK_BONUS_SWAP_DAYS:
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
