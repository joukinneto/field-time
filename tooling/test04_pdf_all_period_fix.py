from pathlib import Path
p=Path('lib/src/timesheet/timesheet_pdf_service.dart')
t=p.read_text()
old='''      TimesheetPeriod.year => TimesheetRange(\n          start: DateTime(value.year),\n          end: DateTime(value.year, 12, 31),\n        ),\n    };\n'''
new='''      TimesheetPeriod.year => TimesheetRange(\n          start: DateTime(value.year),\n          end: DateTime(value.year, 12, 31),\n        ),\n      TimesheetPeriod.all => TimesheetRange(\n          start: DateTime(1900),\n          end: DateTime(9999, 12, 31),\n        ),\n    };\n'''
if old not in t: raise SystemExit('range block not found')
p.write_text(t.replace(old,new,1))
