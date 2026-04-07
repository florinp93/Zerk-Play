import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String version;
  final String downloadUrl;
  final String releaseNotes;
}

final class HephaestusService {
  HephaestusService({
    required String githubRepo,
  }) : _githubRepo = githubRepo;

  final String _githubRepo;
  late final String _currentVersion;

  String get currentVersion => _currentVersion;

  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;
  }

  Future<AppUpdateInfo?> checkForUpdate(String? skippedVersion) async {
    if (kDebugMode) {
      debugPrint('[Hephaestus] Checking for updates on $_githubRepo...');
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map) return null;

      final tagName = json['tag_name'] as String?;
      if (tagName == null) return null;

      final remoteVersion = tagName.replaceFirst('v', '').trim();

      // Check if remote is newer than current
      if (!_isNewerVersion(_currentVersion, remoteVersion)) {
        return null; // Up to date
      }

      if (skippedVersion != null && !_isNewerVersion(skippedVersion, remoteVersion)) {
        // User skipped this version or a newer one
        return null;
      }

      final assets = json['assets'];
      if (assets is! List) return null;

      String? downloadUrl;
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (downloadUrl == null) return null;

      final body = json['body'] as String? ?? '';

      return AppUpdateInfo(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        releaseNotes: body,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Hephaestus] Update check failed: $e');
      }
      return null;
    }
  }

  Future<void> downloadAndInstall(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw StateError('Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var received = 0;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}\\zerk_play_update.exe');

      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        received += chunk.length;
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
        sink.add(chunk);
      }

      await sink.flush();
      await sink.close();

      // Launch the installer
      await Process.start(file.path, [], mode: ProcessStartMode.detached);
      exit(0);
    } finally {
      client.close();
    }
  }

  bool _isNewerVersion(String current, String remote) {
    final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final r = i < rParts.length ? rParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
