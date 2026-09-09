extends "res://UI/pinned_resource_manager.gd"


const MAX_PINNED_BUILDINGS := 3
const PANEL_SPACING := 6.0

var _pinned_buildings: Array[Dictionary] = []
var _slot_ui: Array[Dictionary] = []

var _name_label_path: NodePath
var _requirements_grid_path: NodePath
var _go_to_button_path: NodePath
var _close_button_path: NodePath


func _ready() -> void:
	super._ready()
	_setup_extra_panels()


func _setup_extra_panels() -> void:
	_name_label_path = panel.get_path_to(building_name_label)
	_requirements_grid_path = panel.get_path_to(requirements_grid)
	_go_to_button_path = panel.get_path_to(go_to_button)

	var close_button := _find_close_button()

	if close_button == null:
		push_error("TriplePinnedResources: Could not find close button.")
		return

	_close_button_path = panel.get_path_to(close_button)

	# Remove the original signal handlers.
	_disconnect_method(go_to_button, &"_on_go_to_button_pressed")
	_disconnect_method(close_button, &"_on_close_button_pressed")

	# Slot 0 uses the game's original panel.
	_slot_ui.append({
		"panel": panel,
		"name_label": building_name_label,
		"requirements_grid": requirements_grid,
		"go_to_button": go_to_button,
		"close_button": close_button,
	})

	go_to_button.pressed.connect(_on_slot_go_to_pressed.bind(0))
	close_button.pressed.connect(_on_slot_close_pressed.bind(0))

	# Create slots 1 and 2 by duplicating the existing panel.
	for slot in range(1, MAX_PINNED_BUILDINGS):
		var copy := panel.duplicate(0) as Control
		add_child(copy)

		copy.name = "PinnedResourcePanel_%d" % (slot + 1)
		copy.hide()

		var copy_name := copy.get_node(_name_label_path) as Label
		var copy_grid := copy.get_node(_requirements_grid_path) as GridContainer
		var copy_go := copy.get_node(_go_to_button_path) as BaseButton
		var copy_close := copy.get_node(_close_button_path) as BaseButton

		_slot_ui.append({
			"panel": copy,
			"name_label": copy_name,
			"requirements_grid": copy_grid,
			"go_to_button": copy_go,
			"close_button": copy_close,
		})

		copy_go.pressed.connect(_on_slot_go_to_pressed.bind(slot))
		copy_close.pressed.connect(_on_slot_close_pressed.bind(slot))

	call_deferred("_position_panels")


func _position_panels() -> void:
	if _slot_ui.size() < MAX_PINNED_BUILDINGS:
		return

	var step := panel.size.y + PANEL_SPACING
	var direction := 1.0

	# If stacking downward would go off-screen, stack upward instead.
	var viewport_height := get_viewport_rect().size.y
	var required_bottom := panel.global_position.y + panel.size.y + (
		step * (MAX_PINNED_BUILDINGS - 1)
	)

	if required_bottom > viewport_height:
		direction = -1.0

	for slot in range(1, _slot_ui.size()):
		var slot_panel: Control = _slot_ui[slot]["panel"]

		slot_panel.position = panel.position + Vector2(
			0,
			step * slot * direction
		)


func pin_building(
	building_upgrade: Node,
	location: String
) -> void:
	if location == "" or building_upgrade == null:
		return

	# Remove an existing copy of this building.
	for i in range(
		_pinned_buildings.size() - 1,
		-1,
		-1
	):
		var entry: Dictionary = _pinned_buildings[i]

		if (
			entry.get("kind", "building") == "building"
			and entry.get("location", "") == location
		):
			_pinned_buildings.remove_at(i)

	# Fourth pin removes the oldest pin,
	# regardless of whether it is research or a building.
	if _pinned_buildings.size() >= MAX_PINNED_BUILDINGS:
		_pinned_buildings.pop_front()

	_pinned_buildings.append({
		"kind": "building",
		"upgrade_node": building_upgrade,
		"location": location,
		"pinned_level": globals.get(
			location + "_level"
		),
	})

	_refresh_panels()

	show()
	set_process(true)


func pin_research(
	research_book: Node,
	upgrade_key: String,
	category: String
) -> void:
	if research_book == null:
		return

	if upgrade_key == "":
		return

	if not globals.upgrades.has(upgrade_key):
		return

	var upgrade = globals.upgrades[upgrade_key]

	if upgrade.get("purchased", 0) == 1:
		return

	# Re-pinning the same research moves it to
	# the newest position in the FIFO queue.
	for i in range(
		_pinned_buildings.size() - 1,
		-1,
		-1
	):
		var entry: Dictionary = _pinned_buildings[i]

		if (
			entry.get("kind", "") == "research"
			and entry.get("upgrade_key", "") == upgrade_key
		):
			_pinned_buildings.remove_at(i)

	if _pinned_buildings.size() >= MAX_PINNED_BUILDINGS:
		_pinned_buildings.pop_front()

	_pinned_buildings.append({
		"kind": "research",
		"research_book": research_book,
		"upgrade_key": upgrade_key,
		"category": category,
	})

	_refresh_panels()

	show()
	set_process(true)


