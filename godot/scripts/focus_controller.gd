extends RefCounted
class_name FocusController

var _target_order: Array[String] = []
var _target_states_by_id := {}
var _target_views_by_id := {}
var _target_ids_by_view_instance := {}

func clear():
	_target_order.clear()
	_target_states_by_id.clear()
	_target_views_by_id.clear()
	_target_ids_by_view_instance.clear()

func register_target(state: Dictionary, target_view: Node3D):
	var target_id: String = str(state.get("id", ""))
	if target_id.is_empty():
		return

	if not _target_states_by_id.has(target_id):
		_target_order.append(target_id)

	_target_states_by_id[target_id] = state
	_target_views_by_id[target_id] = target_view
	if target_view != null:
		_target_ids_by_view_instance[target_view.get_instance_id()] = target_id

func update_target_state(state: Dictionary):
	var target_id: String = str(state.get("id", ""))
	if target_id.is_empty() or not _target_states_by_id.has(target_id):
		return

	_target_states_by_id[target_id] = state

func get_target_count() -> int:
	return _target_order.size()

func get_target_ids() -> Array[String]:
	return _target_order.duplicate()

func get_target_state(target_id: String) -> Dictionary:
	return _target_states_by_id.get(target_id, {})

func get_target_view(target_id: String):
	return _target_views_by_id.get(target_id)

func get_target_id_for_view(target_view: Node3D) -> String:
	if target_view == null:
		return ""
	return str(_target_ids_by_view_instance.get(target_view.get_instance_id(), ""))

func has_target_type(focus_type: String) -> bool:
	for target_id in _target_order:
		var state: Dictionary = _target_states_by_id[target_id]
		if str(state.get("focus_type", "")) == focus_type:
			return true
	return false
