extends CharacterBody2D

@export var move_speed: float = 90.0
@export var gravity: float = 750.0
@export var climb_speed: float = 70.0
@export var ladder_source_id: int = -1
@export var ladder_atlas_coords: Array[Vector2i] = []
@export var ladder_top_assist_factor: float = 0.6
@export var sprite_height: float = 32.0
@export var sprite_ground_offset: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tile_map_layer: TileMapLayer = get_parent().get_node("TileMapLayer")

func _ready() -> void:
	_align_sprite_with_collider()

func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var on_ladder := _is_on_ladder()

	velocity.x = input_x * move_speed

	if on_ladder:
		var climb_input_y := input_y
		if input_x != 0.0 and input_y >= 0.0 and _is_at_ladder_top():
			climb_input_y = -ladder_top_assist_factor
		velocity.y = climb_input_y * climb_speed
	else:
		velocity.y += gravity * delta

	move_and_slide()

	_update_animation(Vector2(input_x, input_y))

func _update_animation(input_vector: Vector2) -> void:
	if input_vector.x != 0.0:
		animated_sprite.flip_h = input_vector.x < 0.0

	if input_vector.length() > 0.01:
		if animated_sprite.sprite_frames.has_animation("Run"):
			animated_sprite.play("Run")
		else:
			animated_sprite.play("Idle")
	else:
		animated_sprite.play("Idle")

func _is_on_ladder() -> bool:
	var sample_offsets := [Vector2(0, -6), Vector2.ZERO, Vector2(0, 6)]
	for offset: Vector2 in sample_offsets:
		if _is_ladder_at_offset(offset):
			return true
	return false

func _is_at_ladder_top() -> bool:
	return _is_ladder_at_offset(Vector2.ZERO) and not _is_ladder_at_offset(Vector2(0, -12))

func _is_ladder_at_offset(offset: Vector2) -> bool:
	var map_pos := tile_map_layer.local_to_map(tile_map_layer.to_local(global_position + offset))
	var source_id := tile_map_layer.get_cell_source_id(map_pos)
	if source_id == -1:
		return false

	if ladder_source_id >= 0 and source_id != ladder_source_id:
		return false

	if not ladder_atlas_coords.is_empty():
		return ladder_atlas_coords.has(tile_map_layer.get_cell_atlas_coords(map_pos))

	return _is_auto_ladder_cell(map_pos)

func _is_auto_ladder_cell(map_pos: Vector2i) -> bool:
	if _is_solid_cell(map_pos):
		return false

	var above := map_pos + Vector2i(0, -1)
	var below := map_pos + Vector2i(0, 1)
	return _is_non_solid_used_cell(above) or _is_non_solid_used_cell(below)

func _is_non_solid_used_cell(map_pos: Vector2i) -> bool:
	if tile_map_layer.get_cell_source_id(map_pos) == -1:
		return false
	return not _is_solid_cell(map_pos)

func _is_solid_cell(map_pos: Vector2i) -> bool:
	var tile_data := tile_map_layer.get_cell_tile_data(map_pos)
	if tile_data == null:
		return false
	return tile_data.get_collision_polygons_count(0) > 0

func _align_sprite_with_collider() -> void:
	var shape := collision_shape.shape
	var half_height: float

	if shape is RectangleShape2D:
		half_height = (shape as RectangleShape2D).size.y * 0.5
	elif shape is CircleShape2D:
		half_height = (shape as CircleShape2D).radius
	else:
		return

	var collider_bottom := collision_shape.position.y + half_height
	animated_sprite.position.y = collider_bottom - (sprite_height * 0.5) + sprite_ground_offset
