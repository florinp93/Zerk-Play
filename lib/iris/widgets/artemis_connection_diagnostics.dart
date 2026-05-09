import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services/app_services.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/artemis_error_messages.dart';
import '../../l10n/l10n.dart';
import '../../services/artemis/artemis_transport.dart';

Future<void> showArtemisConnectionDiagnosticsDialog({
  required BuildContext context,
  required AppServices services,
}) async {
  final l10n = context.l10n;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.artemisDiagnosticsTitle),
      content: SizedBox(
        width: 560,
        child: ArtemisConnectionDiagnosticsPanel(services: services),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

final class ArtemisConnectionDiagnosticsPanel extends StatefulWidget {
  const ArtemisConnectionDiagnosticsPanel({super.key, required this.services});

  final AppServices services;

  @override
  State<ArtemisConnectionDiagnosticsPanel> createState() =>
      _ArtemisConnectionDiagnosticsPanelState();
}

final class _ArtemisConnectionDiagnosticsPanelState extends State<ArtemisConnectionDiagnosticsPanel> {
  ArtemisReachabilityResult? _last;
  bool _busy = false;
  String? _savedUrl;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final cfg = await widget.services.config.load();
    if (!mounted) return;
    setState(() {
      _loadingPrefs = false;
      _savedUrl = cfg?.jellyseerrUrl.toString();
    });
  }

  Future<void> _runTest() async {
    setState(() {
      _busy = true;
      _last = null;
    });
    final r = await widget.services.artemis.checkReachability();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = r;
    });
  }

  String _summary(AppLocalizations l10n, ArtemisReachabilityResult r) {
    if (r.reachable) return l10n.artemisDiagnosticsReachableYes;
    return messageForReachability(l10n, r);
  }

  void _copyDetails(AppLocalizations l10n) {
    final urlLine = _savedUrl ?? l10n.artemisDiagnosticsNotConfigured;
    final result = _last;
    if (result == null) return;

    final buf = StringBuffer()
      ..writeln('${l10n.artemisDiagnosticsSeerrUrl}: $urlLine')
      ..writeln('${l10n.artemisDiagnosticsResult}: ${_summary(l10n, result)}');
    final detail = result.debugLine;
    if (detail != null && detail.isNotEmpty) {
      buf.writeln('${l10n.artemisDiagnosticsDebugLine}: $detail');
    }

    Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.artemisDiagnosticsCopyDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    if (_loadingPrefs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final urlText = _savedUrl ?? l10n.artemisDiagnosticsNotConfigured;
    final last = _last;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.artemisDiagnosticsSeerrUrl,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            urlText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _runTest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(l10n.artemisDiagnosticsTest),
              ],
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 18),
            Text(
              l10n.artemisDiagnosticsResult,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _summary(l10n, last),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: last.reachable
                        ? scheme.primary
                        : scheme.error.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (!last.reachable && last.debugLine != null && last.debugLine!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.artemisDiagnosticsDebugLine,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                last.debugLine!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.85),
                    ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _copyDetails(l10n),
              icon: const Icon(Icons.copy_rounded),
              label: Text(l10n.artemisDiagnosticsCopy),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n.artemisDiagnosticsInfraTips,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
