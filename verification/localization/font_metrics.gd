extends SceneTree
func _initialize() -> void:
	var font := ThemeDB.fallback_font
	print("FONT_HEIGHT ", font.get_height(36))
	for text in ["MODÜL BÖLMESİ 01", "GÜÇ BAĞLANTI ARIZASI", "[F] ANA SİSTEMİ", "FIELD DIAGNOSTICS", "POWER COUPLING FAILURE", "[F] RESTORE SYSTEM"]:
		print("FONT_WIDTH ", text, " = ", font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x)
	quit()
