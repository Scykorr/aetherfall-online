extends SceneTree

const ENTITY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const NAVIGATION_SCRIPT: Script = preload("res://scripts/movement/server_navigation.gd")
const NAVIGATION_MESH: NavigationMesh = preload("res://navigation/greybox_navigation_mesh.tres")

var _passed: int = 0
var _failed: int = 0
var _navigation_world: Node3D
var _navigation: RefCounted

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await physics_frame
    await physics_frame
    _navigation_world = Node3D.new()
    root.add_child(_navigation_world)
    var navigation_region := NavigationRegion3D.new()
    navigation_region.navigation_mesh = NAVIGATION_MESH
    _navigation_world.add_child(navigation_region)
    _navigation = NAVIGATION_SCRIPT.new(navigation_region.get_navigation_map())
    await _wait_for_navigation(_navigation)
    await _straight_and_detour()
    await _replacement_and_validation()
    print("[NAV TEST SUMMARY] passed=%d failed=%d total=%d" % [_passed, _failed, _passed + _failed])
    _navigation.cleanup()
    _navigation = null
    _navigation_world.queue_free()
    await physics_frame
    await physics_frame
    quit(0 if _failed == 0 else 1)

func _context() -> Dictionary:
    var entities = ENTITY_SCRIPT.new()
    var sessions = SESSION_SCRIPT.new()
    sessions.create_pending_session(2, 0, 100)
    HANDSHAKE_SCRIPT.new(entities, sessions, 1).process_handshake(2, {"protocol_version": 1}, 1)
    var blockers: Array[Dictionary] = [{"shape": "box", "center": Vector2(0.0, -4.0), "half_extents": Vector2(1.5, 1.0)}]
    var movement = MOVEMENT_SCRIPT.new(sessions, entities, 5.0, 0.15, blockers, 15.0, 0.45, _navigation, 0.75)
    movement.register_ready_player(2, Vector3.ZERO)
    return {"entities": entities, "sessions": sessions, "movement": movement}

func _straight_and_detour() -> void:
    var straight := _context()
    _check("MOVE-NAV-001 straight destination accepted", straight.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(7.0, 0.0, 0.0)}, 1))
    _simulate_until_stopped(straight.movement, 1)
    _check("MOVE-NAV-001 straight destination reached", straight.movement.get_state(1).position.distance_to(Vector3(7.0, 0.0, 0.0)) <= 0.2)
    _free(straight)

    var detour := _context()
    _check("MOVE-NAV-002 obstacle destination accepted", detour.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(0.0, 0.0, -8.0)}, 1))
    var path: PackedVector3Array = detour.movement.get_authoritative_path(1)
    var has_detour := false
    for point: Vector3 in path:
        if absf(point.x) > 1.8:
            has_detour = true
            break
    _check("MOVE-NAV-002 path contains obstacle detour", path.size() >= 3 and has_detour)
    var penetrated := false
    for _tick in 300:
        detour.movement.simulate_tick(1.0 / 30.0)
        var position: Vector3 = detour.movement.get_state(1).position
        if absf(position.x) < 1.95 and position.z < -2.55 and position.z > -5.45:
            penetrated = true
    var state: Dictionary = detour.movement.get_state(1)
    _check("MOVE-NAV-003 player does not cross obstacle", not penetrated)
    _check("MOVE-NAV-004 destination behind obstacle reached", state.movement_mode == &"STOP" and state.position.distance_to(Vector3(0.0, 0.0, -8.0)) <= 0.2)
    _free(detour)

func _replacement_and_validation() -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(0.0, 0.0, -8.0)}, 1)
    for _tick in 20:
        c.movement.simulate_tick(1.0 / 30.0)
    var old_path: PackedVector3Array = c.movement.get_authoritative_path(1)
    _check("MOVE-NAV-005 replacement destination accepted", c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 2, "destination": Vector3(8.0, 0.0, 0.0)}, 2))
    var new_path: PackedVector3Array = c.movement.get_authoritative_path(1)
    _simulate_until_stopped(c.movement, 1)
    _check("MOVE-NAV-005 new destination replaces old path", new_path != old_path and c.movement.get_state(1).position.distance_to(Vector3(8.0, 0.0, 0.0)) <= 0.2)
    _check("MOVE-NAV-006 obstacle destination rejected", not c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 3, "destination": Vector3(0.0, 0.0, -4.0)}, 3))
    _check("MOVE-NAV-007 unreachable destination creates no movement", not c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 4, "destination": Vector3(30.0, 0.0, 0.0)}, 4) and c.movement.get_state(1).movement_mode == &"STOP")
    _check("MOVE-NAV-008 client path data ignored", c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 5, "destination": Vector3(0.0, 0.0, -8.0), "path": PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, -8.0)])}, 5) and c.movement.get_authoritative_path(1).size() >= 3)
    c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 6, "direction": Vector3.RIGHT}, 6)
    c.movement.simulate_tick(0.1)
    _check("MOVE-NAV-009 FOLLOW_CURSOR remains direct", is_equal_approx(c.movement.get_state(1).position.x, 8.5) and c.movement.get_authoritative_path(1).is_empty())
    _free(c)

func _simulate_until_stopped(movement: RefCounted, entity_id: int) -> void:
    for _tick in 600:
        movement.simulate_tick(1.0 / 30.0)
        if movement.get_state(entity_id).movement_mode == &"STOP":
            return

func _wait_for_navigation(navigation: RefCounted) -> void:
    for _frame in 10:
        await physics_frame
        if (
            navigation.is_ready()
            and NavigationServer3D.map_get_closest_point(
                navigation.get_map(),
                Vector3(7.0, 0.0, 0.0)
            ) != Vector3.ZERO
        ):
            return

func _check(name: String, condition: bool) -> void:
    if condition:
        _passed += 1
        print("[PASS] %s" % name)
    else:
        _failed += 1
        print("[FAIL] %s" % name)

func _free(c: Dictionary) -> void:
    (c.entities as Node).free()
    (c.sessions as Node).free()
