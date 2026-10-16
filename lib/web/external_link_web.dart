import 'package:web/web.dart' as web;

void openExternal(String url) {
  if (url.startsWith('http')) {
    web.window.open(url, '_blank');
    return;
  }
  final anchor = web.HTMLAnchorElement()..href = url;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
