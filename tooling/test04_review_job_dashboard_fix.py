from pathlib import Path

controller = Path('lib/src/supervisor_center/supervisor_center_controller.dart')
text = controller.read_text()
text = text.replace(
"""    required double extraBonusHours,\n    required double payPremiumPercent,\n""",
"""    double? extraBonusHours,\n    double? payPremiumPercent,\n""",1)
text = text.replace(
"""      extraBonusHours: extraBonusHours,\n      payPremiumPercent: payPremiumPercent,\n""",
"""      extraBonusHours: extraBonusHours ?? entry.extraBonusHours,\n      payPremiumPercent: payPremiumPercent ?? entry.payPremiumPercent,\n""",1)
controller.write_text(text)

screen = Path('lib/src/supervisor_center/supervisor_center_screen.dart')
text = screen.read_text()
text = text.replace(
"""final class _JobListCard extends ConsumerWidget {\n""",
"""// ignore: unused_element\nfinal class _JobListCard extends ConsumerWidget {\n""",1)
text = text.replace(
"""  if (action == null) return;\n  try {\n    final controller = ref.read(supervisorCenterProvider.notifier);\n""",
"""  if (action == null || !context.mounted) return;\n  try {\n    final controller = ref.read(supervisorCenterProvider.notifier);\n""",1)
screen.write_text(text)
