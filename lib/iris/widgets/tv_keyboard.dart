import 'package:flutter/material.dart';

/// QWERTY on-screen keyboard for Android TV D-PAD navigation.
/// Each key is a focusable button; D-PAD center types the character.
final class TvKeyboard extends StatelessWidget {
  const TvKeyboard({
    super.key,
    required this.onChar,
    required this.onBackspace,
    required this.onClear,
    this.autofocusFirstKey = false,
  });

  final ValueChanged<String> onChar;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool autofocusFirstKey;

  static const _rows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static const _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusTraversalGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(context, _rows[0], scheme, autofocusIndex: autofocusFirstKey ? 0 : null),
          const SizedBox(height: 4),
          _buildRow(context, _rows[1], scheme),
          const SizedBox(height: 4),
          _buildRow(context, _rows[2], scheme),
          const SizedBox(height: 4),
          _buildRow(context, _digits, scheme),
          const SizedBox(height: 4),
          _buildActionRow(context, scheme),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<String> keys,
    ColorScheme scheme, {
    int? autofocusIndex,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _KeyButton(
            label: keys[i],
            autofocus: autofocusIndex == i,
            onPressed: () => onChar(keys[i].toLowerCase()),
            scheme: scheme,
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.space_bar,
          label: 'SPACE',
          onPressed: () => onChar(' '),
          scheme: scheme,
          width: 120,
        ),
        const SizedBox(width: 4),
        _ActionButton(
          icon: Icons.backspace_outlined,
          label: 'DEL',
          onPressed: onBackspace,
          scheme: scheme,
          width: 80,
        ),
        const SizedBox(width: 4),
        _ActionButton(
          icon: Icons.clear,
          label: 'CLEAR',
          onPressed: onClear,
          scheme: scheme,
          width: 80,
        ),
      ],
    );
  }
}

final class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onPressed,
    required this.scheme,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final ColorScheme scheme;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          focusColor: scheme.primary.withValues(alpha: 0.35),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.scheme,
    required this.width,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ColorScheme scheme;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 42,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          focusColor: scheme.primary.withValues(alpha: 0.35),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: scheme.onSurface),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
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
