import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_assets.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';

final class JkddAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JkddAppBar({
    super.key,
    required this.online,
    required this.pendingItems,
    required this.onSettings,
  });

  final bool online;
  final int pendingItems;
  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return AppBar(
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.fieldTimeLogoHorizontal,
            height: compact ? 32 : 44,
            width: compact ? 154 : null,
            fit: BoxFit.contain,
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 34,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(width: 12),
            Text(
              'v1.0.0',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.gray),
            ),
          ],
        ],
      ),
      actions: compact
          ? [
              IconButton(
                onPressed: onSettings,
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ]
          : [
              _HeaderStatus(online: online, pendingItems: pendingItems),
              IconButton(
                onPressed: onSettings,
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 8),
            ],
    );
  }
}

final class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({required this.online, required this.pendingItems});

  final bool online;
  final int pendingItems;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: online ? AppColors.green : AppColors.amber,
          ),
          const SizedBox(width: 4),
          Text('$pendingItems'),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          color: online ? AppColors.green : AppColors.amber,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(online ? 'Online' : 'Offline'),
        const SizedBox(width: 16),
        const Icon(Icons.sync_problem_outlined, size: 20),
        const SizedBox(width: 6),
        Text('$pendingItems pending'),
      ],
    );
  }
}
