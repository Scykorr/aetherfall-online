extends RefCounted

const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const MONSTER_SYSTEM_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TARGETING_SYSTEM_SCRIPT: Script = preload("res://scripts/targeting/targeting_system.gd")
const COMBAT_SYSTEM_SCRIPT: Script = preload("res://scripts/combat/combat_system.gd")

func run(suite) -> void:
    _valid_attack(suite)
    _range_security(suite)
    _cooldown(suite)
    _sequence_replay(suite)
    _security(suite)
    _multi_player(suite)
    _death_transition(suite)
    _dead_target_rejected(suite)

func _context(
    monster_position: Vector3 = Vector3(2.0, 0.0, 0.0),
    max_hp: int = 100,
    two_players: bool = false
) -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    var monsters = MONSTER_SYSTEM_SCRIPT.new(entities, 1)
    var monster_id: int = monsters.spawn_monster({
        "id": "combat_target",
        "stats": {"max_hp": max_hp, "move_speed": 1.0},
        "wander": {"radius": 1.0, "idle_seconds": 100.0},
        "respawn_seconds": 1.0,
    }, monster_position, 0)
    var handshake = HANDSHAKE_SERVICE_SCRIPT.new(entities, sessions, 1)
    sessions.create_pending_session(2, 0, 100)
    var player_a: int = handshake.process_handshake(2, {"protocol_version": 1}, 1).entity_id
    if two_players:
        sessions.create_pending_session(3, 0, 100)
    var player_b: int = 0
    if two_players:
        player_b = handshake.process_handshake(3, {"protocol_version": 1}, 1).entity_id
    var movement = MOVEMENT_SYSTEM_SCRIPT.new(sessions, entities, 5.0)
    movement.register_ready_player(2, Vector3.ZERO)
    if two_players:
        movement.register_ready_player(3, Vector3(0.5, 0.0, 0.0))
    var targeting = TARGETING_SYSTEM_SCRIPT.new(sessions, entities, movement, monsters, 30.0)
    targeting.request_target(2, monster_id)
    if two_players:
        targeting.request_target(3, monster_id)
    var combat = COMBAT_SYSTEM_SCRIPT.new(
        sessions, entities, movement, monsters, targeting, 10, 2.5, 1.0, 30
    )
    return {
        "entities": entities,
        "sessions": sessions,
        "monsters": monsters,
        "movement": movement,
        "targeting": targeting,
        "combat": combat,
        "monster_id": monster_id,
        "player_a": player_a,
        "player_b": player_b,
    }

func _attack(c: Dictionary, sequence: int, tick: int, extra: Dictionary = {}) -> Dictionary:
    var payload := {"sequence": sequence}
    payload.merge(extra, true)
    return c.combat.process_attack(2, payload, tick)

func _valid_attack(suite) -> void:
    var c := _context()
    var result: Dictionary = _attack(c, 1, 10)
    var event: Dictionary = result.event
    suite.check("COM-001 valid in-range attack", result.accepted)
    suite.check("COM-002 authoritative HP decreases", c.monsters.get_state(c.monster_id).current_hp == 90)
    suite.check("COM-003 configured damage used", event.damage == 10)
    suite.check("COM-004 result server tick", event.server_tick == 10)
    suite.check("COM-005 result attacker ID", event.attacker_entity_id == c.player_a)
    suite.check("COM-006 result target ID", event.target_entity_id == c.monster_id)
    suite.check("COM-007 result current HP", event.target_current_hp == 90)
    suite.check("COM-RANGE-001 inside range accepted", result.reason == "OK")
    _free(c)

func _range_security(suite) -> void:
    var c := _context(Vector3(4.0, 0.0, 0.0))
    var before: int = c.monsters.get_state(c.monster_id).current_hp
    var result: Dictionary = _attack(c, 1, 10, {
        "attacker_position": Vector3(4.0, 0.0, 0.0),
        "attack_range": 999.0,
    })
    suite.check("COM-RANGE-002 outside range rejected", result.reason == "OUT_OF_RANGE")
    suite.check("COM-RANGE-003 out-of-range preserves HP", c.monsters.get_state(c.monster_id).current_hp == before)
    suite.check("COM-RANGE-004 spoofed attacker position ignored", not result.accepted)
    suite.check("COM-RANGE-005 spoofed attack range ignored", not result.accepted)
    _free(c)

