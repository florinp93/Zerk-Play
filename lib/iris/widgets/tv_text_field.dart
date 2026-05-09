import 'package:flutter/material.dart';

import 'tv_keyboard.dart';
import 'tv_sidebar_shell.dart' show isTvPlatform;

/// A TextField replacement for Android TV.
/// Displays the current value as a read-only label. On D-PAD select it opens
/// a full-screen dialog with [TvKeyboard] for text entry.
/// On non-TV platforms it renders a standard [TextField].
final class TvTextField extends StatelessWidget {
  const TvTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.decoration,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration? decoration;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (!isTvPlatform) {
      return TextField(
        decoration: decoration,
        onChanged: onChanged,
        autofocus: autofocus,
        controller: TextEditingController(text: value),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final effectiveDecoration = decoration ?? const InputDecoration();

    return InkWell(
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(12),
      focusColor: scheme.primary.withValues(alpha: 0.2),
      onTap: () => _openKeyboardDialog(context),
      child: InputDecorator(
        decoration: effectiveDecoration,
        child: Text(
          value.isEmpty ? (effectiveDecoration.hintText ?? '') : value,
          style: TextStyle(
            color: value.isEmpty
                ? scheme.onSurface.withValues(alpha: 0.4)
                : scheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _openKeyboardDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _TvTextInputDialog(
        initialValue: value,
        title: decoration?.labelText ?? '',
      ),
    );
    if (result != null) {
      onChanged(result);
    }
  }
}

final class _TvTextInputDialog extends StatefulWidget {
  const _TvTextInputDialog({
    required this.initialValue,
    required this.title,
  });

  final String initialValue;
  final String title;

  @override
  State<_TvTextInputDialog> createState() => _TvTextInputDialogState();
}

final class _TvTextInputDialogState extends State<_TvTextInputDialog> {
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: widget.title.isNotEmpty ? Text(widget.title) : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              _text.isEmpty ? '...' : _text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _text.isEmpty
                        ? scheme.onSurface.withValues(alpha: 0.3)
                        : scheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          TvKeyboard(
            autofocusFirstKey: true,
            onChar: (c) => setState(() => _text += c),
            onBackspace: () {
              if (_text.isNotEmpty) {
                setState(() => _text = _text.substring(0, _text.length - 1));
              }
            },
            onClear: () => setState(() => _text = ''),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