func _process(_delta: float) -> void:
	if _pinned_buildings.is_empty():
		return

	var changed := false

	for i in range(
		_pinned_buildings.size() - 1,
		-1,
		-1
	):
		var entry: Dictionary = _pinned_buildings[i]
		var kind: String = entry.get(
			"kind",
			"building"
		)

		match kind:
			"building":
				var node: Node = entry.get(
					"upgrade_node"
				)

				var location: String = entry.get(
					"location",
					""
				)

				var original_level: int = entry.get(
					"pinned_level",
					-1
				)

				if not is_instance_valid(node):
					_pinned_buildings.remove_at(i)
					changed = true
					continue

				var current_level: int = globals.get(
					location + "_level"
				)

				if current_level > original_level:
					_pinned_buildings.remove_at(i)
					changed = true


			"research":
				var upgrade_key: String = entry.get(
					"upgrade_key",
					""
				)

				if not globals.upgrades.has(
					upgrade_key
				):
					_pinned_buildings.remove_at(i)
					changed = true
					continue

				var upgrade = globals.upgrades[
					upgrade_key
				]

				# Purchasing the research removes its pin.
				if upgrade.get(
					"purchased",
					0
				) == 1:
					_pinned_buildings.remove_at(i)
					changed = true

	if changed:
		_refresh_panels()
	else:
		for i in range(
			_pinned_buildings.size()
		):
			_update_slot(i)


func _refresh_panels() -> void:
	for slot in range(_slot_ui.size()):
		var slot_panel: Control = _slot_ui[slot]["panel"]
		var grid: GridContainer = _slot_ui[slot]["requirements_grid"]

		if slot < _pinned_buildings.size():
			slot_panel.show()
			_update_slot(slot)
		else:
			_clear_grid(grid)
			slot_panel.hide()

	if _pinned_buildings.is_empty():
		hide()
		set_process(false)
	else:
		show()
		set_process(true)
		
	call_deferred("_position_panels")


func _update_slot(slot: int) -> void:
	if (
		slot < 0
		or slot >= _pinned_buildings.size()
	):
		return

	var entry: Dictionary = _pinned_buildings[slot]

	match entry.get("kind", "building"):
		"research":
			_update_research_slot(slot, entry)

		_:
			_update_building_slot(slot, entry)


func _update_building_slot(
	slot: int,
	entry: Dictionary
) -> void:
	var upgrade: Node = entry["upgrade_node"]
	var location: String = entry["location"]

	if not is_instance_valid(upgrade):
		return

	var name_label: Label = _slot_ui[slot][
		"name_label"
	]

	var grid: GridContainer = _slot_ui[slot][
		"requirements_grid"
	]

	var level: int = globals.get(
		location + "_level"
	)

	var level_key := (
		location
		+ "_level_"
		+ str(level)
	)

	var data = upgrade.get(level_key)

	if data == null:
		name_label.text = "Fully Upgraded"
		_clear_grid(grid)
		return

	name_label.text = data["name"]

	_update_slot_requirements(
		grid,
		upgrade,
		level_key,
		data
	)


func _update_research_slot(
	slot: int,
	entry: Dictionary
) -> void:
	var research_book: Node = entry.get(
		"research_book"
	)

	var upgrade_key: String = entry.get(
		"upgrade_key",
		""
	)

	if not is_instance_valid(research_book):
		return

	if not globals.upgrades.has(upgrade_key):
		return

	var upgrade = globals.upgrades[upgrade_key]

	var name_label: Label = _slot_ui[slot][
		"name_label"
	]

	var grid: GridContainer = _slot_ui[slot][
		"requirements_grid"
	]

	name_label.text = upgrade.get(
		"name",
		"Research"
	)

	_clear_grid(grid)

	var requirements: Array[Dictionary] = []

	for resource in [
		"food",
		"wood",
		"stone",
		"iron",
		"gold",
		"magic",
	]:
		var cost: int = research_book.get_upgrade_cost(
			upgrade_key,
			resource
		)

		if cost > 0:
			requirements.append({
				"icon": globals.get(
					resource + "_icon"
				),
				"amount": cost,
				"current": globals.get(
					resource
				),
			})

	var blueprint_types: Array[String] = [
	"advanced",
	"expert",
	"master",
	"legendary",
]

	for blueprint: String in blueprint_types:
		var cost_key: String = (
			"cost_blueprints_"
			+ blueprint
		)

		var amount: int = upgrade.get(
			cost_key,
			0
		)

		if amount > 0:
			requirements.append({
				"icon": globals.get(
					"blueprint_"
					+ blueprint
					+ "_icon"
				),
				"amount": amount,
				"current": globals.get(
					"blueprints_"
					+ blueprint
				),
			})

	if requirements.size() <= 1:
		grid.columns = 1
	else:
		grid.columns = 3

	for requirement in requirements:
		var label := RichTextLabel.new()

		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = (
			TextServer.AUTOWRAP_OFF
		)

		label.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		label.size_flags_vertical = (
			Control.SIZE_SHRINK_CENTER
		)

		label.custom_minimum_size = Vector2(
			90,
			28
		)

		if (
			requirement["current"]
			>= requirement["amount"]
		):
			label.text = (
				"[img]%s[/img] "
				+ "[color=green]%s[/color]"
			) % [
				requirement["icon"],
				requirement["amount"],
			]
		else:
			label.text = (
				"[img]%s[/img] %s"
			) % [
				requirement["icon"],
				requirement["amount"],
			]

		grid.add_child(label)


