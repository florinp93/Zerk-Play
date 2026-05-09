/// Classifies transport-layer failures from Jellyseerr / HTTP clients so the UI
/// and logcat output can distinguish TLS, DNS, and generic network issues.
library;

/// Ordered specificity: TLS/DNS checks run before broad SocketException heuristics.
enum ArtemisTransportIssue {
  tls,
  dns,
  network,
  /// Host responded but is not Jellyseerr (e.g. Emby URL in the *seerr field).
  wrongService,
  unknown,
}

ArtemisTransportIssue categorizeArtemisTransportError(Object? error) {
  if (error == null) return ArtemisTransportIssue.unknown;
  final s = error.toString().toLowerCase();

  if (_looksLikeTls(s)) return ArtemisTransportIssue.tls;
  if (_looksLikeDns(s)) return ArtemisTransportIssue.dns;
  if (_looksLikeNetwork(s)) return ArtemisTransportIssue.network;
  return ArtemisTransportIssue.unknown;
}

bool _looksLikeTls(String s) {
  return s.contains('handshakeexception') ||
      s.contains('tlsexception') ||
      s.contains('certificate_verify_failed') ||
      s.contains('cert_verify') ||
      s.contains('bad_certificate') ||
      (s.contains('ssl') && s.contains('error')) ||
      (s.contains('tls') && (s.contains('handshake') || s.contains('fatal')));
}

bool _looksLikeDns(String s) {
  return s.contains('failed host lookup') ||
      s.contains('nodename nor servname') ||
      s.contains('no address associated with hostname') ||
      s.contains('temporary failure in name resolution') ||
      s.contains('name or service not known');
}

bool _looksLikeNetwork(String s) {
  return s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('connection timed out') ||
      s.contains('connection reset') ||
      s.contains('connection refused') ||
      s.contains('network is unreachable') ||
      s.contains('host is unreachable') ||
      s.contains('broken pipe') ||
      s.contains('software caused connection abort');
}

/// Outcome of `ArtemisService.checkReachability`.
final class ArtemisReachabilityResult {
  const ArtemisReachabilityResult({
    required this.reachable,
    this.issue,
    this.debugLine,
  });

  final bool reachable;
  final ArtemisTransportIssue? issue;
  /// Full diagnostic line for logcat; non-null when [reachable] is false.
  final String? debugLine;
}

/// Single-line summary for `adb logcat` / Flutter tooling (avoid multi-line in prod logs).
String artemisConnectivityDebugLine(Object error, [StackTrace? stackTrace]) {
  final type = error.runtimeType;
  final msg = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  final truncated = msg.length > 320 ? '${msg.substring(0, 320)}…' : msg;
  final buf = StringBuffer('[Artemis] transportFailure type=$type msg=$truncated');
  if (stackTrace != null) {
    buf.write(' at ');
    buf.write(stackTrace.toString().split('\n').first.trim());
  }
  return buf.toString();
}
