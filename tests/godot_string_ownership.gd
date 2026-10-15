extends SceneTree

func _initialize():
	call_deferred("check_strings")

func resident_bytes():
	# procfs reports zero file length; FileAccess.get_file_as_string therefore
	# reads no bytes. Read this process's proc entry through the system reader.
	var output = []
	assert(OS.execute("/bin/cat", ["/proc/" + str(OS.get_process_id()) + "/statm"], output) == 0)
	var status = output[0].strip_edges().split(" ", false)
	assert(status.size() >= 2)
	return int(status[1]) * 4096

func check_strings():
	# Native Rulebook strings own their buffers. The bridge used to mark heap
	# allocations non-owning, leaking both allocations on every conversion.
	var input = "Orks: Waaagh! ".repeat(512)
	for warmup in range(100):
		var converted = RLCLib.godot_string_to_rlc_string(input)
		assert(RLCLib.convert_string(converted) == input)
	var before = resident_bytes()
	for iteration in range(10000):
		var converted = RLCLib.godot_string_to_rlc_string(input)
		assert(RLCLib.convert_string(converted) == input)
	var growth = resident_bytes() - before
	# The former leak grows by >40MiB. Allow allocator/engine noise without
	# mistaking a small retained pool for a leak. This probe runs on Linux.
	if growth >= 16 * 1024 * 1024:
		push_error("Native conversion memory growth: " + str(growth))
		root.get_node("GlobalRules").library.free()
		quit(1)
		return
	var unicode_text = "Orks: Waaagh! — ⌀ Big’ed Bossbunka"
	assert(RLCLib.convert_string(RLCLib.godot_string_to_rlc_string(unicode_text)) == unicode_text)
	assert(RLCLib.convert_string(RLCLib.godot_string_to_rlc_string("")) == "")
	print("PASS: Godot schema exports, UTF-8/empty string ownership; RSS growth=", growth)
	root.get_node("GlobalRules").library.free()
	quit(0)
