extends Node2D

signal card_clicked(card)

var card_id: int = -1
var is_face_up: bool = false
var is_matched: bool = false
var front_texture: Texture2D
var back_texture: Texture2D
var is_flipping: bool = false
var setup_complete: bool = false
var card_size: Vector2 = Vector2(150, 150)

@onready var card_3d = %Card3D
@onready var front_sprite = %FrontSprite
@onready var back_sprite = %BackSprite
@onready var viewport = %SubViewport
@onready var card_background = %CardBackground
@onready var match_particles = %MatchParticles
@onready var flip_sound = %FlipSound
@onready var card_button = $CardButton
@onready var viewport_container = $SubViewportContainer

func _ready() -> void:
	# Ensure each card has its own world
	viewport.own_world_3d = true

	# Duplicate the material so each card has its own instance
	var material = card_background.get_surface_override_material(0)
	if material:
		card_background.set_surface_override_material(0, material.duplicate())

	# Apply stored textures if setup was called before ready
	if front_texture:
		front_sprite.texture = front_texture
		if back_texture:
			back_sprite.texture = back_texture
			back_sprite.visible = true
		else:
			back_sprite.visible = false
		card_3d.rotation_degrees.y = 0

	# Apply stored card size
	_apply_card_size()
	setup_complete = true

func set_card_size(size: Vector2) -> void:
	card_size = size
	if setup_complete:
		_apply_card_size()

func _apply_card_size() -> void:
	# Resize button to match
	card_button.position = Vector2.ZERO
	card_button.size = card_size
	# Resize SubViewportContainer
	viewport_container.position = Vector2.ZERO
	viewport_container.size = card_size
	# Update SubViewport resolution
	viewport.size = Vector2i(card_size)

func setup(id: int, front: Texture2D, back: Texture2D) -> void:
	card_id = id
	front_texture = front
	back_texture = back
	is_face_up = false
	is_matched = false

	# If already ready, apply textures immediately
	if setup_complete:
		front_sprite.texture = front_texture
		if back_texture:
			back_sprite.texture = back_texture
			back_sprite.visible = true
		else:
			back_sprite.visible = false
		card_3d.rotation_degrees.y = 0

func flip_up() -> void:
	if not is_matched and not is_flipping and setup_complete:
		is_face_up = true
		flip_sound.play()
		animate_flip(180.0)

func flip_down() -> void:
	if not is_matched and not is_flipping and setup_complete:
		is_face_up = false
		flip_sound.play()
		animate_flip(0.0)

func animate_flip(target_rotation: float) -> void:
	is_flipping = true
	var tween = create_tween()
	tween.tween_property(card_3d, "rotation_degrees:y", target_rotation, 0.3).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	is_flipping = false

func set_matched() -> void:
	is_matched = true
	is_face_up = true
	celebrate_match()

func celebrate_match() -> void:
	# Trigger particle effect
	match_particles.emitting = true

	# Animate glow
	var material = card_background.get_surface_override_material(0) as ShaderMaterial
	if material:
		var tween = create_tween()
		tween.tween_property(material, "shader_parameter/glow_intensity", 0.6, 0.3)
		tween.tween_property(material, "shader_parameter/glow_intensity", 0.2, 0.5)

func _on_card_button_pressed() -> void:
	if not is_face_up and not is_matched and not is_flipping and setup_complete:
		card_clicked.emit(self)
