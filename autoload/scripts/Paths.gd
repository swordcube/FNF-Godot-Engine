extends Node

func image(p:String):
	return "res://assets/images/"+p+".png"
	
func music(p:String):
	return "res://assets/music/"+p+".ogg"
	
func sound(p:String):
	return "res://assets/sounds/"+p+".ogg"
	
func json(p:String):
	return "res://assets/"+p+".json"
	
func chart_json(song:String, diff:String = "normal"):
	return "res://assets/songs/"+song.to_lower()+"/"+diff+".json"
	
func inst(song:String):
	return "res://assets/songs/"+song.to_lower()+"/Inst.ogg"
	
func voices(song:String):
	return "res://assets/songs/"+song.to_lower()+"/Voices.ogg"