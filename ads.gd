extends Node

# Autoload "Ads": AdMob (Poing Studios eklentisi) — onay (UMP/GDPR), geçiş ve
# ödüllü reklam. Oyun kodu yalnız şunları kullanır:
#   Ads.rewarded_ready()                 -> ödüllü düğmeyi göster/gizle
#   Ads.show_rewarded(func(earned): ...) -> izletip sonucu bildirir
#   Ads.level_won() / Ads.after_level(level, done)
#                                        -> kurallar uygunsa geçiş reklamı, sonra done()
# Mobil dışında (PC'de test) reklam yok: ödüllü hemen "izlendi" sayılır, geçiş atlanır.
# Akış Chameleon Dash'te sahada denenmiş olanın aynısı (callback sırası güvenilmez,
# pencere fokusu dönünce "reklam kapandı" kabul edilir, ödül biraz gecikebilir).

signal rewarded_changed   # ödüllü reklam hazır oldu / kullanıldı (düğmeleri yenilemek için)
signal consent_ready      # onay akışı bitti (menüdeki "Privacy" düğmesi gerekip gerekmediği artık belli)

const APP_TEST := false   # true: release build'de de Google test birimleri (mağaza öncesi deneme)

const INTERSTITIAL_ID := "ca-app-pub-4752797500144210/1960690130"
const REWARDED_ID := "ca-app-pub-4752797500144210/1111959540"
const INTERSTITIAL_ID_TEST := "ca-app-pub-3940256099942544/1033173712"   # Google resmi test
const REWARDED_ID_TEST := "ca-app-pub-3940256099942544/5224354917"
# Test cihazları (logcat'teki hashed id; Chameleon'da kullanılan telefonlar):
const TEST_DEVICES := ["0A19F3B168FC5DE628D41FE1E5BB333B", "D5B8A059081C01DFD1A8E0E2401DBAC3"]

# Geçiş reklamı kuralları: ilk seviyeler reklamsız (oyuncu oyunu sevsin), sonra
# en fazla 3 seviyede bir ve en az 90 sn arayla. Ödüllü reklam da sayacı sıfırlar
# (az önce reklam izleyene hemen bir tane daha gösterilmez).
const FIRST_AD_LEVEL := 8
const LEVELS_BETWEEN := 3
const MIN_GAP_MSEC := 90000
const RETRY_LOAD_SEC := 30.0      # yükleme başarısızsa bu kadar sonra tekrar dene
const REWARD_ASSUME_MS := 15000   # bu kadar izlendiyse ödül callback'i gelmese de ödül ver

var _mobile := false
var _initialized := false
var _ready_sdk := false           # MobileAds başlatması bitti (yalnız bundan sonra yükleme)
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _interstitial_cb := InterstitialAdLoadCallback.new()
var _rewarded_cb := RewardedAdLoadCallback.new()
var _full_screen_cb := FullScreenContentCallback.new()
var _levels_since_ad := 0
var _last_ad_msec := -MIN_GAP_MSEC

# geçiş reklamı durumu
var _inter_done := Callable()
var _inter_showing := false
# ödüllü reklam durumu
var _rw_active := false
var _rw_done := Callable()
var _rw_earned := false
var _rw_dismissed := false
var _rw_deadline := 0
var _rw_shown_msec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mobile = OS.get_name() == "Android" or OS.get_name() == "iOS"
	if not _mobile:
		return
	_interstitial_cb.on_ad_loaded = _on_interstitial_loaded
	_interstitial_cb.on_ad_failed_to_load = func(_e: LoadAdError): _retry_later(_load_interstitial)
	_full_screen_cb.on_ad_dismissed_full_screen_content = _finish_interstitial
	_full_screen_cb.on_ad_failed_to_show_full_screen_content = func(_e: AdError): _finish_interstitial()
	_full_screen_cb.on_ad_showed_full_screen_content = func(): _inter_showing = true
	_rewarded_cb.on_ad_loaded = _on_rewarded_loaded
	_rewarded_cb.on_ad_failed_to_load = func(_e: LoadAdError):
		_rewarded = null
		_retry_later(_load_rewarded)
	_request_consent()

func _process(_delta: float) -> void:
	if _rw_active:
		_try_resolve_rewarded()

# --- onay (GDPR / UMP): her yoldan _initialize'a çıkar ---

func _request_consent() -> void:
	var request := ConsentRequestParameters.new()
	if OS.is_debug_build():
		# test cihazında AB bölgesi taklit edilir: onay formu görülüp denenebilsin
		var dbg := ConsentDebugSettings.new()
		dbg.debug_geography = DebugGeography.Values.EEA
		for id in TEST_DEVICES:
			dbg.test_device_hashed_ids.append(id)
		request.consent_debug_settings = dbg
	UserMessagingPlatform.consent_information.update(request, _on_consent_info_updated, func(_e: FormError): _initialize())

