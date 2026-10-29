class_name CameraManager extends Node3D

enum CameraStates {
	MAIN,
	CNC_CONSOLE,
	INSIDE,
	ISIDE_V2,
	ORTO_UP_PROJ,
}

var camera_current_state = CameraStates.MAIN
