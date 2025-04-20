extends Control

# References to nodes
var ship_sprite: Sprite2D
var grid_container: Node2D
var parts_container: Node2D
var parts_list_container: VBoxContainer
var ship_option_button: OptionButton
var camera: Camera2D

# Ship data
var current_ship_texture: Texture2D
var grid_cells: Array[Vector2] = []
var grid_cell_size: int = 16
var placed_parts: Array[Dictionary] = []
var scanner_placed: bool = false

# Part being dragged
var dragging_part: Dictionary = {}
var drag_preview: Sprite2D
var is_dragging: bool = false

# Ship and part types
enum PartType { CANNON, THRUSTER, EXPLOSIVE, SCANNER, TRACTOR_BEAM }
var part_data: Dictionary = {
	PartType.CANNON: {
		"name": "Cannon",
		"texture": preload("res://assets/parts/cannon.png"),
		"description": "Basic weapon"
	},
	PartType.THRUSTER: {
		"name": "Thruster",
		"texture": preload("res://assets/parts/thruster.png"),
		"description": "Provides movement"
	},
	PartType.EXPLOSIVE: {
		"name": "Explosive Launcher",
		"texture": preload("res://assets/parts/explosive.png"),
		"description": "Launches bombs, mines, or missiles"
	},
	PartType.SCANNER: {
		"name": "Scanner",
		"texture": preload("res://assets/parts/scanner.png"),
		"description": "Detects nearby objects (limit: 1 per ship)"
	},
	PartType.TRACTOR_BEAM: {
		"name": "Tractor Beam",
		"texture": preload("res://assets/parts/tractor.png"),
		"description": "Attracts or repels objects"
	}
}

var available_ships: Dictionary = {
	"ship1": preload("res://assets/ships/ship1.png"),
	"ship2": preload("res://assets/ships/ship2.png")
}

func _ready():
	# Get references to nodes
	ship_sprite = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/ShipSprite
	grid_container = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/GridContainer
	parts_container = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/PartsContainer
	parts_list_container = $HSplitContainer/PartsPanelContainer/VBoxContainer/PartsScrollContainer/PartsContainer
	ship_option_button = $HSplitContainer/PartsPanelContainer/VBoxContainer/ShipSelectionContainer/ShipOptionButton
	camera = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/Camera2D
	
	# Connect signals
	$HSplitContainer/PartsPanelContainer/VBoxContainer/LoadShipButton.pressed.connect(_on_load_ship_button_pressed)
	$HSplitContainer/PartsPanelContainer/VBoxContainer/SaveShipButton.pressed.connect(_on_save_ship_button_pressed)
	
	# Set up ship selection dropdown
	_populate_ship_dropdown()
	
	# Create parts list
	_create_parts_list()
	
	# Create drag preview
	drag_preview = Sprite2D.new()
	parts_container.add_child(drag_preview)
	drag_preview.visible = false

func _populate_ship_dropdown():
	for ship_name in available_ships.keys():
		ship_option_button.add_item(ship_name)

func _create_parts_list():
	for part_type in part_data.keys():
		var part_info = part_data[part_type]
		var part_button = Button.new()
		part_button.text = part_info.name
		part_button.tooltip_text = part_info.description
		part_button.custom_minimum_size = Vector2(0, 50)
		part_button.pressed.connect(_on_part_button_pressed.bind(part_type))
		
		var part_icon = TextureRect.new()
		part_icon.texture = part_info.texture
		part_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		part_icon.custom_minimum_size = Vector2(40, 40)
		
		var hbox = HBoxContainer.new()
		hbox.add_child(part_icon)
		hbox.add_child(part_button)
		part_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		parts_list_container.add_child(hbox)

func _on_part_button_pressed(part_type: int):
	if is_dragging:
		return
	
	is_dragging = true
	dragging_part = {
		"type": part_type,
		"texture": part_data[part_type].texture,
		"position": Vector2.ZERO
	}
	
	# Set up drag preview
	drag_preview.texture = part_data[part_type].texture
	drag_preview.visible = true

func _on_load_ship_button_pressed():
	var selected_ship = ship_option_button.get_item_text(ship_option_button.selected)
	_load_ship(selected_ship)

