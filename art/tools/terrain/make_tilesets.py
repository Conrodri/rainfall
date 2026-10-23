"""Genere les TileSet .tres (un atlas 256 px par tuile, comme terraces.tres)."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
SETS={"fog_forest":["ground_moss","ground_roots","ground_needles","ground_mud","water_deep","water_shallow","cliff_edge"],
"rust_city":["ground_concrete","ground_rust","ground_grate","ground_bridge","water_deep","water_shallow","cliff_edge"]}
for b,names in SETS.items():
    n=len(names); o=[f'[gd_resource type="TileSet" load_steps={2*n+1} format=3]\n']
    for i,t in enumerate(names,1): o.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/terrain/{b}/{t}.png" id="{i}"]')
    o.append('')
    for i,t in enumerate(names,1):
        o.append(f'[sub_resource type="TileSetAtlasSource" id="src{i}"]\nresource_name = "{t}"\ntexture = ExtResource("{i}")\ntexture_region_size = Vector2i(256, 256)\n0:0/0 = 0\n')
    o.append('[resource]\ntile_size = Vector2i(256, 256)')
    for i in range(n): o.append(f'sources/{i} = SubResource("src{i+1}")')
    (ROOT/f"game/assets/sprites/terrain/{b}/{b}.tres").write_text("\n".join(o)+"\n",encoding="utf8")
