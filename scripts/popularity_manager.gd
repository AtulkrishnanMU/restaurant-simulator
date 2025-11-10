extends Node
class_name PopularityManager

signal popularity_changed(new_popularity: int)

var npcs_served := 0
var popularity := 0

# Popularity calculation: starts at 0, increases based on NPCs served
# Formula: popularity = floor(sqrt(npcs_served) * 10)
# This gives a nice curve: 0 NPCs = 0, 1 NPC = 10, 4 NPCs = 20, 9 NPCs = 30, etc.
func calculate_popularity() -> int:
	return int(sqrt(npcs_served) * 10)

func npc_served():
	npcs_served += 1
	popularity = calculate_popularity()
	popularity_changed.emit(popularity)
	print("NPC served! Total: ", npcs_served, " | Popularity: ", popularity)

func get_popularity() -> int:
	return popularity

func get_npcs_served() -> int:
	return npcs_served
