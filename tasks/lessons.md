# mvp-06 / XATATRON - Lessons Learned
	
	## Date: 2026-04-14
	
	---
	
	## Godot MCP Patterns
	
	### Verified Best Practices
	- `godot:edit_script` is most reliable for full file rewrites
	- `save_scene` frequently times out → attempt, then ask user for Ctrl+S
	- Always confirm active machine with `ProjectSettings.globalize_path("res://")` before file operations
	- `execute_editor_script` parameter is `code`, not `script`
	- Portrait orientation: `display/window/handheld/orientation = "portrait"` + `stretch/mode = "canvas_items"` + `stretch/aspect = "expand"`
	
	### GDScript 4.6 Specific
	- Use `mini()` not `min()` for integers
	- Explicit type annotation needed on `:=` for array subscripts
	- Never use compressed syntax (`if a: b; c`) — always expand to separate lines
	
	### Firebase
	- Anonymous Auth enabled on project: xatatron
	- Firestore collections: rooms, players
	
	---
	
	## Future Issues
	(Add new patterns here as they are discovered)
	