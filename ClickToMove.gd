extends CharacterBody3D

@onready var navigationAgent : NavigationAgent3D = $NavigationAgent3D
@onready var visual_node : Node3D = $Visual

@export var Speed: float = 5.0
@export var rotation_speed: float = 5.0

# Animation parameters
@export_group("Animation Settings")
@export var bob_amplitude: float = 0.1
@export var bob_frequency: float = 8.0
@export var wobble_amplitude: float = 0.05
@export var wobble_frequency: float = 4.0
@export var lean_angle: float = 0.1  # How far to lean forward
@export var lean_speed: float = 3.0   # How fast to transition the lean
var time: float = 0.0
var current_lean: float = 0.0

# Original position and rotation
var original_y: float = 0.0

func _ready() -> void:
	original_y = global_position.y

func _process(delta: float) -> void:
	if navigationAgent.is_navigation_finished():
		# Smooth lean back to upright
		current_lean = move_toward(current_lean, 0.0, delta * lean_speed)
		global_position.y = original_y
		visual_node.rotation = Vector3(-current_lean, 0.0, 0.0)
		return
	
	# Smooth lean into movement
	current_lean = move_toward(current_lean, lean_angle, delta * lean_speed)
	
	time += delta
	
	# Apply bobbing motion (up/down)
	var bob: float = sin(time * bob_frequency) * bob_amplitude
	global_position.y = original_y + bob
	
	# Apply wobble and lean to the visual node
	var wobble: float = sin(time * wobble_frequency) * wobble_amplitude
	visual_node.rotation = Vector3(-current_lean, 0.0, wobble)
	
	moveToPoint(delta, Speed)

func moveToPoint(delta: float, speed: float) -> void:
	var targetPos: Vector3 = navigationAgent.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(targetPos)
	faceDirection(targetPos, delta)
	velocity = direction * speed
	move_and_slide()

func faceDirection(target: Vector3, delta: float) -> void:
	var direction: Vector3 = target - global_position
	direction.y = 0.0
	
	if direction.length() > 0.001:
		var current_y: float = rotation.y
		var target_y: float = atan2(direction.x, direction.z) + PI  # Added PI to match previous look_at behavior
		rotation.y = lerp_angle(current_y, target_y, delta * rotation_speed)
		
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("LeftMouse"):
		var camera: Camera3D = get_tree().get_nodes_in_group("Camera")[0]
		var mousePos: Vector2 = get_viewport().get_mouse_position()
		var rayLength: float = 100.0
		var from: Vector3 = camera.project_ray_origin(mousePos)
		var to: Vector3 = from + camera.project_ray_normal(mousePos) * rayLength
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var rayQuery: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		rayQuery.from = from
		rayQuery.to = to
		rayQuery.collide_with_areas = true
		var result: Dictionary = space.intersect_ray(rayQuery)
		
		if !result.is_empty():
			navigationAgent.target_position = result["position"]
