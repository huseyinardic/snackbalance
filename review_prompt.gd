class_name ReviewPrompt
extends Node

# Google Play'in uygulama içi değerlendirme penceresi (InappReview eklentisi).
# Seyrek sorar: en çok MAX_ASKS kez, aralarında en az MIN_DAYS gün. Önce
# "oyunu beğendin mi?" diye sorulmaz — yalnız memnun oyuncuyu yönlendirmek Play
# politikasına aykırı. Pencerenin gerçekten görünüp görünmeyeceğine Google karar
# verir (kendi kotası; kapalı test kullanıcılarına hiç göstermez).
# Android dışında hiçbir şey yapmaz. (Snack Balance ve Chameleon Dash'te aynı dosya.)

const SAVE_PATH := "user://review.cfg"
const MAX_ASKS := 3
const MIN_DAYS := 30

var _review: InappReview = null
var _busy := false
var _context := ""

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("InappReviewPlugin"):
		return
	_review = InappReview.new()
	add_child(_review)
	_review.review_info_generated.connect(func(): _review.launch_review_flow())
	_review.review_info_generation_failed.connect(func(): _fail("info"))
	_review.review_flow_launched.connect(func():
		_busy = false
		Analytics.log_event("review_flow_done", {"context": _context}))
	_review.review_flow_launch_failed.connect(func(): _fail("launch"))

func can_ask() -> bool:
	if _review == null or _busy:
		return false
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var asks := int(cfg.get_value("review", "asks", 0))
	var last := int(cfg.get_value("review", "last_unix", 0))
	return asks < MAX_ASKS and int(Time.get_unix_time_from_system()) - last >= MIN_DAYS * 86400

# context: analitik için kısa açıklama (ör. "level_win", "new_best")
func maybe_ask(context: String) -> void:
	if not can_ask():
		return
	_busy = true
	_context = context
	# Google göstermese de deneme sayılır: aynı oyuncuyu her fırsatta yoklamayalım
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("review", "asks", int(cfg.get_value("review", "asks", 0)) + 1)
	cfg.set_value("review", "last_unix", int(Time.get_unix_time_from_system()))
	cfg.save(SAVE_PATH)
	Analytics.log_event("review_prompt", {"context": context})
	_review.generate_review_info()

func _fail(stage: String) -> void:
	_busy = false
	Analytics.log_event("review_prompt_failed", {"context": _context, "stage": stage})
