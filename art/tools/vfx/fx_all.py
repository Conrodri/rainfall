"""Charge tous les modules d'effets (enregistrement dans fx_defs.EFFECTS)."""
import importlib
for _m in ('fx_defs', 'fx_p1', 'fx_p2', 'fx_p3', 'fx_p4'):
    try:
        importlib.import_module(_m)
    except ModuleNotFoundError as e:
        if e.name != _m: raise
from fx_defs import EFFECTS
