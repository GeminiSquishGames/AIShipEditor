extends Control

# References to nodes
var ship_sprite: Sprite2D
var grid_container: Node2D
var parts_container: Node2D
var parts_list_container: VBoxContainer
var ship_option_button: OptionButton
var camera: Camera2D
var viewport: SubViewport
var viewport_container: SubViewportContainer

# Ship data
var current_ship_texture: Texture2D
var grid_cells: Array[Vector2i] = []
var grid_cell_size: int = 16
var placed_parts: Array[Dictionary] = []
var scanner_placed: bool = false

# Part being dragged or selected
var dragging_part: Dictionary = {}
var drag_preview: Sprite2D
var is_dragging: bool = false
var selected_part_index: int = -1
var is_moving_part: bool = false

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

# UI components
var delete_button: Button

func _ready():
	# Get references to nodes
	ship_sprite = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/ShipSprite
	grid_container = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/GridContainer
	parts_container = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/PartsContainer
	parts_list_container = $HSplitContainer/PartsPanelContainer/VBoxContainer/PartsScrollContainer/PartsContainer
	ship_option_button = $HSplitContainer/PartsPanelContainer/VBoxContainer/ShipSelectionContainer/ShipOptionButton
	camera = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport/Camera2D
	viewport = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport/SubViewport
	viewport_container = $HSplitContainer/EditorPanelContainer/VBoxContainer/EditorContainer/EditorViewport
	
	# Connect signals
	$HSplitContainer/PartsPanelContainer/VBoxContainer/LoadShipButton.pressed.connect(_on_load_ship_button_pressed)
	$HSplitContainer/PartsPanelContainer/VBoxContainer/SaveShipButton.pressed.connect(_on_save_ship_button_pressed)
	
	# Add delete button
	delete_button = Button.new()
	delete_button.text = "Delete Selected Part"
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_button_pressed)
	$HSplitContainer/PartsPanelContainer/VBoxContainer.add_child(delete_button)
	
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
	# Clear any selected part
	_deselect_part()
	
	if is_dragging or is_moving_part:
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
	_deselect_part()
	
	# Load ship texture
	current_ship_texture = available_ships[ship_name]
	ship_sprite.texture = current_ship_texture
	
	# Center the ship
	ship_sprite.position = Vector2.ZERO
	
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
				var cell_position = Vector2(x, y) + Vector2(grid_cell_size / 2, grid_cell_size / 2) - image_size / 2
				grid_cells.append(cell_position)
				
				# Draw grid cell visual
				var grid_rect = ColorRect.new()
				grid_rect.color = Color(0, 1, 0, 0.2)  # Transparent green
				grid_rect.size = Vector2(grid_cell_size, grid_cell_size)
				grid_rect.position = Vector2(x, y) - image_size / 2
				grid_container.add_child(grid_rect)

func _process(_delta):
	if is_dragging or is_moving_part:
		# Convert mouse position to viewport coordinates
		var mouse_pos = viewport.get_mouse_position()
		
		# Using local to convert properly
		var viewport_rect = viewport_container.get_global_rect()
		var mouse_viewport_pos = get_viewport().get_mouse_position() - viewport_rect.position
		
		# Scale to account for viewport scaling
		mouse_viewport_pos *= Vector2(viewport.size) / Vector2(viewport_rect.size)
		
		# Update preview position
		drag_preview.global_position = mouse_viewport_pos

