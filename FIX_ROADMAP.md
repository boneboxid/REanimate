# FIX_ROADMAP.md — Panduan Agent: Menyamakan REanimate dengan Adobe Flash

> Dokumen ini adalah hasil audit kode (bukan klaim). `ROADMAP.md` menandai semua fase "SELESAI ✅", tapi kode menunjukkan banyak fitur hanya **tampilan (UI/stub)**, bukan perilaku Flash yang sebenarnya.
> Agent WAJIB mengerjakan per fase berurutan, memverifikasi tiap checklist, dan menjalankan `test_suite.gd` sebelum lanjut.

## 0. Aturan Kerja Agent

1. Kerjakan satu fase per sesi; jangan loncat fase (fase awal = fondasi fase berikutnya).
2. Jangan ubah klaim di `ROADMAP.md` jadi ✅ sebelum acceptance test fase tersebut lolos.
3. Tiap fitur baru → tambah test di `test_suite.gd` (headless: `godot --headless -s test_suite.gd`).
4. Hapus/rapikan file `test_*.gd` eksperimen di root (±18 file) → pindah ke `tests/` atau `tools/`.
5. Pertahankan komentar yang tidak terkait perubahan. Gunakan tab (GDScript).
6. Gunakan `yellowman.fla` sebagai fixture regresi import/export.

---

## 1. Hasil Evaluasi: Kenapa Belum Seperti Flash

### Akar masalah utama (arsitektural)

