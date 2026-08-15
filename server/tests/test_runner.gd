extends SceneTree

const TEST_SUITE_SCRIPT: Script = preload("res://tests/test_suite.gd")
const TEST_MODULES: Array[Script] = [
    preload("res://tests/test_entity_registry.gd"),
    preload("res://tests/test_session_registry.gd"),
    preload("res://tests/test_protocol.gd"),
    preload("res://tests/test_movement.gd"),
    preload("res://tests/test_monsters.gd"),
]

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var suite = TEST_SUITE_SCRIPT.new()
    for test_module_script in TEST_MODULES:
        var test_module: RefCounted = test_module_script.new()
        test_module.run(suite)
        test_module = null
    suite.print_summary()
    var exit_code: int = 0 if suite.failed == 0 else 1
    suite = null
    call_deferred("_finish", exit_code)

func _finish(exit_code: int) -> void:
    quit(exit_code)
