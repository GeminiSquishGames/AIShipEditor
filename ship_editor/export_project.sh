#!/bin/bash
# Simple script to zip the project for export

cd "$(dirname "$0")"
zip -r ship_editor.zip . -x "*.zip" -x "*.import/*" -x ".godot/*"
echo "Project exported to ship_editor.zip"