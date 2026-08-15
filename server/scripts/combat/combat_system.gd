class_name CombatSystem
extends RefCounted

const OK: String = "OK"
const NOT_READY: String = "NOT_READY"
const INVALID_SEQUENCE: String = "INVALID_SEQUENCE"
const NO_TARGET: String = "NO_TARGET"
const INVALID_TARGET: String = "INVALID_TARGET"
const TARGET_DEAD: String = "TARGET_DEAD"
const OUT_OF_RANGE: String = "OUT_OF_RANGE"
const COOLDOWN: String = "COOLDOWN"

var _sessions: Node
var _entities: Node
var _movement: RefCounted
var _monsters: RefCounted
var _targeting: RefCounted
var _damage: int
var _range: float
var _cooldown_ticks: int
var _simulation_tick_rate: int
var _player_states: Dictionary = {}
var _events: Array[Dictionary] = []
var _player_health: RefCounted
var _monster_next_attack_tick: Dictionary = {}

func _init(
    sessions: Node,
    entities: Node,
    movement: RefCounted,
    monsters: RefCounted,
    targeting: RefCounted,
    damage: int,
    attack_range: float,
    cooldown_seconds: float,
    simulation_tick_rate: int,
    player_health: RefCounted = null
) -> void:
    _sessions = sessions
    _entities = entities
    _movement = movement
    _monsters = monsters
    _targeting = targeting
    _damage = maxi(1, damage)
    _range = maxf(0.0, attack_range)
    _cooldown_ticks = maxi(1, int(ceil(cooldown_seconds * simulation_tick_rate)))
    _simulation_tick_rate = simulation_tick_rate
    _player_health = player_health

func process_attack(peer_id: int, payload: Variant, current_tick: int) -> Dictionary:
    var session: Dictionary = _sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return _rejected(NOT_READY)
    var attacker_id: int = session.get("entity_id", 0)
    if attacker_id <= 0 or _entities.get_entity(attacker_id).is_empty():
        return _rejected(NOT_READY)
    if not payload is Dictionary or not payload.get("sequence") is int:
        return _rejected(INVALID_SEQUENCE)
    var sequence: int = payload["sequence"]
    var state: Dictionary = _player_states.get(attacker_id, {
        "last_attack_sequence": 0,
        "next_attack_tick": 0,
    })
    if sequence <= state["last_attack_sequence"]:
        return _rejected(INVALID_SEQUENCE)
    state["last_attack_sequence"] = sequence
    _player_states[attacker_id] = state

    var target_id: int = _targeting.get_target(attacker_id)
    if target_id <= 0:
        return _rejected(NO_TARGET)
    var target_entity: Dictionary = _entities.get_entity(target_id)
    if target_entity.is_empty() or target_entity.get("entity_type") != &"monster":
        return _rejected(INVALID_TARGET)
    var attacker_state: Dictionary = _movement.get_state(attacker_id)
    var target_state: Dictionary = _monsters.get_state(target_id)
    if attacker_state.is_empty() or target_state.is_empty():
        return _rejected(INVALID_TARGET)
    if target_state.get("life_state", &"ALIVE") != &"ALIVE":
        return _rejected(TARGET_DEAD)
    if attacker_state.position.distance_to(target_state.position) > _range:
        return _rejected(OUT_OF_RANGE)
    if current_tick < state["next_attack_tick"]:
        return _rejected(COOLDOWN)

    var damage: int = _calculate_basic_attack_damage()
    var damage_result: Dictionary = _monsters.apply_server_damage(
        target_id,
        damage,
        attacker_id,
        current_tick,
        _simulation_tick_rate
    )
    if not damage_result["applied"]:
        return _rejected(INVALID_TARGET)
    var target_hp: int = damage_result["current_hp"]
    state["next_attack_tick"] = current_tick + _cooldown_ticks
    var event := {
        "result_type": "HIT",
        "server_tick": current_tick,
        "attacker_entity_id": attacker_id,
        "target_entity_id": target_id,
        "damage": damage,
        "target_current_hp": target_hp,
        "attack_sequence": sequence,
        "target_died": damage_result["died"],
    }
    _events.append(event)
    if damage_result["died"]:
        _targeting.clear_entity_references(target_id)
    return {"accepted": true, "reason": OK, "event": event}

func remove_player(player_entity_id: int) -> void:
    _player_states.erase(player_entity_id)

func process_monster_attack(
    attacker_entity_id: int,
    target_entity_id: int,
    current_tick: int
) -> Dictionary:
    if _player_health == null:
        return _rejected(INVALID_TARGET)
    var attacker: Dictionary = _monsters.get_state(attacker_entity_id)
    var target: Dictionary = _movement.get_state(target_entity_id)
    if (
        attacker.is_empty() or target.is_empty()
        or attacker.get("life_state") != &"ALIVE"
        or attacker.get("aggro_target_entity_id", 0) != target_entity_id
        or attacker.get("movement_state") != &"ATTACK"
    ):
        return _rejected(INVALID_TARGET)
    if attacker.position.distance_to(target.position) > float(attacker["attack_range"]):
        return _rejected(OUT_OF_RANGE)
    if current_tick < int(_monster_next_attack_tick.get(attacker_entity_id, 0)):
        return _rejected(COOLDOWN)
    var damage: int = int(attacker["attack_damage"])
    var damage_result: Dictionary = _player_health.apply_server_damage(target_entity_id, damage)
    if not damage_result["applied"]:
        return _rejected(INVALID_TARGET)
    _monster_next_attack_tick[attacker_entity_id] = current_tick + maxi(
        1,
        int(ceil(float(attacker["attack_cooldown"]) * _simulation_tick_rate))
    )
    var event := {
        "result_type": "HIT",
        "server_tick": current_tick,
        "attacker_entity_id": attacker_entity_id,
        "target_entity_id": target_entity_id,
        "damage": damage,
        "target_current_hp": damage_result["current_hp"],
        "attack_sequence": 0,
        "target_died": false,
    }
    _events.append(event)
    return {"accepted": true, "reason": OK, "event": event}

func get_event_count() -> int:
    return _events.size()

func get_events() -> Array[Dictionary]:
    return _events.duplicate(true)

func clear() -> void:
    _player_states.clear()
    _events.clear()
    _monster_next_attack_tick.clear()

func _calculate_basic_attack_damage() -> int:
    return _damage

func _rejected(reason: String) -> Dictionary:
    return {"accepted": false, "reason": reason, "event": {}}
