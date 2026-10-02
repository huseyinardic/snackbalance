extends Node

# Firebase Analytics için ince sarmalayıcı (autoload: Analytics).
# Eklenti yalnızca Android export'unda var; masaüstünde/editörde bütün
# çağrılar sessizce hiçbir şey yapmaz, oyun kodu platform kontrolü yapmak zorunda kalmaz.
#
# Toplama, export'taki "privacy-safe defaults" ile kapalı başlar; ads.gd UMP onay
# akışı bitince set_consent() ile açar/kapatır. Bu tercih cihazda kalıcıdır.
# (Chameleon Dash'teki dosyanın aynısı.)

const MAX_QUEUE := 20

var _core: Object = null
var _fa: Object = null
var _ready_to_log := false
var _queue: Array = []   # analytics hazır olmadan gelen olaylar

func _ready() -> void:
	if Engine.has_singleton("GodotxFirebaseAnalytics"):
		_fa = Engine.get_singleton("GodotxFirebaseAnalytics")
		_fa.analytics_initialized.connect(_on_analytics_initialized)
	if Engine.has_singleton("GodotxFirebaseCore"):
		_core = Engine.get_singleton("GodotxFirebaseCore")
		_core.core_initialized.connect(_on_core_initialized)
		_core.initialize()

func _on_core_initialized(success: bool) -> void:
	if success and _fa:
		_fa.initialize()

func _on_analytics_initialized(success: bool) -> void:
	_ready_to_log = success
	if success:
		for e in _queue:
			_fa.log_event(e[0], e[1])
	_queue.clear()

func set_consent(granted: bool) -> void:
	if _fa == null:
		return
	var state := "granted" if granted else "denied"
	_fa.set_consent({
		"analytics_storage": state,
		"ad_storage": state,
		"ad_user_data": state,
		"ad_personalization": state,
	})
	_fa.set_analytics_collection_enabled(granted)

# Parametre değerleri int / float / String olabilir (Firebase bool desteklemez).
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if _fa == null:
		return
	if _ready_to_log:
		_fa.log_event(event_name, params)
	elif _queue.size() < MAX_QUEUE:
		_queue.append([event_name, params])
