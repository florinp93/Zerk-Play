import 'package:flutter/material.dart';

import '../services/hephaestus/hephaestus_service.dart';
import 'app.dart';

class UpdaterWrapper extends StatefulWidget {
  const UpdaterWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<UpdaterWrapper> createState() => _UpdaterWrapperState();
}

class _UpdaterWrapperState extends State<UpdaterWrapper> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdates();
      });
    }
  }

  Future<void> _checkForUpdates() async {
    final services = AppServicesScope.of(context);
    final skipped = await services.config.getSkippedUpdateVersion();
    final update = await services.hephaestus.checkForUpdate(skipped);

    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    final dialogContext = appNavigatorKey.currentContext;
    if (dialogContext == null) return;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(update: update),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});

  final AppUpdateInfo update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _skip() async {
    final services = AppServicesScope.of(context);
    await services.config.setSkippedUpdateVersion(widget.update.version);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    final services = AppServicesScope.of(context);
    try {
      await services.hephaestus.downloadAndInstall(
        widget.update.downloadUrl,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Update Available'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${widget.update.version} is available.',
              style: theme.textTheme.titleMedium,
            ),
            if (widget.update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Release Notes:'),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Text(
                    widget.update.releaseNotes,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                'Error: $_error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text('Downloading... ${(_progress * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: _skip,
                child: const Text('Skip this update'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: _install,
                child: const Text('Update Now'),
              ),
            ],
    );
  }
}
