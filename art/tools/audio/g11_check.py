"""Run existing verification on G11 without rewriting manifests."""
from pathlib import Path

path=Path(__file__).with_name('verify_new.py')
source=path.read_text(encoding='utf-8')
source=source.replace(".glob('*.ogg')", ".glob('*foret_brume*.ogg')")
source=source.replace("for carte in ('terrasses_noyees', 'foret_brume', 'cite_rouille'):", "for carte in ('foret_brume',):")
source='\n'.join('    pass # G11: manifests immutable' if line.lstrip().startswith('json.dump(') else line for line in source.splitlines())
exec(compile(source,str(path),'exec'),{'__file__':str(path),'__name__':'__main__'})