func _load_ship(ship_name: String):
	# Clear existing parts
	for child in parts_container.get_children():
		if child != drag_preview:
			child.queue_free()
	
	placed_parts.clear()
	scanner_placed = false
	
	# Load ship texture
	current_ship_texture = available_ships[ship_name]
	ship_sprite.texture = current_ship_texture
	
	# Generate grid based on ship sprite
	_generate_grid()

func _generate_grid():
	# Clear old grid
	for child in grid_container.get_children():
		child.queue_free()
	
	grid_cells.clear()
	
	# Skip if no texture is loaded
	if current_ship_texture == null:
		return
	
	# Get ship image data
	var image = current_ship_texture.get_image()
	var image_size = image.get_size()
	
	# Create grid based on non-transparent pixels
	for y in range(0, image_size.y, grid_cell_size):
		for x in range(0, image_size.x, grid_cell_size):
			var cell_has_pixels = false
			var erosion_margin = 3  # Pixels to erode from edges
			
			# Check if cell has non-transparent pixels (with erosion)
			for cell_y in range(erosion_margin, grid_cell_size - erosion_margin):
				for cell_x in range(erosion_margin, grid_cell_size - erosion_margin):
					var pixel_x = x + cell_x
					var pixel_y = y + cell_y
					
					if pixel_x < image_size.x and pixel_y < image_size.y:
						var pixel_color = image.get_pixel(pixel_x, pixel_y)
						if pixel_color.a > 0.5:  # Check alpha (transparency)
							cell_has_pixels = true
							break
				
				if cell_has_pixels:
					break
			
			if cell_has_pixels:
				# Add to valid grid cells
				var cell_position = Vector2(x, y) + Vector2(grid_cell_size / 2, grid_cell_size / 2)
				grid_cells.append(cell_position)
				
				# Draw grid cell visual
				var grid_rect = ColorRect.new()
				grid_rect.color = Color(0, 1, 0, 0.2)  # Transparent green
				grid_rect.size = Vector2(grid_cell_size, grid_cell_size)
				grid_rect.position = Vector2(x, y) - ship_sprite.texture.get_size() / 2
				grid_container.add_child(grid_rect)

func _input(event):
	if event is InputEventMouseMotion and is_dragging:
		# Update drag preview position
		var viewport = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport
		var mouse_pos = viewport.get_mouse_position()
		drag_preview.global_position = mouse_pos
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed == false and is_dragging:
			# Try to place the part
			var viewport = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport
			var mouse_pos = viewport.get_mouse_position()
			_try_place_part(mouse_pos)
			
			# Reset dragging state
			is_dragging = false
			drag_preview.visible = false

func _try_place_part(position: Vector2):
	# Check if part can be placed here
	var closest_cell = _find_closest_grid_cell(position)
	
	if closest_cell == null:
		return
	
	# Check if a scanner is already placed
	if dragging_part.type == PartType.SCANNER and scanner_placed:
		# Show notification that only one scanner is allowed
		print("Only one scanner is allowed per ship!")
		return
	
	# Check if cell is already occupied
	for part in placed_parts:
		if part.position.distance_to(closest_cell) < grid_cell_size / 2:
			# Cell already has a part
			return
	
	# Create new part
	var new_part = Sprite2D.new()
	new_part.texture = part_data[dragging_part.type].texture
	new_part.position = closest_cell
	parts_container.add_child(new_part)
	
	# Add to placed parts
	var part_info = {
		"type": dragging_part.type,
		"position": closest_cell,
		"node": new_part
	}
	placed_parts.append(part_info)
	
	# Update scanner status
	if dragging_part.type == PartType.SCANNER:
		scanner_placed = true

func _find_closest_grid_cell(position: Vector2):
	var closest_cell = null
	var closest_distance = INF
	
	for cell in grid_cells:
		var distance = position.distance_to(cell)
		if distance < closest_distance and distance < grid_cell_size:
			closest_cell = cell
			closest_distance = distance
	
	return closest_cell

func _on_save_ship_button_pressed():
	# In a full implementation, this would save to a file
	var ship_config = {
		"ship_name": ship_option_button.get_item_text(ship_option_button.selected),
		"parts": []
	}
	
	for part in placed_parts:
		ship_config.parts.append({
			"type": part.type,
			"position": {"x": part.position.x, "y": part.position.y}
		})
	
	print("Ship configuration saved: ", JSON.stringify(ship_config))
	# In a full implementation, you would use FileAccess to save to a file