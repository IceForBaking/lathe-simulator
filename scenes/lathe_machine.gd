class_name LatheMachine extends Node3D

@onready var spindle_pivot: Marker3D = $SpindlePivot
@onready var carriage_x: MeshInstance3D = %CarriageX
@onready var carriage_z: MeshInstance3D = %CarriageZ      

var current_rpm: float = 0.0          
var target_rpm: float = 0.0         
var spindle_clockwise: bool = true   
var is_spindle_running: bool = false
var spindle_acceleration: float = 500.0
var is_metric: bool = true        
var is_absolute: bool = true     

var current_x: float = 0.0
var current_z: float = 0.0
var target_x: float = 0.0
var target_z: float = 0.0
var is_moving: bool = false
var move_start_time: float = 0.0
var move_duration: float = 0.0

# Скорость быстрого перемещения (G00) в мм/сек
const RAPID_SPEED: float = 2000.0

# Сигнал о завершении движения
signal movement_finished()

func _ready() -> void:
	
	if carriage_x:
		current_x = carriage_x.position.x
		target_x = current_x
	if carriage_z:
		current_z = carriage_z.position.z
		target_z = current_z
		
# Включение шпинделя по часовой стрелке (M03)
func start_spindle_cw(rpm: int) -> void:
	target_rpm = float(rpm)
	spindle_clockwise = true
	is_spindle_running = true

# Включение шпинделя против часовой стрелки (M04)
func start_spindle_ccw(rpm: int) -> void:
	target_rpm = float(rpm)
	spindle_clockwise = false
	is_spindle_running = true

# Остановка шпинделя (M05)
func stop_spindle() -> void:
	target_rpm = 0.0
	is_spindle_running = false
	print("Шпиндель остановлен")

# Установка оборотов без изменения состояния (S-команда)
func set_spindle_speed(rpm: int) -> void:
	target_rpm = float(rpm)
	print("Установлены обороты: ", target_rpm)

# G00 - быстрое позиционирование (возвращает время выполнения в секундах)
func rapid_move(x: float, z: float) -> float:
	var distance = 0.0
	if x != 0:
		target_x = x
		distance += abs(target_x - current_x)
	if z != 0:
		target_z = z
		distance += abs(target_z - current_z)
	
	if distance == 0.0:
		return 0.0
	
	move_duration = distance / RAPID_SPEED
	move_start_time = Time.get_ticks_msec() / 1000.0
	is_moving = true
	
	return move_duration

# G01 - линейная интерполяция (возвращает время выполнения в секундах)
func linear_move(x: float, z: float, feed_mm_per_rev: float) -> float:
	var distance = 0.0
	if x != 0:
		target_x = x
		distance += abs(target_x - current_x)
	if z != 0:
		target_z = z
		distance += abs(target_z - current_z)
	
	if distance == 0.0:
		return 0.0
	
	# Скорость подачи (мм/сек) = подача (мм/об) * обороты (об/сек)
	var rpm = current_rpm if current_rpm > 0 else 500.0
	var feed_mm_per_sec = feed_mm_per_rev * rpm / 60.0
	
	if feed_mm_per_sec <= 0:
		return 0.0
	
	move_duration = distance / feed_mm_per_sec
	move_start_time = Time.get_ticks_msec() / 1000.0
	is_moving = true
	
	return move_duration
	
func set_metric() -> void:
	is_metric = true
	print("Метрическая система (мм)")

func set_absolute_mode() -> void:
	is_absolute = true
	print("Абсолютная система координат")

func set_incremental_mode() -> void:
	is_absolute = false
	print("Относительная система координат")

func _process(delta: float):
	
	_update_spindle(delta)
	_update_carriage(delta)

# Обновление вращения шпинделя с учётом ускорения/замедления
func _update_spindle(delta: float):
	# Плавное изменение оборотов (разгон/замедление)
	if is_spindle_running:
		if current_rpm < target_rpm:
			current_rpm += spindle_acceleration * delta
			if current_rpm > target_rpm:
				current_rpm = target_rpm
		elif current_rpm > target_rpm:
			current_rpm -= spindle_acceleration * delta
			if current_rpm < target_rpm:
				current_rpm = target_rpm
	else:
		# Замедление до полной остановки
		if current_rpm > 0:
			current_rpm -= spindle_acceleration * delta
			if current_rpm < 0:
				current_rpm = 0
	
	# Вращение шпинделя (если есть обороты)
	if current_rpm > 0:
		var direction = 1.0 if spindle_clockwise else -1.0

		var angular_speed = current_rpm * 2.0 * PI / 60.0
		spindle_pivot.rotate_x(direction * angular_speed * delta)

# Обновление плавного перемещения суппорта
func _update_carriage(delta: float):
	if not is_moving:
		return
	print("DEBUG: обновление позиции, is_moving=true")
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - move_start_time
	var t = clamp(elapsed / move_duration, 0.0, 1.0)
	
	# Интерполяция позиции
	if carriage_x and target_x != current_x:
		var new_x = lerp(current_x, target_x, t)
		carriage_x.position.x = new_x
	
	if carriage_z and target_z != current_z:
		var new_z = lerp(current_z, target_z, t)
		carriage_z.position.z = new_z
	
	# Проверка завершения движения
	if t >= 1.0:

		current_x = target_x
		current_z = target_z
		if carriage_x:
			carriage_x.position.x = current_x
		if carriage_z:
			carriage_z.position.z = current_z
		is_moving = false
		movement_finished.emit()
		
func change_tool(tool_id: int) -> void:
	print("Смена инструмента на позицию: ", tool_id)
