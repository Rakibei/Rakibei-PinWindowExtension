extends Node


const RAKIBEI_PINWINDOWEXTENSION_DIR := "Rakibei-PinWindowExtension"
const RAKIBEI_PINWINDOWEXTENSION_LOG_NAME := "Rakibei-PinWindowExtension:Main"

var mod_dir_path := ""
var extensions_dir_path := ""
var config

func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(RAKIBEI_PINWINDOWEXTENSION_DIR)
	# Add extensions
	install_script_extensions()


func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.path_join("extensions")
	ModLoaderMod.install_script_extension(extensions_dir_path.path_join("UI/pinned_resource_manager.gd"))
	ModLoaderMod.install_script_extension(extensions_dir_path.path_join("UI/upgrade_book.gd"))


func _ready() -> void:
	ModLoaderLog.info("Ready!", RAKIBEI_PINWINDOWEXTENSION_LOG_NAME)
