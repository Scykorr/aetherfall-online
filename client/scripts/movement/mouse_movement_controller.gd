class_name MouseMovementController
extends Node

enum MovementMode {
    IDLE,
    MOVE_TO_POINT,
    FOLLOW_CURSOR,
}

@export var player: CharacterBody3D
@export var camera: Camera3D
@export var navigation_agent: NavigationAgent3D
@export var destination_marker: Node3D
@export var navigation_path_debug: MeshInstance3D
@export var targeting_controller: Node
@export_flags_3d_physics var walkable_collision_mask: int = 2
@export_flags_3d_physics var pointer_collision_mask: int = 0xFFFFFFFF
@export var arrival_distance: float = 0.25
@export var hold_threshold: float = 0.2
@export var ray_length: float = 1000.0
@export var navigation_snap_distance: float = 0.75
@export var debug_navigation_path: bool = false

var movement_mode: MovementMode = MovementMode.IDLE

var _movement_direction: Vector3 = Vector3.ZERO
var _cursor_position: Vector2 = Vector2.ZERO
var _primary_held: bool = false
var _hold_elapsed: float = 0.0
var _debug_path_dirty: bool = false

func _ready() -> void:
    _cursor_position = get_viewport().get_mouse_position()
    _hide_destination_marker()
    _clear_navigation_debug()
    if navigation_agent != null:
        navigation_agent.path_changed.connect(_on_navigation_path_changed)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _primary_held = false
        if targeting_controller != null and targeting_controller.clear_target():
            return
        cancel_movement()
        return

    if event is InputEventMouseMotion:
        _cursor_position = event.position

    if event.is_action_pressed("movement_primary"):
        if _is_pointer_over_ui():
            return
        _cursor_position = get_viewport().get_mouse_position()
        if (
            targeting_controller != null
            and targeting_controller.try_request_target(_cursor_position)
        ):
            _primary_held = false
            return
        _primary_held = true
        _hold_elapsed = 0.0
    elif event.is_action_released("movement_primary") and _primary_held:
        _primary_held = false
        _cursor_position = get_viewport().get_mouse_position()
        if movement_mode == MovementMode.FOLLOW_CURSOR:
            cancel_movement()
        elif not _is_pointer_over_ui():
            _try_set_movement_target(_cursor_position)

func _physics_process(delta: float) -> void:
    if _primary_held:
        _hold_elapsed += delta
        if (
            _hold_elapsed >= hold_threshold
            and movement_mode != MovementMode.FOLLOW_CURSOR
        ):
            movement_mode = MovementMode.FOLLOW_CURSOR
            _hide_destination_marker()
            _clear_navigation_debug()

    match movement_mode:
        MovementMode.IDLE:
            _movement_direction = Vector3.ZERO
        MovementMode.MOVE_TO_POINT:
            _update_move_to_point_intent()
        MovementMode.FOLLOW_CURSOR:
            _update_follow_cursor_intent()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _primary_held = false
        cancel_movement()

func get_movement_direction() -> Vector3:
    return _movement_direction

func cancel_movement() -> void:
    var was_moving := movement_mode != MovementMode.IDLE
    movement_mode = MovementMode.IDLE
    _movement_direction = Vector3.ZERO
    _hide_destination_marker()
    _clear_navigation_debug()
    if was_moving:
        var network := get_node_or_null("/root/Network")
        if network != null:
            network.send_stop()

func request_move_to_point(requested_target: Vector3) -> bool:
    if player == null or navigation_agent == null:
        return false

    var navigation_map := navigation_agent.get_navigation_map()
    if not navigation_map.is_valid():
        return false
    if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
        return false

    var resolved_target := NavigationServer3D.map_get_closest_point(
        navigation_map,
        requested_target
    )
    if resolved_target.distance_to(requested_target) > navigation_snap_distance:
        return false

    var navigation_path := NavigationServer3D.map_get_path(
        navigation_map,
        player.global_position,
        resolved_target,
        true
    )
    if navigation_path.is_empty():
        return false
    if navigation_path[-1].distance_to(resolved_target) > arrival_distance:
        return false

    var offset := resolved_target - player.global_position
    offset.y = 0.0
    if offset.length() <= arrival_distance:
        cancel_movement()
        return false

    navigation_agent.target_position = resolved_target
    movement_mode = MovementMode.MOVE_TO_POINT
    _movement_direction = Vector3.ZERO
    _debug_path_dirty = true
    _show_destination_marker(resolved_target)
    var network := get_node_or_null("/root/Network")
    if network != null:
        network.send_move_to_point(resolved_target)
    return true

