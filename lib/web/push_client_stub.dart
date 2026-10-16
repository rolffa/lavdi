import '../models/push_notice.dart';

class BrowserPushKeys {
  const BrowserPushKeys({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}

bool browserPushSupported() => false;

Future<BrowserPushKeys> subscribeBrowserPush(String publicKey) async {
  throw UnsupportedError('Push-varsler krever nettleseren.');
}

Future<String> unsubscribeBrowserPush() async => '';

Future<void> showBrowserPush(PushNotice notice) async {}
