extends RefCounted

const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const MONSTER_SYSTEM_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TARGETING_SYSTEM_SCRIPT: Script = preload("res://scripts/targeting/targeting_system.gd")
const COMBAT_SYSTEM_SCRIPT: Script = preload("res://scripts/combat/combat_system.gd")
const PLAYER_HEALTH_SCRIPT: Script = preload("res://scripts/combat/player_health_system.gd")

func run(suite) -> void:
    _aggro_and_chase(suite)
    _attack_and_hp(suite)
    _leash_and_return(suite)
    _death_interaction(suite)

func _template(overrides: Dictionary = {}) -> Dictionary:
    var combat := {
        "aggro_range": 6.0,
        "attack_range": 1.0,
        "attack_damage": 10,
        "attack_cooldown": 1.0,
        "leash_range": 4.0,
        "return_speed": 3.0,
    }
    combat.merge(overrides, true)
    return {
        "id": "ai_test_monster",
        "stats": {"max_hp": 100, "move_speed": 2.0},
        "wander": {"radius": 1.0, "idle_seconds": 100.0},
        "respawn_seconds": 1.0,
        "combat": combat,
    }

func _context(player_positions: Array[Vector3], monster_position := Vector3.ZERO) -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    var movement = MOVEMENT_SYSTEM_SCRIPT.new(sessions, entities, 5.0)
    var health = PLAYER_HEALTH_SCRIPT.new(100)
    var handshake = HANDSHAKE_SERVICE_SCRIPT.new(entities, sessions, 1)
    var player_ids: Array[int] = []
    for index in player_positions.size():
        var peer_id: int = index + 2
        sessions.create_pending_session(peer_id, 0, 100)
        var player_id: int = handshake.process_handshake(peer_id, {"protocol_version": 1}, 1).entity_id
        movement.register_ready_player(peer_id, player_positions[index])
        health.register_player(player_id)
        player_ids.append(player_id)
    var monsters = MONSTER_SYSTEM_SCRIPT.new(entities, 7)
    monsters.configure_ai(movement, 1)
    var monster_id: int = monsters.spawn_monster(_template(), monster_position, 0)
    var targeting = TARGETING_SYSTEM_SCRIPT.new(sessions, entities, movement, monsters, 30.0)
    var combat = COMBAT_SYSTEM_SCRIPT.new(
        sessions, entities, movement, monsters, targeting, 10, 2.5, 1.0, 30, health
    )
    return {
        "entities": entities, "sessions": sessions, "movement": movement,
        "health": health, "monsters": monsters, "monster_id": monster_id,
        "players": player_ids, "combat": combat,
    }

func _tick(c: Dictionary, tick: int, delta: float = 1.0 / 30.0) -> Array[Dictionary]:
    c.monsters.simulate_tick(delta, tick)
    return c.monsters.drain_attack_requests()

func _free(c: Dictionary) -> void:
    (c.entities as Node).free()
    (c.sessions as Node).free()

func _aggro_and_chase(suite) -> void:
    var outside := _context([Vector3(7.0, 0.0, 0.0)])
    _tick(outside, 1)
    suite.check("AI-AGGRO-001 outside range has no aggro", outside.monsters.get_state(outside.monster_id).aggro_target_entity_id == 0)
    _free(outside)
    var c := _context([Vector3(4.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)])
    _tick(c, 1)
    var state: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-AGGRO-002 inside range acquired", state.aggro_target_entity_id > 0)
    suite.check("AI-AGGRO-003 nearest deterministic player", state.aggro_target_entity_id == c.players[1])
    suite.check("AI-AGGRO-004 aggro target server-owned", state.aggro_target_entity_id != c.players[0])
    suite.check("AI-CHASE-001 aggro enters CHASE", state.movement_state == &"CHASE")
    var before: Vector3 = state.position
    _tick(c, 2)
    var after: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-CHASE-002 moves toward authoritative position", after.position.x > before.x)
    suite.check("AI-CHASE-003 respects template speed", after.position.distance_to(before) <= 2.0 / 30.0 + 0.001)
    c.movement.process_intent(3, {"command": "STOP", "sequence": 1, "position": Vector3(999.0, 0.0, 0.0)}, 3)
    _tick(c, 3)
    suite.check("AI-CHASE-004 spoofed position ignored", c.monsters.get_state(c.monster_id).position.x < 1.0)
    var dead := _context([Vector3(2.0, 0.0, 0.0)])
    dead.monsters.apply_server_damage(dead.monster_id, 100, dead.players[0], 1, 30)
    _tick(dead, 2)
    suite.check("AI-AGGRO-005 dead monster cannot acquire", dead.monsters.get_state(dead.monster_id).aggro_target_entity_id == 0)
    c.monsters.clear_aggro_target(c.players[1])
    suite.check("AI-AGGRO-006 disconnected target cleared", c.monsters.get_state(c.monster_id).aggro_target_entity_id == 0)
    _free(dead); _free(c)

