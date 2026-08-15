class_name MonsterSystem
extends RefCounted

const STATE_IDLE: StringName = &"IDLE"
const STATE_WANDER: StringName = &"WANDER"

var _entities: Node
var _monsters: Dictionary = {}
var _rng := RandomNumberGenerator.new()

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
    if template_id.is_empty() or max_hp <= 0 or move_speed <= 0.0:
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
    }
    return entity_id

func simulate_tick(delta: float) -> void:
    for entity_id: int in _monsters:
        var state: Dictionary = _monsters[entity_id]
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

func get_monster_ids() -> Array[int]:
    var ids: Array[int] = []
    ids.assign(_monsters.keys())
    return ids

func get_monster_count() -> int:
    return _monsters.size()

func clear() -> void:
    for entity_id in get_monster_ids():
        despawn_monster(entity_id)

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
