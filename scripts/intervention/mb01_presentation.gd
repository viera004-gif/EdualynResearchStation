extends CanvasLayer
## MB01 narrative channel and short-lived interaction notices.
var bay: Node
var blackout: ColorRect
var radio: Label
var notice: Label
var objective: Label
var radio_tween: Tween
var notice_tween: Tween
var objective_tween: Tween

func build(world: Node) -> void:
	bay = world
	layer = 8
	var ui := Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radio = centered_label(ui, .73, 20)
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = centered_label(ui, .60, 19)
	objective = centered_label(ui, .19, 25)
	blackout = ColorRect.new()
	blackout.color = Color.BLACK
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(blackout)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boot := centered_label(blackout, .44, 24)
	bay.localization.bind_label(boot, "mb01.boot")
	boot.show()

func centered_label(parent: Control, vertical: float, font_size: int) -> Label:
	var label: Label = bay.hud_label("", Vector2.ZERO, font_size, Color(.78, .88, .94))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(.01, .02, .025, .92))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	label.anchor_left = .16
	label.anchor_right = .84
	label.anchor_top = vertical
	label.anchor_bottom = vertical
	label.offset_left = 0
	label.offset_right = 0
	label.hide()
	return label

func boot_sequence() -> void:
	await get_tree().create_timer(1.1).timeout
	var fade := create_tween()
	fade.tween_property(blackout, "modulate:a", 0.0, .52)
	await fade.finished
	blackout.queue_free()

func assign() -> void:
	speak("mb01.radio.engineer", 9.0)
	if objective_tween != null:
		objective_tween.kill()
	objective_tween = present(objective, "mb01.objective", 5.5)

func speak(key: String, seconds: float) -> Tween:
	if radio_tween != null:
		radio_tween.kill()
	radio_tween = present(radio, key, seconds)
	return radio_tween

func teach(key: String, seconds: float) -> void:
	if notice_tween != null:
		notice_tween.kill()
	notice_tween = present(notice, key, seconds)

func present(label: Label, key: String, seconds: float) -> Tween:
	bay.localization.bind_label(label, key)
	label.modulate.a = 1
	label.show()
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(label, "modulate:a", 0.0, .65)
	tween.tween_callback(label.hide)
	return tween