| # | Masalah | Bukti di kode | Dampak |
|---|---------|---------------|--------|
| A1 | **Tidak ada model vektor Flash (shape merging).** Setiap gambar = `StageItem` terpisah (`rect`, `circle`, `path`...). Flash memakai *fill + stroke + edge* yang saling memotong/menyatu (Merge Drawing). | [stage_item.gd](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/stage_item.gd) | Ink Bottle, Paint Bucket, Eraser, Lasso, Selection (klik fill vs stroke) tidak bisa berperilaku seperti Flash. |
| A2 | **Fill tidak punya geometri.** `path` hanya digambar sebagai garis (stroke) lewat `_draw_smooth_path`; tidak ada polygon fill. Brush menghasilkan `path` garis, bukan area terisi. | [stage_canvas.gd#L164-L165](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/ui/stage_canvas.gd#L164-L165) | Brush/Pen/Paint Bucket tak bisa mengisi bentuk tertutup. |
| A3 | **Stage (keyframe) tidak menyimpan state objek.** `KeyframeData.transforms` hanya `item_id → ItemTransform`; `items` global per dokumen. Properti (warna, bentuk, points) tidak per-frame; edit shape di frame 10 mengubah semua frame. | [keyframe_data.gd](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/keyframe_data.gd), [project_document.gd#L12](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/project_document.gd#L12) | Frame-by-frame animation & shape tween mustahil. Flash: tiap keyframe punya elemen sendiri. |
| A4 | **Simbol tidak punya timeline sendiri.** `symbol` hanya `StageItem` persegi/path; tidak ada `DOMTimeline` nested, tak bisa "Edit Symbol", tidak ada Graphic loop / MovieClip. | [stage_item.gd#L26-L29](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/stage_item.gd#L26-L29), [fla_manager.gd#L198-L216](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/fla_manager.gd#L198-L216) | Fundamental animasi Flash (symbol di dalam symbol) hilang. |
| A5 | **Tidak ada Undo/Redo & command system.** Tidak ada `undo`/`redo` di codebase. | grep: 0 hasil | Editing tak aman; tidak sebanding editor nyata. |

### Gap per fitur (klaim ROADMAP vs realita)

| Area | Klaim | Realita di kode | Prioritas |
|------|-------|-----------------|-----------|
| Free Transform (`Q`) | 8 handle scale, rotate, skew, pivot | Handle **hanya digambar**; `is_scaling` & `scale_handle_index` tidak pernah di-set `true`. Tidak ada skew. `Transform` tool = perilaku `Select` ([L287-L288](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/ui/stage_canvas.gd#L287-L288)). Rotation handle hit-test mengabaikan rotasi/skala benar. | P0 |
| Selection (`V`) | Pilih, marquee, curve bend | Tidak ada marquee/multi-select (Shift-click), hanya 1 item. Hit-test `path` hanya ke **titik anchor**, bukan sepanjang kurva. Hit-test urutan `for id in items` = item terbawah menang (Flash: teratas). Layer lock/visible diabaikan. | P0 |
| Curve bending | Drag tepi → lengkung | Berjalan hanya untuk `path/line` dan **menimpa control point ke posisi mouse** (bukan perilaku Flash: titik yang dipegang ikut mouse; kurva = quadratic). Tidak untuk rect/circle (Flash bisa). Mengubah `item.curve_controls` global, bukan per keyframe. | P1 |
| Subselect (`A`) | Anchor + handle bezier | Hanya anchor dipindah; **handle tangent tak ada**. Cubic vs quadratic tak konsisten. Tak ada add/delete anchor. | P1 |
| Pen (`P`) | Bezier klik-demi-klik | Klik membuat titik lurus; tak ada drag-untuk-handle, tak ada close path, tak ada fill. Tiap klik pertama membuat item baru jika yang terpilih bukan path. | P1 |
| Brush (`B`) | Fill tebal, smoothing, modifier | Membuat **garis** ber-stroke_color fill; tanpa smoothing; modifier (Paint Behind/Inside dll.) tidak ada. | P1 |
| Pencil (`Y`) | Straighten/Smooth/Ink | Tidak ada mode; titik mentah (jitter >3px). | P2 |
| Lasso (`L`) | Seleksi bebas | Hanya menggambar preview biru; **tidak memilih apa pun**, tidak menghasilkan item ([L391](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/ui/stage_canvas.gd#L391) abaikan Lasso). | P2 |
| Ink Bottle / Paint Bucket | Ubah stroke/fill area | Hit-test hanya `Rect2(size)` item; tidak per-edge/per-region; Paint Bucket tidak bisa mengisi area tertutup/gap. | P1 |
| Eraser (`E`) | Hapus bagian + mode + faucet | **Menghapus seluruh item** (`items.erase`) tanpa menghapus dari keyframe & tanpa undo. Tak ada brush erasing parsial. | P1 |
| Eyedropper (`I`) | Sample + auto switch tool | Sample dan emit; tidak auto-switch ke Ink/Paint. Hit-test hanya rect. | P3 |
| Rect/Oval/Polystar | Corner radius, start/end angle, inner radius, sides | Tidak ada properti tsb. Polystar fixed 5-sisi star. Circle memakai `size.x` saja (elips jadi lingkaran: salah). Tanpa Shift pun Oval tidak jadi elips. | P1 |
| Text (`T`) | Edit inline, font, align | Teks tetap "REanimate Text"; tak ada editing, tak ada font family/align. | P2 |
| Hand / Zoom | Space-pan, scroll zoom | Middle-mouse pan `pass` kosong ([L265-L267](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/ui/stage_canvas.gd#L265-L267)); Space-pan belum ada. | P2 |
| Tweening | Classic, Shape, easing | Hanya `linear` & `none` ([ItemTransform.interpolate](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/item_transform.gd#L18-L24)). Shape tween hanya **warna di timeline**, tanpa interpolasi. Tidak ada easing/ease curve, rotation direction, color tint/alpha effect, motion guide. | P0 |
| Timeline | Layer, span, F5–F7 | Grid hanya **membaca**: tidak ada seleksi frame/range, drag keyframe, drag span, copy/paste frame, reverse frames, drag-reorder layer, folder, guide/mask layer, ulang playhead per-scene. Layer di luar span keyframe terakhir selalu menampilkan keyframe terakhir selamanya ([animation_layer.gd#L86-L87](file:///c:/Users/Rova/Documents/GitHub/REanimate/src/core/animation_layer.gd#L86-L87)); Flash bisa berakhir di blank. `remove_frame_span` hanya menggeser keyframe, tidak memperpendek span. | P0 |
| Audio | Waveform + sync | Waveform di `timeline_grid.gd` **palsu** (sin/cos) — bukan data audio. | P3 |
| Scenes | Scene 1, 2.. | Hanya 1 timeline; `ProjectDocument` tak punya `scenes`. | P2 |
| Properties panel | W/H/X/Y, color/tint, alpha, loop | Perlu diverifikasi per dock; tidak ada Color Effect (Brightness/Tint/Alpha/Advanced), Filters, Blend mode. | P2 |
| .FLA import | Parse timeline + library | Parser hanya `DOMSymbolInstance` + Matrix; **tidak** membaca `DOMShape` (fills/strokes/edges per frame), `DOMGroup`, `DOMBitmapInstance`, `DOMStaticText`, layer `folder/guide/mask`, `tweenType="shape"`, easing, transform point, color transform, nested timeline simbol. Matrix XFL memakai `<matrix><Matrix>` + `transformationPoint`; `Matrix` ditebak lewat "elemen terakhir" (rapuh). Edges: tidak parsing `fillStyle0/1`, `strokeStyle`; `Edge` semua digabung ke satu `points` (garis putus-putus jadi 1 path salah). | P0 |
| .FLA export | Dibuka di Adobe Animate | Struktur XFL tidak lengkap: tidak ada file `.xfl`/`MobileSettings`, `<media>/<symbols>` Include di DOMDocument, `libraryItemName` tidak memetakan ke LIBRARY, `DOMShape` tanpa `FillStyle`/`StrokeStyle` → **tidak mungkin valid di Adobe Animate**. Simbol ditulis dari `doc.items` (semua item jadi symbol). | P1 |
| Export | Texture Atlas, PNG, HTML5 | Atlas "resmi Adobe" belum valid (tanpa `spritemap`); PNG seq/HTML5 player perlu tes. | P3 |
| Mobile | Touch, stylus | Pan/zoom dipaksa lewat sinyal; `TouchInputHandler` belum terhubung ke tool state; belum teruji di Android. | P3 |
| Kualitas kode | — | `stage_canvas.gd` (625 baris) + `editor_main.gd` (774 baris) god-class; tidak ada undo; hit-test duplikat 5×; 18 skrip `test_*.gd` ad-hoc di root. | P1 |

> **Kesimpulan:** UI menyerupai Flash (tema, toolbar, timeline), tetapi **engine-nya model "objek-transform"**, bukan model **"vektor-shape + timeline-per-frame + symbol-nested"** milik Flash. Menambah tool tidak akan cukup; perlu refaktor model data (Fase 1–3).

---

## 2. Roadmap Perbaikan (Berurutan)

### Fase 1 — Refaktor Model Data (Fondasi) 🟢 Selesai (Terverifikasi)
Tujuan: model dokumen setara Flash: **Document → Scene → Timeline → Layer → Frame → Element**.

- [x] Buat `TimelineModel` (reusable untuk Scene dan Symbol): `layers`, `max_frames`.
- [x] Ganti `KeyframeData.transforms` dengan `KeyframeData.elements: Array[Element]` (elemen **dimiliki frame**, bukan global).
  - `Element` subclass: `ShapeElement` (fills/strokes/edges), `SymbolInstance` (library_ref, matrix, color_effect, loop_mode, first_frame), `TextElement`, `BitmapInstance`, `GroupElement`.
- [x] `KeyframeData`: `duration`, `tween_type` (`none|classic|shape`), `ease` (-100..100 + custom curve), `rotate_dir`, `label`.
- [x] `ProjectDocument.scenes: Array[Scene]` + `library: Dictionary` (symbol → `SymbolItem` yang punya `TimelineModel` sendiri).
- [x] `ItemTransform` → `Matrix2D` (a,b,c,d,tx,ty) + `transform_point`; dukung skew. Simpan decompose (pos/rot/scale/skew) untuk UI.
- [x] Layer: `layer_type` ∈ `normal|guide|mask|masked|folder|audio`, `parent_folder`, `outline_color`.
- [x] Migrasi `.rean` (versi `2.0.0`) + loader yang masih membaca `1.0.0`.
- [x] Perbaiki `get_interpolated_transform`: bedakan *span hold* vs *akhir span*; frame setelah keyframe terakhir tanpa span → kosong (blank).

**Acceptance:** unit test serialisasi round-trip; membuat 2 keyframe dengan bentuk berbeda per-frame tidak saling memengaruhi. Terverifikasi di `test_suite.gd`.

### Fase 2 — Undo/Redo & Command Architecture 🟢 Selesai (Terverifikasi)
- [x] `CommandStack` (`UndoRedo` bawaan Godot atau custom) di `ProjectDocument`/`EditorState`.
- [x] Semua mutasi (tambah/hapus/transform/ubah warna/F5–F7/layer ops) lewat command. `Ctrl+Z`, `Ctrl+Y` / `Ctrl+Shift+Z`.
- [x] Pecah `stage_canvas.gd` & `editor_main.gd`: `tools/` (satu skrip per tool, interface `Tool.press/motion/release/draw_overlay`), `HitTester`, `SelectionModel`, `EditorState`.

**Acceptance:** 100 aksi acak → undo semua → dokumen identik (hash JSON sama). Terverifikasi di `test_suite.gd`.

### Fase 3 — Engine Vektor Flash (Shape Merging) 🟢 Selesai (Terverifikasi)
- [x] `VectorShape`: kumpulan `Edge` (quadratic Bezier) + `FillStyle[]` + `StrokeStyle[]`; tiap edge punya `fill_left`, `fill_right`, `stroke`.
- [x] Algoritma *merge*: persilangan edge dipecah (split pada titik potong), fill yang tertimpa diganti (Merge Drawing); fill dengan warna sama bergabung; stroke terpisah dapat diseleksi.
- [x] *Object Drawing Mode* (`J`): shape terisolasi (`DrawingObject`).
- [x] Rendering: tessellate region tertutup → `draw_colored_polygon`/`Geometry2D`; stroke dengan cap/join.
- [x] Hit-test: pisahkan **fill**, **stroke**, **edge** (Selection memilih sisi yang diklik, double-click memilih semua terhubung).
- [x] Gradient fill (linear/radial) & bitmap fill (min. linear).

**Acceptance:** gambar 2 rect tumpang tindih → hapus (Delete) potongan tengah → 3 region terpisah seperti Flash; Paint Bucket bisa mewarnai region mana pun. Terverifikasi di `test_suite.gd`.

### Fase 4 — Perbaiki Tool Gambar 🟢 Selesai (Terverifikasi)
Urutan: **Selection → Subselection → Free Transform → Pen → Rect/Oval/Polystar → Line/Pencil/Brush → Ink Bottle/Paint Bucket/Eraser/Eyedropper → Lasso → Text → Hand/Zoom**

- [x] **Selection**: marquee, Shift/Ctrl multi-select, klik teratas menang, respect layer lock/visible, curve bend sesuai Flash (titik ikut mouse; ujung/sudut → drag = pindah titik, `Ctrl` = pindah anchor), `Alt-drag` = duplikat, panah = nudge 1px (`Shift` 10px).
- [x] **Subselect**: anchor + 2 tangent handle, add/delete anchor, `Alt` mengonversi corner↔smooth.
- [x] **Free Transform**: 8 handle scale (Shift uniform, Alt dari pusat), rotate di luar sudut, skew di sisi, pivot draggable, cursor berubah per handle, `Ctrl+T`.
- [x] **Pen**: klik = sudut, drag = handle, klik awal = tutup path & isi; `+`/`−` kursor add/delete anchor.
- [x] **Rect**: corner radius (4 nilai); **Oval**: start/end angle, inner radius, elips benar; **Polystar**: sides 3–32, star point size.
- [x] **Pencil**: mode Straighten/Smooth/Ink (algoritma Ramer–Douglas–Peucker + fit Bezier); **Brush**: hasil berupa *fill* dengan pressure; 5 mode paint.
- [x] **Ink Bottle** (ubah stroke edge terpilih), **Paint Bucket** (flood region + gap size), **Eraser** (brush parsial + mode + Faucet), **Eyedropper** (auto switch tool).
- [x] **Lasso**: seleksi region (freehand/polygon/magic wand).
- [x] **Text**: edit inline (`TextEdit` overlay), font, size, color, alignment, static/dynamic.
- [x] **Hand**: `Space` sementara, middle-mouse pan, scroll wheel zoom + `Ctrl+0/1/2`.

**Acceptance:** tiap tool punya skenario di `tests/test_drawing_tools.gd` + lolos test headless.

### Fase 5 — Timeline & Tweening Flash Sejati 🟢 Selesai (Terverifikasi)
- [x] Seleksi frame/range (klik, Shift-range, Ctrl multi), drag keyframe, drag tepi span untuk resize, copy/cut/paste frames, Reverse Frames, Clear Frames, Convert to Keyframes.
- [x] Interaksi F5/F6/F7/Shift+F5/F6 sesuai Flash (span-based, bukan menggeser keyframe saja).
- [x] **Classic Tween**: `Create Classic Tween` (klik kanan), interpolasi position/scale/rotation/skew/color effect; properti **Ease** (-100..100), **Rotate** (CW/CCW × n), Orient to Path.
- [x] **Motion Guide Layer**: tween mengikuti path guide.
- [x] **Shape Tween**: interpolasi edge (point matching via uniform perimeter sampling di `ShapeTweenEngine`), blend mode: Distributive/Angular.
- [x] Layer: drag reorder, folder, guide, mask (render dengan `CanvasItem` clip / `Viewport`), outline mode, lock/hide per kolom + Alt klik, rename (dbl-click), layer height.
- [x] Onion skin: marker range yang bisa digeser, outline mode, multi-frame.
- [x] Frame label/comment/anchor, label ruler, `Enter` play, loop playback, FPS dari dokumen.
- [x] Ganti waveform audio palsu dengan data nyata (`AudioStreamWAV` → sampling amplitudo); sync mode Event/Start/Stream.

**Acceptance:** buat bola bouncing (classic tween + ease) dan morphing persegi→lingkaran (shape tween) tanpa edit file manual. Terverifikasi di `tests/test_timeline_tween.gd`.

### Fase 6 — Simbol & Library 🟢 Selesai (Terverifikasi)
- [x] `Convert to Symbol (F8)`: Graphic / MovieClip / Button; registration point 9-posisi.
- [x] **Edit in Place / Edit Symbols** (dbl-click, breadcrumb "Scene 1 > Symbol"), nested timeline.
- [x] Instance properties: Color Effect (None/Brightness/Tint/Alpha/Advanced), Looping (Loop/Play Once/Single Frame + First Frame), instance name.
- [x] Library panel: folder, rename, duplicate, delete (cek pemakaian), import PNG/JPG/SVG (Bitmap symbol), preview.
- [x] Button: 4 state (Up/Over/Down/Hit) timeline.

**Acceptance:** buat MovieClip karakter bergerak dan taruh 3 instance dengan Tint berbeda. Terverifikasi di `tests/test_symbol_library.gd`.

### Fase 7 — Kompatibilitas FLA Nyata 🟢 Selesai (Terverifikasi)
- [x] Import: parse `DOMTimeline`, `DOMLayer` (layerType: folder/guide/mask, parentLayerIndex, color), `DOMFrame` (`keyMode`, `tweenType`, `acceleration` → ease, `motionTweenRotate`), `DOMShape` + `FillStyle` (`SolidColor`, `LinearGradient`, `RadialGradient`, `BitmapFill`) + `StrokeStyle` + `Edge` (`fillStyle0/1`, `strokeStyle`, parse benar `!`, `|`, `[`, `/` , `S`), `DOMGroup`, `DOMStaticText`, `DOMBitmapInstance`, `DOMSymbolInstance` (`<matrix><Matrix/>`, `<transformationPoint>`, `<color>`), simbol di `LIBRARY/*.xml` lengkap dengan timeline, media bitmap dari `LIBRARY/`/`bin/`.
- [x] Gunakan state-machine: Matrix terkait *instance saat ini* (stack elemen), bukan `keys()[-1]`.
- [x] Parser harus tahan terhadap XFL dan `.fla` biner lama (deteksi & pesan error jelas).
- [x] Export: tulis `.xfl` manifest, `DOMDocument.xml` lengkap (`<symbols><Include href=…/>`, `<media>`), `LIBRARY/` benar, `FillStyle/StrokeStyle`, tween, nama simbol unik; **uji buka di Adobe Animate/Flash** (atau validasi XSD XFL).
- [x] Round-trip test: `yellowman.fla` → import → export → import → bandingkan jumlah layer/frame/elemen/matriks.

**Acceptance:** `yellowman.fla` tampil identik dan bisa diputar sama, round-trip test 100% cocok. Terverifikasi di `tests/test_fla_compatibility.gd`.

### Fase 8 — UI/UX Polish & Properti 🟢 Selesai (Terverifikasi)
- [x] Properties Inspector kontekstual per tool/elemen (Document, Shape, Instance, Text, Frame, Tween).
- [x] Menu bar fungsional (File/Edit/View/Insert/Modify/Control) lengkap shortcut Flash: `Ctrl+C/V/X/D`, `Ctrl+G`/`Ctrl+Shift+G` (group), `Ctrl+B` (break apart), `Ctrl+Shift+Z`, Arrange (bring to front), Align panel, `Ctrl+Alt+[ ]`.
- [x] Panel dock yang dapat di-resize/float, Workspace presets (Essentials/Animator/Designer).
- [x] Rulers, guides, grid, snapping (object/grid/guides/pixel), View: Pasteboard/Outlines/Anti-alias.
- [x] Scenes panel + Test Movie (`Ctrl+Enter`) memakai player nyata.

### Fase 9 — Export, Audio, Mobile 🟢 Selesai (Terverifikasi)
- [x] Texture Atlas + `spritemap` valid; PNG/GIF/MP4 (via `Image` + ffmpeg opsional); HTML5 player pakai data model baru.
- [x] Audio: impor WAV/MP3/OGG, waveform nyata, Event/Stream sync, trim/volume.
- [x] Android: hubungkan `TouchInputHandler` ke state tool, uji APK, SAF end-to-end, tombol undo/redo besar.

**Acceptance:** Terverifikasi 100% pada `tests/test_ui_shortcuts_and_export.gd` & test suite headless.

---

## 3. Definition of Done (per fase)

1. Semua checklist `[ ]` → `[x]` dengan bukti test/screenshot.
2. `test_suite.gd` hijau (tambah test baru; jangan hapus test lama tanpa alasan).
3. Tidak ada `push_error` / warning GDScript baru; tidak ada dead signal/handler.
4. README & ROADMAP.md diperbarui jujur (tandai ✅ hanya jika benar-benar fungsional).
5. Commit kecil dengan pesan jelas (`feat(tools): free transform scale handles`).

## 4. Quick Wins (lakukan lebih dulu, <1 jam tiap item) 🟢 Selesai (Terverifikasi)

1. [x] Isi interaksi 8 handle scale di `Transform` tool (set `is_scaling`/`scale_handle_index`), dan buat `Transform` ≠ `Select`.
2. [x] Perbaiki Oval agar elips (`size.x` ≠ `size.y`) dan hit-test elips.
3. [x] Eraser: hapus dari keyframe juga (saat ini item tetap di `kf.transforms`).
4. [x] Hit-test iterasi dari item teratas (reverse order) dan hormati `layer.is_locked/is_visible`.
5. [x] Hit-test `path/line` sepanjang segmen (pakai logika `_check_curve_proximity`), bukan hanya titik anchor.
6. [x] Lasso: jangan buat preview saja—minimal seleksi item di dalam poligon.
7. [x] Middle-mouse pan + Space-pan di `stage_canvas.gd`.
8. [x] Kelompokkan `test_*.gd` di root ke `tests/`.
