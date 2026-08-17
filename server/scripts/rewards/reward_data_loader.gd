class_name RewardDataLoader
extends RefCounted

static func load_json(repository_relative_path: String) -> Variant:
    var path := ProjectSettings.globalize_path("res://../%s" % repository_relative_path)
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return null
    return JSON.parse_string(file.get_as_text())
