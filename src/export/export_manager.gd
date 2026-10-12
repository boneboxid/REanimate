# Modul untuk mengekspor animasi ke berbagai format (Texture Atlas, PNG Sequence, HTML5 Canvas Player, Animated Frame Bundle)
class_name ExportManager
extends RefCounted

# Ekspor project ke format Adobe Animate Texture Atlas compatible JSON
static func export_to_texture_atlas_json(doc: RefCounted, file_path: String) -> Error:
	var root_dict: Dictionary = {
		"AN": {
			"N": doc.name,
			"SN": "MainTimeline",
			"TL": {
				"L": []
			}
		},
		"SD": {
			"S": []
		},
		"MD": {
			"FRT": doc.fps,
			"STAGE_W": doc.stage_size.x,
			"STAGE_H": doc.stage_size.y
		}
	}
	
	var layers_json: Array = []
	for layer in doc.layers:
		var layer_data: Dictionary = {
			"LN": layer.name,
			"FR": []
		}
		
		# Tulis setiap keyframe span
		for i in range(layer.keyframes.size()):
			var kf = layer.keyframes[i]
			var duration = 1
			if i + 1 < layer.keyframes.size():
				duration = layer.keyframes[i + 1].frame_index - kf.frame_index
			else:
				duration = doc.max_frames - kf.frame_index
			duration = max(1, duration)
			
			var elements: Array = []
			for item_id in kf.transforms:
				var t: ItemTransform = kf.transforms[item_id]
				var item: StageItem = doc.items.get(item_id, null)
				if item == null: continue
				
				# Convert Transform2D ke format Matrix 3D (16 float)
				var cos_r = cos(t.rotation)
				var sin_r = sin(t.rotation)
				var a = cos_r * t.scale.x
				var b = sin_r * t.scale.x
				var c = -sin_r * t.scale.y
				var d = cos_r * t.scale.y
				
				var m3d = [
					a, b, 0.0, 0.0,
					c, d, 0.0, 0.0,
					0.0, 0.0, 1.0, 0.0,
					t.position.x, t.position.y, 0.0, 1.0
				]
				
				elements.append({
					"SI": {
						"SN": item.name,
						"IN": item.id,
						"ST": "G",
						"M3D": m3d,
						"ALPHA": t.opacity
					}
				})
				
			layer_data["FR"].append({
				"I": kf.frame_index,
				"DU": duration,
				"E": elements
			})
			
		layers_json.append(layer_data)
		
	root_dict["AN"]["TL"]["L"] = layers_json
	
	# Simpan ke file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(root_dict, "\t"))
	file.close()
	return OK

# Ekspor frame sequence ke kumpulan gambar PNG dalam satu folder
static func export_png_sequence(viewport: SubViewport, doc: ProjectDocument, out_dir: String, callback_update_frame: Callable) -> int:
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)
		
	var exported_count = 0
	for frame in range(doc.max_frames):
		callback_update_frame.call(frame)
		if DisplayServer.get_name() == "headless":
			await (Engine.get_main_loop() as SceneTree).process_frame
		else:
			await RenderingServer.frame_post_draw
		
		if DisplayServer.get_name() == "headless":
			continue
		var tex = viewport.get_texture()
		var img: Image = tex.get_image() if tex != null else null
		if img != null and not img.is_empty():
			var filename = "%s/frame_%04d.png" % [out_dir, frame]
			if img.save_png(filename) == OK:
				exported_count += 1
			
	return exported_count

# Ekspor HTML5 Canvas Web Player mandiri (Dapat dibuka di browser apa pun tanpa install software)
static func export_html5_player(doc: ProjectDocument, file_path: String) -> Error:
	var html = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>%s - REanimate Web Player</title>
    <style>
        body { margin: 0; background: #262626; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; font-family: sans-serif; color: #eee; }
        canvas { background: #fff; box-shadow: 0 4px 16px rgba(0,0,0,0.5); }
        .controls { margin-top: 12px; display: flex; gap: 8px; align-items: center; }
        button { background: #444; color: #fff; border: 1px solid #666; padding: 6px 12px; cursor: pointer; border-radius: 4px; }
        button:hover { background: #555; }
    </style>
</head>
<body>
    <canvas id="stage" width="%d" height="%d"></canvas>
    <div class="controls">
        <button id="btnPlay">Pause</button>
        <button id="btnLoop">Loop: On</button>
        <span id="txtInfo">Frame: 1 / %d</span>
    </div>
    <script>
        const doc = %s;
        const canvas = document.getElementById('stage');
        const ctx = canvas.getContext('2d');
        let currentFrame = 0;
        let isPlaying = true;
        let isLooping = true;
        
        function drawFrame(frame) {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.save();
            ctx.translate(canvas.width / 2, canvas.height / 2);
            // Render layers
            doc.layers.forEach(layer => {
                if (!layer.is_visible) return;
                // Interpolate keyframes
                for (let k = 0; k < layer.keyframes.length; k++) {
                    const kf = layer.keyframes[k];
                    if (kf.frame_index === frame) {
                        for (let id in kf.transforms) {
                            const t = kf.transforms[id];
                            const item = doc.items[id];
                            if (!item) continue;
                            ctx.save();
                            ctx.translate(t.position[0], t.position[1]);
                            ctx.rotate(t.rotation);
                            ctx.scale(t.scale[0], t.scale[1]);
                            ctx.globalAlpha = t.opacity;
                            ctx.fillStyle = `rgba(${Math.round(item.color[0]*255)}, ${Math.round(item.color[1]*255)}, ${Math.round(item.color[2]*255)}, ${item.color[3]})`;
                            if (item.shape_type === 'circle') {
                                ctx.beginPath();
                                ctx.arc(0, 0, item.size[0]/2, 0, Math.PI*2);
                                ctx.fill();
                            } else {
                                ctx.fillRect(-item.size[0]/2, -item.size[1]/2, item.size[0], item.size[1]);
                            }
                            ctx.restore();
                        }
                    }
                }
            });
            ctx.restore();
            document.getElementById('txtInfo').innerText = `Frame: ${frame + 1} / ${doc.max_frames}`;
        }
        
        let lastTime = performance.now();
        const frameInterval = 1000 / doc.fps;
        function loop(now) {
            if (isPlaying && now - lastTime >= frameInterval) {
                lastTime = now;
                currentFrame++;
                if (currentFrame >= doc.max_frames) {
                    if (isLooping) currentFrame = 0;
                    else isPlaying = false;
                }
                drawFrame(currentFrame);
            }
            requestAnimationFrame(loop);
        }
        
        document.getElementById('btnPlay').onclick = () => {
            isPlaying = !isPlaying;
            document.getElementById('btnPlay').innerText = isPlaying ? 'Pause' : 'Play';
        };
        document.getElementById('btnLoop').onclick = () => {
            isLooping = !isLooping;
            document.getElementById('btnLoop').innerText = `Loop: ${isLooping ? 'On' : 'Off'}`;
        };
        drawFrame(0);
        requestAnimationFrame(loop);
    </script>
</body>
</html>
""" % [doc.name, int(doc.stage_size.x), int(doc.stage_size.y), doc.max_frames, JSON.stringify(doc.to_dict())]

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(html)
	file.close()
	return OK
