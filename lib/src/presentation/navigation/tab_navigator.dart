import 'package:flutter/material.dart';

typedef PopPageCallback = bool Function(Route<dynamic> route, dynamic result);

class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.pages,
    required this.onPopPage,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final List<Page<void>> pages;
  final PopPageCallback onPopPage;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onPopPage: (route, result) => onPopPage(route, result),
    );
  }
}
