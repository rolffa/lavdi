import 'dart:js_interop';

import '../core/errors.dart';
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

@JS()
extension type _LavdiPush(JSObject _) implements JSObject {
  external bool supported();
  external JSPromise<JSObject> subscribe(JSString publicKey);
  external JSPromise<JSObject> unsubscribe();
  external JSPromise<JSAny?> show(JSString title, JSString body, JSString url);
}

@JS('lavdiPush')
external _LavdiPush? get _lavdiPush;

bool browserPushSupported() {
  final bridge = _lavdiPush;
  if (bridge == null) return false;
  try {
    return bridge.supported();
  } catch (_) {
    return false;
  }
}

Future<BrowserPushKeys> subscribeBrowserPush(String publicKey) async {
  final bridge = _lavdiPush;
  if (bridge == null || !browserPushSupported()) {
    throw PortalException('Nettleseren støtter ikke push-varsler.');
  }
  final raw = (await bridge.subscribe(publicKey.toJS).toDart).dartify();
  if (raw is! Map) {
    throw PortalException('Kunne ikke slå på varsler.');
  }
  final error = raw['error'];
  if (error == 'denied') {
    throw PortalException('Varsler er blokkert i nettleseren.');
  }
  if (error != null) {
    final text = '$error';
    if (text.contains('push service not available')) {
      throw PortalException('Denne nettleseren kan ikke ta imot push-varsler.');
    }
    throw PortalException('Kunne ikke slå på varsler.');
  }
  final endpoint = raw['endpoint'];
  final p256dh = raw['p256dh'];
  final auth = raw['auth'];
  if (endpoint is! String || p256dh is! String || auth is! String || endpoint.isEmpty) {
    throw PortalException('Kunne ikke slå på varsler.');
  }
  return BrowserPushKeys(endpoint: endpoint, p256dh: p256dh, auth: auth);
}

Future<String> unsubscribeBrowserPush() async {
  final bridge = _lavdiPush;
  if (bridge == null) return '';
  try {
    final raw = (await bridge.unsubscribe().toDart).dartify();
    if (raw is Map && raw['endpoint'] is String) return raw['endpoint'] as String;
  } catch (_) {}
  return '';
}

Future<void> showBrowserPush(PushNotice notice) async {
  final bridge = _lavdiPush;
  if (bridge == null || !browserPushSupported()) return;
  try {
    await bridge.show(notice.title.toJS, notice.body.toJS, notice.url.toJS).toDart;
  } catch (_) {}
}
