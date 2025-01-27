extends Node2D

signal level_completed


const TAG = "Player"

var crates_on_goal = 0
var goals = []
var crates = []
var walls = []
var player

var level_info

var tile_size = Globals.TILE_SIZE

const PLAYER_COLLISION_BIT= 0x1
const GOAL_COLLISION_BIT= 0x2

const OBJECTS_Z_INDEX = 20
const GOAL_Z_INDEX = 10


const player_scene = preload("res://objects/Player.tscn")
const crate_scene = preload("res://objects/Crate.tscn")
const wall_scene = preload("res://objects/Wall.tscn")
const goal_scene = preload("res://objects/Landing.tscn")

const ground_texture = preload("res://assets/PNG/Ground/ground_01.png")

onready var helper = load("res://utils/Helper.gd").new()

var width: int
var height: int
var move_stack: Array
var level_completed = false
var enable_undo_stack = true
var turn_ended = true

var moves: int
var pushes: int

func initialize(level_info: LevelInfo):
	self.level_info = level_info
	_setup_objects()
	_calc_level_size()

func undo():
	if not self.move_stack.empty():
		var last_turn_entry = move_stack.pop_back()
		var opposite_dir = last_turn_entry['direction'] * Vector2(-1, -1)
		self.enable_undo_stack = false
		self.player.move(opposite_dir, true)
		
		var crate = last_turn_entry['crate_moved']
		if crate:
			crate.move(opposite_dir)
			pushes -= 1

func get_stats():
	return {'moves': moves, 'pushes': pushes}

func _calc_level_size():
	var max_size = Vector2(0, 0)
	
	# All levels are bound by walls
	for wall in self.walls:
		if wall.position.x > max_size.x:
			max_size.x = wall.position.x
		if wall.position.y > max_size.y:
			max_size.y = wall.position.y
	self.width = max_size.x + tile_size
	self.height = max_size.y + tile_size

func _setup_objects():	
	_setup_player()
	_setup_crates()
	_setup_goals()
	_setup_walls()
	_setup_ground()

func _init_objects(objects: PoolVector2Array, obj_scene, container):
	for object_pos in objects:
		var obj = obj_scene.instance()
		obj.position = object_pos * tile_size
		container.append(obj)

func _setup_player():
	self.player = player_scene.instance()
	self.player.position = level_info.player * tile_size
	self.player.set_z_index(OBJECTS_Z_INDEX)
	player.connect("turn_ended", self, "_on_Player_turn_ended")
	add_child(self.player)

func _setup_goals():
	_init_objects(level_info.goals, goal_scene, self.goals)
	for goal in goals:
		goal.connect("area_entered", self, "_on_Crate_entered_Goal")
		goal.connect("area_exited", self, "_on_Crate_exited_Goal")
		goal.set_collision_layer_bit(GOAL_COLLISION_BIT, true)
		goal.set_collision_mask_bit(GOAL_COLLISION_BIT, true)
		goal.set_collision_layer_bit(PLAYER_COLLISION_BIT, false)
		goal.set_collision_mask_bit(PLAYER_COLLISION_BIT, false)
		goal.set_z_index(GOAL_Z_INDEX)
		add_child(goal)

func _setup_crates():
	_init_objects(level_info.crates, crate_scene, self.crates)
	for crate in crates:
		crate.set_collision_mask_bit(GOAL_COLLISION_BIT, true)
		crate.set_z_index(OBJECTS_Z_INDEX)
		add_child(crate)
	
func _setup_walls():
	_init_objects(level_info.walls, wall_scene, self.walls)
	for wall in walls:
		wall.set_z_index(OBJECTS_Z_INDEX)
		add_child(wall)

func _setup_ground():
	for ground in level_info.ground:
		add_child(_create_ground_tile(ground * tile_size))
	for wall in level_info.walls:
		add_child(_create_ground_tile(wall * tile_size))

func _create_ground_tile(position):
	var ch = BlockSprite.new()
	var sprite = Sprite.new()
	sprite.texture = ground_texture
	ch.add_child(sprite)
	ch.position = position
	return ch
	
func _check_victory_condition():
	if self.crates_on_goal == len(self.goals):
		if not self.level_completed:
			self.level_completed = true
			emit_signal("level_completed")
	else:
		self.level_completed = false

# Callbacks
func _on_Crate_entered_Goal(area):
	self.crates_on_goal += 1

func _on_Crate_exited_Goal(area):
	self.crates_on_goal -= 1

func _physics_process(delta):
	if turn_ended:
		_check_victory_condition()
		turn_ended = false

func _translate_movement(dir):
	var vec_dir = {Vector2.UP: 'Up', Vector2.DOWN: 'Down',
	 Vector2.LEFT: 'Left', Vector2.RIGHT: 'Right'}
	for vec in vec_dir:
		if helper.is_close(dir ,vec):
			return vec_dir[vec]
	return dir

func _on_Player_turn_ended(direction: Vector2, crate_moved: Crate):
	moves += int(self.enable_undo_stack)  * 1 + int(not self.enable_undo_stack) * -1
	
	# undo push reported in 'undo' function
	pushes += int(self.enable_undo_stack)  * int(crate_moved != null)
	Logger.info("Player move #{moves}: {dir}".format({'moves': moves,
	 'dir': str(_translate_movement(direction))}), TAG)

	if self.enable_undo_stack:
		var entry = Dictionary()
		entry['direction'] = direction
		entry['crate_moved'] = crate_moved
		self.move_stack.append(entry)
	else:
		self.enable_undo_stack = true

	# wait for a complete physics step before confirming that a turn has ended
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	
	turn_ended = true
	
