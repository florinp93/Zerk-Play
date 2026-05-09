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

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      minimumSize: Size(800, 500),
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    final prefs = await AppPrefs.load();
    if (prefs.startFullscreen) {
      await windowManager.setFullScreen(true);
    }

    final services = await AppServices.create();
    runApp(App(services: services));
    return;
  }

  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // Start loading services while showing the splash so there is no black screen.
  runApp(_SplashLoader(servicesFuture: AppServices.create()));
}

final class _SplashLoader extends StatefulWidget {
  const _SplashLoader({required this.servicesFuture});
  final Future<AppServices> servicesFuture;

  @override
  State<_SplashLoader> createState() => _SplashLoaderState();
}

final class _SplashLoaderState extends State<_SplashLoader>
    with SingleTickerProviderStateMixin {
  AppServices? _services;
  late final AnimationController _fadeOut;

  @override
  void initState() {
    super.initState();
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeOut.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });

    widget.servicesFuture.then((s) {
      if (!mounted) return;
      setState(() => _services = s);
      // Let the real App paint one frame before fading the splash out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fadeOut.forward();
      });
    });
  }

  @override
  void dispose() {
    _fadeOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;

    if (services != null && _fadeOut.isCompleted) {
      return App(services: services);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          if (services != null) App(services: services),
          FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(parent: _fadeOut, curve: Curves.easeIn),
            ),
            child: const _SplashScreen(),
          ),
        ],
      ),
    );
  }
}

final class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

final class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0A0F),
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'ZERK PLAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
