class_name PlayerHealthSystem
extends RefCounted

const LIFE_ALIVE: StringName = &"ALIVE"
const LIFE_DEAD: StringName = &"DEAD"

var _states: Dictionary = {}
var _max_hp: int
var _respawn_delay_ticks: int
var _events: Array[Dictionary] = []

func _init(max_hp: int, respawn_delay_seconds: float = 4.0, tick_rate: int = 30) -> void:
    _max_hp = maxi(1, max_hp)
    _respawn_delay_ticks = maxi(1, int(ceil(respawn_delay_seconds * tick_rate)))

func register_player(entity_id: int, spawn_position: Vector3 = Vector3.ZERO) -> bool:
    if entity_id <= 0 or _states.has(entity_id) or not _is_finite_vector(spawn_position):
        return false
    _states[entity_id] = {
        "entity_id": entity_id,
        "max_hp": _max_hp,
        "current_hp": _max_hp,
        "life_state": LIFE_ALIVE,
        "death_tick": -1,
        "respawn_tick": -1,
        "spawn_position": spawn_position,
    }
    return true

func apply_server_damage(
    entity_id: int,
    damage: int,
    killer_entity_id: int = 0,
    current_tick: int = 0,
    death_position: Vector3 = Vector3.ZERO
) -> Dictionary:
    if not _states.has(entity_id) or damage <= 0:
        return {"applied": false, "current_hp": 0, "died": false}
    var state: Dictionary = _states[entity_id]
    if state["life_state"] != LIFE_ALIVE:
        return {"applied": false, "current_hp": 0, "died": false}
    state["current_hp"] = maxi(0, int(state["current_hp"]) - damage)
    var died: bool = state["current_hp"] == 0
    if died:
        state["life_state"] = LIFE_DEAD
        state["death_tick"] = current_tick
        state["respawn_tick"] = current_tick + _respawn_delay_ticks
        _events.append({
            "event_type": "DIED",
            "server_tick": current_tick,
            "player_entity_id": entity_id,
            "killer_entity_id": killer_entity_id,
            "death_position": death_position,
        })
    return {"applied": true, "current_hp": state["current_hp"], "died": died}

func simulate_tick(current_tick: int) -> void:
    for entity_id: int in _states:
        var state: Dictionary = _states[entity_id]
        if state["life_state"] == LIFE_DEAD and current_tick >= state["respawn_tick"]:
            state["life_state"] = LIFE_ALIVE
            state["current_hp"] = state["max_hp"]
            state["death_tick"] = -1
            state["respawn_tick"] = -1
            _events.append({
                "event_type": "RESPAWNED",
                "server_tick": current_tick,
                "player_entity_id": entity_id,
                "killer_entity_id": 0,
                "respawn_position": state["spawn_position"],
            })

func drain_lifecycle_events() -> Array[Dictionary]:
    var events := _events.duplicate(true)
    _events.clear()
    return events

func is_alive(entity_id: int) -> bool:
    return _states.has(entity_id) and _states[entity_id]["life_state"] == LIFE_ALIVE

func get_state(entity_id: int) -> Dictionary:
    if not _states.has(entity_id):
        return {}
    return (_states[entity_id] as Dictionary).duplicate(true)

func decorate_player_snapshot(players: Array) -> void:
    for player: Dictionary in players:
        var health := get_state(player["entity_id"])
        if not health.is_empty():
            player["current_hp"] = health["current_hp"]
            player["max_hp"] = health["max_hp"]
            player["life_state"] = String(health["life_state"])

func remove_player(entity_id: int) -> bool:
    return _states.erase(entity_id)

func clear() -> void:
    _states.clear()
    _events.clear()

func _is_finite_vector(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
