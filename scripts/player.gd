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
@export var horizontal_climb_sprite_offset: float = 8.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tile_map_layer: TileMapLayer = get_parent().get_node("TileMapLayer")

var current_state: MovementState = MovementState.IDLE
var base_sprite_y: float = 0.0
var was_on_horizontal_bar: bool = false

func _ready() -> void:
	_align_sprite_with_collider()

func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var on_ladder := _is_on_ladder()
	var on_horizontal_bar := _is_on_horizontal_bar()
	var at_ladder_top := _is_at_ladder_top()
	var can_latch_to_horizontal_bar := on_horizontal_bar and (was_on_horizontal_bar or at_ladder_top)

	_update_state(input_x, input_y, on_ladder, can_latch_to_horizontal_bar, at_ladder_top)
	_apply_state_movement(delta, input_x, input_y, can_latch_to_horizontal_bar, at_ladder_top)

	if current_state == MovementState.UP_STAIRS and can_latch_to_horizontal_bar and animated_sprite.sprite_frames.has_animation("Climb"):
		animated_sprite.flip_h = false
	elif input_x != 0.0:
		animated_sprite.flip_h = input_x < 0.0

	move_and_slide()
	_apply_state_animation(input_x, can_latch_to_horizontal_bar)
	_update_sprite_vertical_offset(can_latch_to_horizontal_bar and animated_sprite.animation == "Climb")
	was_on_horizontal_bar = can_latch_to_horizontal_bar and current_state == MovementState.UP_STAIRS

func _update_state(input_x: float, input_y: float, on_ladder: bool, on_horizontal_bar: bool, at_ladder_top: bool) -> void:
	if on_horizontal_bar and input_y > 0.5:
		current_state = MovementState.RUN if absf(input_x) > 0.01 else MovementState.IDLE
	elif on_ladder and (on_horizontal_bar or absf(input_y) > 0.01 or (input_x != 0.0 and at_ladder_top and input_y >= 0.0)):
		current_state = MovementState.UP_STAIRS
	elif absf(input_x) > 0.01:
		current_state = MovementState.RUN
	else:
		current_state = MovementState.IDLE

func _apply_state_movement(delta: float, input_x: float, input_y: float, on_horizontal_bar: bool, at_ladder_top: bool) -> void:
	velocity.x = input_x * move_speed

	match current_state:
		MovementState.UP_STAIRS:
			var climb_input_y := 0.0
			if not on_horizontal_bar and absf(input_y) > 0.01:
				climb_input_y = input_y
			elif not on_horizontal_bar and input_x != 0.0 and input_y >= 0.0 and at_ladder_top:
				climb_input_y = -ladder_top_assist_factor
			velocity.y = climb_input_y * climb_speed
		MovementState.IDLE, MovementState.RUN:
			velocity.y += gravity * delta

func _apply_state_animation(input_x: float, on_horizontal_bar: bool) -> void:
	match current_state:
		MovementState.UP_STAIRS:
			if on_horizontal_bar and absf(input_x) > 0.01 and animated_sprite.sprite_frames.has_animation("Climb"):
				_play_animation_if_needed("Climb")
			elif animated_sprite.sprite_frames.has_animation("UpStairs"):
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

func _is_on_horizontal_bar() -> bool:
	var sample_offsets := [Vector2(0, -6), Vector2.ZERO, Vector2(0, 6)]
	for offset: Vector2 in sample_offsets:
		var map_pos := tile_map_layer.local_to_map(tile_map_layer.to_local(global_position + offset))
		if _is_horizontal_bar_cell(map_pos):
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

	var has_vertical_connection := _is_non_solid_used_cell(above) or _is_non_solid_used_cell(below)
	var has_horizontal_bridge := _is_horizontal_bar_cell(map_pos)
	return has_vertical_connection or has_horizontal_bridge

func _is_horizontal_bar_cell(map_pos: Vector2i) -> bool:
	if _is_solid_cell(map_pos):
		return false

	var left := map_pos + Vector2i(-1, 0)
	var right := map_pos + Vector2i(1, 0)
	return _is_non_solid_used_cell(left) and _is_non_solid_used_cell(right)

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
		base_sprite_y = animated_sprite.position.y
		return

	var collider_bottom := collision_shape.position.y + half_height
	base_sprite_y = collider_bottom - (sprite_height * 0.5) + sprite_ground_offset
	animated_sprite.position.y = base_sprite_y

func _update_sprite_vertical_offset(use_horizontal_climb_offset: bool) -> void:
	var target_y := base_sprite_y
	if use_horizontal_climb_offset:
		target_y += horizontal_climb_sprite_offset

	if not is_equal_approx(animated_sprite.position.y, target_y):
		animated_sprite.position.y = target_y
