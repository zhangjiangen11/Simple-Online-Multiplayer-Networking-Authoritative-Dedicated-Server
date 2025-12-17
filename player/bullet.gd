extends Node2D


const SPEED = 1000


func _process(delta):
	global_position += global_transform.x * SPEED * delta
