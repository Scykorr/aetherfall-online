class_name MovementCollisionMap
extends RefCounted

var _blockers: Array[Dictionary] = []
var _world_half_extent: float = 0.0

func _init(blockers: Array[Dictionary] = [], world_half_extent: float = 0.0) -> void:
    _blockers = blockers.duplicate(true)
    _world_half_extent = maxf(0.0, world_half_extent)

func resolve_motion(from: Vector3, desired: Vector3, radius: float) -> Vector3:
    var resolved := from
    var x_candidate := Vector3(desired.x, from.y, from.z)
    if not _is_blocked(x_candidate, radius):
        resolved.x = desired.x
    var z_candidate := Vector3(resolved.x, from.y, desired.z)
    if not _is_blocked(z_candidate, radius):
        resolved.z = desired.z
    return resolved

func _is_blocked(position: Vector3, radius: float) -> bool:
    if _world_half_extent > 0.0:
        var allowed_extent := maxf(0.0, _world_half_extent - radius)
        if absf(position.x) > allowed_extent or absf(position.z) > allowed_extent:
            return true
    for blocker: Dictionary in _blockers:
        var center: Vector2 = blocker["center"]
        var offset := Vector2(position.x, position.z) - center
        if blocker["shape"] == "box":
            var half_extents: Vector2 = blocker["half_extents"]
            if (
                absf(offset.x) < half_extents.x + radius
                and absf(offset.y) < half_extents.y + radius
            ):
                return true
        elif blocker["shape"] == "circle":
            var combined_radius: float = float(blocker["radius"]) + radius
            if offset.length_squared() < combined_radius * combined_radius:
                return true
    return false
