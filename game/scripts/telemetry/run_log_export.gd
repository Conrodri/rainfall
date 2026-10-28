class_name RunLogExport
extends RefCounted
## Export VOLONTAIRE des journaux de run (bouton « Exporter les journaux » des Réglages, onglet Jeu).
## Regroupe les journaux de RunLog dans une archive unique `rainfall_journaux_<date>.zip` (un .json par run + un
## LISEZMOI.txt). Rien n'est envoyé : le fichier est écrit sur l'appareil, puis
##   - PC (Windows) : le dossier est ouvert dans l'explorateur (OS.shell_show_in_file_manager) ;
##   - Android : feuille de partage du système (Intent ACTION_SEND via JavaClassWrapper + FileProvider du gabarit
##     Godot, aucune permission Internet) ; à défaut, copie dans Documents/Rainfall ; à défaut, user://exports ;
##   - iOS : user://exports (dossier Documents de l'app, visible dans l'app Fichiers si l'option d'export
##     « Accessible depuis l'app Fichiers » est cochée).
## Le testeur choisit ensuite lui-même de transmettre le fichier (courriel, messagerie, clé USB…).

const EXPORT_SUBDIR := "exports"
const README := "Journaux de run de Rainfall (un fichier .json par partie, schéma %d).\nIls restent sur ton appareil : rien n'est envoyé automatiquement. Si tu veux aider l'équilibrage, transmets ce fichier .zip à l'équipe.\nAnalyse : python tools/analyse_runs.py <dossier ou .zip>\n"


## Crée l'archive. Retourne {ok, path (user:// ou absolu), abs_path, count, error}.
static func build_archive(log_dir: String = RunLog.DIR, out_dir: String = "") -> Dictionary:
	var files := PackedStringArray()
	if DirAccess.dir_exists_absolute(log_dir):
		for f in DirAccess.get_files_at(log_dir):
			if f.begins_with("run_") and f.ends_with(".json"):
				files.append(f)
	files.sort()
	if files.is_empty():
		return {"ok": false, "count": 0, "error": "Aucune partie enregistrée pour l'instant."}
	if out_dir == "":
		out_dir = "user://".path_join(EXPORT_SUBDIR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	var path := out_dir.path_join("rainfall_journaux_%s.zip" % stamp)
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return {"ok": false, "count": 0, "error": "Impossible de créer le fichier d'export."}
	zip.start_file("LISEZMOI.txt")
	zip.write_file((README % RunLog.SCHEMA).to_utf8_buffer())
	zip.close_file()
	for f in files:
		zip.start_file(f)
		zip.write_file(FileAccess.get_file_as_bytes(log_dir.path_join(f)))
		zip.close_file()
	zip.close()
	return {"ok": true, "path": path, "abs_path": ProjectSettings.globalize_path(path), "count": files.size(), "error": ""}


## Exporte puis présente le fichier selon la plateforme. Retourne le résultat de build_archive complété de
## `shown` (dossier ouvert / partage lancé) et `where` (texte français pour le joueur).
static func export_and_show(log_dir: String = RunLog.DIR, out_dir: String = "") -> Dictionary:
	var res := build_archive(log_dir, out_dir)
	if not res["ok"]:
		res["where"] = res["error"]
		return res
	var abs_path: String = res["abs_path"]
	res["shown"] = false
	match OS.get_name():
		"Android":
			if _android_share(abs_path):
				res["shown"] = true
				res["where"] = "Choisis où envoyer le fichier dans la fenêtre de partage."
			else:
				var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
				var copied := ""
				if docs != "":
					var dst := docs.path_join("Rainfall")
					DirAccess.make_dir_recursive_absolute(dst)
					dst = dst.path_join(abs_path.get_file())
					if DirAccess.copy_absolute(abs_path, dst) == OK:
						copied = dst
				if copied != "":
					res["abs_path"] = copied
					res["where"] = "Fichier copié dans Documents/Rainfall :\n%s" % breakable(copied)
				else:
					res["where"] = "Fichier créé :\n%s" % breakable(abs_path)
		"iOS":
			res["where"] = "Fichier créé dans l'app Fichiers, dossier Rainfall :\n%s" % breakable(abs_path.get_file())
		_:
			if not DisplayServer.get_name() == "headless":
				res["shown"] = OS.shell_show_in_file_manager(abs_path, true) == OK
			res["where"] = "Fichier créé :\n%s" % breakable(abs_path)
	return res


## Chemin coupable en fin de ligne (espace insécable de largeur nulle après chaque « / ») pour les dialogues.
static func breakable(path: String) -> String:
	return path.replace("/", "/​").replace("\\", "\\​")


## Feuille de partage Android (ACTION_SEND, application/zip) via JavaClassWrapper et le FileProvider du gabarit
## Godot (`<paquet>.fileprovider`). Faux si une étape manque (l'appelant copie alors le fichier dans Documents).
## Non testable sur PC : chaque appel est vérifié, aucune exception ne remonte en GDScript.
static func _android_share(abs_path: String) -> bool:
	if not Engine.has_singleton(&"AndroidRuntime") or not ClassDB.class_exists(&"JavaClassWrapper"):
		return false
	var runtime: Object = Engine.get_singleton(&"AndroidRuntime")
	var activity: Variant = runtime.call(&"getActivity") if runtime != null and runtime.has_method(&"getActivity") else null
	if activity == null:
		return false
	var jcw: Object = Engine.get_singleton(&"JavaClassWrapper")
	if jcw == null:
		return false
	var file_cls: Variant = jcw.call(&"wrap", "java.io.File")
	var provider_cls: Variant = jcw.call(&"wrap", "androidx.core.content.FileProvider")
	var intent_cls: Variant = jcw.call(&"wrap", "android.content.Intent")
	if file_cls == null or provider_cls == null or intent_cls == null:
		return false
	var jfile: Variant = file_cls.call(&"File", abs_path) # constructeur : méthode au nom de la classe
	var pkg: Variant = activity.call(&"getPackageName")
	if jfile == null or pkg == null:
		return false
	var uri: Variant = provider_cls.call(&"getUriForFile", activity, "%s.fileprovider" % str(pkg), jfile)
	var intent: Variant = intent_cls.call(&"Intent", "android.intent.action.SEND")
	if uri == null or intent == null:
		return false
	intent.call(&"setType", "application/zip")
	intent.call(&"putExtra", "android.intent.extra.STREAM", uri)
	intent.call(&"addFlags", 1) # FLAG_GRANT_READ_URI_PERMISSION
	var chooser: Variant = intent_cls.call(&"createChooser", intent, "Exporter les journaux de Rainfall")
	if chooser == null:
		return false
	activity.call(&"startActivity", chooser)
	return true
