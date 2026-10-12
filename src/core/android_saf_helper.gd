# Helper utilitas untuk integrasi Android Storage Access Framework (SAF)
class_name AndroidSAFHelper
extends RefCounted

# Meminta perizinan storage pada runtime Android jika diperlukan
static func request_storage_permissions() -> bool:
	if OS.get_name() == "Android":
		return OS.request_permissions()
	return true

# Dapatkan direktori penyimpanan publik yang aman untuk ekspor/simpan dokumen
static func get_export_storage_dir() -> String:
	if OS.get_name() == "Android":
		var docs_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if docs_dir != "" and DirAccess.dir_exists_absolute(docs_dir):
			return docs_dir
		return OS.get_user_data_dir()
	return "user://"

# Mengonversi nama file dan ekstensi menjadi MIME type standar
static func get_mime_type_for_extension(ext: String) -> String:
	match ext.to_lower():
		"rean":
			return "application/json"
		"fla":
			return "application/zip"
		"json":
			return "application/json"
		"png":
			return "image/png"
		"jpg", "jpeg":
			return "image/jpeg"
		"mp4":
			return "video/mp4"
		"gif":
			return "image/gif"
		_:
			return "application/octet-stream"

# Validasi apakah path dapat ditulis
static func is_path_writable(target_path: String) -> bool:
	var dir_path = target_path.get_base_dir()
	return DirAccess.dir_exists_absolute(dir_path)
