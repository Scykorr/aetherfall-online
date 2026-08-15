extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/world/main.tscn"
const NAVIGATION_SYNC_FRAMES := 120
const MOVEMENT_TIMEOUT_FRAMES := 900

var _failures: int = 0

func _init() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
    if packed_scene == null:
        _fail("Could not load main scene.")
        quit(_failures)
        return

    var main := packed_scene.instantiate() as Node3D
    root.add_child(main)
    var navigation_region := main.get_node(
        "NavigationGreybox"
    ) as NavigationRegion3D
    var movement_controller := main.get_node(
        "MouseMovementController"
    ) as MouseMovementController
    var player := main.get_node("Player") as PlayerController
    var camera := main.get_node("Camera3D") as MmorpgCamera
    var navigation_map := navigation_region.get_navigation_map()
    print(
        "Processing: main=%s movement=%s player=%s inside_tree=%s"
        % [
            main.can_process(),
            movement_controller.is_physics_processing(),
            player.is_physics_processing(),
            movement_controller.is_inside_tree(),
        ]
    )

    if not await _wait_for_navigation_map(navigation_map):
        _fail("Navigation map did not synchronize.")
        quit(_failures)
        return
    _print_navigation_diagnostics(navigation_region, navigation_map)

    _assert_path_exists(
        navigation_map,
        Vector3(0.0, 0.3, 0.0),
        Vector3(7.0, 0.3, 0.0),
        "straight path"
    )
    _assert_cube_detour(navigation_map)
    _assert_column_detour(navigation_map)
    _assert_path_exists(
        navigation_map,
        Vector3(-1.5, 0.3, 1.0),
        Vector3(-1.5, 0.3, 9.0),
        "passage path"
    )
    _assert_obstacle_target_rejected(movement_controller)
    _assert_outside_target_rejected(movement_controller)
    await _assert_debug_path_and_marker(movement_controller)
    await _assert_hold_input_stops(movement_controller)
    _assert_camera_inputs(camera)

    await _assert_character_reaches(
        player,
        movement_controller,
        Vector3(0.0, 0.1, 0.0),
        Vector3(0.0, 0.3, -8.0),
        "movement around cube"
    )
    await _assert_new_target_replaces_path(player, movement_controller)

    main.queue_free()
    if _failures == 0:
        print("Navigation smoke tests: PASS")
    else:
        push_error("Navigation smoke tests failed: %d" % _failures)
    quit(_failures)

func _wait_for_navigation_map(navigation_map: RID) -> bool:
    for frame in NAVIGATION_SYNC_FRAMES:
        if NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
            var probe := NavigationServer3D.map_get_closest_point(
                navigation_map,
                Vector3(7.0, 0.3, 0.0)
            )
            if probe.distance_to(Vector3.ZERO) > 1.0:
                return true
        await physics_frame
    return false

func _print_navigation_diagnostics(
    navigation_region: NavigationRegion3D,
    navigation_map: RID
) -> void:
    var navigation_mesh := navigation_region.navigation_mesh
    print("Navigation iteration: %d" % NavigationServer3D.map_get_iteration_id(navigation_map))
    print("Navigation regions: %d" % NavigationServer3D.map_get_regions(navigation_map).size())
    print("Map cell size: %s" % NavigationServer3D.map_get_cell_size(navigation_map))
    print("Map cell height: %s" % NavigationServer3D.map_get_cell_height(navigation_map))
    print("Baked polygons: %d" % navigation_mesh.get_polygon_count())
    print(
        "Closest start: %s"
        % NavigationServer3D.map_get_closest_point(
            navigation_map,
            Vector3(0.0, 0.3, 0.0)
        )
    )

func _assert_path_exists(
    navigation_map: RID,
    start: Vector3,
    destination: Vector3,
    scenario_name: String
) -> void:
    var path := NavigationServer3D.map_get_path(
        navigation_map,
        start,
        destination,
        true
    )
    if path.is_empty():
        _fail("No path for %s." % scenario_name)
        return
    if path[-1].distance_to(destination) > 0.5:
        _fail("Path does not reach destination for %s." % scenario_name)
        return
    print("PASS: %s (%d points)" % [scenario_name, path.size()])

