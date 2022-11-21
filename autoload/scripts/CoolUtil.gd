extends Node

func _ready():
	RenderingServer.set_default_clear_color(Color.BLACK)

func bytes_to_human(bytes:int = 0):
	var size:float = abs(bytes) + 2147483648 if abs(bytes) != bytes else bytes
	var data:int = 0
	var data_types:Array[String] = ["b", "kb", "mb", "gb", "tb", "pb"]
	while size > 1024 && data < data_types.size()-1:
		data += 1
		size /= 1024;
	size = round(size * 100) / 100
	return str(size) + data_types[data]
	
func load_json(path:String) -> Dictionary:
	var e = FileAccess.open(path, FileAccess.READ)
	if e != null:
		var text:String = e.get_as_text()
		var parsed = JSON.new()
		parsed.parse(text)
		return parsed.data
	return {}
	
func load_json_from_text(text:String) -> Dictionary:
	var parsed = JSON.new()
	parsed.parse(text)
	return parsed.data

# only making these becausethese pieces of code are so long
func get_mem_usage():
	return Performance.get_monitor(Performance.MEMORY_STATIC)
	
func get_mem_peak():
	return Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	
var vram_peak:int = 0
	
func get_vram_usage():
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	
func get_vram_peak():
	var usage:int = get_vram_usage()
	if usage > vram_peak:
		vram_peak = usage
	return vram_peak