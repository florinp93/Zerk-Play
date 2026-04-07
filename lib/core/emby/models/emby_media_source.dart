import 'emby_media_stream.dart';

final class EmbyVideoStreamSummary {
  EmbyVideoStreamSummary({
    required this.displayTitle,
    required this.codec,
    required this.width,
    required this.height,
    required this.videoRange,
    required this.bitDepth,
  });

  final String? displayTitle;
  final String? codec;
  final int? width;
  final int? height;
  final String? videoRange;
  final int? bitDepth;

  static EmbyVideoStreamSummary? fromMediaStreams(List<dynamic>? streams) {
    if (streams == null) return null;
    for (final s in streams) {
      if (s is! Map) continue;
      final map = s.cast<String, dynamic>();
      if (map['Type'] != 'Video') continue;
      final widthValue = map['Width'];
      final heightValue = map['Height'];
      final bitDepthValue = map['BitDepth'];
      return EmbyVideoStreamSummary(
        displayTitle: map['DisplayTitle'] as String? ?? map['Title'] as String?,
        codec: map['Codec'] as String?,
        width: widthValue is num ? widthValue.toInt() : widthValue as int?,
        height: heightValue is num ? heightValue.toInt() : heightValue as int?,
        videoRange: map['VideoRange'] as String?,
        bitDepth: bitDepthValue is num ? bitDepthValue.toInt() : bitDepthValue as int?,
      );
    }
    return null;
  }
}

final class EmbyMediaSource {
  EmbyMediaSource({
    required this.id,
    required this.name,
    required this.path,
    required this.container,
    required this.size,
    required this.bitrate,
    required this.streamUrl,
    required this.directStreamUrl,
    required this.transcodingUrl,
    required this.video,
    required this.audioStreams,
    required this.subtitleStreams,
  });

  final String id;
  final String? name;
  final String? path;
  final String? container;
  final int? size;
  final int? bitrate;
  final Uri streamUrl;
  final Uri? directStreamUrl;
  final Uri? transcodingUrl;
  final EmbyVideoStreamSummary? video;
  final List<EmbyAudioStream> audioStreams;
  final List<EmbySubtitleStream> subtitleStreams;

  factory EmbyMediaSource.fromJson(
    Map<String, dynamic> json, {
    required Uri serverUrl,
    required String accessToken,
  }) {
    Uri? resolveUrl(String? value) {
      if (value == null || value.isEmpty) return null;
      final parsed = Uri.parse(value);
      final resolved = parsed.hasScheme ? parsed : serverUrl.resolveUri(parsed);
      return resolved.replace(
        queryParameters: {
          ...resolved.queryParameters,
          'api_key': resolved.queryParameters['api_key'] ?? accessToken,
        },
      );
    }

    final id = (json['Id'] as String?) ?? '';
    final directStreamUrlRaw = json['DirectStreamUrl'] as String?;
    final transcodingUrlRaw = json['TranscodingUrl'] as String?;
    final autoUrl = (directStreamUrlRaw?.isNotEmpty ?? false)
        ? directStreamUrlRaw!
        : (transcodingUrlRaw?.isNotEmpty ?? false)
            ? transcodingUrlRaw!
            : null;

    if (autoUrl == null) {
      throw StateError('No playable url returned by Emby media source.');
    }

    final directStreamUrl = resolveUrl(directStreamUrlRaw);
    final transcodingUrl = resolveUrl(transcodingUrlRaw);
    final streamUrl = resolveUrl(autoUrl)!;

    final sizeValue = json['Size'];
    final bitrateValue = json['Bitrate'];
    final mediaStreams = json['MediaStreams'];
    final streamsList = mediaStreams is List ? mediaStreams : null;

    final audioStreams = <EmbyAudioStream>[];
    final subtitleStreams = <EmbySubtitleStream>[];
    if (streamsList != null) {
      for (final stream in streamsList) {
        if (stream is! Map) continue;
        final map = stream.cast<String, dynamic>();
        final type = map['Type'];
        if (type == 'Audio') {
          final audio = EmbyAudioStream.fromJson(map);
          if (audio.index >= 0) audioStreams.add(audio);
        } else if (type == 'Subtitle') {
          final sub = EmbySubtitleStream.fromJson(map);
          if (sub.index >= 0) subtitleStreams.add(sub);
        }
      }
    }

    return EmbyMediaSource(
      id: id,
      name: json['Name'] as String?,
      path: json['Path'] as String?,
      container: json['Container'] as String?,
      size: sizeValue is num ? sizeValue.toInt() : sizeValue as int?,
      bitrate: bitrateValue is num ? bitrateValue.toInt() : bitrateValue as int?,
      streamUrl: streamUrl,
      directStreamUrl: directStreamUrl,
      transcodingUrl: transcodingUrl,
      video: EmbyVideoStreamSummary.fromMediaStreams(streamsList),
      audioStreams: audioStreams,
      subtitleStreams: subtitleStreams,
    );
  }
}

