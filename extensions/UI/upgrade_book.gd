extends "res://UI/upgrade_book.gd"

const BUILDING_PIN_PATH := NodePath(
	"ScaledUI/Building Upgrade/VBoxContainer/HBoxContainer2/PinButton"
)

var _pin_button_template: TextureButton

func _ready() -> void:
	super._ready()

	call_deferred("_setup_research_pin_buttons")


func _setup_research_pin_buttons() -> void:
	_find_pin_button_template()

	if _pin_button_template == null:
		push_error(
			"Research Pin: Could not find Building Upgrade PinButton."
		)
		return

	_create_research_pin_buttons()

	if (
		affordability_timer != null
		and not affordability_timer.timeout.is_connected(
			_update_research_pin_buttons
		)
	):
		affordability_timer.timeout.connect(
			_update_research_pin_buttons
		)


func _find_pin_button_template() -> void:
	var source: TextureButton = null

	var current_scene := get_tree().current_scene

	if current_scene != null:
		source = current_scene.get_node_or_null(
			"ScaledUI/Building Upgrade/VBoxContainer/HBoxContainer2/PinButton"
		) as TextureButton

	if source == null:
		for child in get_tree().root.get_children():
			var candidate := child.get_node_or_null(
				"ScaledUI/Building Upgrade/VBoxContainer/HBoxContainer2/PinButton"
			)

			if candidate is TextureButton:
				source = candidate
				break

	if source == null:
		return

	_pin_button_template = source


func _create_research_pin_buttons() -> void:
	if _pin_button_template == null:
		return

	for slot_index in range(1, 7):
		var is_right_page := slot_index > 3

		var container = (
			$HBoxCon / VBoxCon2
			if is_right_page
			else $HBoxCon / VBoxCon
		)

		var slot = container.get_node(
			"P" + str(slot_index)
		)

		var button_container = slot.get_node(
			"HBoxCon/VBoxContainer"
		)

		var button_name := (
			"ResearchPin_" + str(slot_index)
		)

		if button_container.has_node(button_name):
			continue

		var pin_button := (
			_pin_button_template.duplicate(
				Node.DUPLICATE_GROUPS
			) as TextureButton
		)

		if pin_button == null:
			continue

		pin_button.name = button_name

		# Important:
		# don't duplicate the original building button's
		# signal connection.
		button_container.add_child(pin_button)

		pin_button.pressed.connect(
			_on_research_pin_pressed.bind(
				slot_index - 1
			)
		)

	_update_research_pin_buttons()


func _update_research_pin_buttons() -> void:
	for offset in range(6):
		var slot_index := offset + 1
		var is_right_page := slot_index > 3

		var container = (
			$HBoxCon / VBoxCon2
			if is_right_page
			else $HBoxCon / VBoxCon
		)

		var slot = container.get_node(
			"P" + str(slot_index)
		)

		var pin_button := slot.get_node_or_null(
			"HBoxCon/VBoxContainer/ResearchPin_"
			+ str(slot_index)
		) as TextureButton

		if pin_button == null:
			continue

		var should_be_visible := false

		if (
			current_page != ""
			and globals.category_upgrade_order.has(current_page)
		):
			var ordered := get_ordered_upgrade_keys(
				current_page
			)

			var index := (
				current_page_index
				* slots_per_page
				+ offset
			)

			if index < ordered.size():
				var upgrade_key: String = ordered[index]
				var upgrade = globals.upgrades.get(
					upgrade_key
				)

				if upgrade != null:
					should_be_visible = (
						upgrade.get("unlocked", 0) == 1
						and upgrade.get("purchased", 0) == 0
					)

		# Don't hide/show it every timer tick.
		# Only change visibility if it actually changed.
		if pin_button.visible != should_be_visible:
			pin_button.visible = should_be_visible


func _on_research_pin_pressed(offset: int) -> void:
	if current_page == "":
		return

	var ordered := get_ordered_upgrade_keys(current_page)
	var index := current_page_index * slots_per_page + offset

	if index >= ordered.size():
		return

	var upgrade_key: String = ordered[index]
	var upgrade = globals.upgrades.get(upgrade_key)

	if upgrade == null:
		return

	if upgrade.get("unlocked", 0) != 1:
		return

	if upgrade.get("purchased", 0) == 1:
		return

	var pinned = get_tree().get_first_node_in_group(
		"pinned_resource_manager"
	)

	if pinned and pinned.has_method("pin_research"):
		pinned.pin_research(
			self,
			upgrade_key,
			current_page
		)
	else:
		push_warning(
			"PinnedResourceManager does not support research pins."
		)
