extends Node

# -----------------------------------------------------------------------------
# Конфигурация парсера
# -----------------------------------------------------------------------------

const SUPPORTED_G_CODES = {
	"G00": "rapid",      # быстрое позиционирование
	"G01": "linear",     # линейная интерполяция
	"G02": "cw",         # круговая по часовой
	"G03": "ccw",        # круговая против часовой
	"G21": "metric",      # метрическая система измерений (мм)
	"G90": "absolute",    # абсолютная система координат
	"G91": "incremental"
}

const SUPPORTED_M_CODES = {
	"M03": "spindle_cw",
	"M04": "spindle_ccw",
	"M05": "spindle_stop",
	"M06": "tool_change",
	"M08": "coolant_on",
	"M09": "coolant_off",
	"M30": "program_end",
}

const PARAM_ALIASES = {
	"X": "x", "Z": "z", "F": "feed", "S": "speed", "T": "tool"
}

# Регулярное выражение для токена: буква (G,M,X,Z,F,S,T) и число (целое или дробное)
const TOKEN_PATTERN = "([GMXZFST])(-?\\d+(?:\\.\\d+)?)"

# -----------------------------------------------------------------------------
# Структура команды
# -----------------------------------------------------------------------------

class Command:
	var line_index: int        # номер строки (0-based)
	var raw: String            # исходный текст
	var g_code: Array = []    # "G00", "G01",...
	var m_code: String = ""    # "M03", "M05",...
	var params: Dictionary     # {"x": 50.0, "z": 100.0, "feed": 0.2}
	var is_valid: bool = true
	var is_empty: bool = false
	var error_msg: String = ""

	func _to_string() -> String:
		return "[%d] %s" % [line_index, raw]

# -----------------------------------------------------------------------------
# Состояние парсера
# -----------------------------------------------------------------------------

var commands: Array[Command] = []
var current_step: int = -1
var is_running: bool = false
var animation_controller: Node3D = null
var current_move_duration: float = 0.0
# Сигналы
signal parsing_completed(success: bool, error_lines: Array)
signal step_executed(line_index: int, command_text: String)
signal execution_finished()

# -----------------------------------------------------------------------------
# Публичные методы
# -----------------------------------------------------------------------------

func parse_program(source_text: String) -> bool:
	commands.clear()
	var lines = source_text.split("\n")
	var has_errors = false
	var error_lines = []
	
	var regex = RegEx.new()
	regex.compile(TOKEN_PATTERN)
	
	for i in range(lines.size()):
		var raw_line = lines[i].strip_edges()
		var cmd = Command.new()
		cmd.line_index = i
		cmd.raw = raw_line
		
		if raw_line == "":
			cmd.is_valid = true
			cmd.is_empty = true
			commands.append(cmd)
			continue
		
		# Разбор токенов с помощью регулярного выражения
		var tokens = []
		var result = regex.search_all(raw_line.to_upper())
		for match in result:
			var letter = match.get_string(1)
			var number = match.get_string(2)
			tokens.append({
				"type": letter,
				"value": number.to_float()
			})
		
		
		# внутри parse_program, после получения tokens
		if _has_extra_chars(raw_line, tokens):
			cmd.is_valid = false
			cmd.error_msg = "Недопустимые символы в строке"
			has_errors = true
			error_lines.append(i)
			commands.append(cmd)
			continue
		
		# Валидация и заполнение команды
		cmd = _validate_tokens(tokens, raw_line, i)
		if not cmd.is_valid:
			has_errors = true
			error_lines.append(i)
		
		commands.append(cmd)
	
	parsing_completed.emit(not has_errors, error_lines)
	return not has_errors

func start_execution() -> bool:
	if commands.is_empty():
		return false
	current_step = -1
	is_running = true
	_execute_next_step()
	return true

func stop_execution() -> void:
	is_running = false
	current_step = -1

func get_command_at_line(line: int) -> Command:
	if line >= 0 and line < commands.size():
		return commands[line]
	return null

# -----------------------------------------------------------------------------
# Приватные методы
# -----------------------------------------------------------------------------

