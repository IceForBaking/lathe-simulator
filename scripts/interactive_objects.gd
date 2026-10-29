extends Node3D

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var on_button_area: Area3D = $OnButtonArea

var is_pressed = false

func _on_on_button_area_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and is_pressed == false:
		animation_player.play("OnButton")
		is_pressed = true
		await animation_player.animation_finished
		animation_player.play("DoorClose")


func _on_off_button_area_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and is_pressed == true:
		animation_player.play("OffButton")
		await animation_player.animation_finished
		animation_player.play_backwards("DoorClose")
		await animation_player.animation_finished
		animation_player.play_backwards("OnButton")
		is_pressed = false
