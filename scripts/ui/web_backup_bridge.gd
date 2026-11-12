class_name WebBackupBridge
extends Node
## Browser file access is explicit: downloaded encrypted bytes and a user-picked
## upload. The same authenticated SaveManager format is used on every platform.

signal feedback(message: String)
signal download_ready(bytes: PackedByteArray)
signal backup_selected(path: String, password: String)

const EXPORT_PATH := "user://browser-export.mqbackup"
const IMPORT_PATH := "user://browser-import.mqbackup"
const MAX_BYTES := 2097152
const PICKER_SCRIPT := """
window.momentumQuestFiles = {
    pick: function(callback) {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.mqbackup,application/octet-stream';
        input.style.display = 'none';
        let completed = false;
        const finish = (status, data) => {
            if (completed) return;
            completed = true;
            input.remove();
            callback(status, data);
        };
        input.addEventListener('cancel', () => finish('cancel', null));
        input.addEventListener('change', () => {
            const file = input.files && input.files[0];
            if (!file) { finish('cancel', null); return; }
            if (file.size > 2097152) { finish('error', 'The backup file is too large.'); return; }
            const reader = new FileReader();
            reader.onerror = () => finish('error', 'The selected file could not be read.');
            reader.onload = () => finish('ok', new Uint8Array(reader.result));
            reader.readAsArrayBuffer(file);
        });
        document.body.appendChild(input);
        input.click();
    }
};
"""

var _upload_callback: JavaScriptObject
var _upload_password := ""
var _upload_pending := false

func request_export(password: String) -> void:
	if not OS.has_feature("web"):
		feedback.emit("Browser downloads are only available in the Web build.")
		return
	var manager := get_node_or_null("/root/SaveManager")
	if manager == null:
		feedback.emit("Progress is not available yet.")
		return
	var error: String = manager.export_backup(EXPORT_PATH, password)
	if not error.is_empty():
		feedback.emit(error)
		return
	var file := FileAccess.open(EXPORT_PATH, FileAccess.READ)
	if file == null:
		feedback.emit("The encrypted backup could not be prepared.")
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()
	DirAccess.remove_absolute(EXPORT_PATH)
	# A second explicit Download click keeps the browser's user activation fresh
	# even if deriving the encryption key took longer than its activation window.
	download_ready.emit(bytes)

func download(bytes: PackedByteArray) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, "doodledrift.mqbackup", "application/octet-stream")
		feedback.emit("Backup sent to your browser's downloads.")

func request_import(password: String) -> void:
	if not OS.has_feature("web"):
		feedback.emit("Browser uploads are only available in the Web build.")
		return
	# A previous picker may have been dismissed by older browsers without a
	# cancel event; opening another picker safely replaces its pending callback.
	_upload_password = password
	_upload_pending = true
	_upload_callback = JavaScriptBridge.create_callback(_on_file_received)
	JavaScriptBridge.eval(PICKER_SCRIPT, true)
	var picker := JavaScriptBridge.get_interface("momentumQuestFiles")
	picker.pick(_upload_callback)

func _on_file_received(arguments: Array) -> void:
	if not _upload_pending:
		return
	_upload_pending = false
	var password := _upload_password
	_upload_password = ""
	if arguments.is_empty() or str(arguments[0]) == "cancel":
		return
	if str(arguments[0]) != "ok":
		feedback.emit(str(arguments[1]) if arguments.size() > 1 else "The selected file could not be read.")
		return
	if arguments.size() < 2 or not arguments[1] is JavaScriptObject or not JavaScriptBridge.is_js_buffer(arguments[1]):
		feedback.emit("The browser returned an unreadable file.")
		return
	var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(arguments[1])
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		feedback.emit("The backup is empty or too large.")
		return
	var file := FileAccess.open(IMPORT_PATH, FileAccess.WRITE)
	if file == null:
		feedback.emit("The selected backup could not be opened for import.")
		return
	file.store_buffer(bytes)
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK:
		feedback.emit("The selected backup could not be read completely.")
		return
	backup_selected.emit(IMPORT_PATH, password)

func cleanup_import() -> void:
	if FileAccess.file_exists(IMPORT_PATH):
		DirAccess.remove_absolute(IMPORT_PATH)

func _exit_tree() -> void:
	_upload_password = ""
	cleanup_import()
