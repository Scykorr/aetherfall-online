class_name PlayerProgressionSystem
extends RefCounted

var _states: Dictionary = {}

func register_player(entity_id: int) -> bool:
    if entity_id <= 0 or _states.has(entity_id):
        return false
    _states[entity_id] = {"level": 1, "current_xp": 0}
    return true

func grant_xp(entity_id: int, amount: int) -> bool:
    if not _states.has(entity_id) or amount <= 0:
        return false
    var state: Dictionary = _states[entity_id]
    state["current_xp"] += amount
    while state["current_xp"] >= xp_required_for_level(state["level"]):
        state["current_xp"] -= xp_required_for_level(state["level"])
        state["level"] += 1
    return true

func get_state(entity_id: int) -> Dictionary:
    if not _states.has(entity_id): return {}
    return (_states[entity_id] as Dictionary).duplicate(true)

func decorate_player_snapshot(players: Array) -> void:
    for player: Dictionary in players:
        var state := get_state(player["entity_id"])
        if not state.is_empty():
            player["level"] = state["level"]
            player["current_xp"] = state["current_xp"]
            player["xp_to_next_level"] = xp_required_for_level(state["level"])

func remove_player(entity_id: int) -> bool: return _states.erase(entity_id)
func clear() -> void: _states.clear()

static func xp_required_for_level(level: int) -> int:
    return maxi(1, level) * 100
