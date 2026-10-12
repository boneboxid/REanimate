# Parser dan Exporter resmi Adobe Flash / Animate (.fla / XFL ZIP)
class_name FLAManager
extends RefCounted

# Menerjemahkan string edge Bezier Adobe Flash ("!x y|x y[cx cy x y") menjadi Vector2 points & control points
static func parse_flash_edges(edge_str: String) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	var curves: PackedVector2Array = PackedVector2Array()
	
	var s = edge_str.strip_edges()
	var idx = 0
	var n = s.length()
	var current_pt = Vector2.ZERO
	
	while idx < n:
		var cmd = s[idx]
		idx += 1
		
		while idx < n and (s[idx] == ' ' or s[idx] == '\t'):
			idx += 1
			
		if cmd == '!':
			# Move to: !x y (dalam satuan twips, 1 px = 20 twips)
			var tokens = _read_numeric_tokens(s, idx, 2)
			idx = tokens["next_idx"]
			if tokens["values"].size() >= 2:
				current_pt = Vector2(tokens["values"][0], tokens["values"][1]) / 20.0
				points.append(current_pt)
		elif cmd == '|':
			# Line to: |x y
			var tokens = _read_numeric_tokens(s, idx, 2)
			idx = tokens["next_idx"]
			if tokens["values"].size() >= 2:
				var target_pt = Vector2(tokens["values"][0], tokens["values"][1]) / 20.0
				points.append(target_pt)
				curves.append((current_pt + target_pt) * 0.5)
				current_pt = target_pt
		elif cmd == '[':
			# Quadratic Bezier: [cx cy x y
			var tokens = _read_numeric_tokens(s, idx, 4)
			idx = tokens["next_idx"]
			if tokens["values"].size() >= 4:
				var ctrl_pt = Vector2(tokens["values"][0], tokens["values"][1]) / 20.0
				var target_pt = Vector2(tokens["values"][2], tokens["values"][3]) / 20.0
				points.append(target_pt)
				curves.append(ctrl_pt)
				current_pt = target_pt
		elif cmd == '/' or cmd == 'S':
			while idx < n and s[idx] != '!' and s[idx] != '|' and s[idx] != '[':
				idx += 1
				
	return {
		"points": points,
		"curves": curves
	}

static func _read_numeric_tokens(s: String, start_idx: int, count: int) -> Dictionary:
	var vals: Array[float] = []
	var idx = start_idx
	var n = s.length()
	
	for _c in range(count):
		while idx < n and (s[idx] == ' ' or s[idx] == '\t' or s[idx] == '\n' or s[idx] == '\r'):
			idx += 1
		if idx >= n or (s[idx] in ['!', '|', '[', '/', 'S']):
			break
			
		var is_negative = false
		if s[idx] == '-':
			is_negative = true
			idx += 1
		elif s[idx] == '+':
			idx += 1
			
		var is_hex = false
		if idx < n and s[idx] == '#':
			is_hex = true
			idx += 1
			
		var num_str = ""
		while idx < n and ((s[idx] >= '0' and s[idx] <= '9') or s[idx] == '.' or (s[idx] >= 'A' and s[idx] <= 'F') or (s[idx] >= 'a' and s[idx] <= 'f')):
			num_str += s[idx]
			idx += 1
			
		if is_hex and num_str != "":
			var parts = num_str.split(".")
			var int_hex = parts[0]
			var int_val = float(int_hex.hex_to_int())
			var l = int_hex.length()
			if l <= 4 and int_val >= 0x8000:
				int_val -= 0x10000
			elif l <= 6 and int_val >= 0x800000:
				int_val -= 0x1000000
			elif l > 6 and int_val >= 0x80000000:
				int_val -= 0x100000000
			if parts.size() > 1:
				var frac_val = float(parts[1].hex_to_int()) / pow(16.0, float(parts[1].length()))
				if int_val < 0:
					int_val -= frac_val
				else:
					int_val += frac_val
			if is_negative:
				int_val = -int_val
			vals.append(int_val)
		elif num_str != "":
			var f_val = num_str.to_float()
			if is_negative:
				f_val = -f_val
			vals.append(f_val)
			
	return { "values": vals, "next_idx": idx }

