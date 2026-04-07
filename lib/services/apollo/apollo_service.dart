import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/emby/models/emby_playback_info.dart';
import '../janus/janus_service.dart';
import 'mpv_device_profile.dart';

final class ApolloService {
  ApolloService({required JanusService janus}) : _janus = janus;

  final JanusService _janus;

  Timer? _progressTimer;

  Future<EmbyPlaybackInfo> getPlaybackInfo(
    String itemId, {
    int? maxStreamingBitrate,
  }) async {
    final session = _janus.session;
    final json = await _janus.client.postJson(
      '/Items/$itemId/PlaybackInfo',
      queryParameters: {
        'UserId': session.userId,
      },
      body: {
        'DeviceProfile': buildMpvDeviceProfile(),
        ...?maxStreamingBitrate == null
            ? null
            : <String, Object?>{
                'MaxStreamingBitrate': maxStreamingBitrate,
              },
      },
    );

    await _debugDumpPlaybackInfo(itemId: itemId, json: json);

    return EmbyPlaybackInfo.fromJson(
      json,
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
    );
  }

  Future<String?> getNextUpEpisodeId({
    required String seriesId,
    String? excludeItemId,
  }) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Shows/NextUp',
      queryParameters: {
        'UserId': session.userId,
        'SeriesId': seriesId,
        'Limit': '2',
        'EnableUserData': 'true',
        'Fields': 'Overview,ProductionYear,ImageTags,UserData,Chapters,SeriesId,SeasonId,ParentId',
      },
    );
    final items = json['Items'];
    if (items is! List || items.isEmpty) return null;
    for (final entry in items) {
      if (entry is! Map) continue;
      final id = entry['Id'];
      if (id is! String || id.isEmpty) continue;
      if (excludeItemId != null && excludeItemId.isNotEmpty && id == excludeItemId) {
        continue;
      }
      return id;
    }
    return null;
  }

  Future<void> registerCapabilities() async {
    final session = _janus.session;
    await _janus.client.postNoContent(
      '/Sessions/Capabilities',
      body: {
        'PlayableMediaTypes': ['Video', 'Audio'],
        'SupportedCommands': [
          'Play',
          'Pause',
          'Stop',
          'Seek',
          'SetVolume',
          'DisplayMessage',
        ],
        'DeviceProfile': buildMpvDeviceProfile(),
        'AppDescription': 'Zerk Play: High-Performance Windows Client',
        'DeviceId': session.deviceId,
      },
    );
  }

  Future<void> reportPlaybackStart({
    required String itemId,
    required EmbyPlaybackInfo info,
    required int positionTicks,
  }) async {
    final session = _janus.session;
    await _janus.client.postNoContent(
      '/Sessions/Playing',
      body: {
        'ItemId': itemId,
        'PlaySessionId': info.playSessionId,
        'MediaSourceId': info.mediaSourceId,
        'CanSeek': true,
        'IsPaused': false,
        'PositionTicks': positionTicks,
        'DeviceId': session.deviceId,
        'DeviceName': 'Zerk Play Windows',
      },
    );
  }

  Future<void> reportPlaybackProgress({
    required String itemId,
    required EmbyPlaybackInfo info,
    required int positionTicks,
    required bool isPaused,
    required String eventName,
  }) async {
    final session = _janus.session;
    await _janus.client.postNoContent(
      '/Sessions/Playing/Progress',
      body: {
        'ItemId': itemId,
        'PlaySessionId': info.playSessionId,
        'MediaSourceId': info.mediaSourceId,
        'CanSeek': true,
        'IsPaused': isPaused,
        'PositionTicks': positionTicks,
        'EventName': eventName,
        'DeviceId': session.deviceId,
      },
    );
  }

  void startProgressReporting({
    required String itemId,
    required EmbyPlaybackInfo info,
    required int Function() positionTicks,
    required bool Function() isPaused,
  }) {
    stopProgressReporting();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await reportPlaybackProgress(
          itemId: itemId,
          info: info,
          positionTicks: positionTicks(),
          isPaused: isPaused(),
          eventName: 'timeupdate',
        );
      } catch (_) {}
    });
  }

  void stopProgressReporting() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> reportStopped({
    required String itemId,
    required EmbyPlaybackInfo info,
    required int positionTicks,
  }) async {
    stopProgressReporting();
    final session = _janus.session;
    await _janus.client.postNoContent(
      '/Sessions/Playing/Stopped',
      body: {
        'ItemId': itemId,
        'PlaySessionId': info.playSessionId,
        'MediaSourceId': info.mediaSourceId,
        'PositionTicks': positionTicks,
        'DeviceId': session.deviceId,
      },
    );
  }

  Future<void> markPlayed(String itemId) async {
    final session = _janus.session;
    await _janus.client.postNoContent(
      '/Users/${session.userId}/PlayedItems/$itemId',
    );
  }

  Future<void> markUnplayed(String itemId) async {
    final session = _janus.session;
    await _janus.client.deleteNoContent(
      '/Users/${session.userId}/PlayedItems/$itemId',
    );
  }
}

const bool _kDumpPlaybackInfoToDisk = false;

Future<void> _debugDumpPlaybackInfo({
  required String itemId,
  required Map<String, dynamic> json,
}) async {
  if (!kDebugMode || !_kDumpPlaybackInfoToDisk) return;
  try {
    final sanitized = _redact(json);
    final outDir = Directory('emby_dumps');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final file = File('${outDir.path}${Platform.pathSeparator}playbackinfo_$itemId.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(sanitized),
    );
    debugPrint('[ApolloService] PlaybackInfo dumped: ${file.path}');
  } catch (e) {
    debugPrint('[ApolloService] PlaybackInfo dump failed: $e');
  }
}

Object? _redact(Object? value) {
  if (value is Map) {
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key is String ? entry.key as String : '${entry.key}';
      final lower = key.toLowerCase();
      if (lower.contains('token') || lower.contains('accesstoken') || lower.contains('apikey')) {
        out[key] = '[REDACTED]';
        continue;
      }
      out[key] = _redact(entry.value);
    }
    return out;
  }

  if (value is List) {
    return value.map(_redact).toList(growable: false);
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.queryParameters.containsKey('api_key')) {
        return uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'api_key': '[REDACTED]',
          },
        ).toString();
      }
    }
  }

  return value;
}
