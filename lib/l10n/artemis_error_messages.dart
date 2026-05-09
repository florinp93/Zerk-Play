import 'app_localizations.dart';
import '../services/artemis/artemis_transport.dart';

String messageForArtemisIssue(AppLocalizations l10n, ArtemisTransportIssue issue) {
  switch (issue) {
    case ArtemisTransportIssue.tls:
      return l10n.artemisConnectionFailedCertificate;
    case ArtemisTransportIssue.dns:
      return l10n.artemisConnectionFailedDns;
    case ArtemisTransportIssue.network:
      return l10n.artemisConnectionFailedNetwork;
    case ArtemisTransportIssue.wrongService:
      return l10n.artemisWrongServerNotJellyseerr;
    case ArtemisTransportIssue.unknown:
      return l10n.artemisConnectionFailed;
  }
}

String messageForArtemisError(AppLocalizations l10n, Object? error) {
  return messageForArtemisIssue(l10n, categorizeArtemisTransportError(error));
}

/// Use when [ArtemisReachabilityResult.reachable] is false (e.g. after pairing).
String messageForReachability(AppLocalizations l10n, ArtemisReachabilityResult result) {
  return messageForArtemisIssue(l10n, result.issue ?? ArtemisTransportIssue.unknown);
}