func _cooldown(suite) -> void:
    var c := _context()
    var first: Dictionary = _attack(c, 1, 10)
    var second: Dictionary = _attack(c, 2, 11, {"client_time": 999999})
    suite.check("COM-CD-001 first attack succeeds", first.accepted)
    suite.check("COM-CD-002 immediate second rejected", second.reason == "COOLDOWN")
    suite.check("COM-CD-003 cooldown changes HP once", c.monsters.get_state(c.monster_id).current_hp == 90)
    var third: Dictionary = _attack(c, 3, 40)
    suite.check("COM-CD-004 succeeds after server ticks", third.accepted and c.monsters.get_state(c.monster_id).current_hp == 80)
    suite.check("COM-CD-005 client clock ignored", not second.accepted)
    _free(c)

func _sequence_replay(suite) -> void:
    var c := _context()
    suite.check("COM-SEQ-001 new sequence accepted", _attack(c, 1, 10).accepted)
    suite.check("COM-SEQ-002 duplicate rejected", _attack(c, 1, 40).reason == "INVALID_SEQUENCE")
    suite.check("COM-SEQ-003 old sequence rejected", _attack(c, 0, 40).reason == "INVALID_SEQUENCE")
    suite.check("COM-SEQ-004 newer sequence works", _attack(c, 2, 40).accepted)
    suite.check("COM-MULTI-003 replay creates no event", c.combat.get_event_count() == 2)
    _free(c)

func _security(suite) -> void:
    var c := _context()
    suite.check("COM-SEC-001 non-READY cannot attack", not c.combat.process_attack(99, {"sequence": 1}, 1).accepted)
    suite.check("COM-SEC-002 unknown peer cannot attack", not c.combat.process_attack(404, {"sequence": 1}, 1).accepted)
    c.targeting.clear_entity_references(c.monster_id)
    suite.check("COM-SEC-003 nonexistent/no target rejected", not _attack(c, 1, 10).accepted)
    c.targeting.request_target(2, c.player_a)
    suite.check("COM-SEC-004 player target cannot be attacked", not _attack(c, 2, 40).accepted)
    c.targeting.request_target(2, c.monster_id)
    var hp_before: int = c.monsters.get_state(c.monster_id).current_hp
    var result: Dictionary = _attack(c, 3, 50, {
        "damage": 9999,
        "target_hp": 1,
        "attacker_entity_id": 999,
    })
    suite.check("COM-SEC-005 client cannot mutate HP directly", c.monsters.get_state(c.monster_id).current_hp == hp_before - 10)
    suite.check("COM-SEC-006 arbitrary damage ignored", result.event.damage == 10)
    suite.check("COM-SEC-007 attacker spoof ignored", result.event.attacker_entity_id == c.player_a)
    _free(c)

func _multi_player(suite) -> void:
    var c := _context(Vector3(2.0, 0.0, 0.0), 100, true)
    var a: Dictionary = c.combat.process_attack(2, {"sequence": 1}, 10)
    var b: Dictionary = c.combat.process_attack(3, {"sequence": 1}, 10)
    suite.check("COM-MULTI-001 sequential attacks produce HP 80", c.monsters.get_state(c.monster_id).current_hp == 80)
    suite.check("COM-MULTI-002 each success creates result", a.accepted and b.accepted and c.combat.get_event_count() == 2)
    _free(c)

func _death_transition(suite) -> void:
    var c := _context(Vector3(2.0, 0.0, 0.0), 5, true)
    var result: Dictionary = _attack(c, 1, 10)
    var state: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("DEATH-001 lethal damage reaches zero", result.accepted and state.current_hp == 0)
    suite.check("DEATH-002 lethal hit transitions once", state.life_state == &"DEAD" and result.event.target_died)
    suite.check("DEATH-003 killer is authoritative attacker", state.killer_entity_id == c.player_a)
    suite.check(
        "DEATH-004 death clears all targets",
        c.targeting.get_target(c.player_a) == 0
        and c.targeting.get_target(c.player_b) == 0
    )
    suite.check("DEATH-005 runtime entity survives death", c.entities.get_entity(c.monster_id).entity_type == &"monster")
    _free(c)

func _dead_target_rejected(suite) -> void:
    var c := _context(Vector3(2.0, 0.0, 0.0), 5)
    _attack(c, 1, 10)
    suite.check("DEATH-006 dead monster cannot be selected", not c.targeting.request_target(2, c.monster_id))
    var event_count: int = c.combat.get_event_count()
    var result: Dictionary = _attack(c, 2, 40)
    suite.check("DEATH-007 attack against dead target rejected", not result.accepted and result.reason == "NO_TARGET")
    suite.check("DEATH-008 rejected dead attack creates no damage event", c.combat.get_event_count() == event_count)
    _free(c)

func _free(c: Dictionary) -> void:
    (c.entities as Node).free()
    (c.sessions as Node).free()