func _validate_tokens(tokens: Array, raw_line: String, line_index: int) -> Command:
	var cmd = Command.new()
	cmd.line_index = line_index
	cmd.raw = raw_line
	cmd.is_valid = true
	cmd.g_code = []
	
	for token in tokens:
		var t = token.type
		var val = token.value
		
		match t:
			"G":
				var code_str = "G%02d" % val  # G00, G01,...
				if SUPPORTED_G_CODES.has(code_str):
					cmd.g_code.append(code_str)
				else:
					cmd.is_valid = false
					cmd.error_msg = "Неподдерживаемый G-код: %s" % code_str
					return cmd
			"M":
				var code_str = "M%02d" % val
				if SUPPORTED_M_CODES.has(code_str):
					if cmd.m_code != "":
						cmd.is_valid = false
						cmd.error_msg = "Две M-команды в одной строке"
						return cmd
					cmd.m_code = code_str
				else:
					cmd.is_valid = false
					cmd.error_msg = "Неподдерживаемый M-код: %s" % code_str
					return cmd
			"X", "Z", "F", "S", "T":
				var param_key = PARAM_ALIASES[t]
				cmd.params[param_key] = val
			_:
				cmd.is_valid = false
				cmd.error_msg = "Неизвестный токен: %s" % t
				return cmd
	
	# Проверка наличия команды
	if cmd.g_code.is_empty() and cmd.m_code == "":
		cmd.is_valid = false
		cmd.error_msg = "Отсутствует G- или M-команда"
	
	return cmd

func _execute_next_step() -> void:
	if not is_running:
		return
	
	current_step += 1
	if current_step >= commands.size():
		is_running = false
		execution_finished.emit()
		return
	
	var cmd = commands[current_step]
	
	if cmd.is_empty:
		_execute_next_step()
		return
	
	if not cmd.is_valid:
		_execute_next_step()  # пропускаем ошибочные строки
		return
	
	# Сигнал для GUI
	step_executed.emit(current_step, cmd.raw)
	
	var duration = _simulate_command(cmd)
	
	# Ждём реальное время выполнения
	print("DEBUG execute: waiting for ", duration)
	if duration > 0:
		await get_tree().create_timer(duration, false).timeout
	#else:
		#await get_tree().process_frame
		 #
	print("DEBUG execute: wait finished")
	_execute_next_step()

func _has_extra_chars(line: String, tokens: Array) -> bool:
	# Собираем все символы, которые были покрыты токенами
	var covered_indices = []
	var regex = RegEx.new()
	regex.compile(TOKEN_PATTERN)
	var matches = regex.search_all(line.to_upper())
	for match in matches:
		var start = match.get_start()
		var end = match.get_end()
		for i in range(start, end):
			covered_indices.append(i)
	# Проверяем каждый символ строки
	for i in range(line.length()):
		var ch = line[i]
		if ch == ' ' or ch == '\t':
			continue
		if i not in covered_indices:
			return true  # найден непокрытый символ
	return false

func set_animation_controller(controller: Node3D) -> void:
	animation_controller = controller
	print("AnimationController передан в парсер")

func _simulate_command(cmd: Command) -> float:
	if not animation_controller:
		print("Ошибка: animation_controller не установлен")
		return 0.1
		
	var duration = 0.1
	
	if cmd.params.has("speed"):
		animation_controller.set_spindle_speed(cmd.params["speed"])
		
	for g_code in cmd.g_code:
		match g_code:
			"G00":
				var x = cmd.params.get("x", 0.0)
				var z = cmd.params.get("z", 0.0)
				duration = animation_controller.rapid_move(x, z)
			"G01":
				var x = cmd.params.get("x", 0.0)
				var z = cmd.params.get("z", 0.0)
				var feed = cmd.params.get("feed", 0.1)
				duration = animation_controller.linear_move(x, z, feed)
			"G21":
				animation_controller.set_metric()
			"G90":
				animation_controller.set_absolute_mode()
			"G91":
				animation_controller.set_incremental_mode()
			_:
				print("Неизвестный G-код: ", cmd.g_code)
	
	
	match cmd.m_code:
		"M03":
			var speed = cmd.params.get("speed", 1000)
			animation_controller.start_spindle_cw(speed)
		"M04":
			var speed = cmd.params.get("speed", 1000)
			animation_controller.start_spindle_ccw(speed)
		"M05":
			animation_controller.stop_spindle()
		"M06":
			var tool = cmd.params.get("tool", 1)
			# Для смены инструмента можно сделать небольшую задержку
			animation_controller.change_tool(tool)
			duration = 0.3
		"M08":
			animation_controller.start_coolant()
			duration = 0.1
		"M09":
			animation_controller.stop_coolant()
			duration = 0.1
		"M30":
			print("Программа завершена")
			duration = 0.1
			
	print("DEBUG simulate: duration=", duration)
	return duration
