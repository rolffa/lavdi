import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/portal_repository.dart';
import '../../models/push_notice.dart';
import '../../web/push_client.dart';

class PushNoticeBridge extends StatefulWidget {
  const PushNoticeBridge({
    super.key,
    required this.repository,
    required this.child,
  });

  final PortalRepository repository;
  final Widget child;

  @override
  State<PushNoticeBridge> createState() => _PushNoticeBridgeState();
}

class _PushNoticeBridgeState extends State<PushNoticeBridge> {
  StreamSubscription<PushNotice>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.pushNotices.listen((notice) {
      unawaited(showBrowserPush(notice));
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
