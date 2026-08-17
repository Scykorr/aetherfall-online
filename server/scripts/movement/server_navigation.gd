class_name ServerNavigation
extends RefCounted

var _map: RID

func _init(navigation_map: RID) -> void:
    _map = navigation_map

func is_ready() -> bool:
    return (
        _map.is_valid()
        and not NavigationServer3D.map_get_regions(_map).is_empty()
        and NavigationServer3D.map_get_iteration_id(_map) > 1
    )

func calculate_path(
    start: Vector3,
    requested_destination: Vector3,
    destination_snap_distance: float
) -> PackedVector3Array:
    if not is_ready():
        return PackedVector3Array()
    var resolved_destination := NavigationServer3D.map_get_closest_point(
        _map,
        requested_destination
    )
    if resolved_destination.distance_to(requested_destination) > destination_snap_distance:
        return PackedVector3Array()
    var resolved_start := NavigationServer3D.map_get_closest_point(_map, start)
    var path := NavigationServer3D.map_get_path(
        _map,
        resolved_start,
        resolved_destination,
        true
    )
    if path.is_empty() or path[-1].distance_to(resolved_destination) > destination_snap_distance:
        return PackedVector3Array()
    return path

func get_map() -> RID:
    return _map

func cleanup() -> void:
    # The World3D owns this map; ServerNavigation only borrows its RID.
    _map = RID()
