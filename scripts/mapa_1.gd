extends Node2D

@export var solid_source_id: int = 0
@export var collision_layer: int = 1
@export var collision_mask: int = 1

@onready var tile_map_layer: TileMapLayer = $TileMapLayer

func _ready() -> void:
	pass

func _build_runtime_collisions() -> void:
	var static_body := StaticBody2D.new()
	static_body.name = "GeneratedTileCollisions"
	static_body.collision_layer = collision_layer
	static_body.collision_mask = collision_mask
	add_child(static_body)

	var tile_size := tile_map_layer.tile_set.tile_size
	for cell: Vector2i in tile_map_layer.get_used_cells():
		if tile_map_layer.get_cell_source_id(cell) != solid_source_id:
			continue

		var shape := RectangleShape2D.new()
		shape.size = Vector2(tile_size)

		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = tile_map_layer.map_to_local(cell)
		static_body.add_child(collision)
