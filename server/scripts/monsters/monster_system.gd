class_name MonsterSystem
extends RefCounted

const STATE_IDLE: StringName = &"IDLE"
const STATE_WANDER: StringName = &"WANDER"
const STATE_CHASE: StringName = &"CHASE"
const STATE_ATTACK: StringName = &"ATTACK"
const STATE_RETURN: StringName = &"RETURN"
const STATE_DEAD: StringName = &"DEAD"
const LIFE_ALIVE: StringName = &"ALIVE"
const LIFE_DEAD: StringName = &"DEAD"

var _entities: Node
var _monsters: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lifecycle_events: Array[Dictionary] = []
var _attack_requests: Array[Dictionary] = []
var _players: RefCounted
var _aggro_interval_ticks: int = 5
var _player_lifecycle: RefCounted

func _init(entities: Node, random_seed: int) -> void:
    _entities = entities
    _rng.seed = random_seed

func configure_ai(
    players: RefCounted,
    aggro_interval_ticks: int = 5,
    player_lifecycle: RefCounted = null
) -> void:
    _players = players
    _aggro_interval_ticks = maxi(1, aggro_interval_ticks)
    _player_lifecycle = player_lifecycle

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
    var combat: Dictionary = template.get("combat", {})
    var aggro_range := float(combat.get("aggro_range", 0.0))
    var attack_range := float(combat.get("attack_range", 0.0))
    var attack_damage := int(combat.get("attack_damage", 0))
    var attack_cooldown := float(combat.get("attack_cooldown", 0.0))
    var leash_range := float(combat.get("leash_range", 0.0))
    var return_speed := float(combat.get("return_speed", move_speed))
    if (
        template_id.is_empty() or max_hp <= 0 or move_speed <= 0.0
        or respawn_seconds < 0.0 or aggro_range < 0.0 or attack_range < 0.0
        or attack_damage < 0 or attack_cooldown < 0.0 or leash_range < 0.0
        or return_speed <= 0.0
    ):
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
        "xp_reward": int(template.get("xp_reward", 0)),
        "loot_table_id": String(template.get("loot_table_id", "")),
        "aggro_range": aggro_range,
        "attack_range": attack_range,
        "attack_damage": attack_damage,
        "attack_cooldown": attack_cooldown,
        "leash_range": leash_range,
        "return_speed": return_speed,
        "aggro_target_entity_id": 0,
    }
    return entity_id

func simulate_tick(delta: float, current_tick: int = -1) -> void:
    for entity_id: int in _monsters:
        var state: Dictionary = _monsters[entity_id]
        if state["life_state"] == LIFE_DEAD:
            state["velocity"] = Vector3.ZERO
            state["movement_state"] = STATE_DEAD
            state["aggro_target_entity_id"] = 0
            if current_tick >= 0 and current_tick >= int(state["respawn_tick"]):
                _respawn(state, current_tick)
            continue
        if _players != null and _simulate_combat_ai(state, delta, current_tick):
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
            "aggro_target_entity_id": state["aggro_target_entity_id"],
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
        state["movement_state"] = STATE_DEAD
        state["aggro_target_entity_id"] = 0
        var event := _make_lifecycle_event(state, "DIED", current_tick)
        _lifecycle_events.append(event)
    return {"applied": true, "current_hp": state["current_hp"], "died": died}

func drain_lifecycle_events() -> Array[Dictionary]:
    var events := _lifecycle_events.duplicate(true)
    _lifecycle_events.clear()
    return events

func drain_attack_requests() -> Array[Dictionary]:
    var requests := _attack_requests.duplicate(true)
    _attack_requests.clear()
    return requests

func clear_aggro_target(player_entity_id: int) -> void:
    for entity_id: int in _monsters:
        var state: Dictionary = _monsters[entity_id]
        if state["aggro_target_entity_id"] == player_entity_id:
            if state["life_state"] == LIFE_ALIVE:
                _retarget_or_return(state, player_entity_id)
            else:
                state["aggro_target_entity_id"] = 0

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
    _attack_requests.clear()

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
    state["aggro_target_entity_id"] = 0
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

