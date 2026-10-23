"""Rendu CEL de référence de Rainfall (factorisé du lot CS1, validé par le joueur le 22/10/2026).

Règle écrite : art/briefs/STYLE_cel.md. TOUS les lots visuels Codex importent ce module ; ne recopiez
pas ses réglages dans vos scripts (une seule source de vérité : PROFILES et les constantes ci-dessous).

Deux moitiés :
  * côté Blender (bpy, `blender --background --python <lot>_build.py -- --render`) :
      install(profile)        -> branche le cel sur le pipeline d'origine (boss_common.configure_passes,
                                 donc iso_rig.render_frame / render_still / render_animation) ; les
                                 scripts de rendu d'origine tournent ENSUITE sans modification.
      toon_materials(profile) -> convertit les matériaux PBR en rampes constantes (appelé par install).
      setup_scene(scene)      -> Eevee 8 échantillons, Standard, passes Normal/Emit + AOV d'accent.
      quantize_normal_files() -> re-quantifie les _n APRÈS réduction/assemblage (Blender, compositeur).
      PLUS DE NORMAL MAPS LIVRÉES (décision du joueur, 22/10/2026, budget mobile) : passer
      install(profile, normals=False) ; la passe Normal reste calculée (plis d'encre) mais aucun
      fichier <f>_n n'est écrit. Le défaut normals=True ne sert qu'aux lots lancés avant cette date.
  * côté Python système (PIL/numpy, pas de bpy) : archive_folder(), check_sheet(), contact_pair().

Exemple minimal (squelette de art/tools/night/<lot>_build.py) :
    import sys; from pathlib import Path
    ROOT = Path(__file__).resolve().parents[3]
    sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/iso')]
    import cel_style as cel
    # driver (python système) : cel.archive_folder('characters/tocsin') AVANT toute écriture
    # rendu (Blender)         : import iso_rig; cel.install('creature', normals=False); <code de rendu d'origine>
    # vérif (python système)  : cel.check_sheet(...) pour chaque planche, cel.contact_pair(...)
Le cel ne change QUE le shading : caméra, cellules, frames, directions, pivots, noms = ceux d'origine.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GAME_SPRITES = ROOT / 'game/assets/sprites'
ARCHIVE = ROOT / 'art/archive_3d/sprites'  # hors projet Godot : jamais importé ni exporté
WORK = ROOT / 'art/blender/cel'            # copies .blend cel et frames brutes (jamais les .blend d'origine)
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
DIRS = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne']
AOV = 'CEL_Accent'

# --- Réglages CS1 (valeurs exactes du lot validé, _cs1_render.json « style ») -----------------------
TONE_SCALES = (.63, 1.12, 1.65)      # ombre / ton moyen / lumière, multipliés à la couleur de base
TONE_STOPS = (0.0, .34, .70)         # positions de la rampe CONSTANT (Shader to RGB d'un diffus gris)
DIFFUSE_GREY = .72                   # albédo du diffus de mesure (rugosité 0)
PBR_RAMP_MIX = .30                   # base = 30 % du ton sombre + 70 % du ton clair de la rampe PBR
SHADOW_FLOOR_LUMA = .040             # luminance linéaire minimale de la base (jamais un corps noir)
MAX_CHANNEL = .72                    # plafond linéaire d'un canal après relèvement
INK_RGB = (.009, .006, .005)         # encre brun-noir (linéaire) ≈ #1A1512 en sRGB
CREASE_THRESHOLD = .72               # Sobel des normales lisses au-delà duquel on encre un pli
CREASE_STRENGTH = .70                # opacité des plis intérieurs (plus fins/légers que la silhouette)
EEVEE_SAMPLES = 8
SUPERSAMPLE = 2                      # iso_rig rend à 2x puis réduit (LANCZOS) : l'encre est en px 2x

# Profils par famille. ink_px = épaisseur de la silhouette À LA TAILLE D'AFFICHAGE (px finaux).
# CS1 (créatures 96-192 px) : érosion 3 px à 2x = 1,5 px final. Plis = 1 px Sobel à 2x (~0,5-1 px final).
PROFILES = {
    'creature': dict(tones=3, ink_px=1.5, creases=True, quantize_normals=True, keep_normals=True),
    'boss':     dict(tones=3, ink_px=2.0, creases=True, quantize_normals=True, keep_normals=True),
    'prop':     dict(tones=3, ink_px=1.5, creases=True, quantize_normals=True, keep_normals=True),
    # Tuiles : JAMAIS de contour de silhouette (les tuiles se raccordent : l'encre dessinerait la grille).
    'tile':     dict(tones=3, ink_px=0.0, creases=True, quantize_normals=True, keep_normals=True,
                     keep_texture=True),
    'icon':     dict(tones=3, ink_px=1.0, creases=True, quantize_normals=False, keep_normals=False),
    'ui':       dict(tones=2, ink_px=1.0, creases=False, quantize_normals=False, keep_normals=False),
    # VFX additifs (lumière pure) : pas d'encre, pas de normale ; seuls les VFX à corps (rochers, lames,
    # météores, eau) passent en tons, l'émission reste continue (le glow HDR du jeu s'en charge).
    'vfx':      dict(tones=2, ink_px=0.0, creases=False, quantize_normals=False, keep_normals=False),
}


def profile(name_or_dict) -> dict:
    p = dict(PROFILES['creature'])
    p.update(PROFILES[name_or_dict] if isinstance(name_or_dict, str) else name_or_dict)
    return p


# =============================== Blender (bpy) ===============================================

def setup_scene(scene=None, samples=EEVEE_SAMPLES):
    """Réglages de rendu cel communs (ne touche ni caméra ni résolution : ceux du script d'origine)."""
    import bpy
    s = scene or bpy.context.scene
    s.render.engine = 'BLENDER_EEVEE'
    s.eevee.taa_render_samples = samples
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.render.dither_intensity = 0
    s.view_settings.view_transform = 'Standard'
    for layer in s.view_layers:
        layer.use_pass_normal = True
        layer.use_pass_emit = True
        if not layer.aovs.get(AOV):
            layer.aovs.add().name = AOV
    return s


def toon_materials(prof='creature', only_new=True) -> dict:
    """PBR -> aplats : diffus gris -> Shader to RGB -> rampe CONSTANT de N tons -> Emission.

    La teinte vient de la matière d'origine (Base Color, ou 30/70 de sa rampe procédurale) ; le grain
    procédural est abandonné, la teinte jamais. Matières lumineuses (rainfall_emissive, ou émission sans
    rampe) : émission conservée + AOV d'accent (-> _e). Idempotent (étiquette mat['cel_done']).
    Avec keep_texture (tuiles) et une Base Color reliée à une texture : texture × ton quantifié.
    Retourne {matière: [couleurs des tons]} pour le rapport du lot.
    """
    import bpy
    p = profile(prof)
    palettes = {}
    for mat in bpy.data.materials:
        if not mat.use_nodes or (only_new and mat.get('cel_done')):
            continue
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        base = tuple(bsdf.inputs['Base Color'].default_value)
        ramps = [n for n in nodes if n.type == 'VALTORGB']
        if ramps:
            r = ramps[0].color_ramp
            dark, light = tuple(r.elements[0].color), tuple(r.elements[-1].color)
            base = tuple(dark[i] * PBR_RAMP_MIX + light[i] * (1 - PBR_RAMP_MIX) for i in range(3)) + (1,)
        texture_src = None
        if p.get('keep_texture') and bsdf.inputs['Base Color'].is_linked:
            link = bsdf.inputs['Base Color'].links[0]
            if link.from_node.type == 'TEX_IMAGE':
                texture_src = (link.from_node, link.from_socket.name)
        glow = tuple(bsdf.inputs['Emission Color'].default_value)
        strength = bsdf.inputs['Emission Strength'].default_value
        luminous = strength > .01 and (bool(mat.get('rainfall_emissive')) or not ramps)
        keep = {texture_src[0].name} if texture_src else set()
        for n in list(nodes):
            if n.name not in keep:
                nodes.remove(n)
        output = nodes.new('ShaderNodeOutputMaterial')
        emit = nodes.new('ShaderNodeEmission')
        accent = nodes.new('ShaderNodeOutputAOV'); accent.aov_name = AOV
        accent.inputs['Color'].default_value = (tuple(c * strength for c in glow[:3]) + (1,)) if luminous else (0, 0, 0, 1)
        if luminous:
            emit.inputs['Color'].default_value = glow
            emit.inputs['Strength'].default_value = strength
        else:
            diffuse = nodes.new('ShaderNodeBsdfDiffuse')
            diffuse.inputs['Color'].default_value = (DIFFUSE_GREY, DIFFUSE_GREY, DIFFUSE_GREY, 1)
            diffuse.inputs['Roughness'].default_value = 0
            rgb = nodes.new('ShaderNodeShaderToRGB')
            links.new(diffuse.outputs[0], rgb.inputs[0])
            ramp = nodes.new('ShaderNodeValToRGB'); ramp.name = 'CEL tones'
            ramp.color_ramp.interpolation = 'CONSTANT'
            luma = sum(base[i] * w for i, w in enumerate((.2126, .7152, .0722)))
            lift = max(1, SHADOW_FLOOR_LUMA / max(luma, .0001))
            base = tuple(min(MAX_CHANNEL, c * lift) for c in base[:3])
            scales = TONE_SCALES if p['tones'] >= 3 else (TONE_SCALES[0], TONE_SCALES[2])
            stops = TONE_STOPS if p['tones'] >= 3 else (TONE_STOPS[0], TONE_STOPS[1])
            tint = (1, 1, 1) if texture_src else base
            colors = [tuple(c * k for c in tint) + (1,) for k in scales]
            els = ramp.color_ramp.elements
            els[0].position, els[0].color = stops[0], colors[0]
            els[1].position, els[1].color = stops[1], colors[1]
            for stop, col in zip(stops[2:], colors[2:]):
                els.new(stop).color = col
            links.new(rgb.outputs['Color'], ramp.inputs['Fac'])
            if texture_src:
                mul = nodes.new('ShaderNodeVectorMath'); mul.operation = 'MULTIPLY'
                links.new(texture_src[0].outputs[texture_src[1]], mul.inputs[0])
                links.new(ramp.outputs['Color'], mul.inputs[1])
                links.new(mul.outputs[0], emit.inputs['Color'])
            else:
                links.new(ramp.outputs['Color'], emit.inputs['Color'])
            palettes[mat.name] = [list(c) for c in colors]
        links.new(emit.outputs[0], output.inputs['Surface'])
        mat['cel_done'] = True
    return palettes


def _boss_common():
    sys.path.insert(0, str(ROOT / 'art/tools/bosses'))
    import boss_common
    return boss_common


def cel_passes(path, prof='creature', base_configure=None, normals=True):
    """Compositeur cel : passes d'origine (boss_common.configure_passes) + normales quantifiées,
    _e depuis l'AOV d'accent, encre (silhouette érodée vers l'intérieur + plis Sobel des normales).
    normals=False : la sortie fichier `<f>_n` est retirée (aucune normal map écrite, 22/10/2026)."""
    import bpy
    p = profile(prof)
    (base_configure or _boss_common().configure_passes)(Path(path))
    s = bpy.context.scene
    tree = getattr(s, 'node_tree', None) or s.compositing_node_group
    nodes, links = tree.nodes, tree.links
    rl = next(n for n in nodes if n.bl_idname == 'CompositorNodeRLayers')
    output = next(n for n in nodes if n.bl_idname == 'NodeGroupOutput')

    def math(op, a=None, b=None):
        n = nodes.new('ShaderNodeMath'); n.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                links.new(v, n.inputs[i])
        return n.outputs[0]

    def set_alpha(image):
        n = nodes.new('CompositorNodeSetAlpha'); n.inputs['Type'].default_value = 'Replace Alpha'
        links.new(image, n.inputs['Image']); links.new(rl.outputs['Alpha'], n.inputs['Alpha'])
        return n.outputs[0]

    files = [n for n in nodes if n.bl_idname == 'CompositorNodeOutputFile']
    if not normals:
        for f in [f for f in files if '_n__' in (f.file_name if hasattr(f, 'file_name') else f.file_slots[0].path)]:
            files.remove(f)
            nodes.remove(f)
    if p['quantize_normals'] and normals:
        # Trois paliers signés par composante écran puis renormalisation : 26 directions finies.
        quant = nodes.new('ShaderNodeCombineXYZ')
        dots = [n for n in nodes if n.bl_idname == 'ShaderNodeVectorMath' and n.operation == 'DOT_PRODUCT']
        for i, dot in enumerate(dots[:3]):
            links.new(math('ROUND', dot.outputs['Value']), quant.inputs[i])
        unit = nodes.new('ShaderNodeVectorMath'); unit.operation = 'NORMALIZE'
        links.new(quant.outputs[0], unit.inputs[0])
        enc = nodes.new('ShaderNodeVectorMath'); enc.operation = 'MULTIPLY_ADD'
        links.new(unit.outputs[0], enc.inputs[0])
        enc.inputs[1].default_value = (.5, .5, .5); enc.inputs[2].default_value = (.5, .5, .5)
        normals = set_alpha(enc.outputs['Vector'])
    for f in files:
        name = f.file_name if hasattr(f, 'file_name') else f.file_slots[0].path
        if '_n__' in name and p['quantize_normals'] and normals:
            links.new(normals, f.inputs[0])
        elif '_e__' in name:
            links.new(set_alpha(rl.outputs[AOV]), f.inputs[0])

    ink = None
    erode_px = round(p['ink_px'] * SUPERSAMPLE)
    erode = nodes.new('CompositorNodeDilateErode'); erode.inputs['Type'].default_value = 'Distance'
    erode.inputs['Size'].default_value = -max(1, erode_px)
    links.new(rl.outputs['Alpha'], erode.inputs['Mask'])
    if erode_px > 0:
        ink = math('SUBTRACT', rl.outputs['Alpha'], erode.outputs[0])
    if p['creases']:
        sobel = nodes.new('CompositorNodeFilter'); sobel.inputs['Type'].default_value = 'Sobel'
        links.new(rl.outputs['Normal'], sobel.inputs['Image'])
        sep = nodes.new('CompositorNodeSeparateColor'); links.new(sobel.outputs[0], sep.inputs[0])
        e = [math('ABSOLUTE', sep.outputs[i]) for i in range(3)]
        edge = math('GREATER_THAN', math('MAXIMUM', math('MAXIMUM', e[0], e[1]), e[2]), CREASE_THRESHOLD)
        # Tuiles : pas d'érosion de silhouette, mais les plis restent hors du bord de la tuile.
        edge = math('MULTIPLY', math('MULTIPLY', edge, erode.outputs[0]), CREASE_STRENGTH)
        ink = edge if ink is None else math('MAXIMUM', ink, edge)
    if ink is None:
        return
    body = nodes.new('ShaderNodeVectorMath'); body.operation = 'MULTIPLY'
    links.new(rl.outputs['Image'], body.inputs[0]); links.new(math('SUBTRACT', 1, ink), body.inputs[1])
    mix = nodes.new('ShaderNodeVectorMath'); mix.operation = 'MULTIPLY_ADD'
    links.new(ink, mix.inputs[0]); mix.inputs[1].default_value = INK_RGB
    links.new(body.outputs[0], mix.inputs[2])
    links.new(set_alpha(mix.outputs[0]), output.inputs['Image'])


_installed = {}


def install(prof='creature', keep_black_emission=True, normals=True):
    """Branche le cel sur le pipeline d'origine. À appeler après bpy.ops.wm.open_mainfile / la
    construction de scène et AVANT les rendus ; chaque rendu passant par configure_passes (iso_rig,
    boss_common) reçoit alors matériaux toon + compositeur cel. keep_black_emission : garde les _e
    noirs pour que la grille de fichiers reste identique à l'original (CS1). normals=False (obligatoire
    depuis le 22/10/2026) : aucun fichier _n écrit."""
    common = _boss_common()
    original = _installed.get('configure_passes', common.configure_passes)
    _installed['configure_passes'] = original

    def configure(path):
        setup_scene()
        toon_materials(prof)
        cel_passes(path, prof, original, normals)

    common.configure_passes = configure
    iso = sys.modules.get('iso_rig')
    if iso is not None:
        iso.common.configure_passes = configure
        if keep_black_emission and 'optimize_png' not in _installed:
            _installed['optimize_png'] = iso.optimize_png
            def optimize(path, crop=False, margin=6):
                from PIL import Image
                path = Path(path)
                if path.stem.endswith('_e') and not crop:
                    with Image.open(path) as im:
                        im.convert('RGBA').save(path, optimize=True, compress_level=9)
                    return (0, 0, *Image.open(path).size)
                return _installed['optimize_png'](path, crop, margin)
            iso.optimize_png = optimize
    return configure


def uninstall():
    common = _boss_common()
    if 'configure_passes' in _installed:
        common.configure_passes = _installed.pop('configure_passes')
        iso = sys.modules.get('iso_rig')
        if iso is not None:
            iso.common.configure_passes = common.configure_passes
            if 'optimize_png' in _installed:
                iso.optimize_png = _installed.pop('optimize_png')


def quantize_normal_files(paths, work=None):
    """Re-quantifie des _n déjà réduits/assemblés (le filtrage LANCZOS recrée des dégradés aux bords
    des paliers). Compositeur Blender : décode, ROUND par composante, renormalise, ré-encode.
    L'original filtré est gardé une fois dans work/ (idempotent : on repart toujours de lui)."""
    import bpy
    paths = [Path(p) for p in paths]
    if not paths:
        return
    work = Path(work or WORK / 'frames/normals'); work.mkdir(parents=True, exist_ok=True)
    scene = bpy.data.scenes.new('CEL normal plateaus')
    scene.render.engine = 'BLENDER_EEVEE'; scene.eevee.taa_render_samples = 1
    scene.render.film_transparent = True; scene.render.dither_intensity = 0
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'; scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'; scene.view_settings.view_transform = 'Raw'
    cam = bpy.data.objects.new('CEL normal camera', bpy.data.cameras.new('CEL normal camera'))
    scene.collection.objects.link(cam); scene.camera = cam
    tree = bpy.data.node_groups.new('CEL post-filter normal plateaus', 'CompositorNodeTree')
    scene.compositing_node_group = tree
    tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    nodes, links = tree.nodes, tree.links
    src = nodes.new('CompositorNodeImage')
    dec = nodes.new('ShaderNodeVectorMath'); dec.operation = 'MULTIPLY_ADD'
    links.new(src.outputs['Image'], dec.inputs[0])
    dec.inputs[1].default_value = (2, 2, 2); dec.inputs[2].default_value = (-1, -1, -1)
    split = nodes.new('ShaderNodeSeparateXYZ'); links.new(dec.outputs[0], split.inputs[0])
    comb = nodes.new('ShaderNodeCombineXYZ')
    for i in range(3):
        r = nodes.new('ShaderNodeMath'); r.operation = 'ROUND'
        links.new(split.outputs[i], r.inputs[0]); links.new(r.outputs[0], comb.inputs[i])
    length = nodes.new('ShaderNodeVectorMath'); length.operation = 'LENGTH'
    links.new(comb.outputs[0], length.inputs[0])
    zero = nodes.new('ShaderNodeMath'); zero.operation = 'LESS_THAN'; zero.inputs[1].default_value = .1
    links.new(length.outputs['Value'], zero.inputs[0])
    fallback = nodes.new('ShaderNodeCombineXYZ'); links.new(zero.outputs[0], fallback.inputs[2])
    valid = nodes.new('ShaderNodeVectorMath'); valid.operation = 'ADD'
    links.new(comb.outputs[0], valid.inputs[0]); links.new(fallback.outputs[0], valid.inputs[1])
    unit = nodes.new('ShaderNodeVectorMath'); unit.operation = 'NORMALIZE'
    links.new(valid.outputs[0], unit.inputs[0])
    enc = nodes.new('ShaderNodeVectorMath'); enc.operation = 'MULTIPLY_ADD'
    links.new(unit.outputs[0], enc.inputs[0])
    enc.inputs[1].default_value = (.5, .5, .5); enc.inputs[2].default_value = (.5, .5, .5)
    alpha = nodes.new('CompositorNodeSetAlpha'); alpha.inputs['Type'].default_value = 'Replace Alpha'
    links.new(enc.outputs[0], alpha.inputs['Image']); links.new(src.outputs['Alpha'], alpha.inputs['Alpha'])
    out = nodes.new('NodeGroupOutput'); links.new(alpha.outputs[0], out.inputs['Image'])
    for p in paths:
        key = hashlib.sha1(str(p.resolve()).encode()).hexdigest()[:10]
        original = work / f'{key}_{p.name}'
        if not original.exists():
            shutil.copyfile(p, original)
        image = bpy.data.images.load(str(original), check_existing=False)
        image.colorspace_settings.name = 'Non-Color'; src.image = image
        scene.render.resolution_x, scene.render.resolution_y = image.size
        scene.render.filepath = str(p)
        bpy.ops.render.render(scene=scene.name, write_still=True)
        bpy.data.images.remove(image)
        print('CEL normal plateaus ' + str(p), flush=True)
    bpy.data.scenes.remove(scene)
    bpy.data.objects.remove(cam, do_unlink=True)


# ============================ Python système (PIL / numpy) ===================================

def archive_folder(rel: str) -> Path:
    """Copie UNE FOIS game/assets/sprites/<rel> (PNG, .tres, .json, .md ; pas les .import) vers
    art/archive_3d/sprites/<rel> avant que le lot n'écrase les planches 3D. Idempotent : si l'archive
    existe, elle n'est jamais réécrite (c'est la référence 3D de la vérification et du retour arrière)."""
    src = GAME_SPRITES / rel
    dst = ARCHIVE / rel
    if not src.is_dir():
        raise FileNotFoundError(src)
    marker = dst / '.archived.json'
    if marker.exists():
        return dst
    manifest = {}
    for f in sorted(src.rglob('*')):
        if f.is_dir() or f.suffix == '.import':
            continue
        out = dst / f.relative_to(src)
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, out)
        manifest[str(f.relative_to(src)).replace('\\', '/')] = hashlib.sha256(f.read_bytes()).hexdigest()
    marker.write_text(json.dumps(manifest, indent=1), encoding='utf-8')
    return dst


