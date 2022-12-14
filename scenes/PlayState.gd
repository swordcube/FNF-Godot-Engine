extends Node2D

class_name PlayState

@onready var opponent_strums:StrumLine = $UI/OpponentStrums
@onready var player_strums:StrumLine = $UI/PlayerStrums

@onready var inst:AudioStreamPlayer = $Inst
@onready var voices:AudioStreamPlayer = $Voices

var SONG = Global.SONG
var unspawn_notes:Array[UnspawnNote] = []

var skipped_intro:bool = false
var starting_song:bool = true

var og_speed:float = 0.0

var note_offset:float = 0.0

var modcharts:ModchartGroup

func _ready():
	modcharts = ModchartGroup.new()
	note_offset = Settings.grab("note-offset") + (AudioServer.get_output_latency() * 1000)
	
	inst.stream = load(Paths.inst(SONG.name))
	voices.stream = load(Paths.voices(SONG.name))
	
	inst.pitch_scale = Conductor.rate
	voices.pitch_scale = Conductor.rate
	
	$Inst.connect("finished", finish_song)
	
	Settings.setup_binds()
	
	Conductor.change_bpm(SONG.bpm)
	Conductor.position = Conductor.crochet * -5.0
	
	if Settings.grab("play-as-opponent"):
		opponent_strums.is_opponent = !opponent_strums.is_opponent
		player_strums.is_opponent = !player_strums.is_opponent
		
		opponent_strums.init()
		player_strums.init()
	
	if !Settings.grab("downscroll"):
		opponent_strums.position.y = 95
		player_strums.position.y = 95
		
	# load song scripts
	var modchart_path:String = Paths.song_modchart(SONG.name)
	if Paths.exists(modchart_path):
		var modchart:Modchart = Modchart.create(modchart_path, self)
		modcharts.add(modchart)
		
	# load global scripts
	var init_path:String = "res://assets/data/global_modcharts/"
	var file_list:PackedStringArray = CoolUtil.list_files_in_dir(init_path)
	for item in file_list:
		if item.ends_with(".tscn"):
			var modchart:Modchart = Modchart.create(init_path+item, self)
			modcharts.add(modchart)
	
	# load notes
	for section in SONG.sections:
		for note in section.notes:
			var gotta_hit:bool = section.player_section
			if note.direction > (SONG.key_amount - 1):
				gotta_hit = !section.player_section
				
			var data:UnspawnNote = UnspawnNote.new()
			data.strum_time = note.strum_time + (note_offset * Conductor.rate)
			data.direction = note.direction % SONG.key_amount
			data.sustain_length = note.sustain_length
			data.must_press = !gotta_hit if Settings.grab("play-as-opponent") else gotta_hit
			data.type = note.type
			data.alt_anim = note.alt_anim
			unspawn_notes.append(data)
			
	unspawn_notes.sort_custom(func sorting(a, b): return a.strum_time < b.strum_time)
	Conductor.connect("beat_hit", func d(): beat_hit(Conductor.cur_beat))
	Conductor.connect("step_hit", func d(): step_hit(Conductor.cur_step))
	
	og_speed = opponent_strums.note_speed
	
func beat_hit(beat:int):
	modcharts.call_func("_beat_hit", [beat])
	if(inst.playing && !(Conductor.is_audio_synced(inst) || Conductor.is_audio_synced(voices))):
		Conductor.position = inst.get_playback_position() * 1000.0
		voices.seek(inst.get_playback_position())
	modcharts.call_func("_beat_hit_post", [beat])
	
func step_hit(step:int):
	modcharts.call_func("_step_hit", [step])
	modcharts.call_func("_step_hit_post", [step])
	
func finish_song():
	if note_offset <= 0:
		end_song()
	else:
		EasyTimer.new().start(note_offset / 1000.0, func(tmr:EasyTimer):
			end_song()
		)
	
func end_song():
	if Global.is_story_mode:
		pass
	else:
		Audio.play_music(Paths.music("menuMusic"))
		Global.switch_scene("menus/FreeplayMenu")

func _process(delta):
	Conductor.position += (delta * 1000.0) * Conductor.rate
	if Conductor.position >= 0 && starting_song: start_song() 
	
	if Input.is_action_just_pressed("skip_intro") && !skipped_intro:
		skipped_intro = true
		if unspawn_notes[0].strum_time >= 1000:
			start_song()
		Conductor.position = unspawn_notes[0].strum_time - 1000
		if unspawn_notes[0].strum_time >= 1000:
			inst.seek(Conductor.position / 1000.0)
			voices.seek(Conductor.position / 1000.0)
			
	modcharts.call_func("_process_post", [delta])
		
func start_song():
	starting_song = false
	Conductor.position = 0
	
	inst.play()
	voices.play()
	
	inst.seek(0.0)
	voices.seek(0.0)
	
func _physics_process(delta):
	for note in unspawn_notes:
		var strum_line:StrumLine = player_strums if note.must_press else opponent_strums
		if Settings.grab("play-as-opponent"):
			strum_line = player_strums if !note.must_press else opponent_strums
			
		var spawn_mult:float = (1500 / strum_line.note_speed) * Conductor.rate
		if note.strum_time <= Conductor.position + spawn_mult:
			skipped_intro = true
			
			var new_note:Note = load("res://scenes/game/notes/"+note.type+".tscn").instantiate()
			new_note.strum_time = note.strum_time
			new_note.direction = note.direction
			new_note.must_press = note.must_press
			new_note.position.x = strum_line.receptors.get_child(note.direction).position.x
			strum_line.notes.add_child(new_note)
			
			var length:int = floor(note.sustain_length / Conductor.step_crochet)
			for i in length:
				var sus_note:Note = load("res://scenes/game/notes/"+note.type+".tscn").instantiate()
				sus_note.strum_time = note.strum_time + (Conductor.step_crochet * i) + (Conductor.step_crochet / og_speed)
				sus_note.direction = note.direction
				sus_note.must_press = note.must_press
				sus_note.is_sustain = true
				sus_note.step_crochet = Conductor.step_crochet
				sus_note.parent = strum_line
				sus_note.position.x = strum_line.receptors.get_child(note.direction).position.x + (strum_line.sustains.size.x / 2)
				sus_note.modulate.a = 0.6
				if i >= length-1: sus_note.is_sustain_tail = true
				strum_line.sustains.add_child(sus_note)
				new_note.sustain_pieces.append(sus_note)
				
			unspawn_notes.erase(note)
		else:
			break
