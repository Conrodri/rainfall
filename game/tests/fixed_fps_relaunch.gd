extends RefCounted
## Relance d'un test « temps de jeu simulé » en `--fixed-fps 60`.
##
## Certains tests avancent des minutes de jeu image par image (boss_obstacle_test : 64 essais de 20 s ; balance_sim_fullrun :
## une run complète). Lancés sans `--fixed-fps`, Godot cadence la physique sur le temps réel (60 pas par seconde réelle) :
## 20 minutes de jeu prennent 20 minutes, et une suite de tests qui ne passe pas l'option tombe sur son délai sans
## « RESULT ». Avec `--fixed-fps 60`, chaque image vaut 1/60 s de jeu, sans attente.
##
## Usage, en tête du test : `if await FixedFpsRelaunch.relaunch_if_needed(get_tree(), "res://tests/<test>.tscn"): return`
## Godot retire `--fixed-fps` de OS.get_cmdline_args() : on détecte donc le mode au chronomètre (PROBE_FRAMES images
## physiques en moins de PROBE_MAX_MS = pas d'attente réelle, déjà en --fixed-fps). Sinon, relance le même test dans un
## processus fils en `--fixed-fps` (mêmes options utilisateur après `--`), recopie sa sortie et quitte avec son code de
## retour. Le fils porte CHILD_ENV et ne se relance jamais (aucune récursion possible, même si la mesure se trompe).

const CHILD_ENV := "RAINFALL_FIXED_FPS_CHILD"
const PROBE_FRAMES := 30 ## en temps réel : 500 ms ; en --fixed-fps : quelques ms
const PROBE_MAX_MS := 300


static func relaunch_if_needed(tree: SceneTree, scene: String, fps: int = 60) -> bool:
	if OS.get_environment(CHILD_ENV) == "1":
		return false
	var t0 := Time.get_ticks_msec()
	for i in PROBE_FRAMES:
		await tree.physics_frame
	if Time.get_ticks_msec() - t0 < PROBE_MAX_MS:
		return false # déjà en --fixed-fps
	var cmd: PackedStringArray = ["--headless", "--fixed-fps", str(fps), "--path", ProjectSettings.globalize_path("res://"), scene]
	var user := OS.get_cmdline_user_args()
	if not user.is_empty():
		cmd.append("--")
		cmd.append_array(user)
	print("%s : relancé en --fixed-fps %d (temps de jeu simulé, sans attente réelle)" % [scene, fps])
	OS.set_environment(CHILD_ENV, "1")
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), cmd, out, true)
	OS.unset_environment(CHILD_ENV)
	for s in out:
		printraw(String(s))
	if code < 0:
		print("RESULT: FAIL (relance impossible : %s)" % OS.get_executable_path())
		code = 1
	tree.quit(code)
	return true
