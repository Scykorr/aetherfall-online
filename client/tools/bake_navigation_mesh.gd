extends SceneTree

const GREYBOX_SCENE_PATH := "res://scenes/world/navigation_greybox.tscn"
const NAVIGATION_MESH_PATH := "res://navigation/greybox_navigation_mesh.tres"

func _init() -> void:
    call_deferred("_bake_navigation_mesh")

func _bake_navigation_mesh() -> void:
    var packed_scene := load(GREYBOX_SCENE_PATH) as PackedScene
    if packed_scene == null:
        push_error("Could not load navigation greybox scene.")
        quit(1)
        return

    var navigation_region := packed_scene.instantiate() as NavigationRegion3D
    if navigation_region == null:
        push_error("Navigation greybox root must be NavigationRegion3D.")
        quit(1)
        return

    root.add_child(navigation_region)
    var navigation_mesh := navigation_region.navigation_mesh
    navigation_mesh.agent_height = 2.0
    navigation_mesh.agent_radius = 0.5
    navigation_mesh.agent_max_climb = 0.0
    navigation_mesh.cell_size = 0.25
    navigation_mesh.cell_height = 0.25
    navigation_mesh.region_min_size = 1.0
    navigation_mesh.geometry_parsed_geometry_type = (
        NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    )
    navigation_mesh.geometry_collision_mask = 3
    navigation_mesh.geometry_source_geometry_mode = (
        NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
    )
    navigation_mesh.filter_baking_aabb = AABB(
        Vector3(-15.0, -0.5, -15.0),
        Vector3(30.0, 1.0, 30.0)
    )

    navigation_region.bake_navigation_mesh(false)
    var save_error := ResourceSaver.save(
        navigation_mesh,
        NAVIGATION_MESH_PATH
    )
    navigation_region.queue_free()
    if save_error != OK:
        push_error("Could not save baked navigation mesh: %s" % save_error)
        quit(1)
        return

    print("Baked navigation mesh: %s" % NAVIGATION_MESH_PATH)
    quit()
