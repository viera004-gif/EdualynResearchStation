extends CanvasLayer
## Small reusable startup selector, reopened with L. Does not pause mission clocks.
var localization: Node
var panel: PanelContainer
var buttons: Dictionary = {}
var opened := false
var previous_mouse_mode: int
func _ready() -> void:
	layer = 20
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	layout.add_child(title)
	localization.bind_label(title, "language.title")
	for code in localization.catalog.locales:
		var button := Button.new()
		button.text = localization.catalog.locales[code]
		button.add_theme_font_override("font", localization.font)
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size.y = 44
		button.pressed.connect(select.bind(code))
		layout.add_child(button)
		buttons[code] = button
	var resume := Label.new()
	resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(resume)
	localization.bind_label(resume, "language.resume")
	panel.hide()
func open() -> void:
	previous_mouse_mode = Input.mouse_mode
	opened = true
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buttons[localization.locale].grab_focus()
func close() -> void:
	opened = false
	panel.hide()
	Input.mouse_mode = previous_mouse_mode
func select(code: String) -> void:
	localization.set_locale(code)
	close()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("language"):
		if opened:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif opened and event.is_action_pressed("release_mouse"):
		close()
		get_viewport().set_input_as_handled()