func _assert_cube_detour(navigation_map: RID) -> void:
    var path := NavigationServer3D.map_get_path(
        navigation_map,
        Vector3(0.0, 0.3, 0.0),
        Vector3(0.0, 0.3, -8.0),
        true
    )
    var detours_around_cube := false
    for point in path:
        if absf(point.x) > 1.8:
            detours_around_cube = true
            break
    if path.size() < 3 or not detours_around_cube:
        _fail("Cube path does not contain a safe detour.")
        return
    print("PASS: cube obstacle detour (%d points)" % path.size())

func _assert_column_detour(navigation_map: RID) -> void:
    var path := NavigationServer3D.map_get_path(
        navigation_map,
        Vector3(5.0, 0.3, 0.0),
        Vector3(5.0, 0.3, 8.0),
        true
    )
    var detours_around_column := false
    for point in path:
        if absf(point.x - 5.0) > 1.4:
            detours_around_column = true
            break
    if path.size() < 3 or not detours_around_column:
        _fail("Column path does not contain a safe detour.")
        return
    print("PASS: column obstacle detour (%d points)" % path.size())

func _assert_obstacle_target_rejected(
    movement_controller: MouseMovementController
) -> void:
    if movement_controller.request_move_to_point(Vector3(0.0, 0.3, -4.0)):
        _fail("Target inside cube obstacle was accepted.")
        return
    print("PASS: obstacle target rejected")

func _assert_outside_target_rejected(
    movement_controller: MouseMovementController
) -> void:
    if movement_controller.request_move_to_point(Vector3(30.0, 0.3, 0.0)):
        _fail("Target outside navigation mesh was accepted.")
        return
    print("PASS: outside navigation target rejected")

func _assert_debug_path_and_marker(
    movement_controller: MouseMovementController
) -> void:
    movement_controller.cancel_movement()
    movement_controller.debug_navigation_path = true
    if not movement_controller.request_move_to_point(Vector3(7.0, 0.3, 0.0)):
        _fail("Debug path command was rejected.")
        return
    for frame in 3:
        await physics_frame

    var debug_mesh := movement_controller.navigation_path_debug.mesh as ImmediateMesh
    if not movement_controller.destination_marker.visible:
        _fail("Destination marker was not shown for navigation target.")
    elif not movement_controller.navigation_path_debug.visible:
        _fail("Navigation debug path was not shown.")
    elif debug_mesh.get_surface_count() == 0:
        _fail("Navigation debug path has no geometry.")
    else:
        print("PASS: destination marker and optional path debug")
    movement_controller.debug_navigation_path = false
    movement_controller.cancel_movement()

func _assert_hold_input_stops(
    movement_controller: MouseMovementController
) -> void:
    var press := InputEventAction.new()
    press.action = &"movement_primary"
    press.pressed = true
    Input.parse_input_event(press)
    for frame in 20:
        await physics_frame
    if movement_controller.movement_mode != MouseMovementController.MovementMode.FOLLOW_CURSOR:
        _fail("Hold input did not enter FOLLOW_CURSOR.")

    var release := InputEventAction.new()
    release.action = &"movement_primary"
    release.pressed = false
    Input.parse_input_event(release)
    await physics_frame
    if movement_controller.movement_mode != MouseMovementController.MovementMode.IDLE:
        _fail("Hold release did not stop movement.")
        return
    print("PASS: hold-to-move enters FOLLOW_CURSOR and stops on release")

