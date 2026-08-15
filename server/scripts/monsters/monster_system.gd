class_name MonsterSystem
extends RefCounted

const STATE_IDLE: StringName = &"IDLE"
const STATE_WANDER: StringName = &"WANDER"
const LIFE_ALIVE: StringName = &"ALIVE"
const LIFE_DEAD: StringName = &"DEAD"

var _entities: Node
var _monsters: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lifecycle_events: Array[Dictionary] = []

func _init(entities: Node, random_seed: int) -> void:
    _entities = entities
    _rng.seed = random_seed

func spawn_monster(template: Dictionary, position: Vector3, created_tick: int) -> int:
    if template.is_empty() or not _is_finite_vector(position):
        return 0
    var template_id: String = template.get("id", "")
    var stats: Dictionary = template.get("stats", {})
    var wander: Dictionary = template.get("wander", {})
    var max_hp := int(stats.get("max_hp", 0))
    var move_speed := float(stats.get("move_speed", 0.0))
    var wander_radius := float(wander.get("radius", 0.0))
    var idle_seconds := float(wander.get("idle_seconds", 0.0))
    var respawn_seconds := float(template.get("respawn_seconds", 0.0))
    if template_id.is_empty() or max_hp <= 0 or move_speed <= 0.0 or respawn_seconds < 0.0:
        return 0
    var entity_id: int = _entities.register_entity(
        &"monster",
        created_tick,
        {"template_id": template_id}
    )
    _monsters[entity_id] = {
        "entity_id": entity_id,
        "entity_type": "monster",
        "template_id": template_id,
        "position": position,
        "velocity": Vector3.ZERO,
        "max_hp": max_hp,
        "current_hp": max_hp,
        "movement_state": STATE_IDLE,
        "spawn_position": position,
        "wander_target": position,
        "wander_radius": wander_radius,
        "idle_seconds": idle_seconds,
        "idle_elapsed": 0.0,
        "move_speed": move_speed,
        "life_state": LIFE_ALIVE,
        "killer_entity_id": 0,
        "death_tick": -1,
        "respawn_tick": -1,
        "respawn_seconds": respawn_seconds,
    }
    return entity_id

func simulate_tick(delta: float, current_tick: int = -1) -> void:
    for entity_id: int in _monsters:
        var state: Dictionary = _monsters[entity_id]
        if state["life_state"] == LIFE_DEAD:
            state["velocity"] = Vector3.ZERO
            if current_tick >= 0 and current_tick >= int(state["respawn_tick"]):
                _respawn(state, current_tick)
            continue
        if state["movement_state"] == STATE_IDLE:
            state["velocity"] = Vector3.ZERO
            state["idle_elapsed"] += delta
            if state["idle_elapsed"] >= state["idle_seconds"]:
                _begin_wander(state)
        elif state["movement_state"] == STATE_WANDER:
            var offset: Vector3 = state["wander_target"] - state["position"]
            offset.y = 0.0
            var max_step: float = state["move_speed"] * delta
            if offset.length() <= max_step:
                state["position"] += offset
                state["velocity"] = Vector3.ZERO
                state["movement_state"] = STATE_IDLE
                state["idle_elapsed"] = 0.0
            else:
                state["velocity"] = offset.normalized() * float(state["move_speed"])
                state["position"] += state["velocity"] * delta

func create_snapshot_entities() -> Array[Dictionary]:
    var snapshot_entities: Array[Dictionary] = []
    for entity_id: int in _monsters:
        var state: Dictionary = _monsters[entity_id]
        snapshot_entities.append({
            "entity_id": entity_id,
            "entity_type": "monster",
            "template_id": state["template_id"],
            "position": state["position"],
            "velocity": state["velocity"],
            "movement_state": String(state["movement_state"]),
            "current_hp": state["current_hp"],
            "max_hp": state["max_hp"],
            "life_state": String(state["life_state"]),
            "killer_entity_id": state["killer_entity_id"],
            "death_tick": state["death_tick"],
            "respawn_tick": state["respawn_tick"],
        })
    return snapshot_entities

