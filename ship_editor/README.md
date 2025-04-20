# 2D Ship Editor for Godot Space Shooter

This is a ship editor that allows you to customize ships for a top-down space shooter game by placing various parts (cannons, thrusters, explosives launchers, scanners, and tractor beams) on the ship's grid.

## Controls

- **Left Click**: Select a part
- **Middle Click**: Move a selected part
- **Right Click**: Delete a part (or cancel dragging)
- **Delete Button**: Remove the selected part

## Features

- Load different ship sprites
- Automatically generate placement grid based on ship sprite's opaque pixels
- Drag and drop ship parts onto the grid
- Rules enforcement (parts must be placed on valid grid cells, only one scanner allowed)
- Save and load ship configurations
- Placeholder assets for ships and parts

## How to Use

1. Download or clone this repository
2. Open the project in Godot 4.4.1
3. Run the generate_assets.gd script first to create placeholder assets:
   - From the Godot project view, go to Editor → Run Script
   - Select `scripts/generate_assets.gd`
   - This will create placeholder sprites for ships and parts
4. Run the main scene (`scenes/main.tscn`)
5. Select a ship from the dropdown and click "Load Ship"
6. Drag and drop parts from the left panel onto the ship grid
7. Click "Save Ship" to save the configuration (currently just prints to console)

## Ship Editor Controls

- Left panel: Ship parts you can drag onto the ship
- Right panel: Ship editing area
- Green grid shows valid placement areas
- Parts snap to the nearest valid grid cell when placed

## Customization

You can add your own ship sprites and part sprites:
1. Add ship sprites to the `assets/ships/` directory
2. Add part sprites to the `assets/parts/` directory
3. Update the `available_ships` and `part_data` dictionaries in `editor.gd`

## Future Enhancements

- Visual customization (colors, textures)
- Ship statistics editing
- Proper file saving and loading
- More ship and part types
- Preview of ship performance

## Requirements

- Godot 4.4.1 or compatible version