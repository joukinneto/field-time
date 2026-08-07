from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'lib/src/supervisor_center/supervisor_center_screen.dart'
text = path.read_text(encoding='utf-8')

old = """    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);\n    return Card("""
new = """    final entries = state.timeEntries\n        .where((entry) => entry.jobId == job.id)\n        .toList(growable: false);\n    final todayEntries = entries.where((entry) => _sameDay(entry.date, DateTime.now()));\n    return Card("""
if old not in text:
    raise RuntimeError('JobListCard entries anchor not found')
text = text.replace(old, new, 1)

old = """                JkddInfoRow(\n                  label: context.tr('supervisor.hoursToday'),\n                  value: _hours(entries.fold<double>(\n                    0,\n                    (total, entry) => total + _entryHoursValue(entry),\n                  )),\n                ),"""
new = """                JkddInfoRow(\n                  label: context.tr('supervisor.hoursToday'),\n                  value: _hours(todayEntries.fold<double>(\n                    0,\n                    (total, entry) => total + _entryHoursValue(entry),\n                  )),\n                ),\n                JkddInfoRow(\n                  label: context.tr('timesheet.totalHours'),\n                  value: _hours(entries.fold<double>(\n                    0,\n                    (total, entry) => total + _entryHoursValue(entry),\n                  )),\n                ),"""
if old not in text:
    raise RuntimeError('JobListCard hours anchor not found')
text = text.replace(old, new, 1)

old = """    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);\n    return Column(\n      crossAxisAlignment: CrossAxisAlignment.stretch,\n      children: [\n        _ResponsiveGrid("""
new = """    final entries = state.timeEntries\n        .where((entry) => entry.jobId == job.id)\n        .toList(growable: false);\n    final todayEntries = entries.where((entry) => _sameDay(entry.date, DateTime.now()));\n    final approvedEntries = entries.where((entry) => entry.status == TimeReviewStatus.approved);\n    final pendingEntries = entries.where((entry) =>\n        entry.status != TimeReviewStatus.approved && entry.clockOut != null);\n    return Column(\n      crossAxisAlignment: CrossAxisAlignment.stretch,\n      children: [\n        _ResponsiveGrid("""
if old not in text:
    raise RuntimeError('JobSummary entries anchor not found')
text = text.replace(old, new, 1)

old = """                JkddInfoRow(\n                  label: context.tr('supervisor.totalDayHours'),\n                  value: _hours(entries.fold<double>(\n                    0,\n                    (sum, entry) => sum + _entryHoursValue(entry),\n                  )),\n                ),"""
new = """                JkddInfoRow(\n                  label: context.tr('supervisor.totalDayHours'),\n                  value: _hours(todayEntries.fold<double>(\n                    0,\n                    (sum, entry) => sum + _entryHoursValue(entry),\n                  )),\n                ),\n                JkddInfoRow(\n                  label: context.tr('timesheet.totalHours'),\n                  value: _hours(entries.fold<double>(\n                    0,\n                    (sum, entry) => sum + _entryHoursValue(entry),\n                  )),\n                ),\n                JkddInfoRow(\n                  label: context.tr('approval.approved'),\n                  value: _hours(approvedEntries.fold<double>(\n                    0,\n                    (sum, entry) => sum + _entryHoursValue(entry),\n                  )),\n                ),\n                JkddInfoRow(\n                  label: context.tr('supervisor.pendingHours'),\n                  value: _hours(pendingEntries.fold<double>(\n                    0,\n                    (sum, entry) => sum + _entryHoursValue(entry),\n                  )),\n                ),"""
if old not in text:
    raise RuntimeError('JobSummary totals anchor not found')
text = text.replace(old, new, 1)

old = """    final state = ref.watch(supervisorCenterProvider);\n    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);\n    return Column(\n      crossAxisAlignment: CrossAxisAlignment.stretch,\n      children: [\n        Align("""
new = """    final state = ref.watch(supervisorCenterProvider);\n    final entries = state.timeEntries\n        .where((entry) => entry.jobId == job.id)\n        .toList(growable: false);\n    final todayEntries = entries.where((entry) => _sameDay(entry.date, DateTime.now()));\n    final approvedEntries = entries.where((entry) => entry.status == TimeReviewStatus.approved);\n    final pendingEntries = entries.where((entry) =>\n        entry.status != TimeReviewStatus.approved && entry.clockOut != null);\n    return Column(\n      crossAxisAlignment: CrossAxisAlignment.stretch,\n      children: [\n        _ResponsiveGrid(\n          minWidth: 170,\n          children: [\n            JkddSummaryCard(\n              label: context.tr('supervisor.hoursToday'),\n              value: _hours(todayEntries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),\n              icon: Icons.today_outlined,\n              color: AppColors.blue,\n            ),\n            JkddSummaryCard(\n              label: context.tr('timesheet.totalHours'),\n              value: _hours(entries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),\n              icon: Icons.schedule_outlined,\n              color: AppColors.purple,\n            ),\n            JkddSummaryCard(\n              label: context.tr('approval.approved'),\n              value: _hours(approvedEntries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),\n              icon: Icons.verified_outlined,\n              color: AppColors.green,\n            ),\n            JkddSummaryCard(\n              label: context.tr('supervisor.pendingHours'),\n              value: _hours(pendingEntries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),\n              icon: Icons.pending_actions_outlined,\n              color: AppColors.amber,\n            ),\n          ],\n        ),\n        const SizedBox(height: AppSpacing.lg),\n        Align("""
if old not in text:
    raise RuntimeError('JobHours anchor not found')
text = text.replace(old, new, 1)

old = """double _entryHoursValue(TimeEntry entry) {"""
new = """bool _sameDay(DateTime left, DateTime right) =>\n    left.year == right.year &&\n    left.month == right.month &&\n    left.day == right.day;\n\ndouble _entryHoursValue(TimeEntry entry) {"""
if old not in text:
    raise RuntimeError('helper anchor not found')
text = text.replace(old, new, 1)

old = """String _hours(double value) {\n  final minutes = (value * 60).round().clamp(0, 24 * 60);\n  return '${minutes ~/ 60}h ${minutes.remainder(60).toString().padLeft(2, '0')}m';\n}"""
new = """String _hours(double value) {\n  final minutes = (value * 60).round();\n  final safeMinutes = minutes < 0 ? 0 : minutes;\n  return '${safeMinutes ~/ 60}h ${safeMinutes.remainder(60).toString().padLeft(2, '0')}m';\n}"""
if old not in text:
    raise RuntimeError('hours helper anchor not found')
text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('Test 04 job-hours patch applied.')