func _try_set_movement_target(screen_position: Vector2) -> void:
    var ground_hit := _get_ground_hit(screen_position)
    if ground_hit.is_empty():
        return

    var target: Vector3 = ground_hit["position"]
    request_move_to_point(target)

func _update_move_to_point_intent() -> void:
    if navigation_agent == null or navigation_agent.is_navigation_finished():
        cancel_movement()
        return

    var next_path_position := navigation_agent.get_next_path_position()
    var offset := next_path_position - player.global_position
    offset.y = 0.0
    _movement_direction = Vector3.ZERO if offset.is_zero_approx() else offset.normalized()
    _update_navigation_debug()

func _update_follow_cursor_intent() -> void:
    var ground_hit := _get_ground_hit(_cursor_position)
    if ground_hit.is_empty():
        _movement_direction = Vector3.ZERO
        return

    var target: Vector3 = ground_hit["position"]
    var offset := target - player.global_position
    offset.y = 0.0
    _movement_direction = (
        Vector3.ZERO
        if offset.length() <= arrival_distance
        else offset.normalized()
    )
    if not _movement_direction.is_zero_approx():
        var network := get_node_or_null("/root/Network")
        if network != null:
            network.send_follow_direction(_movement_direction)

func _get_ground_hit(screen_position: Vector2) -> Dictionary:
    if player == null or camera == null or not camera.is_inside_tree():
        return {}

    var ray_origin := camera.project_ray_origin(screen_position)
    var ray_end := ray_origin + camera.project_ray_normal(screen_position) * ray_length
    var query := PhysicsRayQueryParameters3D.create(
        ray_origin,
        ray_end,
        pointer_collision_mask
    )
    query.exclude = [player.get_rid()]
    query.collide_with_areas = false
    query.collide_with_bodies = true

    var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
    if result.is_empty():
        return {}

    var collider := result.get("collider") as CollisionObject3D
    if collider == null:
        return {}
    if (collider.get_collision_layer() & walkable_collision_mask) == 0:
        return {}
    return result

func _is_pointer_over_ui() -> bool:
    return get_viewport().gui_get_hovered_control() != null

func _show_destination_marker(target: Vector3) -> void:
    if destination_marker == null:
        return
    destination_marker.global_position = target + Vector3.UP * 0.03
    destination_marker.visible = true

func _hide_destination_marker() -> void:
    if destination_marker != null:
        destination_marker.visible = false

func _on_navigation_path_changed() -> void:
    _debug_path_dirty = true

func _update_navigation_debug() -> void:
    if not _debug_path_dirty:
        return
    _debug_path_dirty = false
    if not debug_navigation_path or navigation_path_debug == null:
        _clear_navigation_debug()
        return

    var immediate_mesh := navigation_path_debug.mesh as ImmediateMesh
    if immediate_mesh == null:
        return

    var navigation_path := navigation_agent.get_current_navigation_path()
    immediate_mesh.clear_surfaces()
    if navigation_path.is_empty():
        navigation_path_debug.visible = false
        return

    immediate_mesh.surface_begin(
        Mesh.PRIMITIVE_LINE_STRIP,
        navigation_path_debug.material_override
    )
    for path_position in navigation_path:
        immediate_mesh.surface_add_vertex(path_position + Vector3.UP * 0.08)
    immediate_mesh.surface_end()
    navigation_path_debug.visible = true

func _clear_navigation_debug() -> void:
    if navigation_path_debug == null:
        return
    var immediate_mesh := navigation_path_debug.mesh as ImmediateMesh
    if immediate_mesh != null:
        immediate_mesh.clear_surfaces()
    navigation_path_debug.visible = false