func _on_consent_info_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, func(_e: FormError): _initialize())
	else:
		_initialize()

func _on_consent_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(func(_e: FormError): _initialize())
	else:
		_initialize()

func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_apply_analytics_consent()
	Analytics.consent_done()
	consent_ready.emit()
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_s): _ready_sdk = true
	MobileAds.initialize(on_init)
	var conf := RequestConfiguration.new()
	# alan Array[String]: tipsiz sabit doğrudan atanınca hata verip reklam yüklemeyi durduruyordu
	conf.test_device_ids.assign(TEST_DEVICES)   # bu telefonlarda release'de bile test reklamı
	MobileAds.set_request_configuration(conf)
	# Reklamlar yalnız MobileAds başlatması BİTİNCE yüklenir: erken yükleme yavaş telefonlarda
	# oyunu çökertiyordu ("MobileAds.initialize must be called before using the Google Mobile
	# Ads SDK" — moto g24, Galaxy A2 Core). Hızlı telefonda başlatma 0,1 sn'de bittiği için fark
	# edilmemişti.
	var waited := 0.0
	while not _ready_sdk and waited < 60.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_load_interstitial()
	_load_rewarded()

# Onay gerektirmeyen bölgelerde analitik açık. AB/İngiltere'de oyuncunun seçimi UMP'nin cihaza
# yazdığı TCF dizesinden okunur: eskiden oradaki herkes için kapalıydı (onay verse bile), AB'den
# gelen oyuncu hiç görünmüyordu. Debug build'de test cihazı AB taklit eder: TCF yolu telefonda
# denenebilir (onay formunda kabul / ret, logcat'te "TCF").
func _apply_analytics_consent() -> void:
	if OS.get_name() != "Android":
		return
	match UserMessagingPlatform.consent_information.get_consent_status():
		ConsentInformation.ConsentStatus.NOT_REQUIRED:
			Analytics.set_consent(true)
		ConsentInformation.ConsentStatus.REQUIRED, ConsentInformation.ConsentStatus.OBTAINED:
			_apply_tcf_consent()
		_:
			# UNKNOWN (ör. çevrimdışı): önceki açılıştaki kalıcı tercih geçerli kalsın
			if OS.is_debug_build():
				Analytics.set_consent(true)

# TCF amaçları (1'den başlar; dizenin i. karakteri i+1. amaç, "1" = onay). Google'ın onay
# modu eşlemesi: reklam depolama = 1, reklam kullanıcı verisi = 1 ve 7, kişiselleştirme = 3 ve 4.
# Analitik: 1 (cihazda bilgi saklama) ve ölçüm amaçlarından biri (8 içerik ölçümü, 9 kitle
# istatistiği). Dize boşsa (form kapatıldı / onay yok) hepsi reddedilmiş sayılır.
func _apply_tcf_consent() -> void:
	var p := _tcf_purposes()
	var has := func(n: int) -> bool:
		return p.length() >= n and p[n - 1] == "1"
	var analytics: bool = has.call(1) and (has.call(8) or has.call(9))
	Analytics.set_consent(analytics, has.call(1), has.call(1) and has.call(7), has.call(3) and has.call(4))
	print("TCF purposes='", p, "' analytics=", analytics)

# UMP, TCF dizesini uygulamanın varsayılan SharedPreferences'ına yazar ("<paket>_preferences").
func _tcf_purposes() -> String:
	if not Engine.has_singleton("AndroidRuntime"):
		return ""
	var ctx = Engine.get_singleton("AndroidRuntime").getApplicationContext()
	if ctx == null:
		return ""
	var prefs = ctx.getSharedPreferences(str(ctx.getPackageName()) + "_preferences", 0)
	if prefs == null:
		return ""
	var v = prefs.getString("IABTCF_PurposeConsents", "")
	return "" if v == null else str(v)

func _use_test_ids() -> bool:
	return OS.is_debug_build() or APP_TEST or OS.get_name() != "Android"

func _retry_later(loader: Callable) -> void:
	await get_tree().create_timer(RETRY_LOAD_SEC).timeout
	loader.call()

# AB/İngiltere'de Google, oyuncunun onay tercihini sonradan değiştirebileceği bir
# giriş noktası ister: gerekiyorsa menüde "Privacy" düğmesi gösterilir.
func privacy_options_required() -> bool:
	return _mobile and _initialized and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() 		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func show_privacy_options() -> void:
	if _mobile:
		# oyuncu tercihini değiştirdiyse analitik de hemen ona uysun
		UserMessagingPlatform.show_privacy_options_form(func(_e: FormError): _apply_analytics_consent())

# --- geçiş reklamı ---

func _load_interstitial() -> void:
	if not _ready_sdk:
		return
	var id := INTERSTITIAL_ID_TEST if _use_test_ids() else INTERSTITIAL_ID
	InterstitialAdLoader.new().load(id, AdRequest.new(), _interstitial_cb)

