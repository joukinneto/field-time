from pathlib import Path

path = Path('lib/src/presentation/screens/time_records_screen.dart')
text = path.read_text()
old = """        children: [\n          Padding(\n            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),\n            child: Image.asset(AppAssets.fieldTimeLogoDark),\n          ),\n          Expanded(\n"""
new = """        children: [\n          Expanded(\n"""
if old not in text:
    raise RuntimeError('Desktop sidebar logo block not found')
text = text.replace(old, new, 1)
path.write_text(text)
