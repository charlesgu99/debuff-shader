extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 0.75, 1.1)


func _process(_delta: float) -> void:
	if target == null:
		return
	global_position = target.global_position + offset
