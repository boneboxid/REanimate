class_name TestUndoRedo
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 2 UNDO/REDO & COMMAND ARCHITECTURE TESTS <<<")
	test_command_stack_basics()
	test_frame_span_undo()
	test_100_random_actions_undo_acceptance()
	print(">>> ALL PHASE 2 UNDO/REDO TESTS PASSED! <<<")

static func test_command_stack_basics() -> void:
	var stack = CommandStack.new()
	assert(!stack.can_undo(), "Initially cannot undo")
	assert(!stack.can_redo(), "Initially cannot redo")
	
	var doc = ProjectDocument.create_default()
	var box_id = doc.items.keys()[0]
	var layer = doc.layers[0]
	
	# Transform Command
	var old_t = layer.keyframes[0].transforms[box_id].duplicate_transform()
	var new_t = old_t.duplicate_transform()
	new_t.position = Vector2(999, 888)
	
	var cmd = DocCommands.TransformItemCommand.new(layer, 0, box_id, old_t, new_t)
	stack.execute_command(cmd)
	
	assert(stack.can_undo(), "Should be able to undo after command")
	assert(!stack.can_redo(), "Should not be able to redo immediately after command")
	assert(layer.keyframes[0].transforms[box_id].position == Vector2(999, 888), "Position must be updated")
	
	# Undo
	assert(stack.undo(), "Undo must succeed")
	assert(layer.keyframes[0].transforms[box_id].position == old_t.position, "Position must be reverted")
	assert(stack.can_redo(), "Should be able to redo")
	
	# Redo
	assert(stack.redo(), "Redo must succeed")
	assert(layer.keyframes[0].transforms[box_id].position == Vector2(999, 888), "Position must be reapplied")
	print("  [OK] 1. CommandStack basic execute/undo/redo mechanics")

static func test_frame_span_undo() -> void:
	var doc = ProjectDocument.create_default()
	var before = JSON.stringify(doc.to_dict())
	var stack = CommandStack.new()
	for f in [0, 30, 10]:
		stack.execute_command(DocCommands.InsertFrameSpanCommand.new(doc, f))
		assert(stack.undo(), "Undo insert span must succeed")
		assert(JSON.stringify(doc.to_dict()) == before, "Undo insert span @%d must restore doc" % f)
		stack.execute_command(DocCommands.RemoveFrameSpanCommand.new(doc, f))
		assert(stack.undo(), "Undo remove span must succeed")
		assert(JSON.stringify(doc.to_dict()) == before, "Undo remove span @%d must restore doc" % f)
	print("  [OK] 1b. Insert/Remove Frame Span undo restores keyframes & max_frames")

static func test_100_random_actions_undo_acceptance() -> void:
	# PHASE 2 ACCEPTANCE: 100 random actions -> undo all -> document is 100% identical!
	var doc = ProjectDocument.create_default()
	var initial_json = JSON.stringify(doc.to_dict())
	var stack = CommandStack.new()
	stack.max_history = 150
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 # Deterministic seed for reproducible test
	
	var added_item_ids: Array[String] = []
	var added_layer_ids: Array[AnimationLayer] = []
	
	var actions_done = 0
	while actions_done < 100:
		var action_type = rng.randi_range(0, 5)
		var cmd: Command = null
		match action_type:
			0: # Add Item
				var new_item = StageItem.new()
				new_item.id = "rand_item_" + str(actions_done)
				new_item.name = "Rand Item " + str(actions_done)
				new_item.shape_type = "rect"
				var t = ItemTransform.new()
				t.position = Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
				cmd = DocCommands.AddItemCommand.new(doc, doc.layers[0], 0, new_item, t)
				added_item_ids.append(new_item.id)
				
			1: # Transform an existing item
				if not doc.items.is_empty():
					var rand_id = doc.items.keys()[rng.randi_range(0, doc.items.size() - 1)]
					var old_t = doc.layers[0].keyframes[0].transforms.get(rand_id, ItemTransform.new())
					var new_t = old_t.duplicate_transform()
					new_t.position += Vector2(10.0, 10.0)
					new_t.rotation += 0.1
					cmd = DocCommands.TransformItemCommand.new(doc.layers[0], 0, rand_id, old_t, new_t)
					
			2: # Change Color
				if not doc.items.is_empty():
					var rand_id = doc.items.keys()[rng.randi_range(0, doc.items.size() - 1)]
					var item = doc.items[rand_id]
					var new_col = Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
					cmd = DocCommands.ChangeColorCommand.new(item, rng.randf() > 0.5, new_col)
					
			3: # Insert Frame Span (F5)
				cmd = DocCommands.InsertFrameSpanCommand.new(doc, 10)
				
			4: # Add Layer
				var new_layer = AnimationLayer.new()
				new_layer.name = "New Layer " + str(actions_done)
				cmd = DocCommands.AddLayerCommand.new(doc, new_layer)
				added_layer_ids.append(new_layer)
				
			5: # Delete an item added during test
				if not added_item_ids.is_empty():
					var to_del_id = added_item_ids.pop_back()
					if doc.items.has(to_del_id):
						cmd = DocCommands.DeleteItemCommand.new(doc, to_del_id)

		if cmd != null:
			stack.execute_command(cmd)
			actions_done += 1
						
	var mutated_json = JSON.stringify(doc.to_dict())
	assert(mutated_json != initial_json, "Document must be mutated after 100 actions")
	
	# UNDO ALL 100 ACTIONS!
	var undo_count = 0
	while stack.can_undo():
		assert(stack.undo(), "Undo must succeed")
		undo_count += 1
		
	assert(undo_count == 100, "Must have undone exactly 100 actions, got: " + str(undo_count))
	
	var final_json = JSON.stringify(doc.to_dict())
	assert(final_json == initial_json, "Final document state must be 100% IDENTICAL to initial state after undoing all actions!")
	print("  [OK] 2. 100 random actions -> Undo all -> Document 100% identical (Acceptance Verified)")
