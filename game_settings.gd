extends Node

const CONFIG_PATH = "user://settings.cfg"

var pairs_to_match: int = 8
var custom_theme_path: String = ""

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("theme", "custom_theme_path", custom_theme_path)
	var err = config.save(CONFIG_PATH)
	if err != OK:
		push_error("Failed to save settings: " + str(err))

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		custom_theme_path = config.get_value("theme", "custom_theme_path", "")
		# Validate that the path still exists
		if custom_theme_path != "" and not DirAccess.dir_exists_absolute(custom_theme_path):
			push_warning("Saved theme path no longer exists: " + custom_theme_path)
			custom_theme_path = ""
			save_settings()

func load_texture_from_path(path: String) -> Texture2D:
	# Check if it's a resource path
	if path.begins_with("res://"):
		return load(path)

	# Otherwise, load from filesystem
	if FileAccess.file_exists(path):
		var image = Image.new()
		var err = image.load(path)
		if err == OK:
			return ImageTexture.create_from_image(image)
		else:
			push_error("Failed to load image from " + path + ": " + str(err))

	return null
