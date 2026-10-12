# ⚡ REanimate - 2D Animation Authoring Suite

An **Adobe Flash** core animation clone built on the **Godot 4.7 Engine**, designed for high performance, fast workflow, and multiplatform (**Windows & Android**).

---

## 🚀 Available Features (Production Ready)

### 1. Interactive Stage & Drawing Tools
- **Select Tool (`V`)**: Select objects on the Stage with an interactive bounding box and pivot point.
- **Transform Tool**: Move (drag) and rotate the object via the green circle handle above the object.
- **Freehand Brush Tool (`B`)**: Draw freely on the Stage in realtime, automatically normalized into object paths.
- **Rectangle Tool (`R`) & Circle/Oval Tool (`O`)**: Drag-and-drop to draw new geometric shapes directly onto the Stage.
- **Stage Navigation**:
  - **Zoom**: Mouse Scroll Wheel (Zoom In/Out from 0.2x to 8.0x).
  - **Pan Canvas**: Click & drag Middle Mouse Button.

### 2. Timeline & Motion Tweening Engine
- **Flash-Style Timeline Grid**: Displays frame numbers, divider lines, rows for each layer, and a **Red Playhead**.
- **Keyframe Dots & Tween Spans**: Black/white dot indicators for keyframes and blue blocks/arrows for automatic motion interpolation (*Motion Tween*).
- **Shortcut & Controls**:
  - `Space`: Play / Pause realtime playback (30 / 60 FPS).
  - `F6`: Insert a new Keyframe at the active frame position.
  - `F7`: Delete the Keyframe at the active frame position.
  - `Delete / Backspace`: Delete the currently selected object.
  - **Loop Toggle (`🔁`)**: Automatically loop animation or stop at the end.
  - **Onion Skinning**: Displays transparent shadows (ghosts) of 2 frames before and 2 frames after the active frame.

### 3. Multi-Layer Management
- Add a new layer (`+ Layer`) and delete a layer (`- Del`).
- Multi-layer compositing: Objects on each layer are calculated and tweened independently.

### 4. Properties Inspector (Right Panel)
- Edit object names directly.
- Precise numerical inputs for:
  - **X** & **Y** Position.
  - **Rotation (°)** in degrees.
  - **Scale X** & **Scale Y**.
  - **Opacity / Alpha** (0.0 – 1.0).
  - **Fill Color Picker**: Choose solid colors for objects.

### 5. Project & Export Pipeline
- **New Project**: Resets the canvas to the default template.
- **Save Project (`.rean`)**: Saves the entire configuration of objects, layers, keyframes, and timeline to a JSON `.rean` file.
- **Open Project**: Reopens a `.rean` file.
- **Export Atlas JSON**: Exports the timeline hierarchy and 3D affine transformation matrices (`M3D`) to a standard format compatible with **Adobe Animate Texture Atlas**.
- **Export PNG Sequence**: Renders each animation frame individually to a target folder as image files (`frame_0000.png`, `frame_0001.png`, etc.).

---

## 📂 Source Code Structure

```
REanimate/
├── project.godot                     # Godot 4.7 Configuration (GL Compatibility)
├── test_suite.gd                     # Automated test engine
└── src/
    ├── core/
    │   ├── stage_item.gd             # Object element data model (Rect, Circle, Path, Sprite)
    │   ├── item_transform.gd         # Transformation model (Pos, Rot, Scale, Alpha) + Tween Lerp
    │   ├── keyframe_data.gd          # Keyframe model and object transformation map
    │   ├── animation_layer.gd        # Layer model with multi-keyframe interpolation
    │   └── project_document.gd       # Root project document model + Save/Load JSON (.rean)
    ├── export/
    │   └── export_manager.gd         # Texture Atlas JSON & PNG Sequence Exporter
    └── ui/
        ├── stage_canvas.gd           # Canvas render stage, hit-testing, handles, brush
        ├── timeline_grid.gd          # Visual timeline ruler, scrubber, dots, tween arrows
        ├── editor_main.gd            # Main editor controller & event wiring
        └── editor_main.tscn          # Main UI layout
```

---

## 🧪 Engine Verification
Automated test suite (`test_suite.gd`) includes:
1. `ProjectDocument.create_default()`
2. `Multi-layer support`
3. `Project Save (.rean) and Load`
4. `Texture Atlas JSON Export`
5. `Interpolated Tweening calculations`

Execution result: **All 5/5 Engine Tests Passed Successfully!**