func _update_slot_requirements(
	grid: GridContainer,
	upgrade: Node,
	level_key: String,
	data: Dictionary
) -> void:
	_clear_grid(grid)

	if upgrade.is_quest_locked(level_key):
		grid.columns = 1

		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = tr("ADVANCE_QUESTS_TO_UNLOCK")

		grid.add_child(label)
		return

	var reqs: Array[Dictionary] = []

	for res in [
		"food",
		"wood",
		"stone",
		"iron",
		"gold",
		"magic",
	]:
		var cost: int = upgrade.get_cost(level_key, res)

		if cost > 0:
			reqs.append({
				"icon": globals.get(res + "_icon"),
				"amount": cost,
				"current": globals.get(res),
			})

	var bp_map = [
		[
			"cost_blueprints_advanced",
			"blueprint_advanced_icon",
			"blueprints_advanced"
		],
		[
			"cost_blueprints_expert",
			"blueprint_expert_icon",
			"blueprints_expert"
		],
		[
			"cost_blueprints_master",
			"blueprint_master_icon",
			"blueprints_master"
		],
		[
			"cost_blueprints_legendary",
			"blueprint_legendary_icon",
			"blueprints_legendary"
		],
	]

	for bp in bp_map:
		var amount: int = data.get(bp[0], 0)

		if amount > 0:
			reqs.append({
				"icon": globals.get(bp[1]),
				"amount": amount,
				"current": globals.get(bp[2]),
			})

	if reqs.size() <= 1:
		grid.columns = 1
	else:
		grid.columns = 3

	for requirement in reqs:
		var label := RichTextLabel.new()

		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.custom_minimum_size = Vector2(90, 28)

		if requirement["current"] >= requirement["amount"]:
			label.text = (
				"[img]%s[/img] [color=green]%s[/color]"
				% [
					requirement["icon"],
					requirement["amount"],
				]
			)
		else:
			label.text = (
				"[img]%s[/img] %s"
				% [
					requirement["icon"],
					requirement["amount"],
				]
			)

		grid.add_child(label)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


func _on_slot_go_to_pressed(slot: int) -> void:
	if (
		slot < 0
		or slot >= _pinned_buildings.size()
	):
		return

	var entry: Dictionary = _pinned_buildings[slot]

	match entry.get("kind", "building"):
		"research":
			var research_book: Node = entry.get(
				"research_book"
			)

			if not is_instance_valid(
				research_book
			):
				return

			var category: String = entry.get(
				"category",
				""
			)

			var upgrade_key: String = entry.get(
				"upgrade_key",
				""
			)

			research_book.open_book(
				category,
				upgrade_key
			)

		_:
			var location: String = entry.get(
				"location",
				""
			)

			if location != "":
				signal_manager.camera_to_building.emit(
					location
				)


func _on_slot_close_pressed(slot: int) -> void:
	if slot < 0 or slot >= _pinned_buildings.size():
		return

	_pinned_buildings.remove_at(slot)
	_refresh_panels()


# Fallbacks for the game's original signal connections.
func _on_go_to_button_pressed() -> void:
	_on_slot_go_to_pressed(0)


func _on_close_button_pressed() -> void:
	_on_slot_close_pressed(0)


# Preserve the original public close() behavior:
# calling manager.close() closes every pinned building.
func close() -> void:
	_pinned_buildings.clear()

	for ui in _slot_ui:
		var slot_panel: Control = ui["panel"]
		var grid: GridContainer = ui["requirements_grid"]

		_clear_grid(grid)
		slot_panel.hide()

	current_location = ""
	upgrade_node = null
	pinned_level = -1

	hide()
	set_process(false)


func _find_close_button() -> BaseButton:
	for candidate in panel.find_children("*", "BaseButton", true, false):
		var button := candidate as BaseButton

		for connection in button.pressed.get_connections():
			var callable: Callable = connection["callable"]

			if (
				callable.get_object() == self
				and callable.get_method() == &"_on_close_button_pressed"
			):
				return button

	# Fallback if signal information isn't preserved.
	for candidate in panel.find_children("*", "BaseButton", true, false):
		var button := candidate as BaseButton

		if "close" in button.name.to_lower():
			return button

	return null


func _disconnect_method(
	button: BaseButton,
	method: StringName
) -> void:
	for connection in button.pressed.get_connections():
		var callable: Callable = connection["callable"]

		if (
			callable.get_object() == self
			and callable.get_method() == method
		):
			button.pressed.disconnect(callable)