func _assert_camera_inputs(camera: MmorpgCamera) -> void:
    var initial_yaw := camera.orbit_yaw
    Input.action_press(&"camera_orbit")
    var mouse_motion := InputEventMouseMotion.new()
    mouse_motion.relative = Vector2(20.0, 0.0)
    camera._unhandled_input(mouse_motion)
    Input.action_release(&"camera_orbit")
    if is_equal_approx(camera.orbit_yaw, initial_yaw):
        _fail("RMB orbit action no longer rotates the camera.")
        return

    var zoom_mapping_found := false
    for event in InputMap.action_get_events(&"camera_zoom_in"):
        if (
            event is InputEventMouseButton
            and event.button_index == MOUSE_BUTTON_WHEEL_UP
        ):
            zoom_mapping_found = true
            break
    if not zoom_mapping_found:
        _fail("Mouse wheel zoom Input Map binding is missing.")
        return
    print("PASS: RMB orbit logic and wheel zoom Input Map remain functional")

func _assert_character_reaches(
    player: PlayerController,
    movement_controller: MouseMovementController,
    start: Vector3,
    destination: Vector3,
    scenario_name: String
) -> void:
    _reset_player(player, movement_controller, start)
    await physics_frame
    if not movement_controller.request_move_to_point(destination):
        _fail("Movement command rejected for %s." % scenario_name)
        return

    for frame in MOVEMENT_TIMEOUT_FRAMES:
        await physics_frame
        if frame > 0 and frame % 180 == 0:
            print(
                "Movement diagnostic: position=%s velocity=%s direction=%s path_index=%d"
                % [
                    player.global_position,
                    player.velocity,
                    movement_controller.get_movement_direction(),
                    movement_controller.navigation_agent.get_current_navigation_path_index(),
                ]
            )
            print(
                "Agent diagnostic: mode=%s map_matches=%s target=%s final=%s finished=%s reachable=%s path_size=%d"
                % [
                    movement_controller.movement_mode,
                    movement_controller.navigation_agent.get_navigation_map()
                    == movement_controller.get_node("../NavigationGreybox").get_navigation_map(),
                    movement_controller.navigation_agent.target_position,
                    movement_controller.navigation_agent.get_final_position(),
                    movement_controller.navigation_agent.is_navigation_finished(),
                    movement_controller.navigation_agent.is_target_reachable(),
                    movement_controller.navigation_agent.get_current_navigation_path().size(),
                ]
            )
        if (
            movement_controller.movement_mode
            == MouseMovementController.MovementMode.IDLE
        ):
            var horizontal_offset := destination - player.global_position
            horizontal_offset.y = 0.0
            if horizontal_offset.length() > 0.9:
                _fail("Character stopped too far away for %s." % scenario_name)
                return
            print("PASS: %s" % scenario_name)
            return
    _fail(
        "Movement timed out for %s at %s."
        % [scenario_name, player.global_position]
    )

func _assert_new_target_replaces_path(
    player: PlayerController,
    movement_controller: MouseMovementController
) -> void:
    _reset_player(player, movement_controller, Vector3(0.0, 0.1, 0.0))
    await physics_frame
    if not movement_controller.request_move_to_point(Vector3(-8.0, 0.3, 0.0)):
        _fail("Initial replacement-path command was rejected.")
        return
    for frame in 30:
        await physics_frame
    var replacement := Vector3(8.0, 0.3, 0.0)
    if not movement_controller.request_move_to_point(replacement):
        _fail("Replacement path command was rejected.")
        return

    for frame in MOVEMENT_TIMEOUT_FRAMES:
        await physics_frame
        if (
            movement_controller.movement_mode
            == MouseMovementController.MovementMode.IDLE
        ):
            var horizontal_offset := replacement - player.global_position
            horizontal_offset.y = 0.0
            if horizontal_offset.length() > 0.9:
                _fail("Character did not finish at replacement target.")
                return
            print("PASS: new click replaces active path")
            return
    _fail("Replacement path movement timed out.")

func _reset_player(
    player: PlayerController,
    movement_controller: MouseMovementController,
    position: Vector3
) -> void:
    movement_controller.cancel_movement()
    player.velocity = Vector3.ZERO
    player.global_position = position

func _fail(message: String) -> void:
    _failures += 1
    push_error(message)
