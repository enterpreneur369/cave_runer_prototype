extends CharacterBody2D

enum MovementState {
	IDLE,
	RUN,
	UP_STAIRS
}

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

var current_state: MovementState = MovementState.IDLE

func _ready() -> void:
	_align_sprite_with_collider()

func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var on_ladder := _is_on_ladder()
	var at_ladder_top := _is_at_ladder_top()

	_update_state(input_x, input_y, on_ladder, at_ladder_top)
	_apply_state_movement(delta, input_x, input_y, at_ladder_top)

	if input_x != 0.0:
		animated_sprite.flip_h = input_x < 0.0

	move_and_slide()
	_apply_state_animation()

func _update_state(input_x: float, input_y: float, on_ladder: bool, at_ladder_top: bool) -> void:
	if on_ladder and (absf(input_y) > 0.01 or (input_x != 0.0 and at_ladder_top and input_y >= 0.0)):
		current_state = MovementState.UP_STAIRS
	elif absf(input_x) > 0.01:
		current_state = MovementState.RUN
	else:
		current_state = MovementState.IDLE

func _apply_state_movement(delta: float, input_x: float, input_y: float, at_ladder_top: bool) -> void:
	velocity.x = input_x * move_speed

	match current_state:
		MovementState.UP_STAIRS:
			var climb_input_y := input_y
			if input_x != 0.0 and input_y >= 0.0 and at_ladder_top:
				climb_input_y = -ladder_top_assist_factor
			velocity.y = climb_input_y * climb_speed
		MovementState.IDLE, MovementState.RUN:
			velocity.y += gravity * delta

func _apply_state_animation() -> void:
	match current_state:
		MovementState.UP_STAIRS:
			if animated_sprite.sprite_frames.has_animation("UpStairs"):
				_play_animation_if_needed("UpStairs")
			elif animated_sprite.sprite_frames.has_animation("Run"):
				_play_animation_if_needed("Run")
			else:
				_play_animation_if_needed("Idle")
		MovementState.RUN:
			if animated_sprite.sprite_frames.has_animation("Run"):
				_play_animation_if_needed("Run")
			else:
				_play_animation_if_needed("Idle")
		MovementState.IDLE:
			_play_animation_if_needed("Idle")

func _play_animation_if_needed(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

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
