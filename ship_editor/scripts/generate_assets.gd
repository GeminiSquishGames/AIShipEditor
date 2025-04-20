extends SceneTree

# This script generates placeholder assets for ships and parts
# Run with: godot --headless --script scripts/generate_assets.gd

func _init():
	print("Generating placeholder assets...")
	
	# Create directories if they don't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")
	
	if not dir.dir_exists("assets/ships"):
		dir.make_dir("assets/ships")
		
	if not dir.dir_exists("assets/parts"):
		dir.make_dir("assets/parts")
	
	# Generate ship sprites
	generate_ship_sprite("ship1", Color(0.2, 0.4, 0.8), Vector2(200, 120))
	generate_ship_sprite("ship2", Color(0.8, 0.2, 0.3), Vector2(160, 140))
	
	# Generate part sprites
	generate_part_sprite("cannon", Color(0.7, 0.7, 0.7), Vector2(24, 32))
	generate_part_sprite("thruster", Color(0.9, 0.5, 0.1), Vector2(20, 28))
	generate_part_sprite("explosive", Color(0.9, 0.2, 0.2), Vector2(26, 26))
	generate_part_sprite("scanner", Color(0.3, 0.8, 0.3), Vector2(30, 30))
	generate_part_sprite("tractor", Color(0.6, 0.3, 0.9), Vector2(24, 32))
	
	print("Asset generation complete!")
	quit()

func generate_ship_sprite(name: String, base_color: Color, size: Vector2):
	var image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	
	# Fill with transparent color
	image.fill(Color(0, 0, 0, 0))
	
	# Draw ship body
	for y in range(int(size.y)):
		for x in range(int(size.x)):
			# Create a ship-like shape
			var center_x = size.x / 2
			var center_y = size.y / 2
			var dist_from_center_x = abs(x - center_x) / (size.x / 2)
			var dist_from_center_y = abs(y - center_y) / (size.y / 2)
			
			# Ship body shape (roughly oval with pointed front)
			var shape_value = dist_from_center_x * dist_from_center_x + dist_from_center_y * dist_from_center_y
			
			# Adjust shape based on x position (make front pointier)
			if x > center_x:
				shape_value += 0.1 * (1.0 - dist_from_center_x)
			
			if shape_value < 1.0:
				# Inside the ship shape
				var color = base_color
				
				# Add some variation/shading
				var highlight = (1.0 - dist_from_center_y) * 0.3
				color = Color(
					min(color.r + highlight, 1.0),
					min(color.g + highlight, 1.0),
					min(color.b + highlight, 1.0),
					1.0
				)
				
				image.set_pixel(x, y, color)
	
	# Save the image
	var err = image.save_png("res://assets/ships/" + name + ".png")
	if err != OK:
		print("Error saving ship image: ", err)
	else:
		print("Generated ship: ", name)

func generate_part_sprite(name: String, base_color: Color, size: Vector2):
	var image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	
	# Fill with transparent color
	image.fill(Color(0, 0, 0, 0))
	
	# Draw part based on type
	for y in range(int(size.y)):
		for x in range(int(size.x)):
			var center_x = size.x / 2
			var center_y = size.y / 2
			var dist_from_center_x = abs(x - center_x) / (size.x / 2)
			var dist_from_center_y = abs(y - center_y) / (size.y / 2)
			
			var shape_value = 0.0
			
			# Different shapes for different parts
			match name:
				"cannon":
					# Rectangular barrel shape
					if abs(x - center_x) < size.x * 0.25 and y < size.y * 0.8:
						image.set_pixel(x, y, base_color)
					# Circular base
					elif dist_from_center_x * dist_from_center_x + dist_from_center_y * dist_from_center_y < 0.2 and y > size.y * 0.7:
						image.set_pixel(x, y, base_color.darkened(0.3))
				
				"thruster":
					# Thruster nozzle
					if abs(x - center_x) < size.x * 0.3:
						if y > size.y * 0.6:
							image.set_pixel(x, y, base_color)
						elif y > size.y * 0.3:
							var flame_color = base_color.lerp(Color(1, 0.7, 0.1, 0.8), 0.7)
							image.set_pixel(x, y, flame_color)
				
				"explosive":
					# Circular bomb/missile
					shape_value = dist_from_center_x * dist_from_center_x + dist_from_center_y * dist_from_center_y
					if shape_value < 0.5:
						var color = base_color
						# Add highlight at top
						if y < center_y and x > center_x * 0.7 and x < center_x * 1.3:
							color = color.lightened(0.3)
						image.set_pixel(x, y, color)
				
				"scanner":
					# Radar dish shape
					shape_value = dist_from_center_x * dist_from_center_x + dist_from_center_y * dist_from_center_y
					if shape_value < 0.7 and y < size.y * 0.8:
						var color = base_color
						# Add radar lines
						if (abs(x - center_x) + abs(y - center_y)) % 5 < 2:
							color = color.darkened(0.2)
						image.set_pixel(x, y, color)
				
				"tractor":
					# Tractor beam emitter
					if abs(x - center_x) < size.x * 0.25:
						image.set_pixel(x, y, base_color)
					
					# Add beam effect at bottom
					if y > size.y * 0.6 and abs(x - center_x) < size.x * 0.4:
						var beam_color = base_color.lerp(Color(0.9, 0.9, 1.0, 0.5), 0.7)
						image.set_pixel(x, y, beam_color)
	
	# Save the image
	var err = image.save_png("res://assets/parts/" + name + ".png")
	if err != OK:
		print("Error saving part image: ", err)
	else:
		print("Generated part: ", name)