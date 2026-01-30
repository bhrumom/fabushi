import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void registerGlobeView(String viewId, String htmlFile) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = html.IFrameElement()
      ..src = htmlFile
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
}

void sendMessageToGlobe() {
  html.window.postMessage({'type': 'startTransfer'}, '*');
}
