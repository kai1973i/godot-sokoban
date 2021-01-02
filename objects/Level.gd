extends Node2D

signal level_completed


var crates_on_goal = 0
var goals = []
var crates = []
var walls = []
var player

var level_info

var tile_size = Globals.tile_size

const PLAYER_COLLISION_BIT= 0x1
const GOAL_COLLISION_BIT= 0x2

const OBJECTS_Z_INDEX = 20
const GOAL_Z_INDEX = 10


const player_scene = preload("res://objects/Player.tscn")
const crate_scene = preload("res://objects/Crate.tscn")
const wall_scene = preload("res://objects/Wall.tscn")
const goal_scene = preload("res://objects/Landing.tscn")

const ground_texture = preload("res://assets/PNG/Ground/ground_01.png")

var width: int
var height: int

func initialize(level_info: LevelInfo):
	self.level_info = level_info
	_setup_objects()
	_calc_level_size()

func _calc_level_size():
	var max_size = Vector2(0, 0)
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

func _ready():
	pass

func _setup_player():
	self.player = player_scene.instance()
	self.player.position = level_info.player * tile_size
	self.player.set_z_index(OBJECTS_Z_INDEX)
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
	for goal in level_info.goals:
		add_child(_create_ground_tile(goal * tile_size))
	for crate in level_info.crates:
		add_child(_create_ground_tile(crate * tile_size))
	add_child(_create_ground_tile(level_info.player * tile_size))

func _create_ground_tile(position):
	var ch = Character.new()
	var sprite = Sprite.new()
	sprite.texture = ground_texture
	ch.add_child(sprite)
	ch.position = position
	return ch
	
func _on_Crate_entered_Goal(area):
	self.crates_on_goal += 1
	if self.crates_on_goal == len(self.goals):
		# To avoid a case when a crate is moving from goal to goal and conidered
		# as scoring 2 goals, the game will check again the end condition when timer
		# expires and movement has setteled
		var timer = Timer.new()
		timer.one_shot = true
		timer.autostart = true
		timer.wait_time = 0.1
		add_child(timer)
		timer.connect("timeout", self, "_on_Timeout_level_ended_check")
		#emit_signal("level_completed")

func _on_Timeout_level_ended_check():
	if self.crates_on_goal == len(self.goals):
		emit_signal("level_completed")

func _on_Crate_exited_Goal(area):
	self.crates_on_goal -= 1
