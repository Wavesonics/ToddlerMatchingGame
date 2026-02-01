extends Node2D

var max_pairs: int = 18
var selected_pairs: int = 8

@onready var pairs_slider = %PairsSlider
@onready var pairs_label = %PairsLabel

func _ready() -> void:
	max_pairs = 10
	pairs_slider.tick_count = 10
	pairs_slider.min_value = 2
	pairs_slider.max_value = max_pairs
	pairs_slider.value = 8
	selected_pairs = int(pairs_slider.value)
	update_label()

func count_available_images() -> int:
	var count = 0
	var dir = DirAccess.open("res://cards")

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