func _input(event):
	# Handle mouse movement in _process for smoother updates
	
	if event is InputEventMouseButton:
		var viewport_rect = viewport_container.get_global_rect()
		var is_in_viewport = viewport_rect.has_point(get_viewport().get_mouse_position())
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_in_viewport and not is_dragging and not is_moving_part:
					# Try to select a part
					_try_select_part_at_position(viewport.get_mouse_position())
			else:  # Button released
				if is_dragging and is_in_viewport:
					# Try to place a new part
					_try_place_part(viewport.get_mouse_position())
					is_dragging = false
					drag_preview.visible = false
				elif is_moving_part and is_in_viewport:
					# Finish moving a part
					_finish_move_part(viewport.get_mouse_position())
					is_moving_part = false
					drag_preview.visible = false
		
		# Middle mouse button to move a selected part
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			if selected_part_index >= 0 and not is_dragging and not is_moving_part:
				_start_move_part()
				
		# Right-click to cancel drag or move, or delete a part
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_dragging or is_moving_part:
				is_dragging = false
				is_moving_part = false
				drag_preview.visible = false
				# If moving, return the part to its original position
				if selected_part_index >= 0 and selected_part_index < placed_parts.size():
					var part = placed_parts[selected_part_index]
					part.node.modulate = Color(1, 1, 1)  # Reset highlight
					part.node.visible = true  # Ensure visibility is restored
				_deselect_part()
			elif selected_part_index >= 0:
				# Delete the selected part with right-click
				_on_delete_button_pressed()

func _try_select_part_at_position(position: Vector2):
	var closest_part_index = -1
	var closest_distance = grid_cell_size
	
	for i in range(placed_parts.size()):
		var part = placed_parts[i]
		var distance = position.distance_to(part.position)
		if distance < closest_distance:
			closest_part_index = i
			closest_distance = distance
	
	if closest_part_index >= 0:
		_select_part(closest_part_index)
	else:
		_deselect_part()

func _select_part(index: int):
	_deselect_part()
	
	selected_part_index = index
	delete_button.disabled = false
	
	# Highlight the selected part
	var part = placed_parts[selected_part_index]
	part.node.modulate = Color(1.2, 1.2, 0.8)  # Slight yellow tint

func _deselect_part():
	if selected_part_index >= 0 and selected_part_index < placed_parts.size():
		var part = placed_parts[selected_part_index]
		part.node.modulate = Color(1, 1, 1)  # Reset highlight
	
	selected_part_index = -1
	delete_button.disabled = true

func _on_delete_button_pressed():
	if selected_part_index >= 0 and selected_part_index < placed_parts.size():
		var part = placed_parts[selected_part_index]
		
		# Update scanner status if deleting a scanner
		if part.type == PartType.SCANNER:
			scanner_placed = false
		
		# Remove visual node
		part.node.queue_free()
		
		# Remove from array
		placed_parts.remove_at(selected_part_index)
		
		# Reset selection
		_deselect_part()

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

func _start_move_part():
	if selected_part_index >= 0 and selected_part_index < placed_parts.size():
		var part = placed_parts[selected_part_index]
		
		is_moving_part = true
		dragging_part = {
			"type": part.type,
			"texture": part_data[part.type].texture,
			"position": part.position,
			"original_index": selected_part_index
		}
		
		# Setup drag preview
		drag_preview.texture = part_data[part.type].texture
		drag_preview.visible = true
		
		# Hide original part while moving
		part.node.visible = false

func _finish_move_part(position: Vector2):
	if selected_part_index < 0 or selected_part_index >= placed_parts.size():
		return
		
	var part = placed_parts[selected_part_index]
	var closest_cell = _find_closest_grid_cell(position)
	
	if closest_cell == null:
		# Invalid location, return to original position
		part.node.visible = true
		return
	
	# Check if cell is already occupied by another part
	for i in range(placed_parts.size()):
		if i != selected_part_index and placed_parts[i].position.distance_to(closest_cell) < grid_cell_size / 2:
			# Cell already has a part
			part.node.visible = true
			return
	
	# Move part to new position
	part.position = closest_cell
	part.node.position = closest_cell
	part.node.visible = true

func _find_closest_grid_cell(position: Vector2):
	var closest_cell = null
	var closest_distance = INF
	
	for cell in grid_cells:
		var distance = position.distance_to(cell)
		if distance < closest_distance and distance < grid_cell_size * 1.5:
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