static func matrix_to_item_transform(a: float, b: float, c: float, d: float, tx: float, ty: float) -> ItemTransform:
	var t = ItemTransform.new()
	t.position = Vector2(tx, ty)
	var sx = sqrt(a * a + b * b)
	var sy = sqrt(c * c + d * d)
	var det = a * d - b * c
	if det < 0:
		sx = -sx
	t.scale = Vector2(sx if abs(sx) > 0.0001 else 1.0, sy if abs(sy) > 0.0001 else 1.0)
	t.rotation = atan2(b, a if det >= 0 else -a)
	t.opacity = 1.0
	t.has_affine = true
	t.affine_matrix = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(tx, ty))
	return t

# Import file .FLA (ZIP XFL) menjadi ProjectDocument
static func import_from_fla(file_path: String) -> ProjectDocument:
	var fa = FileAccess.open(file_path, FileAccess.READ)
	if fa == null:
		push_error("Gagal membuka file .fla: " + file_path)
		return null
	var buf = fa.get_buffer(fa.get_length())
	fa.close()
	
	# Deteksi format biner lama Adobe Flash (OLE CFB: D0 CF 11 E0)
	if buf.size() >= 4 and buf[0] == 0xD0 and buf[1] == 0xCF and buf[2] == 0x11 and buf[3] == 0xE0:
		push_error("Format FLA biner lama terdeteksi (Flash CS3/CS4 kebawah). Silakan simpan ulang sebagai XFL di Adobe Animate.")
		return null
		
	# Normalisasi header ZIP EOCD (Adobe Flash sering menulis cd_size off beberapa bytes)
	var n = buf.size()
	if n > 22:
		for i in range(n - 22, maxi(0, n - 2048), -1):
			if buf[i] == 0x50 and buf[i+1] == 0x4B and buf[i+2] == 0x05 and buf[i+3] == 0x06:
				var cd_offset = buf[i + 16] | (buf[i + 17] << 8) | (buf[i + 18] << 16) | (buf[i + 19] << 24)
				var real_cd_size = i - cd_offset
				if real_cd_size > 0:
					buf[i + 12] = real_cd_size & 0xFF
					buf[i + 13] = (real_cd_size >> 8) & 0xFF
					buf[i + 14] = (real_cd_size >> 16) & 0xFF
					buf[i + 15] = (real_cd_size >> 24) & 0xFF
				break
				
	var temp_zip_path = "user://temp_fla_import.zip"
	var out_fa = FileAccess.open(temp_zip_path, FileAccess.WRITE)
	if out_fa != null:
		out_fa.store_buffer(buf)
		out_fa.close()
	else:
		temp_zip_path = file_path
		
	var reader = ZIPReader.new()
	var err = reader.open(temp_zip_path)
	if err != OK:
		push_error("Gagal membaca arsip zip .fla: " + str(err))
		return null
		
	var files = reader.get_files()
	if not ("DOMDocument.xml" in files):
		push_error("File .fla tidak memiliki DOMDocument.xml yang valid.")
		reader.close()
		return null
		
	var doc = ProjectDocument.new()
	doc.name = file_path.get_file().get_basename()
	doc.layers.clear()
	
	# 1. Parse DOMDocument.xml
	var doc_bytes = reader.read_file("DOMDocument.xml")
	var doc_xml = XMLParser.new()
	doc_xml.open_buffer(doc_bytes)
	
	var current_layer: AnimationLayer = null
	var current_frame_idx = 0
	var current_kf: KeyframeData = null
	var cur_doc_shape_color = Color(0.9, 0.9, 0.9, 1.0)
	var root_offset = Vector2.ZERO
	
	# State machine stack untuk elemen aktif saat parsing XML
	var current_active_instance_id = ""
	
	while doc_xml.read() == OK:
		var node_type = doc_xml.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT_END:
			if doc_xml.get_node_name() == "DOMSymbolInstance":
				current_active_instance_id = ""
			continue
		if node_type != XMLParser.NODE_ELEMENT:
			continue
			
		var node_name = doc_xml.get_node_name()
		if node_name == "DOMDocument":
			for i in range(doc_xml.get_attribute_count()):
				var attr_name = doc_xml.get_attribute_name(i)
				var attr_val = doc_xml.get_attribute_value(i)
				if attr_name == "width":
					doc.stage_size.x = attr_val.to_float()
				elif attr_name == "height":
					doc.stage_size.y = attr_val.to_float()
				elif attr_name == "frameRate":
					doc.fps = attr_val.to_int()
				elif attr_name == "backgroundColor":
					doc.bg_color = Color.from_string(attr_val, Color(0.98, 0.98, 0.98, 1.0))
			root_offset = -doc.stage_size * 0.5
			
		elif node_name == "DOMLayer":
			current_layer = AnimationLayer.new()
			for i in range(doc_xml.get_attribute_count()):
				var aname = doc_xml.get_attribute_name(i)
				var aval = doc_xml.get_attribute_value(i)
				if aname == "name":
					current_layer.name = aval
				elif aname == "isVisible":
					current_layer.is_visible = (aval == "true")
				elif aname == "isLocked":
					current_layer.is_locked = (aval == "true")
				elif aname == "layerType":
					current_layer.layer_type = aval
				elif aname == "color":
					current_layer.outline_color = Color.from_string(aval, Color.TRANSPARENT)
			doc.layers.append(current_layer)
			
		elif node_name == "DOMFrame":
			current_kf = KeyframeData.new()
			var frame_duration = 1
			for i in range(doc_xml.get_attribute_count()):
				var aname = doc_xml.get_attribute_name(i)
				var aval = doc_xml.get_attribute_value(i)
				if aname == "index":
					current_frame_idx = aval.to_int()
				elif aname == "duration":
					frame_duration = aval.to_int()
				elif aname == "tweenType":
					current_kf.tween_type = "classic" if aval == "motion" else ("shape" if aval == "shape" else "none")
					current_kf.tween_to_next = current_kf.tween_type
				elif aname == "acceleration":
					current_kf.ease = aval.to_float()
				elif aname == "name":
					current_kf.label = aval
				elif aname == "motionTweenRotate":
					current_kf.rotate_dir = "cw" if aval == "clockwise" else ("ccw" if aval == "counter-clockwise" else "none")
				elif aname == "motionTweenRotateTimes":
					current_kf.rotate_times = aval.to_int()
					
			current_kf.frame_index = current_frame_idx
			doc.max_frames = maxi(doc.max_frames, current_frame_idx + frame_duration)
			if current_layer != null:
				current_layer.set_keyframe(current_kf)
				
		elif node_name == "SolidColor" or node_name == "GradientEntry":
			for i in range(doc_xml.get_attribute_count()):
				if doc_xml.get_attribute_name(i) == "color":
					cur_doc_shape_color = Color.from_string(doc_xml.get_attribute_value(i), cur_doc_shape_color)
					
		elif node_name == "DOMSymbolInstance":
			var lib_name = ""
			var loop_val = "loop"
			var first_f = 0
			for i in range(doc_xml.get_attribute_count()):
				var aname = doc_xml.get_attribute_name(i)
				var aval = doc_xml.get_attribute_value(i)
				if aname == "libraryItemName":
					lib_name = aval
				elif aname == "loop":
					loop_val = aval
				elif aname == "firstFrame":
					first_f = aval.to_int()
					
			if lib_name != "":
				var item_id = "sym_" + lib_name.replace("/", "_").replace(" ", "_")
				current_active_instance_id = item_id
				if not doc.items.has(item_id):
					var stage_item = StageItem.new()
					stage_item.id = item_id
					stage_item.name = lib_name.get_file()
					stage_item.shape_type = "symbol"
					stage_item.library_ref = item_id
					stage_item.size = Vector2(160, 240)
					stage_item.color = Color(0.9, 0.4, 0.2, 1.0)
					stage_item.loop_mode = loop_val
					stage_item.first_frame = first_f
					doc.items[item_id] = stage_item
					doc.symbols[item_id] = stage_item
					
				if current_kf != null:
					var t = ItemTransform.new()
					t.position = Vector2.ZERO
					current_kf.transforms[item_id] = t
					
					var sym_el = SymbolInstance.new()
					sym_el.id = item_id
					sym_el.name = lib_name.get_file()
					sym_el.library_ref = item_id
					sym_el.transform = t
					sym_el.loop_mode = loop_val
					sym_el.first_frame = first_f
					current_kf.add_element(sym_el)
					
		elif node_name == "Color":
			# Parse Color Effects dari Flash XML
			if current_kf != null and current_active_instance_id != "":
				var el = current_kf.get_element(current_active_instance_id)
				var sym_el = el as SymbolInstance if el is SymbolInstance else null
				var item = doc.items.get(current_active_instance_id, null)
				for i in range(doc_xml.get_attribute_count()):
					var aname = doc_xml.get_attribute_name(i)
					var aval = doc_xml.get_attribute_value(i)
					if aname == "tintColor":
						var tc = Color.from_string(aval, Color.WHITE)
						if sym_el != null: sym_el.tint_color = tc
						if item != null: item.tint_color = tc
					elif aname == "tintMultiplier":
						var tr = aval.to_float()
						if sym_el != null:
							sym_el.color_effect = "tint"
							sym_el.tint_ratio = tr
						if item != null:
							item.color_effect = "tint"
							item.tint_ratio = tr
					elif aname == "alphaMultiplier":
						var a = aval.to_float()
						if sym_el != null:
							sym_el.alpha = a
							if sym_el.color_effect == "none": sym_el.color_effect = "alpha"
						if item != null:
							item.alpha = a
							if item.color_effect == "none": item.color_effect = "alpha"
							
		elif node_name == "Matrix":
			if current_kf != null and current_active_instance_id != "" and current_kf.transforms.has(current_active_instance_id):
				var a = 1.0; var b = 0.0; var c = 0.0; var d = 1.0; var tx = 0.0; var ty = 0.0
				for i in range(doc_xml.get_attribute_count()):
					var aname = doc_xml.get_attribute_name(i)
					var aval = doc_xml.get_attribute_value(i).to_float()
					if aname == "a": a = aval
					elif aname == "b": b = aval
					elif aname == "c": c = aval
					elif aname == "d": d = aval
					elif aname == "tx": tx = aval
					elif aname == "ty": ty = aval
				var t = matrix_to_item_transform(a, b, c, d, tx, ty)
				t.position += root_offset
				t.affine_matrix.origin += root_offset
				current_kf.transforms[current_active_instance_id] = t
				var el = current_kf.get_element(current_active_instance_id)
				if el != null:
					el.transform = t
					
		elif node_name == "Edge":
			for i in range(doc_xml.get_attribute_count()):
				if doc_xml.get_attribute_name(i) == "edges":
					var pe = parse_flash_edges(doc_xml.get_attribute_value(i))
					if pe["points"].size() > 1:
						var shape_id = "stage_shape_%d_%d" % [current_frame_idx, doc.items.size()]
						var shape_item = StageItem.new()
						shape_item.id = shape_id
						shape_item.name = "Shape"
						shape_item.shape_type = "path"
						shape_item.color = cur_doc_shape_color
						var offset_pts = PackedVector2Array()
						for p in pe["points"]:
							offset_pts.append(p + root_offset)
						var offset_curves = PackedVector2Array()
						for cp in pe["curves"]:
							offset_curves.append(cp + root_offset)
						shape_item.points = offset_pts
						shape_item.curve_controls = offset_curves
						shape_item.sub_paths.append({
							"points": offset_pts,
							"curves": offset_curves,
							"color": cur_doc_shape_color,
							"stroke_color": shape_item.stroke_color
						})
						doc.items[shape_id] = shape_item
						if current_kf != null:
							var st = ItemTransform.new()
							current_kf.transforms[shape_id] = st
							var sh_el = ShapeElement.new()
							sh_el.id = shape_id
							sh_el.shape_type = "path"
							sh_el.points = offset_pts
							sh_el.curve_controls = offset_curves
							sh_el.color = cur_doc_shape_color
							sh_el.transform = st
							current_kf.add_element(sh_el)
					
	# 2. Parse symbols di folder LIBRARY/
	for fname in files:
		if fname.begins_with("LIBRARY/") and fname.ends_with(".xml"):
			var sym_bytes = reader.read_file(fname)
			var sym_xml = XMLParser.new()
			sym_xml.open_buffer(sym_bytes)
			var sym_name = fname.trim_prefix("LIBRARY/").trim_suffix(".xml")
			var sym_id = "sym_" + sym_name.replace("/", "_").replace(" ", "_")
			
			var symbol_item = doc.items.get(sym_id, doc.symbols.get(sym_id, null))
			if symbol_item == null:
				symbol_item = StageItem.new()
				symbol_item.id = sym_id
				symbol_item.name = sym_name.get_file()
				symbol_item.shape_type = "symbol"
				symbol_item.library_ref = sym_id
			doc.items[sym_id] = symbol_item
			doc.symbols[sym_id] = symbol_item
			
			# Buat juga SymbolItem di doc.library untuk arsitektur v2.0.0
			var doc_sym = doc.library.get(sym_id, null)
			if doc_sym == null:
				doc_sym = SymbolItem.new()
				doc_sym.id = sym_id
				doc_sym.name = sym_name.get_file()
				doc.library[sym_id] = doc_sym
			
			var fills_map: Dictionary = {}
			var cur_fill_idx = 1
			var child_instances: Array[Dictionary] = []
			var cur_child_lib = ""
			var in_f0 = true
			var cur_f_idx = 0
			
			while sym_xml.read() == OK:
				if sym_xml.get_node_type() != XMLParser.NODE_ELEMENT:
					continue
				var sname = sym_xml.get_node_name()
				if sname == "DOMSymbolItem":
					for i in range(sym_xml.get_attribute_count()):
						if sym_xml.get_attribute_name(i) == "symbolType":
							symbol_item.symbol_type = sym_xml.get_attribute_value(i)
							doc_sym.symbol_type = symbol_item.symbol_type
				elif sname == "DOMFrame":
					for i in range(sym_xml.get_attribute_count()):
						if sym_xml.get_attribute_name(i) == "index":
							cur_f_idx = sym_xml.get_attribute_value(i).to_int()
					in_f0 = (cur_f_idx == 0)
				elif sname == "FillStyle":
					for i in range(sym_xml.get_attribute_count()):
						if sym_xml.get_attribute_name(i) == "index":
							cur_fill_idx = sym_xml.get_attribute_value(i).to_int()
				elif sname == "SolidColor":
					for i in range(sym_xml.get_attribute_count()):
						if sym_xml.get_attribute_name(i) == "color":
							fills_map[cur_fill_idx] = Color.from_string(sym_xml.get_attribute_value(i), Color(1.0, 0.8, 0.0, 1.0))
				elif sname == "Edge":
					var raw_edges = ""
					var fs0 = -1
					var fs1 = -1
					for i in range(sym_xml.get_attribute_count()):
						var aname = sym_xml.get_attribute_name(i)
						var aval = sym_xml.get_attribute_value(i)
						if aname == "edges":
							raw_edges = aval
						elif aname == "fillStyle0":
							fs0 = aval.to_int()
						elif aname == "fillStyle1":
							fs1 = aval.to_int()
					if raw_edges != "":
						var edge_col = fills_map.get(fs1 if fs1 > 0 else (fs0 if fs0 > 0 else cur_fill_idx), symbol_item.color)
						var parsed_edge = parse_flash_edges(raw_edges)
						if parsed_edge["points"].size() > 1:
							symbol_item.points.append_array(parsed_edge["points"])
							symbol_item.curve_controls.append_array(parsed_edge["curves"])
							var can_stitch = false
							if not symbol_item.sub_paths.is_empty():
								var last_sp = symbol_item.sub_paths[-1]
								if last_sp.get("color") == edge_col and last_sp["points"].size() > 0:
									var last_pt = last_sp["points"][-1]
									var first_pt = parsed_edge["points"][0]
									if last_pt.distance_to(first_pt) < 1.0:
										last_sp["points"].append_array(parsed_edge["points"].slice(1))
										last_sp["curves"].append_array(parsed_edge["curves"])
										can_stitch = true
							if not can_stitch:
								symbol_item.sub_paths.append({
									"points": parsed_edge["points"],
									"curves": parsed_edge["curves"],
									"color": edge_col,
									"stroke_color": symbol_item.stroke_color
								})
							symbol_item.shape_type = "path"
							symbol_item.color = edge_col
				elif sname == "DOMSymbolInstance":
					for i in range(sym_xml.get_attribute_count()):
						if sym_xml.get_attribute_name(i) == "libraryItemName":
							cur_child_lib = sym_xml.get_attribute_value(i)
				elif sname == "Matrix":
					if cur_child_lib != "" and in_f0:
						var a = 1.0; var b = 0.0; var c = 0.0; var d = 1.0; var tx = 0.0; var ty = 0.0
						for i in range(sym_xml.get_attribute_count()):
							var aname = sym_xml.get_attribute_name(i)
							var aval = sym_xml.get_attribute_value(i).to_float()
							if aname == "a": a = aval
							elif aname == "b": b = aval
							elif aname == "c": c = aval
							elif aname == "d": d = aval
							elif aname == "tx": tx = aval
							elif aname == "ty": ty = aval
						var child_t = matrix_to_item_transform(a, b, c, d, tx, ty)
						var child_id = "sym_" + cur_child_lib.replace("/", "_").replace(" ", "_")
						child_instances.append({
							"symbol_id": child_id,
							"name": cur_child_lib.get_file(),
							"transform": child_t,
							"lib_name": cur_child_lib
						})
						cur_child_lib = ""
						
			if not child_instances.is_empty():
				symbol_item.shape_type = "symbol"
				if child_instances.size() > 1:
					var has_anim = false
					for ci in child_instances:
						if "anim" in ci.get("lib_name", ""):
							has_anim = true
							break
					if has_anim:
						child_instances = [child_instances[0]]
						
				symbol_item.nested_instances = child_instances
				for ci in child_instances:
					symbol_item.nested_item_ids.append(ci["symbol_id"])
				symbol_item.size = Vector2(160, 240)
				
			doc.symbols[sym_id] = symbol_item
			doc.items[sym_id] = symbol_item
			
	reader.close()
	if doc.layers.is_empty():
		var def_l = AnimationLayer.new()
		def_l.name = "Layer 1"
		doc.layers.append(def_l)
		
	return doc