func _simulate_combat_ai(state: Dictionary, delta: float, current_tick: int) -> bool:
    var target_id: int = state["aggro_target_entity_id"]
    if target_id > 0 and (
        _players.get_state(target_id).is_empty()
        or (_player_lifecycle != null and not _player_lifecycle.is_alive(target_id))
    ):
        target_id = _retarget_or_return(state, target_id)
    if target_id == 0 and state["movement_state"] != STATE_RETURN:
        if current_tick >= 0 and current_tick % _aggro_interval_ticks == 0:
            target_id = _find_nearest_player(state)
            if target_id > 0:
                state["aggro_target_entity_id"] = target_id
                state["movement_state"] = STATE_CHASE
        if target_id == 0:
            return false
    if state["movement_state"] == STATE_RETURN:
        _move_toward(state, state["spawn_position"], state["return_speed"], delta)
        if state["position"].distance_to(state["spawn_position"]) <= 0.01:
            state["position"] = state["spawn_position"]
            state["velocity"] = Vector3.ZERO
            state["movement_state"] = STATE_IDLE
            state["idle_elapsed"] = 0.0
            state["current_hp"] = state["max_hp"]
        return true
    var target: Dictionary = _players.get_state(target_id)
    if target.is_empty():
        return true
    if state["position"].distance_to(state["spawn_position"]) > state["leash_range"]:
        state["aggro_target_entity_id"] = 0
        state["movement_state"] = STATE_RETURN
        state["velocity"] = Vector3.ZERO
        return true
    var distance: float = state["position"].distance_to(target["position"])
    if distance <= state["attack_range"]:
        state["movement_state"] = STATE_ATTACK
        state["velocity"] = Vector3.ZERO
        _attack_requests.append({
            "attacker_entity_id": state["entity_id"],
            "target_entity_id": target_id,
            "server_tick": current_tick,
        })
    else:
        state["movement_state"] = STATE_CHASE
        _move_toward(state, target["position"], state["move_speed"], delta)
    return true

func _find_nearest_player(
    state: Dictionary,
    excluded_player_id: int = 0,
    require_spawn_leash: bool = false
) -> int:
    var nearest_id := 0
    var nearest_distance := INF
    for player_id: int in _players.get_player_ids():
        if player_id == excluded_player_id:
            continue
        var player: Dictionary = _players.get_state(player_id)
        if player.is_empty():
            continue
        if _player_lifecycle != null and not _player_lifecycle.is_alive(player_id):
            continue
        var distance: float = state["position"].distance_to(player["position"])
        var spawn_distance: float = state["spawn_position"].distance_to(player["position"])
        if distance <= state["aggro_range"] and (not require_spawn_leash or spawn_distance <= state["leash_range"]) and (
            distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and player_id < nearest_id)
        ):
            nearest_id = player_id
            nearest_distance = distance
    return nearest_id

func _retarget_or_return(state: Dictionary, excluded_player_id: int) -> int:
    var replacement_id := _find_nearest_player(state, excluded_player_id, true)
    state["aggro_target_entity_id"] = replacement_id
    state["velocity"] = Vector3.ZERO
    state["movement_state"] = STATE_CHASE if replacement_id > 0 else STATE_RETURN
    return replacement_id

func _move_toward(state: Dictionary, destination: Vector3, speed: float, delta: float) -> void:
    var offset: Vector3 = destination - state["position"]
    offset.y = 0.0
    var max_step := speed * delta
    if offset.length() <= max_step:
        state["position"] += offset
        state["velocity"] = Vector3.ZERO
    else:
        state["velocity"] = offset.normalized() * speed
        state["position"] += state["velocity"] * delta

func _is_finite_vector(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
