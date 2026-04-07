import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import 'app_menu.dart';

final class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  bool _wasOnHome = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    final onHome = state.matchedLocation == '/';
    if (onHome && !_wasOnHome) {
      final scope = AppUiScope.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scope.homeRefreshTick.value = scope.homeRefreshTick.value + 1;
      });
    }
    _wasOnHome = onHome;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final padded = mq.padding.copyWith(
      top: mq.padding.top + AppFloatingMenu.reservedTopPadding,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaQuery(
          data: mq.copyWith(padding: padded),
          child: widget.child,
        ),
        const AppFloatingMenu(),
        ValueListenableBuilder<bool>(
          valueListenable: AppUiScope.of(context).showFeedbackButton,
          builder: (context, show, _) {
            if (!show) return const SizedBox.shrink();
            return SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 14),
                  child: _FeedbackButton(
                    onPressed: () => _openExternalUrl('https://discord.gg/GnqY9z6zry'),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _openExternalUrl(String url) async {
  if (kIsWeb) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    if (Platform.isWindows) {
      await Process.start(
        'explorer',
        [uri.toString()],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    if (Platform.isMacOS) {
      await Process.start(
        'open',
        [uri.toString()],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    if (Platform.isLinux) {
      await Process.start(
        'xdg-open',
        [uri.toString()],
        mode: ProcessStartMode.detached,
      );
      return;
    }
  } catch (_) {}
}

final class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Tooltip(
      message: 'Provide feedback',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: surface.withValues(alpha: 0.40),
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_rounded, size: 20, color: Colors.white.withValues(alpha: 0.92)),
                    const SizedBox(width: 8),
                    Text(
                      'Feedback',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
