import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'preview_app.dart';

/// Offline design entry point. Does not initialize auth, Firebase or API clients.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final key = GlobalKey<DesignPreviewState>();
  registerExtension('ext.moabook.preview', (method, parameters) async {
    final state = key.currentState;
    if (state == null) {
      return ServiceExtensionResponse.error(-32000, 'Preview is not ready');
    }
    try {
      state.showPreview(
        parameters['screen'] ?? 'shelf',
        parameters['style'] ?? 'A',
        page: int.tryParse(parameters['page'] ?? '') ?? 0,
      );
      await WidgetsBinding.instance.endOfFrame;
      return ServiceExtensionResponse.result(
        jsonEncode({
          'screen': state.screen,
          'style': state.mood.name.toUpperCase(),
          if (parameters.containsKey('page')) 'page': state.shelfPage,
          if (parameters.containsKey('page')) 'pageCount': state.shelfPageCount,
        }),
      );
    } catch (error) {
      return ServiceExtensionResponse.error(-32000, error.toString());
    }
  });
  runApp(DesignPreviewApp(previewKey: key));
}
