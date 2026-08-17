class_name MovementSystem
extends RefCounted

const MOVEMENT_COLLISION_MAP_SCRIPT: Script = preload(
    "res://scripts/movement/movement_collision_map.gd"
)
const MODE_STOP: StringName = &"STOP"
const MODE_MOVE_TO_POINT: StringName = &"MOVE_TO_POINT"
const MODE_FOLLOW_CURSOR: StringName = &"FOLLOW_CURSOR"

var _sessions: Node
var _entities: Node
var _states: Dictionary = {}
var _move_speed: float
var _arrival_distance: float
var _player_radius: float
var _collision_map: RefCounted
var _player_lifecycle: RefCounted

func configure_player_lifecycle(player_lifecycle: RefCounted) -> void:
    _player_lifecycle = player_lifecycle

func _init(
    sessions: Node,
    entities: Node,
    move_speed: float = 5.0,
    arrival_distance: float = 0.1,
    blockers: Array[Dictionary] = [],
    world_half_extent: float = 0.0,
    player_radius: float = 0.45
) -> void:
    _sessions = sessions
    _entities = entities
    _move_speed = move_speed
    _arrival_distance = arrival_distance
    _player_radius = player_radius
    _collision_map = MOVEMENT_COLLISION_MAP_SCRIPT.new(blockers, world_half_extent)

func register_ready_player(peer_id: int, spawn_position: Vector3) -> bool:
    var session: Dictionary = _sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return false
    var entity_id: int = session.get("entity_id", 0)
    if entity_id <= 0 or _entities.get_entity(entity_id).is_empty():
        return false
    _states[entity_id] = {
        "entity_id": entity_id,
        "peer_id": peer_id,
        "position": spawn_position,
        "velocity": Vector3.ZERO,
        "movement_mode": MODE_STOP,
        "move_speed": _move_speed,
        "current_destination": spawn_position,
        "direction": Vector3.ZERO,
        "last_processed_input_sequence": 0,
        "last_input_tick": -1,
    }
    return true

func process_intent(peer_id: int, payload: Variant, current_tick: int) -> bool:
    var session: Dictionary = _sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return false
    var entity_id: int = session.get("entity_id", 0)
    if not _states.has(entity_id) or _entities.get_entity(entity_id).is_empty():
        return false
    if _player_lifecycle != null and not _player_lifecycle.is_alive(entity_id):
        return false
    if not payload is Dictionary:
        return false
    var sequence: Variant = payload.get("sequence")
    var command: Variant = payload.get("command")
    if not sequence is int or not command is String:
        return false
    var state: Dictionary = _states[entity_id]
    if sequence <= state["last_processed_input_sequence"]:
        return false
    if state["last_input_tick"] == current_tick and command != String(MODE_STOP):
        return false

    match StringName(command):
        MODE_STOP:
            state["movement_mode"] = MODE_STOP
            state["direction"] = Vector3.ZERO
            state["velocity"] = Vector3.ZERO
        MODE_MOVE_TO_POINT:
            var destination: Variant = payload.get("destination")
            if not destination is Vector3 or not _is_finite_vector(destination):
                return false
            state["movement_mode"] = MODE_MOVE_TO_POINT
            state["current_destination"] = Vector3(destination.x, state["position"].y, destination.z)
        MODE_FOLLOW_CURSOR:
            var direction: Variant = payload.get("direction")
            if not direction is Vector3 or not _is_finite_vector(direction):
                return false
            var horizontal := Vector3(direction.x, 0.0, direction.z)
            if horizontal.is_zero_approx():
                return false
            state["direction"] = horizontal.normalized()
            state["movement_mode"] = MODE_FOLLOW_CURSOR
        _:
            return false

    state["last_processed_input_sequence"] = sequence
    state["last_input_tick"] = current_tick
    return true

func simulate_tick(delta: float) -> void:
    for entity_id: int in _states:
        var state: Dictionary = _states[entity_id]
        var direction := Vector3.ZERO
        var desired_position: Vector3
        var completing_destination := false
        if state["movement_mode"] == MODE_MOVE_TO_POINT:
            var offset: Vector3 = state["current_destination"] - state["position"]
            offset.y = 0.0
            var max_step: float = state["move_speed"] * delta
            if offset.length() <= maxf(_arrival_distance, max_step):
                desired_position = state["position"] + offset
                completing_destination = true
            else:
                direction = offset.normalized()
                desired_position = (
                    state["position"]
                    + direction * float(state["move_speed"]) * delta
                )
        elif state["movement_mode"] == MODE_FOLLOW_CURSOR:
            direction = state["direction"]
            desired_position = (
                state["position"]
                + direction * float(state["move_speed"]) * delta
            )
        else:
            state["velocity"] = Vector3.ZERO
            continue
        var previous_position: Vector3 = state["position"]
        state["position"] = _collision_map.resolve_motion(
            previous_position,
            desired_position,
            _player_radius
        )
        state["velocity"] = (
            (state["position"] - previous_position) / delta
            if delta > 0.0
            else Vector3.ZERO
        )
        if (
            completing_destination
            and state["position"].is_equal_approx(desired_position)
        ):
            state["velocity"] = Vector3.ZERO
            state["movement_mode"] = MODE_STOP

func create_snapshot(server_tick: int) -> Dictionary:
    var entities: Array[Dictionary] = []
    for entity_id: int in _states:
        var state: Dictionary = _states[entity_id]
        entities.append({
            "entity_id": entity_id,
            "entity_type": "player",
            "position": state["position"],
            "velocity": state["velocity"],
            "movement_mode": String(state["movement_mode"]),
            "last_processed_input_sequence": state["last_processed_input_sequence"],
        })
    return {"server_tick": server_tick, "entities": entities}

func remove_player(entity_id: int) -> bool:
    return _states.erase(entity_id)

func stop_player(entity_id: int) -> bool:
    if not _states.has(entity_id):
        return false
    var state: Dictionary = _states[entity_id]
    state["velocity"] = Vector3.ZERO
    state["movement_mode"] = MODE_STOP
    state["direction"] = Vector3.ZERO
    state["current_destination"] = state["position"]
    return true

func respawn_player(entity_id: int, spawn_position: Vector3) -> bool:
    if not _states.has(entity_id):
        return false
    var state: Dictionary = _states[entity_id]
    state["position"] = spawn_position
    state["current_destination"] = spawn_position
    state["velocity"] = Vector3.ZERO
    state["direction"] = Vector3.ZERO
    state["movement_mode"] = MODE_STOP
    return true

func get_state(entity_id: int) -> Dictionary:
    if not _states.has(entity_id):
        return {}
    return (_states[entity_id] as Dictionary).duplicate(true)

func get_player_count() -> int:
    return _states.size()

func get_player_ids() -> Array[int]:
    var ids: Array[int] = []
    ids.assign(_states.keys())
    ids.sort()
    return ids

func clear() -> void:
    _states.clear()

func _is_finite_vector(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
