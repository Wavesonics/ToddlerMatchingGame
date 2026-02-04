extends Node2D

var max_pairs: int = 18
var selected_pairs: int = 8

@onready var pairs_slider = %PairsSlider
@onready var pairs_label = %PairsLabel
@onready var theme_logo = %ThemeLogo

var _file_picker: AndroidFilePicker = null

func _ready() -> void:
	# Setup file picker
	_file_picker = AndroidFilePicker.new()
	_file_picker.directory_selected.connect(_on_directory_selected)
	_file_picker.selection_cancelled.connect(_on_selection_cancelled)
	add_child(_file_picker)

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

	# Check if custom theme is set
	if GameSettings.custom_theme_path != "":
		# For custom themes, use directory listing (only works on filesystem paths)
		var cards_path = GameSettings.custom_theme_path + "/cards"
		var dir = DirAccess.open(cards_path)

		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()

			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
					count += 1
				file_name = dir.get_next()
			dir.list_dir_end()
	else:
		# For built-in cards, use sequential naming (works in exported builds)
		# Try to load card_00.png, card_01.png, etc. until one doesn't exist
		var i = 0
		while true:
			var card_path = "res://cards/card_%02d.png" % i
			if ResourceLoader.exists(card_path):
				count += 1
				i += 1
			else:
				break

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
	if _file_picker:
		_file_picker.open_directory_picker()
	else:
		show_error_dialog("File picker not initialized")

func _on_directory_selected(path: String) -> void:
	var validation = validate_theme_directory(path)

	if validation.valid:
		# Import theme to app's private directory
		var import_result = import_theme_to_user_dir(path)
		if import_result.success:
			GameSettings.custom_theme_path = "user://themes/custom"
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

			show_success_dialog("Theme imported successfully! Found " + str(validation.card_count) + " card images.")
		else:
			show_error_dialog("Failed to import theme: " + import_result.error)
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

func import_theme_to_user_dir(source_path: String) -> Dictionary:
	var result = {
		"success": false,
		"error": ""
	}

	var dest_path = "user://themes/custom"

	# Create destination directories
	if not DirAccess.dir_exists_absolute("user://themes"):
		var err = DirAccess.make_dir_absolute("user://themes")
		if err != OK:
			result.error = "Failed to create themes directory: " + str(err)
			return result

	# Remove existing custom theme directory if it exists
	if DirAccess.dir_exists_absolute(dest_path):
		remove_directory_recursive(dest_path)

	# Create new custom theme directory
	var err = DirAccess.make_dir_absolute(dest_path)
	if err != OK:
		result.error = "Failed to create custom theme directory: " + str(err)
		return result

	# Copy theme-logo.png
	var logo_src = source_path + "/theme-logo.png"
	var logo_dest = dest_path + "/theme-logo.png"
	err = copy_file(logo_src, logo_dest)
	if err != OK:
		result.error = "Failed to copy theme-logo.png: " + str(err)
		return result

	# Create cards subdirectory
	var cards_dest = dest_path + "/cards"
	err = DirAccess.make_dir_absolute(cards_dest)
	if err != OK:
		result.error = "Failed to create cards directory: " + str(err)
		return result

	# Copy all card images
	var cards_src = source_path + "/cards"
	var dir = DirAccess.open(cards_src)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var src_file = cards_src + "/" + file_name
				var dest_file = cards_dest + "/" + file_name
				err = copy_file(src_file, dest_file)
				if err != OK:
					result.error = "Failed to copy " + file_name + ": " + str(err)
					return result
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		result.error = "Failed to open source cards directory"
		return result

	result.success = true
	return result

func copy_file(source: String, dest: String) -> int:
	var source_file = FileAccess.open(source, FileAccess.READ)
	if not source_file:
		return FileAccess.get_open_error()

	var dest_file = FileAccess.open(dest, FileAccess.WRITE)
	if not dest_file:
		return FileAccess.get_open_error()

	dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	return OK

func remove_directory_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			var file_path = path + "/" + file_name
			if dir.current_is_dir():
				remove_directory_recursive(file_path)
			else:
				DirAccess.remove_absolute(file_path)
			file_name = dir.get_next()
		dir.list_dir_end()

		DirAccess.remove_absolute(path)

func _on_reset_theme_button_pressed() -> void:
	# Clear the custom theme
	GameSettings.custom_theme_path = ""
	GameSettings.save_settings()

	# Reload the theme logo to default
	load_theme_logo()

	# Update max pairs based on default card count
	max_pairs = count_available_images()
	pairs_slider.tick_count = max_pairs - 1
	pairs_slider.max_value = max_pairs
	if selected_pairs > max_pairs:
		pairs_slider.value = max_pairs
		selected_pairs = max_pairs
		update_label()

func show_error_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Invalid Theme Directory"
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()

func show_success_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Success"
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()

func _on_selection_cancelled() -> void:
	print("File selection cancelled")
