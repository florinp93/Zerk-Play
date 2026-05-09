import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/services/app_services.dart';
import 'iris/settings/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isAndroidTv = !kIsWeb && Platform.isAndroid;

  if (!isAndroidTv) {
    MediaKit.ensureInitialized();
  }

  if (isAndroidTv) {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB
    PaintingBinding.instance.imageCache.maximumSize = 200;
  }

  // Initialise window_manager on desktop platforms.
  if (!isAndroidTv) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      minimumSize: Size(800, 500),
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Apply saved fullscreen preference before the first frame.
    final prefs = await AppPrefs.load();
    if (prefs.startFullscreen) {
      await windowManager.setFullScreen(true);
    }
  }

  final services = await AppServices.create();
  runApp(App(services: services));
}
