class_name Camera3DTexelSnapper
extends Node

# NOTE(david): this script should be inside Camera3D under PhantomCameraHost, so
# that Phantom Camera updates first, then texel snapping is applied.
# It's the same as Camera3DTexelSnapped but as a child node.
# It doesn't rely on PhantomCamera, so can just be used as a composed alternative.

@export var snap := true
@export var snap_objects := true

var texel_error := Vector2.ZERO

@onready var _cam := get_parent() as Camera3D
@onready var _prev_rotation := _cam.global_rotation
@onready var _snap_space := _cam.global_transform
var _texel_size: float = 0.0

var _snap_nodes: Array[Node]
var _pre_snapped_positions: Array[Vector3]


func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_snap_objects_revert)


func _process(_delta: float) -> void:
	# rotation changes the snap space
	if _cam.global_rotation != _prev_rotation:
		_prev_rotation = _cam.global_rotation
		_snap_space = _cam.global_transform
	_texel_size = _cam.size / float((get_viewport() as SubViewport).size.y)
	# camera position in snap space
	var snap_space_position := _cam.global_position * _snap_space
	# snap!
	var snapped_snap_space_position := snap_space_position.snapped(Vector3.ONE * _texel_size)
	# how much we snapped (in snap space)
	var snap_error := snapped_snap_space_position - snap_space_position
	if snap:
		# apply camera offset as to not affect the actual transform
		_cam.h_offset = snap_error.x
		_cam.v_offset = snap_error.y
		# error in screen texels (will be used later)
		texel_error = Vector2(snap_error.x, -snap_error.y) / _texel_size
		if snap_objects:
			_snap_objects.call_deferred()
	else:
		texel_error = Vector2.ZERO
	_cam.set_meta("texel_error", texel_error)


func _snap_objects() -> void:
	_snap_nodes = get_tree().get_nodes_in_group("snap")
	_pre_snapped_positions.resize(_snap_nodes.size())
	for i in _snap_nodes.size():
		var node := _snap_nodes[i] as Node3D
		var pos := node.global_position
		_pre_snapped_positions[i] = pos
		var snap_space_pos := pos * _snap_space
		var snapped_snap_space_pos := snap_space_pos.snapped(Vector3(_texel_size, _texel_size, 0.0))
		node.global_position = _snap_space * snapped_snap_space_pos


func _snap_objects_revert() -> void:
	for i in _snap_nodes.size():
		(_snap_nodes[i] as Node3D).global_position = _pre_snapped_positions[i]
	_snap_nodes.clear()
