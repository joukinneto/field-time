from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f'Pattern not found: {label}')
    path.write_text(text.replace(old, new, 1))

models = Path('lib/src/domain/field_time_models.dart')
replace_once(
    models,
    """  WorkDay? get activeWorkDay {
    for (final day in workDays.reversed) {
      if (day.isOpen) return day;
    }
    return null;
  }
""",
    """  WorkDay? get activeWorkDay {
    for (final day in workDays.reversed) {
      if (day.isOpen && day.workerId == worker.id) return day;
    }
    return null;
  }
""",
    'active workday scoped to current worker',
)

service = Path('lib/src/application/field_time_application_service.dart')
replace_once(
    service,
    """    return snapshot.workDays
        .where((day) =>
            !day.workDate.isBefore(start) && day.workDate.isBefore(end))
""",
    """    return snapshot.workDays
        .where((day) =>
            day.workerId == snapshot.worker.id &&
            !day.workDate.isBefore(start) &&
            day.workDate.isBefore(end))
""",
    'timesheet scoped to current worker',
)
replace_once(
    service,
    """    for (final day in snapshot.workDays.reversed) {
      if (day.workDate == date && day.status == WorkDayStatus.completed) {
        return day;
      }
    }
""",
    """    for (final day in snapshot.workDays.reversed) {
      if (day.workerId == snapshot.worker.id &&
          day.workDate == date &&
          day.status == WorkDayStatus.completed) {
        return day;
      }
    }
""",
    'same-day reopening scoped to current worker',
)
