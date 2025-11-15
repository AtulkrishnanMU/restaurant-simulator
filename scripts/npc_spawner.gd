extends Node2D
class_name NPCSpawner

@export var npc_scene: PackedScene
@export var max_npcs := 5
@export var base_spawn_interval_min := 20.0  # Base minimum seconds between spawns (when popularity is 0)
@export var base_spawn_interval_max := 30.0  # Base maximum seconds between spawns (when popularity is 0)
@export var min_spawn_interval_min := 3.0  # Minimum possible spawn interval (at high popularity)
@export var min_spawn_interval_max := 8.0  # Maximum possible spawn interval (at high popularity)
@export var spawn_area_min := Vector2(-200, -100)  # Minimum spawn position
@export var spawn_area_max := Vector2(400, 300)    # Maximum spawn position

var current_npcs := 0
var spawn_timer := 0.0
var next_spawn_time := 0.0
var popularity_manager: PopularityManager = null
var spawning_enabled: bool = false

func _ready():
	# Load NPC scene if not set in editor
	if not npc_scene:
		npc_scene = load("res://scenes/npc.tscn")
	
	# Get popularity manager
	var game_node = get_parent()
	if game_node:
		popularity_manager = game_node.get_node_or_null("PopularityManager")
	
	# Set initial spawn time with random delay (start slow)
	var intervals = get_spawn_intervals()
	next_spawn_time = randf_range(intervals.x, intervals.y)
	
	# Count existing NPCs in the scene
	update_npc_count()
	
	# Don't spawn initial NPCs - let them spawn randomly over time

func _process(delta):
	if not spawning_enabled:
		return
	spawn_timer += delta
	
	# Update NPC count (in case NPCs were removed manually)
	update_npc_count()
	
	# Spawn new NPC if timer is up and we're below max
	if spawn_timer >= next_spawn_time and current_npcs < max_npcs:
		spawn_npc()
		spawn_timer = 0.0
		var intervals = get_spawn_intervals()
		next_spawn_time = randf_range(intervals.x, intervals.y)

func update_npc_count():
	var count = 0
	var game_node = get_parent()  # NPCSpawner is a child of Game
	if game_node:
		for child in game_node.get_children():
			if child is NPC:
				count += 1
	current_npcs = count

func spawn_npc():
	if not npc_scene:
		print("ERROR: NPC scene not loaded!")
		return
	
	if current_npcs >= max_npcs:
		return
	
	var game_node = get_parent()
	if not game_node:
		print("ERROR: Game node (parent) not found!")
		return
	
	# Spawn NPC regardless of chair availability - they will wait if needed
	var npc = npc_scene.instantiate()
	if not npc:
		print("ERROR: Failed to instantiate NPC!")
		return
	
	# Generate random spawn position (spawn from top)
	var spawn_x = randf_range(spawn_area_min.x, spawn_area_max.x)
	var entry_offset = -100.0  # Start above the screen
	npc.position = Vector2(spawn_x, spawn_area_min.y + entry_offset)
	
	# Randomize NPC properties
	npc.ramen_needed = randi_range(1, 3)  # Random ramen needed (1-3)
	
	# Add to scene
	game_node.add_child(npc)
	
	current_npcs += 1
	print("Spawned NPC (Total NPCs: ", current_npcs, ") - NPC will find a chair or wait")

# Calculate spawn intervals based on popularity
# Higher popularity = faster spawning (lower intervals)
func get_spawn_intervals() -> Vector2:
	var popularity = 0
	if popularity_manager:
		popularity = popularity_manager.get_popularity()
	
	# Interpolate between base (slow) and min (fast) intervals based on popularity
	# Use a curve: at popularity 0, use base intervals; at popularity 100+, use min intervals
	# Popularity typically ranges from 0 to ~100+ (sqrt of NPCs served * 10)
	var max_popularity_for_scaling = 100.0  # At this popularity, we reach min intervals
	var t = clamp(popularity / max_popularity_for_scaling, 0.0, 1.0)
	
	# Linear interpolation
	var min_interval = lerp(base_spawn_interval_min, min_spawn_interval_min, t)
	var max_interval = lerp(base_spawn_interval_max, min_spawn_interval_max, t)
	
	return Vector2(min_interval, max_interval)

func enable_spawning(initial_delay: float = 2.0) -> void:
	# Enable NPC spawning after first ramen is made
	spawning_enabled = true
	spawn_timer = 0.0
	var intervals = get_spawn_intervals()
	# Start with a short initial delay to give feedback quickly
	next_spawn_time = clamp(initial_delay, intervals.x, intervals.y)
