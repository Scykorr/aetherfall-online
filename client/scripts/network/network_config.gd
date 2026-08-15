class_name NetworkConfig
extends Resource

@export var host: String = "127.0.0.1"
@export_range(1, 65535, 1) var port: int = 7777
@export var protocol_version: int = 1
