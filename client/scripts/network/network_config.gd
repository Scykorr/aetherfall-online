class_name NetworkConfig
extends Resource

const PROTOCOL_VERSION: int = 1

@export var host: String = "127.0.0.1"
@export_range(1, 65535, 1) var port: int = 7777
var protocol_version: int = PROTOCOL_VERSION
