extends RefCounted

const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const MONSTER_SYSTEM_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TARGETING_SYSTEM_SCRIPT: Script = preload("res://scripts/targeting/targeting_system.gd")

func run(suite) -> void:
    var c := _context()
    suite.check("TGT-001 READY player can target monster", c.targeting.request_target(2, c.monster_id))
    suite.check("TGT-007 accepted target stored server-side", c.targeting.get_target(c.player_a) == c.monster_id)
    suite.check("TGT-013 duplicate request safe", c.targeting.request_target(2, c.monster_id) and c.targeting.get_target(c.player_a) == c.monster_id)
    suite.check("TGT-008 clear target works", c.targeting.request_target(2, 0) and c.targeting.get_target(c.player_a) == 0)
    suite.check("TGT-002 non-READY session rejected", not c.targeting.request_target(99, c.monster_id))
    suite.check("TGT-003 nonexistent entity rejected", not c.targeting.request_target(2, 99999))
    suite.check("TGT-004 self target rejected", not c.targeting.request_target(2, c.player_a))
    suite.check("TGT-005 player entity type rejected", not c.targeting.request_target(2, c.player_b))
    suite.check("TGT-011 unknown peer rejected", not c.targeting.request_target(404, c.monster_id))
    suite.check("TGT-012 malformed target ID rejected", not c.targeting.request_target(2, "monster"))
    c.targeting.request_target(2, c.monster_id)
    suite.check("TGT-010 A target does not modify B", c.targeting.get_target(c.player_a) == c.monster_id and c.targeting.get_target(c.player_b) == 0)
    c.monsters.despawn_monster(c.monster_id)
    c.targeting.cleanup_invalid_targets()
    suite.check("TGT-009 despawn clears target", c.targeting.get_target(c.player_a) == 0)
    _free(c)
    _out_of_range(suite)

func _context(monster_position: Vector3 = Vector3(6.0, 0.1, -2.0)) -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    var monsters = MONSTER_SYSTEM_SCRIPT.new(entities, 1)
    var monster_id: int = monsters.spawn_monster({
        "id": "test_monster",
        "stats": {"max_hp": 100, "move_speed": 1.0},
        "wander": {"radius": 1.0, "idle_seconds": 1.0},
    }, monster_position, 0)
    var handshake = HANDSHAKE_SERVICE_SCRIPT.new(entities, sessions, 1)
    sessions.create_pending_session(2, 0, 100)
    var player_a: int = handshake.process_handshake(2, {"protocol_version": 1}, 1).entity_id
    sessions.create_pending_session(3, 0, 100)
    var player_b: int = handshake.process_handshake(3, {"protocol_version": 1}, 1).entity_id
    var movement = MOVEMENT_SYSTEM_SCRIPT.new(sessions, entities, 5.0)
    movement.register_ready_player(2, Vector3.ZERO)
    movement.register_ready_player(3, Vector3(2.0, 0.0, 0.0))
    var targeting = TARGETING_SYSTEM_SCRIPT.new(sessions, entities, movement, monsters, 30.0)
    return {"entities": entities, "sessions": sessions, "monsters": monsters, "movement": movement, "targeting": targeting, "monster_id": monster_id, "player_a": player_a, "player_b": player_b}

func _out_of_range(suite) -> void:
    var c := _context(Vector3(40.0, 0.1, 0.0))
    suite.check("TGT-006 out-of-range target rejected", not c.targeting.request_target(2, c.monster_id))
    _free(c)

func _free(c: Dictionary) -> void:
    (c.entities as Node).free()
    (c.sessions as Node).free()