func _on_interstitial_loaded(ad: InterstitialAd) -> void:
	_interstitial = ad
	_interstitial.full_screen_content_callback = _full_screen_cb

# Her kazanılan seviyede çağrılır (geçiş reklamı sayacı).
func level_won() -> void:
	_levels_since_ad += 1

# Seviye geçilip "Next"e basılınca: kurallar uygunsa reklam, her durumda sonunda done().
func after_level(level: int, done: Callable) -> void:
	var ok := _mobile and _interstitial != null and level >= FIRST_AD_LEVEL \
		and _levels_since_ad >= LEVELS_BETWEEN and Time.get_ticks_msec() - _last_ad_msec >= MIN_GAP_MSEC \
		and not _rw_active and not _inter_done.is_valid()
	if not ok:
		done.call()
		return
	_inter_done = done
	_inter_showing = false
	_mark_ad_shown()
	_interstitial.show()   # referansı burada bırakma — callback'ler için canlı kalsın
	# birkaç saniyede ekrana gelmediyse bir şey ters gitti: oyuncuyu bekletme
	await get_tree().create_timer(4.0).timeout
	if _inter_done.is_valid() and not _inter_showing:
		_finish_interstitial()

func _finish_interstitial() -> void:
	if not _inter_done.is_valid():
		return
	var done := _inter_done
	_inter_done = Callable()
	_inter_showing = false
	_interstitial = null
	_load_interstitial()
	done.call()

func _mark_ad_shown() -> void:
	_levels_since_ad = 0
	_last_ad_msec = Time.get_ticks_msec()

# --- ödüllü reklam ---

func _load_rewarded() -> void:
	if not _ready_sdk:
		return
	var id := REWARDED_ID_TEST if _use_test_ids() else REWARDED_ID
	RewardedAdLoader.new().load(id, AdRequest.new(), _rewarded_cb)

func _on_rewarded_loaded(ad: RewardedAd) -> void:
	_rewarded = ad
	_rewarded.full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
	_rewarded.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_e: AdError):
		_rw_dismissed = true
		_rw_deadline = Time.get_ticks_msec()   # hemen, ödülsüz çöz
	_rewarded.full_screen_content_callback.on_ad_showed_full_screen_content = func():
		_rw_shown_msec = Time.get_ticks_msec()
	rewarded_changed.emit()

# Tam ekran reklam açık ya da sonucu bekleniyor: bu arada kart düğmeleri çalışmasın.
func busy() -> bool:
	return _rw_active or _inter_done.is_valid()

func rewarded_ready() -> bool:
	return not _mobile or (_rewarded != null and not _rw_active)

# done(earned: bool). false dönerse reklam hazır değildi (done çağrılmaz).
func show_rewarded(done: Callable) -> bool:
	if not _mobile:
		done.call(true)
		return true
	if _rewarded == null or _rw_active or _inter_done.is_valid():
		return false
	_rw_active = true
	_rw_done = done
	_rw_earned = false
	_rw_dismissed = false
	_rw_deadline = 0
	_rw_shown_msec = 0
	_mark_ad_shown()
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item): _rw_earned = true
	_rewarded.show(listener)
	rewarded_changed.emit()
	_rewarded_safety_timeout()
	return true

# Ödül callback'i dismiss'ten önce ya da sonra gelebilir: dismiss'ten sonra kısa süre bekle.
func _on_rewarded_dismissed() -> void:
	_rw_dismissed = true
	if _rw_deadline == 0:
		_rw_deadline = Time.get_ticks_msec() + 2500

# Tam ekran reklam kapanınca uygulama fokusu geri döner — dismiss callback'i
# gelmese bile güvenilir "reklam bitti" işareti (reklam açıkken hiç tetiklenmez).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if _rw_active:
			_on_rewarded_dismissed()

func _rewarded_safety_timeout() -> void:
	await get_tree().create_timer(120.0).timeout
	if _rw_active and get_window().has_focus():
		_rw_dismissed = true
		_rw_deadline = Time.get_ticks_msec()

func _try_resolve_rewarded() -> void:
	if not _rw_dismissed:
		return   # reklam ekrandan gitmeden oyuna dönme
	var deadline_passed := _rw_deadline > 0 and Time.get_ticks_msec() >= _rw_deadline
	if not _rw_earned and not deadline_passed:
		return
	var watched := _rw_shown_msec > 0 and Time.get_ticks_msec() - _rw_shown_msec >= REWARD_ASSUME_MS
	var earned := _rw_earned or watched
	var done := _rw_done
	_rw_active = false
	_rw_done = Callable()
	_rewarded = null
	_load_rewarded()
	rewarded_changed.emit()
	if done.is_valid():
		done.call(earned)