# Ekspor ProjectDocument kembali ke format ZIP .FLA (XFL standar)
static func export_to_fla(doc: ProjectDocument, file_path: String) -> Error:
	var packer = ZIPPacker.new()
	var err = packer.open(file_path)
	if err != OK:
		return err
		
	# 1. Tulis DOMDocument.xml
	var dom_xml = _build_dom_document_xml(doc)
	packer.start_file("DOMDocument.xml")
	packer.write_file(dom_xml.to_utf8_buffer())
	packer.close_file()
	
	# 2. Tulis Symbols di folder LIBRARY/
	for item_id in doc.items:
		var item: StageItem = doc.items[item_id]
		var sym_xml = _build_symbol_xml(item)
		var sym_filename = "LIBRARY/%s.xml" % item.name.replace(" ", "_")
		packer.start_file(sym_filename)
		packer.write_file(sym_xml.to_utf8_buffer())
		packer.close_file()
		
	# 3. Tulis PublishSettings.xml standar
	var pub_xml = '<PublishSettings version="1.0">\n  <publishFormat>HTML5 Canvas</publishFormat>\n</PublishSettings>'
	packer.start_file("PublishSettings.xml")
	packer.write_file(pub_xml.to_utf8_buffer())
	packer.close_file()
	
	packer.close()
	return OK

