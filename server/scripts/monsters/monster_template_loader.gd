class_name MonsterTemplateLoader
extends RefCounted

static func load_template(repository_relative_path: String) -> Dictionary:
    var absolute_path := ProjectSettings.globalize_path("res://../%s" % repository_relative_path)
    var file := FileAccess.open(absolute_path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {}
    var stats: Variant = parsed.get("stats")
    var wander: Variant = parsed.get("wander")
    if (
        not parsed.get("id") is String
        or not stats is Dictionary
        or not _is_number(stats.get("max_hp"))
        or not _is_number(stats.get("move_speed"))
        or not wander is Dictionary
        or not _is_number(parsed.get("respawn_seconds"))
    ):
        return {}
    return parsed

static func _is_number(value: Variant) -> bool:
    return value is int or value is float