func _attack_and_hp(suite) -> void:
    var c := _context([Vector3(0.5, 0.0, 0.0)])
    suite.check("PHP-001 player HP initialized", c.health.get_state(c.players[0]).current_hp == 100)
    var requests := _tick(c, 1)
    var state: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-CHASE-005 range enters ATTACK", state.movement_state == &"ATTACK")
    var first: Dictionary = c.combat.process_monster_attack(c.monster_id, c.players[0], 1)
    suite.check("AI-ATK-001 in-range attack accepted", first.accepted)
    suite.check("AI-ATK-002 authoritative player HP decreases", c.health.get_state(c.players[0]).current_hp == 90)
    suite.check("AI-ATK-003 template damage used", first.event.damage == 10)
    suite.check("AI-ATK-007 event monster attacker", first.event.attacker_entity_id == c.monster_id)
    suite.check("AI-ATK-008 event player target", first.event.target_entity_id == c.players[0])
    suite.check("PHP-002 monster damage mutates health system", first.event.target_current_hp == 90)
    var cooldown: Dictionary = c.combat.process_monster_attack(c.monster_id, c.players[0], 2)
    suite.check("AI-ATK-005 cooldown blocks every tick", cooldown.reason == "COOLDOWN" and c.health.get_state(c.players[0]).current_hp == 90)
    suite.check("AI-ATK-006 succeeds after cooldown ticks", c.combat.process_monster_attack(c.monster_id, c.players[0], 31).accepted)
    var spoof_before: int = c.health.get_state(c.players[0]).current_hp
    c.combat.process_monster_attack(c.monster_id, c.players[0], 32)
    suite.check("PHP-003 client cannot mutate player HP", c.health.get_state(c.players[0]).current_hp == spoof_before)
    suite.check("PHP-004 client cannot choose incoming damage", first.event.damage == state.attack_damage)
    for tick in range(61, 400, 30):
        c.combat.process_monster_attack(c.monster_id, c.players[0], tick)
    suite.check("PHP-005 temporary HP floor is one", c.health.get_state(c.players[0]).current_hp == 1)
    c.movement.process_intent(2, {
        "command": "MOVE_TO_POINT", "sequence": 1,
        "destination": Vector3(2.0, 0.0, 0.0),
    }, 400)
    c.movement.simulate_tick(0.4)
    _tick(c, 401)
    suite.check("AI-CHASE-006 leaving attack range returns to CHASE", c.monsters.get_state(c.monster_id).movement_state == &"CHASE")
    var far := _context([Vector3(2.0, 0.0, 0.0)])
    _tick(far, 1)
    var hp_before: int = far.health.get_state(far.players[0]).current_hp
    var rejected: Dictionary = far.combat.process_monster_attack(far.monster_id, far.players[0], 1)
    suite.check("AI-ATK-004 outside range cannot damage", not rejected.accepted and far.health.get_state(far.players[0]).current_hp == hp_before)
    suite.check("AI attack request produced in range", requests.size() == 1)
    _free(far); _free(c)

func _leash_and_return(suite) -> void:
    var c := _context([Vector3(5.5, 0.0, 0.0)])
    for tick in 30:
        _tick(c, tick + 1)
    suite.check("AI-LEASH-001 inside leash chase continues", c.monsters.get_state(c.monster_id).movement_state == &"CHASE")
    for tick in range(31, 150):
        _tick(c, tick)
        if c.monsters.get_state(c.monster_id).movement_state == &"RETURN":
            break
    var returning: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-LEASH-002 outside leash clears aggro", returning.aggro_target_entity_id == 0)
    suite.check("AI-LEASH-003 outside leash enters RETURN", returning.movement_state == &"RETURN")
    var before: float = returning.position.distance_to(returning.spawn_position)
    _tick(c, 151)
    suite.check("AI-LEASH-004 RETURN moves toward spawn", c.monsters.get_state(c.monster_id).position.distance_to(returning.spawn_position) < before)
    c.monsters.apply_server_damage(c.monster_id, 20, c.players[0], 152, 30)
    for tick in range(152, 300):
        _tick(c, tick)
        if c.monsters.get_state(c.monster_id).movement_state == &"IDLE":
            break
    var returned: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-LEASH-005 reaching spawn enters IDLE", returned.movement_state == &"IDLE")
    suite.check("AI-LEASH-006 successful return resets HP", returned.current_hp == returned.max_hp)
    _free(c)

func _death_interaction(suite) -> void:
    var c := _context([Vector3(3.0, 0.0, 0.0)])
    _tick(c, 1)
    c.monsters.apply_server_damage(c.monster_id, 100, c.players[0], 2, 30)
    var dead: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-DEATH-001 death during chase clears aggro", dead.aggro_target_entity_id == 0)
    suite.check("AI-DEATH-002 death stops movement", dead.velocity == Vector3.ZERO)
    suite.check("AI-DEATH-003 death prevents attack", not c.combat.process_monster_attack(c.monster_id, c.players[0], 3).accepted)
    c.monsters.simulate_tick(1.0 / 30.0, 32)
    var alive: Dictionary = c.monsters.get_state(c.monster_id)
    suite.check("AI-DEATH-004 respawn has no stale aggro", alive.life_state == &"ALIVE" and alive.aggro_target_entity_id == 0)
    suite.check("AI-DEATH-005 respawn restores initial state", alive.movement_state == &"IDLE")
    _free(c)
