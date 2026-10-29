extends Node3D
@onready var camera: Camera3D = $Camera3D


var is_y_rotation = false
var input_rotation : Vector3
var mouse_input : Vector2


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov += 0.5
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov -= 0.5
		
		camera.fov = clamp(camera.fov, 1.0, 100)
	
	if event is InputEventMouseMotion:
		$y_point.rotation.y -= event.screen_relative.y * 0.005
			
