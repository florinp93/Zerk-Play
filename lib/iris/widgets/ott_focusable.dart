import 'package:flutter/material.dart';

final class OttFocusableCard extends StatefulWidget {
  const OttFocusableCard({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.borderRadius = 14,
    this.focusScale = 1.04,
    this.hoverScale = 1.02,
    this.focusBorderWidth = 2,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final double focusScale;
  final double hoverScale;
  final double focusBorderWidth;

  @override
  State<OttFocusableCard> createState() => _OttFocusableCardState();
}

final class _OttFocusableCardState extends State<OttFocusableCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glow = scheme.primary.withValues(alpha: 0.35);
    final borderAlpha = _focused ? 1.0 : (_hovered ? 0.65 : 0.0);
    final border = scheme.primary.withValues(alpha: borderAlpha);
    final active = _focused || _hovered;

    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      mouseCursor:
          widget.onPressed == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _focused
            ? widget.focusScale
            : _hovered
                ? widget.hoverScale
                : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: glow,
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
            border: Border.all(
              color: border,
              width: widget.focusBorderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onLongPress: widget.onLongPress,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

