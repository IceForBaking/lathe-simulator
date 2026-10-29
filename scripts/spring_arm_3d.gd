extends SpringArm3D

@onready var camera: Camera3D = $Camera3D

var is_camera_rotation : bool = false	

func _unhandled_input(event: InputEvent) -> void:
	camera_zoom(event)
	camera_rotation(event)

func camera_zoom(event: InputEvent) -> void:
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov += 0.5
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov -= 0.5
		
		camera.fov = clamp(camera.fov, 1.0, 100)
	
func camera_rotation(event: InputEvent)  -> void:
	
	if Input.is_action_pressed("mouse_movement"):
		is_camera_rotation = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		is_camera_rotation = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion and is_camera_rotation:
		rotation.y -= event.relative.x * 0.002
		rotation.x -= event.relative.y * 0.002
	
