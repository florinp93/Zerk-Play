import 'package:flutter/material.dart';

/// Wraps a horizontally scrollable list item so that when a descendant receives
/// focus, the parent viewport scrolls to ensure it's visible.
///
/// [skipTraversal] is set so D-PAD traversal targets the inner focusable widget
/// (e.g. InkWell inside OttFocusableCard) directly, not this wrapper node.
/// [canRequestFocus] must stay true (default) – setting it to false would
/// prevent all descendants from receiving focus.
final class TvFocusScrollItem extends StatelessWidget {
  const TvFocusScrollItem({
    super.key,
    required this.scrollController,
    required this.child,
  });

  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (!hasFocus) return;
        _ensureVisible(context);
      },
      child: child,
    );
  }

  void _ensureVisible(BuildContext context) {
    if (!scrollController.hasClients) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.4,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }
}