static func _build_dom_document_xml(doc: ProjectDocument) -> String:
	var xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
	xml += '<DOMDocument xmlns="http://ns.adobe.com/xfl/2008/" width="%d" height="%d" frameRate="%d">\n' % [int(doc.stage_size.x), int(doc.stage_size.y), doc.fps]
	
	# Daftar symbols (XFL include references)
	xml += '  <symbols>\n'
	for item_id in doc.items:
		var itm: StageItem = doc.items[item_id]
		xml += '    <Include href="%s.xml"/>\n' % itm.name.replace(" ", "_")
	xml += '  </symbols>\n'
	
	xml += '  <timelines>\n    <DOMTimeline name="Scene 1">\n      <layers>\n'
	
	for layer in doc.layers:
		xml += '        <DOMLayer name="%s" isVisible="%s" isLocked="%s" layerType="%s">\n          <frames>\n' % [layer.name, "true" if layer.is_visible else "false", "true" if layer.is_locked else "false", layer.layer_type]
		for k_i in range(layer.keyframes.size()):
			var kf = layer.keyframes[k_i]
			var duration = 1
			if k_i + 1 < layer.keyframes.size():
				duration = layer.keyframes[k_i + 1].frame_index - kf.frame_index
			else:
				duration = doc.max_frames - kf.frame_index
			duration = maxi(1, duration)
			var tween_type = "motion" if (kf.tween_type == "classic" or kf.tween_to_next == "linear") else ("shape" if (kf.tween_type == "shape" or kf.tween_to_next == "shape") else "none")
			xml += '            <DOMFrame index="%d" duration="%d" tweenType="%s"' % [kf.frame_index, duration, tween_type]
			if kf.ease != 0.0:
				xml += ' acceleration="%d"' % int(kf.ease)
			if kf.label != "":
				xml += ' name="%s"' % kf.label
			xml += '>\n              <elements>\n'
			
			for item_id in kf.transforms:
				var t: ItemTransform = kf.transforms[item_id]
				var item: StageItem = doc.items.get(item_id, null)
				if item == null: continue
				var cos_r = cos(t.rotation)
				var sin_r = sin(t.rotation)
				var a = cos_r * t.scale.x
				var b = sin_r * t.scale.x
				var c = -sin_r * t.scale.y
				var d = cos_r * t.scale.y
				var tx = t.position.x + doc.stage_size.x * 0.5
				var ty = t.position.y + doc.stage_size.y * 0.5
				xml += '                <DOMSymbolInstance libraryItemName="%s">\n' % item.name.replace(" ", "_")
				xml += '                  <matrix>\n                    <Matrix a="%.4f" b="%.4f" c="%.4f" d="%.4f" tx="%.2f" ty="%.2f"/>\n                  </matrix>\n' % [a, b, c, d, tx, ty]
				if item.color_effect == "tint":
					xml += '                  <color>\n                    <Color tintColor="#%s" tintMultiplier="%.2f"/>\n                  </color>\n' % [item.tint_color.to_html(false), item.tint_ratio]
				elif item.color_effect == "alpha" or item.alpha < 1.0:
					xml += '                  <color>\n                    <Color alphaMultiplier="%.2f"/>\n                  </color>\n' % item.alpha
				xml += '                </DOMSymbolInstance>\n'
				
			xml += '              </elements>\n            </DOMFrame>\n'
		xml += '          </frames>\n        </DOMLayer>\n'
		
	xml += '      </layers>\n    </DOMTimeline>\n  </timelines>\n</DOMDocument>'
	return xml

