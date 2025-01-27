extends Node

const SAVE_PATH = "user://levels_progress.json"
const TAG = "UserData"

enum LevelStatus {New, InProgress, Finished}
var _str_to_status = {
	"new": LevelStatus.New,
	"in_progress": LevelStatus.InProgress,
	"finished": LevelStatus.Finished,
}
var _status_to_str = {
	LevelStatus.New: "new",
	LevelStatus.InProgress: "in_progress",
	LevelStatus.Finished: "finished",
}

onready var level_save_data = {}

func _ready():
	_load_game()

func _load_game():
	var save_file = File.new()
	if not save_file.file_exists(SAVE_PATH):
		save_file.open(SAVE_PATH, File.WRITE)
		save_file.store_line("{}")
		save_file.close()
		return

	save_file.open(SAVE_PATH, File.READ)
	Logger.debug("Using file: %s" % save_file.get_path_absolute(), TAG)
	level_save_data = JSON.parse(save_file.get_as_text()).result
	save_file.close()

func _verify_exists(pack_id, level_id):
	if not level_save_data.has(pack_id):
		level_save_data[pack_id] = {}
	if not level_save_data[pack_id].has(str(level_id)):
		level_save_data[pack_id][str(level_id)] = {"status": _status_to_str[LevelStatus.New], "score": 99999}

func set_level_data(pack_id, level_id, status = null, score = null):
	_verify_exists(pack_id, level_id)
	if status:
		level_save_data[pack_id][str(level_id)]["status"] = _status_to_str[status]
	if score and score < level_save_data[pack_id][str(level_id)]["score"]:
		level_save_data[pack_id][str(level_id)]["score"] = score

func save_game():
	var save_file = File.new()
	save_file.open(SAVE_PATH, File.WRITE)
	save_file.store_line(to_json(level_save_data))
	save_file.close()

func get_level_data(pack_id, level_id):
	_verify_exists(pack_id, level_id)
	var res = level_save_data[pack_id][str(level_id)].duplicate()
	res['status'] = _str_to_status[res['status']]
	return res
