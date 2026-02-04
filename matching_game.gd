extends Control

const CARD_SCENE = preload("res://card.tscn")

const MARGIN_TOP = 80
const MARGIN_BOTTOM = 20
const MARGIN_LEFT = 50
const MARGIN_RIGHT = 50
const CARD_GAP = 4

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
@onready var card_container = %CardContainer
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
	position_fireworks()
	get_tree().root.size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	if cards.size() == 0:
		return
	var layout = calculate_card_layout(cards.size())
	for i in range(cards.size()):
		position_card(cards[i], i, layout)
	position_fireworks()

func position_fireworks() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	fireworks1.position = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.7)
	fireworks2.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.6)
	fireworks3.position = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.7)

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

func calculate_card_layout(total_cards: int) -> Dictionary:
	var viewport_size = get_viewport().get_visible_rect().size

	# Available space for cards
	var available_width = viewport_size.x - MARGIN_LEFT - MARGIN_RIGHT
	var available_height = viewport_size.y - MARGIN_TOP - MARGIN_BOTTOM

	# Calculate grid dimensions
	var grid_dims = calculate_grid_dimensions(total_cards)
	var cols = grid_dims.x
	var rows = grid_dims.y

	# Card size considering gaps
	var card_width = (available_width - (cols - 1) * CARD_GAP) / cols
	var card_height = (available_height - (rows - 1) * CARD_GAP) / rows

	# Keep cards square, use smaller dimension
	var card_size = min(card_width, card_height)

	# Calculate grid offset to center it
	var grid_width = cols * card_size + (cols - 1) * CARD_GAP
	var grid_height = rows * card_size + (rows - 1) * CARD_GAP
	var start_x = MARGIN_LEFT + (available_width - grid_width) / 2
	var start_y = MARGIN_TOP + (available_height - grid_height) / 2

	return {
		"card_size": Vector2(card_size, card_size),
		"start_pos": Vector2(start_x, start_y),
		"cols": cols,
		"rows": rows
	}

func position_card(card: Node2D, index: int, layout: Dictionary) -> void:
	var col = index % layout.cols
	var row = index / layout.cols
	var x = layout.start_pos.x + col * (layout.card_size.x + CARD_GAP)
	var y = layout.start_pos.y + row * (layout.card_size.y + CARD_GAP)
	card.position = Vector2(x, y)
	card.set_card_size(layout.card_size)

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

	# Calculate grid dimensions and layout
	var total_cards = pairs_count * 2
	var dimensions = calculate_grid_dimensions(total_cards)
	grid_columns = dimensions.x
	grid_rows = dimensions.y

	var layout = calculate_card_layout(total_cards)

	# Load back texture if it exists
	var back_texture = null
	if FileAccess.file_exists("res://card-back.png"):
		back_texture = load("res://card-back.png")

	# Create cards
	for i in range(total_cards):
		var card = CARD_SCENE.instantiate()
		card.setup(i, game_cards[i], back_texture)
		card.card_clicked.connect(_on_card_clicked)
		card_container.add_child(card)
		position_card(card, i, layout)
		cards.append(card)

	update_ui()

func load_card_images() -> Array:
	var images = []
	var use_custom_theme = GameSettings.custom_theme_path != ""

	if use_custom_theme:
		# For custom themes, use directory listing (only works on filesystem paths)
		var cards_path = GameSettings.custom_theme_path + "/cards"
		var dir = DirAccess.open(cards_path)

		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()

			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
					var full_path = cards_path + "/" + file_name
					var texture = GameSettings.load_texture_from_path(full_path)
					if texture:
						images.append(texture)
				file_name = dir.get_next()
			dir.list_dir_end()
	else:
		# For built-in cards, use sequential naming (works in exported builds)
		# Try to load card_00.png, card_01.png, etc. until one doesn't exist
		var i = 0
		while true:
			var card_path = "res://cards/card_%02d.png" % i
			if ResourceLoader.exists(card_path):
				var texture = load(card_path)
				if texture:
					images.append(texture)
				i += 1
			else:
				break

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
