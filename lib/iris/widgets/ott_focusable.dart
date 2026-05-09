import 'package:flutter/material.dart';

final class OttFocusableCard extends StatefulWidget {
  const OttFocusableCard({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.borderRadius = 14,
    this.focusScale = 1.07,
    this.hoverScale = 1.02,
    this.focusBorderWidth = 2.5,
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

final class _OttFocusableCardState extends State<OttFocusableCard>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  bool _hovered = false;

  late final AnimationController _controller;
  late final Animation<double> _curve;

  // The controller target when only hovered (not focused) so hover scale is
  // naturally reached within the same 0→1 linear mapping as focus.
  double get _hoverTarget =>
      (widget.hoverScale - 1.0) / (widget.focusScale - 1.0).clamp(0.001, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _curve.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFocusHighlight(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      _controller.animateTo(1.0);
    } else if (_hovered) {
      _controller.animateTo(_hoverTarget);
    } else {
      _controller.reverse();
    }
  }

  void _onHoverHighlight(bool hovered) {
    setState(() => _hovered = hovered);
    if (_focused) return;
    if (hovered) {
      _controller.animateTo(_hoverTarget);
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _curve.value;

    final scale = 1.0 + t * (widget.focusScale - 1.0);

    final shadowColor = _focused
        ? Colors.white.withValues(alpha: 0.55 * t)
        : scheme.primary.withValues(alpha: 0.35 * t);
    final borderColor = _focused
        ? Colors.white.withValues(alpha: t)
        : scheme.primary.withValues(alpha: 0.65 * t);

    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: FocusableActionDetector(
        onShowFocusHighlight: _onFocusHighlight,
        onShowHoverHighlight: _onHoverHighlight,
        mouseCursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Transform.scale(
          scale: scale,
          child: Stack(
            children: [
              // Shadow decoration (background — extends outside card bounds).
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: t > 0.01
                      ? [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: (_focused ? 32.0 : 18.0) * t,
                            spreadRadius: (_focused ? 4.0 : 1.0) * t,
                          ),
                        ]
                      : const [],
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
              // Border overlay — drawn ON TOP of the card content so it is
              // always visible regardless of what the child paints.
              if (t > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        border: Border.all(
                          color: borderColor,
                          width: widget.focusBorderWidth,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
