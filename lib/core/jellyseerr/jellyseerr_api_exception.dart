final class JellyseerrApiException implements Exception {
  JellyseerrApiException({
    required this.statusCode,
    required this.reasonPhrase,
    required this.body,
    this.uri,
  });

  final int statusCode;
  final String? reasonPhrase;
  final Object? body;
  final Uri? uri;

  bool get isRequestLimitReached {
    if (statusCode == 429) return true;
    final b = body;
    if (b is Map) {
      final error = b['error'];
      if (error is String && error.toLowerCase().contains('request limit')) return true;
      final message = b['message'];
      if (message is String && message.toLowerCase().contains('request limit')) return true;
      final code = b['code'];
      if (code is String && code.toLowerCase().contains('limit')) return true;
    }
    if (b is String && b.toLowerCase().contains('request limit')) return true;
    return false;
  }

  @override
  String toString() {
    return 'JellyseerrApiException(statusCode: $statusCode, reasonPhrase: $reasonPhrase, body: $body, uri: $uri)';
  }
}

