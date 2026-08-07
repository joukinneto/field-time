from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'Pattern not found: {label}')
    return text.replace(old, new, 1)

# Supervisor/Director/manager management dashboard: four homogeneous interactive cards.
path = Path('lib/src/supervisor_center/supervisor_center_screen.dart')
text = path.read_text()
old = """        _ResponsiveGrid(\n          minWidth: 180,\n          children: [\n"""
new = """        _ManagementMetricsGrid(\n          children: [\n"""
text = replace_once(text, old, new, 'management metrics grid')

marker = """final class _ResponsiveGrid extends StatelessWidget {\n"""
management_grid = """final class _ManagementMetricsGrid extends StatelessWidget {\n  const _ManagementMetricsGrid({required this.children});\n\n  final List<Widget> children;\n\n  @override\n  Widget build(BuildContext context) => LayoutBuilder(\n    builder: (context, constraints) {\n      final columns = constraints.maxWidth >= 900 ? 4 : 2;\n      final ratio = constraints.maxWidth < 520 ? 1.22 : 1.38;\n      return GridView.count(\n        crossAxisCount: columns,\n        shrinkWrap: true,\n        physics: const NeverScrollableScrollPhysics(),\n        crossAxisSpacing: AppSpacing.md,\n        mainAxisSpacing: AppSpacing.md,\n        childAspectRatio: ratio,\n        children: children,\n      );\n    },\n  );\n}\n\n"""
text = replace_once(text, marker, management_grid + marker, 'management grid class')
path.write_text(text)

# Supervisor/Director/manager Timesheet: four status cards aligned 2x2 on phones / one row on wide screens.
# 'Registros' remains interactive, but as a full-width compact control instead of a fifth orphan card.
path = Path('lib/src/presentation/screens/timesheet_screen.dart')
text = path.read_text()
old_width = """                    final itemWidth = constraints.maxWidth < 620\n                        ? (constraints.maxWidth - AppSpacing.md) / 2\n                        : 210.0;\n"""
new_width = """                    final columns = constraints.maxWidth >= 900 ? 4 : 2;\n                    final itemWidth =\n                        (constraints.maxWidth - AppSpacing.md * (columns - 1)) /\n                        columns;\n"""
text = replace_once(text, old_width, new_width, 'timesheet metric width')

old_records_card = """                        _TimesheetStatusCard(\n                          width: itemWidth,\n                          label: 'Registros',\n                          value: '${allEntries.length}',\n                          icon: Icons.list_alt_outlined,\n                          color: AppColors.purple,\n                          selected: _filter == _SupervisorTimesheetFilter.all,\n                          onTap: () =>\n                              _setFilter(_SupervisorTimesheetFilter.all),\n                        ),\n"""
text = replace_once(text, old_records_card, '', 'remove orphan records card')

old_after_wrap = """                const SizedBox(height: AppSpacing.md),\n                Row(\n                  children: [\n                    const Icon(Icons.filter_alt_outlined, size: 18),\n"""
new_after_wrap = """                const SizedBox(height: AppSpacing.md),\n                SizedBox(\n                  width: double.infinity,\n                  child: OutlinedButton.icon(\n                    onPressed: () =>\n                        _setFilter(_SupervisorTimesheetFilter.all),\n                    icon: const Icon(Icons.list_alt_outlined),\n                    label: Text('Todos os registros (${allEntries.length})'),\n                  ),\n                ),\n                const SizedBox(height: AppSpacing.sm),\n                Row(\n                  children: [\n                    const Icon(Icons.filter_alt_outlined, size: 18),\n"""
text = replace_once(text, old_after_wrap, new_after_wrap, 'records full width filter')
path.write_text(text)
