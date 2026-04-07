import 'emby_media_stream.dart';
import 'emby_media_source.dart';

final class EmbyPlaybackInfo {
  EmbyPlaybackInfo({
    required this.serverUrl,
    required this.playSessionId,
    required this.mediaSources,
    required this.mediaSourceId,
    required this.streamUrl,
    required this.directStreamUrl,
    required this.transcodingUrl,
    required this.audioStreams,
    required this.subtitleStreams,
  });

  final Uri serverUrl;
  final String playSessionId;
  final List<EmbyMediaSource> mediaSources;
  final String mediaSourceId;
  final Uri streamUrl;
  final Uri? directStreamUrl;
  final Uri? transcodingUrl;
  final List<EmbyAudioStream> audioStreams;
  final List<EmbySubtitleStream> subtitleStreams;

  EmbyMediaSource get activeMediaSource {
    for (final s in mediaSources) {
      if (s.id == mediaSourceId) return s;
    }
    return mediaSources.first;
  }

  EmbyPlaybackInfo selectMediaSource(String id) {
    if (id == mediaSourceId) return this;
    EmbyMediaSource? chosen;
    for (final s in mediaSources) {
      if (s.id == id) {
        chosen = s;
        break;
      }
    }
    final active = chosen ?? mediaSources.first;
    return EmbyPlaybackInfo(
      serverUrl: serverUrl,
      playSessionId: playSessionId,
      mediaSources: mediaSources,
      mediaSourceId: active.id,
      streamUrl: active.streamUrl,
      directStreamUrl: active.directStreamUrl,
      transcodingUrl: active.transcodingUrl,
      audioStreams: active.audioStreams,
      subtitleStreams: active.subtitleStreams,
    );
  }

  factory EmbyPlaybackInfo.fromJson(
    Map<String, dynamic> json, {
    required Uri serverUrl,
    required String accessToken,
  }) {
    final playSessionId = (json['PlaySessionId'] as String?) ?? '';
    final mediaSources = json['MediaSources'];
    if (mediaSources is! List || mediaSources.isEmpty) {
      throw StateError('No media sources returned by Emby.');
    }

    final parsedSources = <EmbyMediaSource>[];
    for (final s in mediaSources) {
      if (s is! Map) continue;
      parsedSources.add(
        EmbyMediaSource.fromJson(
          s.cast<String, dynamic>(),
          serverUrl: serverUrl,
          accessToken: accessToken,
        ),
      );
    }
    if (parsedSources.isEmpty) {
      throw StateError('No valid media sources returned by Emby.');
    }

    final active = parsedSources.first;

    return EmbyPlaybackInfo(
      serverUrl: serverUrl,
      playSessionId: playSessionId,
      mediaSources: parsedSources,
      mediaSourceId: active.id,
      streamUrl: active.streamUrl,
      directStreamUrl: active.directStreamUrl,
      transcodingUrl: active.transcodingUrl,
      audioStreams: active.audioStreams,
      subtitleStreams: active.subtitleStreams,
    );
  }
}
