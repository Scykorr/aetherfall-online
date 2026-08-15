class_name MouseMovementController
extends Node

enum MovementMode {
    IDLE,
    MOVE_TO_POINT,
    FOLLOW_CURSOR,
}

@export var player: CharacterBody3D
@export var camera: Camera3D
@export var destination_marker: Node3D
@export_flags_3d_physics var walkable_collision_mask: int = 2
@export_flags_3d_physics var pointer_collision_mask: int = 0xFFFFFFFF
@export var arrival_distance: float = 0.25
@export var hold_threshold: float = 0.2
@export var ray_length: float = 1000.0

var movement_mode: MovementMode = MovementMode.IDLE

var _movement_target: Vector3 = Vector3.ZERO
var _movement_direction: Vector3 = Vector3.ZERO
var _cursor_position: Vector2 = Vector2.ZERO
var _primary_held: bool = false
var _hold_elapsed: float = 0.0

func _ready() -> void:
    _cursor_position = get_viewport().get_mouse_position()
    _hide_destination_marker()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _primary_held = false
        cancel_movement()
        return

    if event is InputEventMouseMotion:
        _cursor_position = event.position

    if event.is_action_pressed("movement_primary"):
        if _is_pointer_over_ui():
            return
        _primary_held = true
        _hold_elapsed = 0.0
        _cursor_position = get_viewport().get_mouse_position()
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
        if _hold_elapsed >= hold_threshold:
            movement_mode = MovementMode.FOLLOW_CURSOR
            _hide_destination_marker()

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
    movement_mode = MovementMode.IDLE
    _movement_direction = Vector3.ZERO
    _hide_destination_marker()

func _try_set_movement_target(screen_position: Vector2) -> void:
    var ground_hit := _get_ground_hit(screen_position)
    if ground_hit.is_empty():
        return

    var target: Vector3 = ground_hit["position"]
    var offset := target - player.global_position
    offset.y = 0.0
    if offset.length() <= arrival_distance:
        cancel_movement()
        return

    _movement_target = target
    movement_mode = MovementMode.MOVE_TO_POINT
    _show_destination_marker(target)

func _update_move_to_point_intent() -> void:
    var offset := _movement_target - player.global_position
    offset.y = 0.0
    if offset.length() <= arrival_distance:
        cancel_movement()
        return
    _movement_direction = offset.normalized()

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
