final class EmbyAudioStream {
  EmbyAudioStream({
    required this.index,
    required this.title,
    required this.language,
    required this.codec,
    required this.channels,
    required this.isDefault,
  });

  final int index;
  final String? title;
  final String? language;
  final String? codec;
  final int? channels;
  final bool isDefault;

  factory EmbyAudioStream.fromJson(Map<String, dynamic> json) {
    final indexValue = json['Index'];
    final channelsValue = json['Channels'];
    return EmbyAudioStream(
      index: indexValue is num ? indexValue.toInt() : (indexValue as int?) ?? -1,
      title: json['DisplayTitle'] as String? ?? json['Title'] as String?,
      language: json['Language'] as String?,
      codec: json['Codec'] as String?,
      channels: channelsValue is num ? channelsValue.toInt() : channelsValue as int?,
      isDefault: (json['IsDefault'] as bool?) ?? false,
    );
  }
}

final class EmbySubtitleStream {
  EmbySubtitleStream({
    required this.index,
    required this.title,
    required this.language,
    required this.codec,
    required this.isDefault,
    required this.isForced,
    required this.isExternal,
    required this.deliveryUrl,
    required this.isTextSubtitleStream,
  });

  final int index;
  final String? title;
  final String? language;
  final String? codec;
  final bool isDefault;
  final bool isForced;
  final bool isExternal;
  final String? deliveryUrl;
  final bool? isTextSubtitleStream;

  factory EmbySubtitleStream.fromJson(Map<String, dynamic> json) {
    final indexValue = json['Index'];
    return EmbySubtitleStream(
      index: indexValue is num ? indexValue.toInt() : (indexValue as int?) ?? -1,
      title: json['DisplayTitle'] as String? ?? json['Title'] as String?,
      language: json['Language'] as String?,
      codec: json['Codec'] as String?,
      isDefault: (json['IsDefault'] as bool?) ?? false,
      isForced: (json['IsForced'] as bool?) ?? false,
      isExternal: (json['IsExternal'] as bool?) ?? false,
      deliveryUrl: json['DeliveryUrl'] as String?,
      isTextSubtitleStream: json['IsTextSubtitleStream'] as bool?,
    );
  }
}
