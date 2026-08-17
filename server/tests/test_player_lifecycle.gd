extends RefCounted

const ENTITY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const MONSTER_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TARGETING_SCRIPT: Script = preload("res://scripts/targeting/targeting_system.gd")
const COMBAT_SCRIPT: Script = preload("res://scripts/combat/combat_system.gd")
const HEALTH_SCRIPT: Script = preload("res://scripts/combat/player_health_system.gd")

func run(suite) -> void:
    _death_respawn_security(suite)
    _disconnect_while_dead(suite)

func _context() -> Dictionary:
    var entities = ENTITY_SCRIPT.new()
    var sessions = SESSION_SCRIPT.new()
    sessions.create_pending_session(2, 0, 100)
    var handshake = HANDSHAKE_SCRIPT.new(entities, sessions, 1)
    var player_id: int = handshake.process_handshake(2, {"protocol_version": 1}, 1).entity_id
    var movement = MOVEMENT_SCRIPT.new(sessions, entities, 5.0)
    var spawn := Vector3(0.5, 0.1, 0.0)
    movement.register_ready_player(2, spawn)
    var health = HEALTH_SCRIPT.new(100, 1.0, 30)
    health.register_player(player_id, spawn)
    movement.configure_player_lifecycle(health)
    var monsters = MONSTER_SCRIPT.new(entities, 1)
    monsters.configure_ai(movement, 1, health)
    var monster_id: int = monsters.spawn_monster({
        "id": "lethal_monster",
        "stats": {"max_hp": 100, "move_speed": 2.0},
        "wander": {"radius": 1.0, "idle_seconds": 100.0},
        "respawn_seconds": 1.0,
        "combat": {
            "aggro_range": 5.0, "attack_range": 1.0,
            "attack_damage": 100, "attack_cooldown": 1.0,
            "leash_range": 5.0, "return_speed": 3.0,
        },
    }, Vector3.ZERO, 0)
    var targeting = TARGETING_SCRIPT.new(sessions, entities, movement, monsters, 30.0)
    targeting.configure_player_lifecycle(health)
    targeting.request_target(2, monster_id)
    var combat = COMBAT_SCRIPT.new(
        sessions, entities, movement, monsters, targeting,
        10, 2.5, 1.0, 30, health
    )
    monsters.simulate_tick(1.0 / 30.0, 1)
    return {
        "entities": entities, "sessions": sessions, "handshake": handshake,
        "movement": movement, "health": health, "monsters": monsters,
        "targeting": targeting, "combat": combat, "player_id": player_id,
        "monster_id": monster_id, "spawn": spawn,
    }

func _death_respawn_security(suite) -> void:
    var c := _context()
    var result: Dictionary = c.combat.process_monster_attack(c.monster_id, c.player_id, 1)
    var state: Dictionary = c.health.get_state(c.player_id)
    var events: Array[Dictionary] = c.health.drain_lifecycle_events()
    suite.check("PDEATH-001 lethal damage sets HP zero", result.accepted and state.current_hp == 0)
    suite.check("PDEATH-002 state becomes DEAD", state.life_state == &"DEAD")
    suite.check("PDEATH-003 death event exactly once", events.size() == 1 and c.health.drain_lifecycle_events().is_empty())
    suite.check("PDEATH-004 authoritative killer", events[0].killer_entity_id == c.monster_id)
    suite.check("PDEATH-005 movement stops", c.movement.get_state(c.player_id).velocity == Vector3.ZERO and c.movement.get_state(c.player_id).movement_mode == &"STOP")
    suite.check("PDEATH-006 player target clears", c.targeting.get_target(c.player_id) == 0)
    suite.check("PDEATH-007 monster aggro invalidates", c.monsters.get_state(c.monster_id).aggro_target_entity_id == 0)
    suite.check("PDEATH-SEC-001 dead cannot move", not c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(9.0, 0.0, 0.0)}, 2))
    suite.check("PDEATH-SEC-002 dead cannot attack", c.combat.process_attack(2, {"sequence": 1}, 2).reason == "PLAYER_DEAD")
    suite.check("PDEATH-SEC-003 dead cannot target", not c.targeting.request_target(2, c.monster_id))
    c.movement.process_intent(2, {"command": "STOP", "sequence": 2, "life_state": "ALIVE", "respawn_position": Vector3(99.0, 0.0, 0.0)}, 3)
    suite.check("PDEATH-SEC-004 client cannot request ALIVE", c.health.get_state(c.player_id).life_state == &"DEAD")
    suite.check("PDEATH-SEC-005 client cannot choose respawn position", c.health.get_state(c.player_id).spawn_position == c.spawn)
    suite.check("PDEATH-SEC-006 client cannot modify timer", c.health.get_state(c.player_id).respawn_tick == 31)
    c.health.simulate_tick(30)
    suite.check("PRESP-001 remains DEAD before tick", c.health.get_state(c.player_id).life_state == &"DEAD")
    c.health.simulate_tick(31)
    var respawn_events: Array[Dictionary] = c.health.drain_lifecycle_events()
    var alive: Dictionary = c.health.get_state(c.player_id)
    c.movement.respawn_player(c.player_id, respawn_events[0].respawn_position)
    suite.check("PRESP-002 respawn uses server tick", respawn_events.size() == 1 and respawn_events[0].server_tick == 31)
    suite.check("PRESP-003 state becomes ALIVE", alive.life_state == &"ALIVE")
    suite.check("PRESP-004 HP restored", alive.current_hp == alive.max_hp)
    suite.check("PRESP-005 server spawn position", c.movement.get_state(c.player_id).position == c.spawn)
    suite.check("PRESP-006 velocity zero", c.movement.get_state(c.player_id).velocity == Vector3.ZERO)
    suite.check("PRESP-007 target remains empty", c.targeting.get_target(c.player_id) == 0)
    suite.check("PRESP-008 movement works", c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(1.0, 0.1, 0.0)}, 32))
    c.targeting.request_target(2, c.monster_id)
    suite.check("PRESP-009 combat works", c.combat.process_attack(2, {"sequence": 2}, 32).accepted)
    c.health.simulate_tick(100)
    suite.check("PRESP-010 only one respawn", c.health.drain_lifecycle_events().is_empty())
    _free(c)

func _disconnect_while_dead(suite) -> void:
    var c := _context()
    c.combat.process_monster_attack(c.monster_id, c.player_id, 1)
    c.health.drain_lifecycle_events()
    c.health.remove_player(c.player_id)
    c.movement.remove_player(c.player_id)
    c.handshake.cleanup_peer(2)
    c.health.simulate_tick(31)
    suite.check("PDEATH-DISC-001 dead disconnect removes lifecycle", c.health.get_state(c.player_id).is_empty() and c.health.drain_lifecycle_events().is_empty())
    _free(c)

func _free(c: Dictionary) -> void:
    (c.entities as Node).free()
    (c.sessions as Node).free()
