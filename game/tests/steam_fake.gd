extends RefCounted
## Faux singleton GodotSteam pour les tests (aucun Steam, aucun réseau) : mêmes noms et signatures que les méthodes
## utilisées par SteamServices / SteamCloudSync (GodotSteam 4.2x). Enregistre chaque appel dans `calls`.

signal current_stats_received(game: int, result: int, user: int)

var init_status := 0 ## 0 = k_ESteamAPIInitResult_OK ; 2 = NoSteamClient
var set_ok := true ## réponse de setAchievement
var cloud_account := true
var cloud_app := true
var files := {} ## nom -> PackedByteArray
var timestamps := {} ## nom -> horodatage Unix
var calls: Array = [] ## [méthode, args...]
var achieved: Array = [] ## API names acceptés


func count(method: String) -> int:
	var n := 0
	for c in calls:
		if c[0] == method:
			n += 1
	return n


func steamInitEx(app_id: int = 0, embed_callbacks: bool = false) -> Dictionary:
	calls.append(["steamInitEx", app_id, embed_callbacks])
	return {"status": init_status, "verbal": "" if init_status == 0 else "Steam fermé (faux)"}


func steamShutdown() -> void:
	calls.append(["steamShutdown"])


func setAchievement(achievement_name: String) -> bool:
	calls.append(["setAchievement", achievement_name])
	if set_ok and not achieved.has(achievement_name):
		achieved.append(achievement_name)
	return set_ok


func storeStats() -> bool:
	calls.append(["storeStats"])
	return true


func isCloudEnabledForAccount() -> bool:
	return cloud_account


func isCloudEnabledForApp() -> bool:
	return cloud_app


func fileExists(file: String) -> bool:
	return files.has(file)


func getFileSize(file: String) -> int:
	return (files[file] as PackedByteArray).size() if files.has(file) else 0


func getFileTimestamp(file: String) -> int:
	return int(timestamps.get(file, 0))


func fileRead(file: String, data_to_read: int) -> Dictionary:
	if not files.has(file):
		return {"ret": 0, "buf": PackedByteArray()}
	var b: PackedByteArray = files[file]
	var n := mini(data_to_read, b.size())
	return {"ret": n, "buf": b.slice(0, n)}


func fileWrite(file: String, data: PackedByteArray, size: int = 0) -> bool:
	calls.append(["fileWrite", file])
	files[file] = data.slice(0, size if size > 0 else data.size())
	timestamps[file] = int(Time.get_unix_time_from_system())
	return true


func put(file: String, text: String, ts: int) -> void:
	files[file] = text.to_utf8_buffer()
	timestamps[file] = ts


func text_of(file: String) -> String:
	return (files[file] as PackedByteArray).get_string_from_utf8() if files.has(file) else ""