static func _build_symbol_xml(item: StageItem) -> String:
	var xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
	xml += '<DOMSymbolItem xmlns="http://ns.adobe.com/xfl/2008/" name="%s" symbolType="%s">\n' % [item.name.replace(" ", "_"), item.symbol_type]
	xml += '  <timeline>\n    <DOMTimeline name="%s">\n      <layers>\n        <DOMLayer name="Layer 1">\n          <frames>\n            <DOMFrame index="0">\n              <elements>\n' % item.name.replace(" ", "_")
	
	var edge_str = ""
	if item.points.size() > 1:
		edge_str = "!%d %d" % [int(item.points[0].x * 20), int(item.points[0].y * 20)]
		for i in range(1, item.points.size()):
			if i - 1 < item.curve_controls.size():
				var cp = item.curve_controls[i - 1]
				edge_str += "[%d %d %d %d" % [int(cp.x * 20), int(cp.y * 20), int(item.points[i].x * 20), int(item.points[i].y * 20)]
			else:
				edge_str += "|%d %d" % [int(item.points[i].x * 20), int(item.points[i].y * 20)]
	else:
		var half_w = int(item.size.x * 0.5 * 20)
		var half_h = int(item.size.y * 0.5 * 20)
		edge_str = "!%d %d|%d %d|%d %d|%d %d|%d %d" % [-half_w, -half_h, half_w, -half_h, half_w, half_h, -half_w, half_h, -half_w, -half_h]
		
	xml += '                <DOMShape>\n                  <edges>\n                    <Edge edges="%s"/>\n                  </edges>\n                </DOMShape>\n' % edge_str
	xml += '              </elements>\n            </DOMFrame>\n          </frames>\n        </DOMLayer>\n      </layers>\n    </DOMTimeline>\n  </timeline>\n</DOMSymbolItem>'
	return xml