def check_sheet(rel_png: str, cell=None, frames=None, rows=None, normals=True, emission=None,
                min_iou=.97) -> dict:
    """Contrôle une planche cel réécrite dans le dossier d'origine contre son archive 3D.

    rel_png : chemin relatif à game/assets/sprites (ex. 'monsters/swarm_tier1/run.png').
    Vérifie : même taille (≤ 4096), alpha identique entre X / X_n / X_e, normales finies (≤ 27 teintes,
    unitaires) si normals, silhouette (IoU alpha > min_iou) et zones d'accent identiques à l'archive,
    cellules non vides et non dupliquées si cell/frames/rows sont donnés. Lève AssertionError."""
    from PIL import Image
    import numpy as np
    new = GAME_SPRITES / rel_png
    old = ARCHIVE / rel_png
    res = {'file': rel_png}
    load = lambda p: np.asarray(Image.open(p).convert('RGBA'))
    color = load(new)
    assert max(color.shape[:2]) <= 4096, (rel_png, 'planche > 4096')
    if old.exists():
        ref = load(old)
        assert ref.shape == color.shape, (rel_png, 'taille', ref.shape, color.shape)
        a, b = ref[:, :, 3] > 128, color[:, :, 3] > 128
        res['silhouette_iou'] = float((a & b).sum() / max(1, (a | b).sum()))
        assert res['silhouette_iou'] > min_iou, (rel_png, 'silhouette/pose différente', res['silhouette_iou'])
    n_path = new.with_name(new.stem + '_n.png')
    if normals and n_path.exists():
        n = load(n_path)
        assert np.array_equal(color[:, :, 3], n[:, :, 3]), (rel_png, 'alpha _n')
        opaque = n[:, :, 3] == 255
        pal = np.unique(n[:, :, :3][opaque], axis=0)
        assert len(pal) <= 27, (rel_png, 'normales non quantifiées', len(pal))
        lengths = np.linalg.norm(pal.astype(float) / 127.5 - 1, axis=1)
        assert np.all(np.abs(lengths - 1) < .015), (rel_png, 'normales non unitaires')
        res['normal_palette'] = int(len(pal))
    e_path = new.with_name(new.stem + '_e.png')
    if e_path.exists():
        e = load(e_path)
        if e.shape[:2] != color.shape[:2]:
            # _e déjà réduit à demi-résolution (art/tools/halve_emission.py) : seule la taille est contrôlée.
            h, w = color.shape[:2]
            assert e.shape[:2] == ((h + 1) // 2, (w + 1) // 2), (rel_png, 'taille _e', e.shape, color.shape)
            res['e_half'] = True
        else:
            assert np.array_equal(color[:, :, 3], e[:, :, 3]), (rel_png, 'alpha _e')
        old_e = old.with_name(old.stem + '_e.png')
        if emission is not False and old_e.exists() and not res.get('e_half') \
                and load(old_e).shape == e.shape:
            r = load(old_e)
            a = (r[:, :, :3].max(axis=2) > 100) & (r[:, :, 3] > 128)
            b = (e[:, :, :3].max(axis=2) > 100) & (e[:, :, 3] > 128)
            if a.any() or b.any():
                res['accent_iou'] = float((a & b).sum() / max(1, (a | b).sum()))
                assert res['accent_iou'] > min_iou, (rel_png, 'zones d\'accent différentes', res['accent_iou'])
    if cell and frames and rows:
        cw, ch = (cell, cell) if isinstance(cell, int) else cell
        assert color.shape[:2] == (rows * ch, frames * cw), (rel_png, 'grille')
        for r in range(rows):
            hashes = set()
            for c in range(frames):
                cc = color[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
                assert cc[:, :, 3].max() > 240, (rel_png, r, c, 'cellule vide')
                hashes.add(hashlib.sha256(cc.tobytes()).hexdigest())
            if frames > 1:
                assert len(hashes) == frames, (rel_png, r, 'frames dupliquées')
    return res


def contact_pair(samples, out_path, ground='terrain/terraces/iso/ground_a.png', size=(1440, 900)):
    """Planche de contrôle archive 3D (gauche) / cel (droite) sur le vrai sol sombre du jeu.

    samples : liste de lignes, chaque ligne = liste de (rel_png, cell, frame_col, row) ; ≤ 4 par ligne.
    """
    from PIL import Image
    g = Image.open(GAME_SPRITES / ground).convert('RGBA')
    canvas = Image.new('RGBA', size, (18, 22, 23, 255))
    row_h = size[1] // max(1, len(samples))
    half = size[0] // 2
    for r, line in enumerate(samples):
        step = half // max(1, len(line))
        for side in range(2):
            for c, _ in enumerate(line):
                cx, cy = side * half + c * step + step // 2, r * row_h + row_h // 2
                canvas.alpha_composite(g, (cx - g.width // 2, cy + 54 - g.height // 2))
        for side, base in ((0, ARCHIVE), (1, GAME_SPRITES)):
            for c, (rel, cell, col, row) in enumerate(line):
                p = base / rel
                if not p.exists():
                    continue
                cw, ch = (cell, cell) if isinstance(cell, int) else cell
                atlas = Image.open(p).convert('RGBA')
                crop = atlas.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
                cx, cy = side * half + c * step + step // 2, r * row_h + row_h // 2
                canvas.alpha_composite(crop, (cx - cw // 2, max(0, cy + 54 - round(ch * .70))))
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(out_path, optimize=True)
    return out_path


if __name__ == '__main__':
    # Auto-contrôle sans Blender : réglages lisibles et cohérents.
    assert all(k in PROFILES for k in ('creature', 'boss', 'prop', 'tile', 'icon', 'ui', 'vfx'))
    assert PROFILES['tile']['ink_px'] == 0, 'tuiles sans contour de silhouette'
    print(json.dumps({'profiles': PROFILES, 'tones': TONE_SCALES, 'stops': TONE_STOPS,
                      'shadow_floor_luma': SHADOW_FLOOR_LUMA, 'ink_rgb': INK_RGB}, indent=1))
