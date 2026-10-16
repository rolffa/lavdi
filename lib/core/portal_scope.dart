import 'package:flutter/widgets.dart';

import '../data/portal_repository.dart';

class PortalScope extends InheritedWidget {
  const PortalScope({
    super.key,
    required this.repository,
    required this.demoMode,
    required super.child,
  });

  final PortalRepository repository;
  final bool demoMode;

  static PortalScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PortalScope>();
    assert(scope != null, 'PortalScope mangler over denne widgeten.');
    return scope!;
  }

  @override
  bool updateShouldNotify(PortalScope oldWidget) {
    return repository != oldWidget.repository || demoMode != oldWidget.demoMode;
  }
}
