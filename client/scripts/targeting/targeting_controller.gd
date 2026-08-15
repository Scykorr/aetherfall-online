class_name TargetingController
extends Node

@export var camera: Camera3D
@export_flags_3d_physics var targetable_collision_mask: int = 4
@export var ray_length: float = 1000.0

func try_request_target(screen_position: Vector2) -> bool:
    if camera == null or not camera.is_inside_tree():
        return false
    var origin := camera.project_ray_origin(screen_position)
    var query := PhysicsRayQueryParameters3D.create(
        origin,
        origin + camera.project_ray_normal(screen_position) * ray_length,
        targetable_collision_mask
    )
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
    var collider := hit.get("collider") as Node
    if collider == null or not collider.has_method("get_target_entity_id"):
        return false
    var entity_id: int = collider.call("get_target_entity_id")
    if entity_id <= 0:
        return false
    Network.request_target(entity_id)
    return true

func clear_target() -> bool:
    if Network.confirmed_target_entity_id <= 0:
        return false
    Network.request_target(0)
    return true
