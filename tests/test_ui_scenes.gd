extends SceneTree


func _initialize() -> void:
	var scene_paths: Array[String] = []
	_collect_scenes("res://scenes", scene_paths)
	_collect_scenes("res://ui/components", scene_paths)
	scene_paths.sort()
	var failures: Array[String] = []
	for scene_path in scene_paths:
		var packed_scene := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
		if packed_scene == null:
			failures.append("%s could not be loaded" % scene_path)
			continue
		var instance := packed_scene.instantiate()
		if instance == null:
			failures.append("%s could not be instantiated" % scene_path)
			continue
		instance.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("%d UI scenes loaded and instantiated" % scene_paths.size())
	quit(0)


func _collect_scenes(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("Could not scan %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scenes(path, output)
		elif entry.ends_with(".tscn"):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
