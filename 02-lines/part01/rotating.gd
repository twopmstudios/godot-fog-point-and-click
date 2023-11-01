extends Node3D

@export var axis := Vector3.UP
@export var speed := 45


func _process(delta):
	rotate(axis.normalized(), deg_to_rad(speed) * delta)
