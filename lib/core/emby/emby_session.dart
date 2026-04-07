final class EmbySession {
  EmbySession({
    required this.serverUrl,
    required this.clientName,
    required this.deviceName,
    required this.deviceId,
    required this.appVersion,
    required this.userId,
    required this.accessToken,
  });

  final Uri serverUrl;
  final String clientName;
  final String deviceName;
  final String deviceId;
  final String appVersion;
  final String userId;
  final String accessToken;
}

