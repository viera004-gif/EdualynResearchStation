extends Area3D
var bay: Node
var interaction_id: String = ""
var bounds := Vector3(.6, .4, .5)
var bounds_offset := Vector3.ZERO
func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = bounds
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = bounds_offset
	add_child(collider)
func prompt() -> String:
	return ""
func interact(_player: Node) -> void:
	pass
