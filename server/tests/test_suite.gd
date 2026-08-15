class_name ServerTestSuite
extends RefCounted

var passed: int = 0
var failed: int = 0
var skipped: int = 0

func check(test_id: String, condition: bool, detail: String = "") -> void:
    if condition:
        passed += 1
        print("[PASS] %s" % test_id)
        return
    failed += 1
    var suffix := "" if detail.is_empty() else ": %s" % detail
    print("[FAIL] %s%s" % [test_id, suffix])

func print_summary() -> void:
    print(
        "[TEST SUMMARY] passed=%d failed=%d skipped=%d total=%d" % [
            passed,
            failed,
            skipped,
            passed + failed + skipped,
        ]
    )
