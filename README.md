# ⚡ REanimate - 2D Animation Authoring Suite

Kloning core animasi **Adobe Flash** yang dibangun di atas **Godot 4.7 Engine**, dirancang untuk performa tinggi, workflow cepat, dan multiplatform (**Windows & Android**).

---

## 🚀 Fitur yang Tersedia (Production Ready)

### 1. Interactive Stage & Drawing Tools
- **Select Tool (`V`)**: Seleksi objek di Stage dengan bounding box interaktif dan titik pivot.
- **Transform Tool**: Pindahkan posisi (drag) dan putar sudut rotasi objek via pegangan lingkaran hijau di atas objek.
- **Freehand Brush Tool (`B`)**: Menggambar bebas di Stage secara realtime, otomatis dinormalisasi menjadi path objek.
- **Rectangle Tool (`R`) & Circle/Oval Tool (`O`)**: Drag-and-drop untuk menggambar bentuk geometris baru langsung ke Stage.
- **Navigasi Stage**:
  - **Zoom**: Scroll Wheel Mouse (Zoom In/Out dari 0.2x hingga 8.0x).
  - **Pan Canvas**: Klik & drag tombol tengah mouse (Middle Mouse Button).

### 2. Timeline & Motion Tweening Engine
- **Flash-Style Timeline Grid**: Menampilkan nomor frame, garis pembagi, row tiap layer, dan **Playhead Merah**.
- **Keyframe Dots & Tween Spans**: Indikator titik hitam/putih untuk keyframe dan blok biru/panah untuk interpolasi gerakan otomatis (*Motion Tween*).
- **Shortcut & Controls**:
  - `Space`: Play / Pause playback realtime (30 / 60 FPS).
  - `F6`: Insert Keyframe baru di posisi frame aktif.
  - `F7`: Hapus Keyframe di posisi frame aktif.
  - `Delete / Backspace`: Hapus objek yang sedang dipilih.
  - **Loop Toggle (`🔁`)**: Mengulang animasi otomatis atau stop di akhir.
  - **Onion Skinning**: Menampilkan bayangan transparan (ghost) dari 2 frame sebelum dan 2 frame sesudah frame aktif.

### 3. Multi-Layer Management
- Tambah layer baru (`+ Layer`) dan hapus layer (`- Del`).
- Multi-layer compositing: Objek pada masing-masing layer dihitung dan di-tweening secara independen.

### 4. Properties Inspector (Panel Kanan)
- Mengedit nama objek secara langsung.
- Input numerik presisi untuk:
  - Posisi **X** & **Y**.
  - **Rotation (°)** dalam derajat sudut.
  - **Scale X** & **Scale Y**.
  - **Opacity / Alpha** (0.0 – 1.0).
  - **Fill Color Picker**: Memilih warna solid objek.

### 5. Project & Export Pipeline
- **New Project**: Mereset kanvas ke template default.
- **Save Project (`.rean`)**: Menyimpan seluruh konfigurasi objek, layer, keyframe, dan timeline ke file JSON `.rean`.
- **Open Project**: Membuka kembali file `.rean`.
- **Export Atlas JSON**: Mengekspor hierarki timeline dan matriks transformasi 3D affine (`M3D`) ke format standar yang kompatibel dengan **Adobe Animate Texture Atlas**.
- **Export PNG Sequence**: Merender setiap frame animasi satu per satu ke folder target menjadi file gambar (`frame_0000.png`, `frame_0001.png`, dst).

---

## 📂 Struktur Kode Sumber

```
REanimate/
├── project.godot                     # Konfigurasi Godot 4.7 (GL Compatibility)
├── test_suite.gd                     # Automated test engine
└── src/
    ├── core/
    │   ├── stage_item.gd             # Model data elemen objek (Rect, Circle, Path, Sprite)
    │   ├── item_transform.gd         # Model transformasi (Pos, Rot, Scale, Alpha) + Tween Lerp
    │   ├── keyframe_data.gd          # Model keyframe dan map transformasi objek
    │   ├── animation_layer.gd        # Model layer dengan interpolasi multi-keyframe
    │   └── project_document.gd       # Root model dokumen proyek + Save/Load JSON (.rean)
    ├── export/
    │   └── export_manager.gd         # Exporter Texture Atlas JSON & PNG Sequence
    └── ui/
        ├── stage_canvas.gd           # Canvas render stage, hit-testing, handles, brush
        ├── timeline_grid.gd          # Visual timeline ruler, scrubber, dots, tween arrows
        ├── editor_main.gd            # Controller utama editor & event wiring
        └── editor_main.tscn          # Layout UI utama
```

---

## 🧪 Verifikasi Engine
Automated test suite (`test_suite.gd`) mencakup:
1. `ProjectDocument.create_default()`
2. `Multi-layer support`
3. `Project Save (.rean) and Load`
4. `Texture Atlas JSON Export`
5. `Interpolated Tweening calculations`

Hasil eksekusi: **All 5/5 Engine Tests Passed Successfully!**
