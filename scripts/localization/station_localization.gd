extends Node
## Reusable UTF-8 catalogs backed by Godot Translation resources. No gameplay policy.
signal locale_changed(locale: String)
var locale := "tr"
var catalog: Dictionary
var translations: Dictionary = {}
var messages: Dictionary = {}
var bindings: Array[Dictionary] = []
var missing_keys: Array[String] = []
var font: Font = ThemeDB.fallback_font
func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://localization/catalog.json"))
	for code in catalog.locales:
		var translation := Translation.new()
		translation.set_locale(code)
		var merged: Dictionary = {}
		for pack in catalog.packs:
			var path: String = "res://localization/%s/%s.json" % [pack, code]
			var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			for key in entries:
				assert(not merged.has(key), "Duplicate localization key: " + key)
				merged[key] = entries[key]
				translation.add_message(key, entries[key])
		messages[code] = merged
		translations[code] = translation
	var expected: Array = messages[catalog.default_locale].keys()
	for code in messages:
		assert(messages[code].size() == expected.size(), "Incomplete locale: " + code)
		for key in expected:
			assert(messages[code].has(key), "Missing translation: " + code + ":" + key)
	locale = catalog.default_locale
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale=") and translations.has(arg.trim_prefix("--locale=")):
			locale = arg.trim_prefix("--locale=")
func text(key: String, values: Dictionary = {}) -> String:
	if key.is_empty():
		return ""
	var result: String = translations[locale].get_message(key)
	if result.is_empty():
		if not key in missing_keys:
			missing_keys.append(key)
			push_error("Missing localization key: " + key)
		return key
	return result.format(values)
func set_locale(code: String) -> void:
	if not translations.has(code) or locale == code:
		return
	locale = code
	refresh()
	locale_changed.emit(locale)
func bind_label(label: Node, key: String, values: Dictionary = {}) -> void:
	# Keep semantic keys even while the player switches language or state.
	for binding in bindings:
		if binding.node.get_ref() == label:
			if binding.key == key and binding.values == values:
				return
			binding.key = key
			binding.values = values.duplicate(true)
			label.set_meta("localization_key", key)
			label.set_meta("localization_parameters", values.duplicate(true))
			apply(label, key, values)
			return
	label.set_meta("localization_key", key)
	label.set_meta("localization_parameters", values.duplicate(true))
	bindings.append({"node": weakref(label), "key": key, "values": values.duplicate(true)})
	apply(label, key, values)
func apply(label: Node, key: String, values: Dictionary) -> void:
	if label is Label3D:
		if label.font != font:
			label.font = font
	else:
		if label.get_theme_font("font") != font:
			label.add_theme_font_override("font", font)
	# Resolve nested message parameters at display time, never into telemetry.
	var resolved := values.duplicate(true)
	for parameter in resolved:
		if resolved[parameter] is Dictionary and resolved[parameter].has("key"):
			resolved[parameter] = text(resolved[parameter].key)
	label.text = text(key, resolved)
func refresh() -> void:
	var live: Array[Dictionary] = []
	for binding in bindings:
		var label = binding.node.get_ref()
		if label != null:
			apply(label, binding.key, binding.values)
			live.append(binding)
	bindings = live
