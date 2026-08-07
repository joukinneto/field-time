from pathlib import Path

path = Path(__file__).resolve().parents[1] / "lib/src/presentation/screens/time_records_screen.dart"
text = path.read_text(encoding="utf-8")
old = """\nbool _sameDate(DateTime left, DateTime right) =>\n    left.year == right.year &&\n    left.month == right.month &&\n    left.day == right.day;\n"""
count = text.count(old)
if count != 1:
    raise RuntimeError(f"unused _sameDate cleanup: expected 1 match, found {count}")
path.write_text(text.replace(old, "\n", 1), encoding="utf-8")
print("Removed unused _sameDate helper.")
