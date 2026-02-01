extends Node2D

const CARD_SCENE = preload("res://card.tscn")

var cards: Array = []
var first_card = null
var second_card = null
var can_flip: bool = true
var matches_found: int = 0
var total_flips: int = 0
var pairs_count: int = 8
var grid_columns: int = 4
var grid_rows: int = 4

@onready var score_label = %ScoreLabel
@onready var flips_label = %FlipsLabel
@onready var grid_container = %GridContainer
@onready var victory_panel = %VictoryPanel
@onready var victory_label = %VictoryLabel
@onready var stats_label = %StatsLabel
@onready var match_sound = %MatchSound
@onready var victory_sound = %VictorySound
@onready var fireworks1 = %Fireworks1
@onready var fireworks2 = %Fireworks2
@onready var fireworks3 = %Fireworks3

func _ready() -> void:
	pairs_count = GameSettings.pairs_to_match
	setup_game()

func calculate_grid_dimensions(total_cards: int) -> Vector2i:
	# Try to make grid as square as possible
	var cols = int(ceil(sqrt(total_cards)))
	var rows = int(ceil(float(total_cards) / float(cols)))

	# Adjust to make more rectangular if needed
	while cols * rows > total_cards and rows > 1:
		if (cols - 1) * rows >= total_cards:
			cols -= 1
		else:
			break

	return Vector2i(cols, rows)

func setup_game() -> void:
	var card_images = load_card_images()

	if card_images.size() < pairs_count:
		push_error("Not enough images in the cards directory. Need at least " + str(pairs_count))
		return

	# Select N random images and duplicate them
	card_images.shuffle()
	var selected_images = card_images.slice(0, pairs_count)
	var game_cards = selected_images + selected_images
	game_cards.shuffle()

	# Calculate grid dimensions
	var total_cards = pairs_count * 2
	var dimensions = calculate_grid_dimensions(total_cards)
	grid_columns = dimensions.x
	grid_rows = dimensions.y
	grid_container.columns = grid_columns

	# Load back texture (use first image as back for now)
	var back_texture = load("res://card-back.png")

	# Create grid
	for i in range(total_cards):
		var card = CARD_SCENE.instantiate()
		card.setup(i, game_cards[i], back_texture)
		card.card_clicked.connect(_on_card_clicked)
		grid_container.add_child(card)
		cards.append(card)

	update_ui()

func load_card_images() -> Array:
	var images = []
	var dir = DirAccess.open("res://cards")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
				var texture = load("res://cards/" + file_name)
				if texture:
					images.append(texture)
			file_name = dir.get_next()
		dir.list_dir_end()

	return images

func _on_card_clicked(card) -> void:
	if not can_flip:
		return

	total_flips += 1
	update_ui()

	card.flip_up()

	if first_card == null:
		first_card = card
	elif second_card == null and card != first_card:
		second_card = card
		can_flip = false
		check_match()

func check_match() -> void:
	if first_card.front_texture == second_card.front_texture:
		match_sound.play()
		first_card.set_matched()
		second_card.set_matched()
		matches_found += 1
		update_ui()

		if matches_found == pairs_count:
			show_win_message()
	else:
		await get_tree().create_timer(1.5).timeout
		first_card.flip_down()
		second_card.flip_down()

	first_card = null
	second_card = null
	can_flip = true

func update_ui() -> void:
	score_label.text = "Matches: " + str(matches_found)
	flips_label.text = "Flips: " + str(total_flips)

func show_win_message() -> void:
	victory_sound.play()
	fireworks1.emitting = true
	fireworks2.emitting = true
	fireworks3.emitting = true
	victory_label.text = "Victory!"
	stats_label.text = "You found all %d matches in %d flips!" % [matches_found, total_flips]
	victory_panel.visible = true

func _on_end_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