func create_world_snapshot(
    server_tick: int,
    other_entities: Array = []
) -> Dictionary:
    var entities: Array = other_entities.duplicate(true)
    entities.append_array(create_snapshot_entities())
    return {"server_tick": server_tick, "entities": entities}

func despawn_monster(entity_id: int) -> bool:
    if not _monsters.erase(entity_id):
        return false
    _entities.remove_entity(entity_id)
    return true

func get_state(entity_id: int) -> Dictionary:
    if not _monsters.has(entity_id):
        return {}
    return (_monsters[entity_id] as Dictionary).duplicate(true)

func apply_server_damage(
    entity_id: int,
    damage: int,
    attacker_entity_id: int = 0,
    current_tick: int = 0,
    tick_rate: int = 30
) -> Dictionary:
    if not _monsters.has(entity_id) or damage <= 0:
        return {"applied": false, "current_hp": 0, "died": false}
    var state: Dictionary = _monsters[entity_id]
    if state["life_state"] != LIFE_ALIVE:
        return {"applied": false, "current_hp": state["current_hp"], "died": false}
    state["current_hp"] = maxi(0, int(state["current_hp"]) - damage)
    var died: bool = int(state["current_hp"]) == 0
    if died:
        state["life_state"] = LIFE_DEAD
        state["killer_entity_id"] = attacker_entity_id
        state["death_tick"] = current_tick
        state["respawn_tick"] = current_tick + maxi(
            1,
            int(ceil(float(state["respawn_seconds"]) * float(tick_rate)))
        )
        state["velocity"] = Vector3.ZERO
        state["movement_state"] = STATE_IDLE
        var event := _make_lifecycle_event(state, "DIED", current_tick)
        _lifecycle_events.append(event)
    return {"applied": true, "current_hp": state["current_hp"], "died": died}

func drain_lifecycle_events() -> Array[Dictionary]:
    var events := _lifecycle_events.duplicate(true)
    _lifecycle_events.clear()
    return events

func get_monster_ids() -> Array[int]:
    var ids: Array[int] = []
    ids.assign(_monsters.keys())
    return ids

func get_monster_count() -> int:
    return _monsters.size()

func clear() -> void:
    for entity_id in get_monster_ids():
        despawn_monster(entity_id)
    _lifecycle_events.clear()

func _respawn(state: Dictionary, current_tick: int) -> void:
    state["life_state"] = LIFE_ALIVE
    state["current_hp"] = state["max_hp"]
    state["position"] = state["spawn_position"]
    state["velocity"] = Vector3.ZERO
    state["movement_state"] = STATE_IDLE
    state["idle_elapsed"] = 0.0
    state["wander_target"] = state["spawn_position"]
    state["killer_entity_id"] = 0
    state["death_tick"] = -1
    state["respawn_tick"] = -1
    _lifecycle_events.append(_make_lifecycle_event(state, "RESPAWNED", current_tick))

func _make_lifecycle_event(state: Dictionary, event_type: String, current_tick: int) -> Dictionary:
    return {
        "event_type": event_type,
        "server_tick": current_tick,
        "entity_id": state["entity_id"],
        "life_state": String(state["life_state"]),
        "killer_entity_id": state["killer_entity_id"],
        "current_hp": state["current_hp"],
        "max_hp": state["max_hp"],
        "position": state["position"],
    }

func _begin_wander(state: Dictionary) -> void:
    var angle := _rng.randf_range(0.0, TAU)
    var radius := _rng.randf_range(0.25, float(state["wander_radius"]))
    state["wander_target"] = state["spawn_position"] + Vector3(
        cos(angle) * radius,
        0.0,
        sin(angle) * radius
    )
    state["movement_state"] = STATE_WANDER

func _is_finite_vector(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
