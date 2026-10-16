import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

var _holds = 0;
var _blockTextEditing = false;
var _hooked = false;

void holdDialogOverlay() {
  _holds++;
  _ensureHook();
  _apply(interactive: false);
}

void updateDialogOverlay({required bool blockTextEditing}) {
  _blockTextEditing = blockTextEditing;
  if (_holds == 0) _holds = 1;
  _ensureHook();
  _apply(interactive: false);
}

void releaseDialogOverlay() {
  if (_holds > 0) _holds--;
  if (_holds > 0) return;
  _apply(interactive: true);
  _blockTextEditing = false;
}

void _ensureHook() {
  if (_hooked) return;
  _hooked = true;
  SchedulerBinding.instance.addPersistentFrameCallback((_) {
    if (_holds == 0) return;
    _apply(interactive: false);
  });
}

void _apply({required bool interactive}) {
  final selector = interactive || _blockTextEditing
      ? 'flt-platform-view-slot, flt-platform-view, video, iframe, input, textarea'
      : 'flt-platform-view-slot, flt-platform-view, video, iframe';
  final nodes = web.document.querySelectorAll(selector);
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node is! web.HTMLElement) continue;
    if (interactive) {
      node.style.removeProperty('pointer-events');
    } else {
      node.style.pointerEvents = 'none';
    }
  }
  if (interactive || _blockTextEditing) {
    final active = web.document.activeElement;
    if (!interactive && active is web.HTMLElement) {
      active.blur();
    }
  }
}
