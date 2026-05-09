import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../l10n/l10n.dart';
import 'app_menu.dart';

bool get isTvPlatform => !kIsWeb && Platform.isAndroid;

/// A left sidebar rail for Android TV D-pad navigation.
/// Collapsed by default; expands when focus enters the sidebar.
final class TvSidebarShell extends StatefulWidget {
  const TvSidebarShell({super.key, required this.child});

  final Widget child;

  @override
  State<TvSidebarShell> createState() => _TvSidebarShellState();
}

final class _TvSidebarShellState extends State<TvSidebarShell>
    with SingleTickerProviderStateMixin {
  static const double _collapsedWidth = 56;
  static const double _expandedWidth = 220;

  late final AnimationController _animController;
  late final Animation<double> _widthAnim;

  bool _expanded = false;
  final FocusNode _homeFocusNode = FocusNode(debugLabel: 'TvSidebar-Home');

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnim = Tween<double>(
      begin: _collapsedWidth,
      end: _expandedWidth,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _homeFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSidebarFocusChange(bool hasFocus) {
    if (hasFocus && !_expanded) {
      setState(() => _expanded = true);
      _animController.forward();
    } else if (!hasFocus && _expanded) {
      setState(() => _expanded = false);
      _animController.reverse();
    }
  }

  void _handleBackButton(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else if (!_expanded) {
      _homeFocusNode.requestFocus();
    } else {
      _showExitDialog(context);
    }
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final l10n = context.l10n;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitApp),
        content: Text(l10n.exitAppConfirm),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.exit),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackButton(context);
      },
      child: Row(
        children: [
          Focus(
            onFocusChange: _onSidebarFocusChange,
            child: AnimatedBuilder(
              animation: _widthAnim,
              builder: (context, child) {
                return SizedBox(
                  width: _widthAnim.value,
                  child: child,
                );
              },
              child: FocusTraversalGroup(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.80),
                  child: SafeArea(
                    right: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          _TvSidebarItem(
                            icon: Icons.home_rounded,
                            label: l10n.home,
                            expanded: _expanded,
                            focusNode: _homeFocusNode,
                            autofocus: true,
                            onPressed: () {
                              final router = GoRouter.of(context);
                              while (router.canPop()) {
                                context.pop();
                              }
                              context.go('/');
                              AppUiScope.of(context).homeRefreshTick.value++;
                            },
                          ),
                          _TvSidebarItem(
                            icon: Icons.search_rounded,
                            label: l10n.search,
                            expanded: _expanded,
                            onPressed: () => context.push('/search'),
                          ),
                          _TvSidebarItem(
                            icon: Icons.movie_rounded,
                            label: l10n.movies,
                            expanded: _expanded,
                            onPressed: () => context.push('/library/movies'),
                          ),
                          _TvSidebarItem(
                            icon: Icons.tv_rounded,
                            label: l10n.series,
                            expanded: _expanded,
                            onPressed: () => context.push('/library/series'),
                          ),
                          _TvSidebarItem(
                            icon: Icons.collections_bookmark_rounded,
                            label: l10n.collections,
                            expanded: _expanded,
                            onPressed: () => context.push('/collections'),
                          ),
                          const SizedBox(height: 24),
                          _TvSidebarItem(
                            icon: Icons.settings_rounded,
                            label: l10n.settings,
                            expanded: _expanded,
                            onPressed: () {
                              showSettingsDialog(
                                context: context,
                                services: services,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

final class _TvSidebarItem extends StatelessWidget {
  const _TvSidebarItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          focusNode: focusNode,
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 24),
                if (expanded) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
