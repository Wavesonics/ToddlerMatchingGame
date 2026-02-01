extends Node2D

var max_pairs: int = 18
var selected_pairs: int = 8

@onready var pairs_slider = %PairsSlider
@onready var pairs_label = %PairsLabel
@onready var theme_logo = %ThemeLogo

func _ready() -> void:
	load_theme_logo()
	max_pairs = count_available_images()
	pairs_slider.tick_count = max_pairs - 1
	pairs_slider.min_value = 2
	pairs_slider.max_value = max_pairs
	pairs_slider.value = min(8, max_pairs)
	selected_pairs = int(pairs_slider.value)
	update_label()

func count_available_images() -> int:
	var count = 0
	var cards_path = ""

	# Check if custom theme is set
	if GameSettings.custom_theme_path != "":
		cards_path = GameSettings.custom_theme_path + "/cards"
	else:
		cards_path = "res://cards"

	var dir = DirAccess.open(cards_path)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
				count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	return count

func _on_pairs_slider_value_changed(value: float) -> void:
	selected_pairs = int(value)
	update_label()

func update_label() -> void:
	var total_cards = selected_pairs * 2
	pairs_label.text = "Pairs: %d (%d cards)" % [selected_pairs, total_cards]

func _on_start_button_pressed() -> void:
	GameSettings.pairs_to_match = selected_pairs
	get_tree().change_scene_to_file("res://matching-game.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func validate_theme_directory(path: String) -> Dictionary:
	var result = {
		"valid": false,
		"error": "",
		"card_count": 0
	}

	# Check if directory exists
	if not DirAccess.dir_exists_absolute(path):
		result.error = "Directory does not exist"
		return result

	# Check for theme-logo.png
	var logo_path = path + "/theme-logo.png"
	if not FileAccess.file_exists(logo_path):
		result.error = "Missing theme-logo.png in the selected directory"
		return result

	# Check for cards/ subdirectory
	var cards_path = path + "/cards"
	if not DirAccess.dir_exists_absolute(cards_path):
		result.error = "Missing cards/ subdirectory in the selected directory"
		return result

	# Count PNG files in cards/
	var card_count = 0
	var dir = DirAccess.open(cards_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				card_count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	if card_count < 2:
		result.error = "Need at least 2 card images in cards/ subdirectory (found " + str(card_count) + ")"
		return result

	result.valid = true
	result.card_count = card_count
	return result

func _on_theme_button_pressed() -> void:
	%ThemeFileDialog.popup_centered()

func _on_theme_dialog_dir_selected(path: String) -> void:
	var validation = validate_theme_directory(path)

	if validation.valid:
		GameSettings.custom_theme_path = path
		GameSettings.save_settings()
		load_theme_logo()

		# Update max pairs based on available cards
		max_pairs = validation.card_count
		pairs_slider.tick_count = max_pairs - 1
		pairs_slider.max_value = max_pairs
		if selected_pairs > max_pairs:
			pairs_slider.value = max_pairs
			selected_pairs = max_pairs
			update_label()
	else:
		show_error_dialog(validation.error)

func load_theme_logo() -> void:
	var logo_path = ""
	const TARGET_SIZE = 400.0

	if GameSettings.custom_theme_path != "":
		logo_path = GameSettings.custom_theme_path + "/theme-logo.png"
	else:
		logo_path = "res://theme-logo.png"

	var texture = GameSettings.load_texture_from_path(logo_path)
	if texture:
		theme_logo.texture = texture
	else:
		# Fallback to built-in
		theme_logo.texture = load("res://theme-logo.png")

	# Scale to fixed 512x512 size
	if theme_logo.texture:
		var texture_size = theme_logo.texture.get_size()
		var scale_x = TARGET_SIZE / texture_size.x
		var scale_y = TARGET_SIZE / texture_size.y
		# Use the smaller scale to ensure the image fits within 512x512
		var uniform_scale = min(scale_x, scale_y)
		theme_logo.scale = Vector2(uniform_scale, uniform_scale)

func show_error_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Invalid Theme Directory"
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()
