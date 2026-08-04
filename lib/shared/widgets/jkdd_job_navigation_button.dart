import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:url_launcher/url_launcher.dart';

final class JkddJobNavigationButton extends StatelessWidget {
  const JkddJobNavigationButton({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
    this.compact = true,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled =
        address.trim().isNotEmpty || (latitude != null && longitude != null);
    final button = compact
        ? Tooltip(
            message: context.tr('maps.routeToJob'),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: enabled ? () => _showChoices(context) : null,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_outlined, size: 20),
                    Text(
                      context.tr('maps.routeToJob'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: enabled ? () => _showChoices(context) : null,
            icon: const Icon(Icons.near_me_outlined),
            label: Text(context.tr('maps.routeToJob')),
          );
    return button;
  }

  Future<void> _showChoices(BuildContext context) async {
    final choices = _choices();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('maps.chooseApp'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final choice in choices)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Icon(choice.icon),
                      title: Text(choice.label),
                      subtitle: Text(context.tr(choice.actionLabelKey)),
                      onTap: () async {
                        Navigator.pop(context);
                        await launchUrl(
                          choice.uri,
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: '_blank',
                        );
                      },
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('common.cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_MapChoice> _choices() {
    final query = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : address.trim();
    final encoded = Uri.encodeComponent(query);
    return [
      _MapChoice(
        label: 'Waze',
        actionLabelKey: 'maps.openWaze',
        icon: Icons.alt_route_outlined,
        uri: Uri.parse('https://waze.com/ul?q=$encoded&navigate=yes'),
      ),
      _MapChoice(
        label: 'Google Maps',
        actionLabelKey: 'maps.openGoogleMaps',
        icon: Icons.map,
        uri: Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encoded'),
      ),
      _MapChoice(
        label: 'Apple Maps',
        actionLabelKey: 'maps.openAppleMaps',
        icon: Icons.map_outlined,
        uri: Uri.parse('https://maps.apple.com/?q=$encoded'),
      ),
    ];
  }
}

final class _MapChoice {
  const _MapChoice({
    required this.label,
    required this.actionLabelKey,
    required this.icon,
    required this.uri,
  });

  final String label;
  final String actionLabelKey;
  final IconData icon;
  final Uri uri;
}
