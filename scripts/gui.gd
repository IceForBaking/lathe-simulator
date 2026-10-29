extends CanvasLayer

@onready var main_camera: SpringArm3D = $"../CameraManager/MainCamera"
@onready var camera_animations: AnimationPlayer = $"../CameraManager/CameraAnimations"
@onready var camera: Camera3D = $"../CameraManager/MainCamera/Camera3D"
@onready var panel_container: PanelContainer = $MarginContainer/PanelContainer
@onready var label: RichTextLabel = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/PanelContainer/Label
@onready var line_edit: LineEdit = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/LineEdit
@onready var text_edit: TextEdit = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/PanelContainer/TextEdit
@onready var status_label: Label = $MarginContainer/StatusLabel

@export var camera_position : Vector3

var original_text: String = "" 
var previous_line_count: int = 0
var current_execution_line: int = -1

var camera_manager : CameraManager = CameraManager.new()

func _ready() -> void:

	GCodeParser.parsing_completed.connect(_on_parsing_completed)
	GCodeParser.step_executed.connect(_on_step_executed)
	GCodeParser.execution_finished.connect(_on_execution_finished)

	text_edit.context_menu_enabled = true
	previous_line_count = text_edit.text.split("\n").size()
	
	# Находим узел с анимациями и передаём в парсер
	var anim_controller = $"../LatheMachine" # или путь к вашему узлу
	GCodeParser.set_animation_controller(anim_controller)
	
	# Запускаем парсинг только если есть текст
	if text_edit.text.strip_edges() != "":
		_parse_current_text()
	else:
		status_label.text = "Введите программу"
	
	#_parse_current_text()
	
func switch_anim(anim: String):
	camera_animations.play(anim)
	await camera_animations.animation_finished

func switch_states() -> void:
	
	match  camera_manager.camera_current_state:
		camera_manager.CameraStates.MAIN:
			camera_manager.camera_current_state = camera_manager.CameraStates.CNC_CONSOLE
		camera_manager.CameraStates.CNC_CONSOLE:
			camera_manager.camera_current_state = camera_manager.CameraStates.INSIDE
		camera_manager.CameraStates.INSIDE:
			camera_manager.camera_current_state = camera_manager.CameraStates.ORTO_UP_PROJ
		camera_manager.CameraStates.ORTO_UP_PROJ:
			camera_manager.camera_current_state = camera_manager.CameraStates.ISIDE_V2
		camera_manager.CameraStates.ISIDE_V2:
			camera_manager.camera_current_state = camera_manager.CameraStates.MAIN

func switch_animations()  -> void:
	
	match camera_manager.camera_current_state:
		camera_manager.CameraStates.MAIN:
			switch_anim("reset_main")
		camera_manager.CameraStates.CNC_CONSOLE:
			switch_anim("cnc_console")
		camera_manager.CameraStates.INSIDE:	
			switch_anim("inside")
		camera_manager.CameraStates.ORTO_UP_PROJ:
			switch_anim("orto_up_proj")
		camera_manager.CameraStates.ISIDE_V2:
			switch_anim("inside_v2")

func _parse_current_text():
	var success = GCodeParser.parse_program(text_edit.text)

func _on_parsing_completed(success: bool, error_lines: Array):
	
	_clear_highlighting()
	
	if not success and error_lines.size() > 0:
		for line in error_lines:
			_highlight_line(line, Color.RED)
		status_label.text = "Обнаружены ошибки! Исправьте их перед запуском!"
	else:
		if GCodeParser.commands.is_empty():
			status_label.text = "Программа пуста! Введите команды!"
		else:
			status_label.text = "Синтаксис верен Можно запускать"
		
func _highlight_line(line: int, color: Color):
	if line >= 0 and line < text_edit.get_line_count():
		text_edit.set_line_background_color(line, color)
		
func _clear_highlighting():
	for i in range(text_edit.get_line_count()):
		text_edit.set_line_background_color(i, Color.TRANSPARENT)


func _on_step_executed(line_index: int, command_text: String):
	if current_execution_line != -1:
		text_edit.set_line_background_color(current_execution_line, Color.TRANSPARENT)
	text_edit.set_line_background_color(line_index, Color.YELLOW)
	current_execution_line = line_index
	
	var cmd = GCodeParser.get_command_at_line(line_index)
	var info = "Выполняется: " + command_text
	if cmd and cmd.params:
		# Приводим ключи параметров к верхнему регистру для наглядности
		var display_params = {}
		for key in cmd.params:
			display_params[key.to_upper()] = cmd.params[key]
		info += "\nПараметры: " + str(display_params)
	status_label.text = info
	
func _on_execution_finished():
	status_label.text = "Программа выполнена"
	if current_execution_line != -1:
		text_edit.set_line_background_color(current_execution_line, Color.TRANSPARENT)
	current_execution_line = -1

func _on_next_cam_button_pressed() -> void:

	switch_states()
	switch_animations()

func _on_orto_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	else:camera.projection = Camera3D.PROJECTION_PERSPECTIVE


func _on_panel_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		panel_container.show()
	else: panel_container.hide()


func _on_line_edit_text_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "":
		return

	if text_edit.text == "":
		text_edit.text = new_text
	else:
		text_edit.text += "\n" + new_text
	
	line_edit.clear()
		
		
func _on_text_edit_gui_input(event: InputEvent):
	if event is InputEventKey:
		var key = event.keycode
		
		# Всегда блокируем Enter
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			text_edit.accept_event()
			return
		
		# Проверяем, есть ли в TextEdit хотя бы одна непустая строка
		var has_content = false
		for i in range(text_edit.get_line_count()):
			if text_edit.get_line(i).strip_edges() != "":
				has_content = true
				break
		
		# Если поле пустое – запрещаем ввод любых символов (кроме навигации и удаления)
		if not has_content:
			var allowed_keys = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_BACKSPACE, KEY_DELETE]
			if key in allowed_keys or (event.ctrl_pressed and (key == KEY_C or key == KEY_X)):
				return  # разрешаем
			else:
				text_edit.accept_event()
				return
		
		# Если поле не пустое – разрешаем ввод символов (редактирование)
		# Но дополнительно проверим вставку многострочного текста
		if event.ctrl_pressed and key == KEY_V:
			var clipboard = DisplayServer.clipboard_get()
			if clipboard.contains("\n"):
				text_edit.accept_event()
				return

func _on_run_button_pressed():
	if GCodeParser.is_running:
		return
	# Перепарсим на случай, если текст изменился после последнего парсинга
	_parse_current_text()
	
	var has_valid_command = false
	var has_error = false
	
	for cmd in GCodeParser.commands:
		if cmd.is_empty:
			continue
			
		has_valid_command = true
		
		if not cmd.is_valid:
			has_error = true
			break
		
	if not has_valid_command:
		status_label.text = "Нет команд для выполнения"
		return
	if has_error:
		status_label.text = "Невозможно запустить: есть синтаксические ошибки"
		return
	GCodeParser.start_execution() 

func _on_stop_button_pressed():
	GCodeParser.stop_execution()
	status_label.text = "Выполнение остановлено"
	if current_execution_line != -1:
		text_edit.set_line_background_color(current_execution_line, Color.TRANSPARENT)
	current_execution_line = -1

func _on_text_edit_text_changed() -> void:
	_parse_current_text()
