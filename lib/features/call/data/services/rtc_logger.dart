import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:intl/intl.dart';

/// Centralized RTC Logger & Diagnostics helper
///
/// Stores timestamped logs in memory, categorizes ICE candidate types,
/// tracks signaling requests/responses, and generates diagnostic summaries.
class RtcLogger extends ChangeNotifier {
  static final RtcLogger instance = RtcLogger._internal();

  RtcLogger._internal();

  static const int maxLogEntries = 300;
  final List<String> _logs = [];

  // Candidate type counters
  int localHostCount = 0;
  int localSrflxCount = 0;
  int localRelayCount = 0;

  // Remote candidate type counters
  int remoteHostCount = 0;
  int remoteSrflxCount = 0;
  int remoteRelayCount = 0;

  bool hasSignalingError = false;
  bool candidatesGenerated = false;
  String? lastDiagnosis;
  String? lastSelectedPair;

  List<String> get logs => List.unmodifiable(_logs);

  void resetCounters() {
    localHostCount = 0;
    localSrflxCount = 0;
    localRelayCount = 0;
    remoteHostCount = 0;
    remoteSrflxCount = 0;
    remoteRelayCount = 0;
    hasSignalingError = false;
    candidatesGenerated = false;
    lastDiagnosis = null;
    lastSelectedPair = null;
    notifyListeners();
  }

  /// Formatted timestamped logging
  void log(String message, {String tag = 'RTC'}) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss.SSS').format(now);
    final entry = '[$timeStr] [$tag] $message';

    _logs.add(entry);
    if (_logs.length > maxLogEntries) {
      _logs.removeAt(0);
    }

    debugPrint(entry);
    notifyListeners();
  }

  /// Parse and log local or remote ICE candidate
  void logCandidate(RTCIceCandidate candidate, {bool isLocal = true}) {
    final candStr = candidate.candidate ?? '';
    log('candidate: $candStr', tag: isLocal ? 'ICE-LOCAL' : 'ICE-REMOTE');

    if (candStr.isEmpty) return;

    if (isLocal) {
      candidatesGenerated = true;
    }

    // Determine candidate type by parsing SDP line (e.g., "typ host", "typ srflx", "typ relay")
    final match = RegExp(r'typ\s+([a-zA-Z0-9]+)').firstMatch(candStr);
    final candType = match != null ? match.group(1)?.toLowerCase() : 'unknown';

    if (isLocal) {
      switch (candType) {
        case 'host':
          localHostCount++;
          break;
        case 'srflx':
        case 'prflx':
          localSrflxCount++;
          break;
        case 'relay':
          localRelayCount++;
          break;
      }
      log(
        'Parsed local candidate type: $candType (current counts: host=$localHostCount srflx=$localSrflxCount relay=$localRelayCount)',
        tag: 'ICE-PARSE',
      );
    } else {
      switch (candType) {
        case 'host':
          remoteHostCount++;
          break;
        case 'srflx':
        case 'prflx':
          remoteSrflxCount++;
          break;
        case 'relay':
          remoteRelayCount++;
          break;
      }
    }
    notifyListeners();
  }

  /// Log summary when ICE gathering completes
  void logGatheringComplete() {
    log(
      'GATHER COMPLETE: host=$localHostCount srflx=$localSrflxCount relay=$localRelayCount',
      tag: 'GATHER-SUMMARY',
    );
  }

  /// Log outgoing signaling message with HTTP status
  void logOutgoingSignaling(String type, int httpStatus, {dynamic details}) {
    if (httpStatus < 200 || httpStatus >= 300) {
      hasSignalingError = true;
    }
    log(
      'Outgoing signal: $type | HTTP status: $httpStatus | details: $details',
      tag: 'SIGNAL-OUT',
    );
  }

  /// Log incoming signaling message
  void logIncomingSignaling(String type, {dynamic details}) {
    log('Incoming signal: $type | details: $details', tag: 'SIGNAL-IN');
  }

  /// Evaluate DIAGNOSIS based on ICE connection state and candidate counters
  String evaluateDiagnosis({
    required bool isConnected,
    required String iceState,
  }) {
    String diagnosis;

    if (isConnected) {
      if (localRelayCount > 0 || remoteRelayCount > 0) {
        diagnosis = 'Connected via TURN (relay)';
      } else {
        diagnosis = 'Connected without TURN';
      }
    } else if (!candidatesGenerated || (localHostCount + localSrflxCount + localRelayCount == 0)) {
      diagnosis = 'App code issue: no candidates generated';
    } else if (hasSignalingError) {
      diagnosis = 'Signaling bug: candidates not delivered to Odoo';
    } else if (localSrflxCount > 0) {
      diagnosis = 'Signaling OK but direct connection blocked. TURN is required';
    } else if (localHostCount > 0 && localSrflxCount == 0 && localRelayCount == 0) {
      diagnosis = 'STUN unreachable (firewall or wrong config)';
    } else {
      diagnosis = 'ICE failed or timed out (state: $iceState)';
    }

    lastDiagnosis = diagnosis;

    log('================================================================================', tag: 'DIAGNOSIS');
    log('>>> DIAGNOSIS: $diagnosis <<<', tag: 'DIAGNOSIS');
    log('================================================================================', tag: 'DIAGNOSIS');

    notifyListeners();
    return diagnosis;
  }

  /// Inspect getStats() on hangup to identify selected candidate pair
  Future<void> inspectStatsOnHangup(RTCPeerConnection? pc) async {
    if (pc == null) return;
    try {
      final reports = await pc.getStats();
      String? selectedPairInfo;

      // Search for candidate pair and individual candidates
      final candidateMap = <String, Map<dynamic, dynamic>>{};
      final candidatePairs = <Map<dynamic, dynamic>>[];

      for (final report in reports) {
        final type = report.type;
        final values = report.values;

        if (type == 'local-candidate' || type == 'remote-candidate') {
          candidateMap[report.id] = values;
        } else if (type == 'candidate-pair') {
          candidatePairs.add(values);
        }
      }

      for (final pair in candidatePairs) {
        final state = pair['state'];
        final nominated = pair['nominated'];
        final selected = pair['selected'];

        if (state == 'succeeded' || nominated == true || selected == true) {
          final localId = pair['localCandidateId'];
          final remoteId = pair['remoteCandidateId'];

          final local = candidateMap[localId];
          final remote = candidateMap[remoteId];

          final localType = local?['candidateType'] ?? 'unknown';
          final remoteType = remote?['candidateType'] ?? 'unknown';
          final protocol = pair['protocol'] ?? local?['protocol'] ?? 'udp';
          final relayProtocol = local?['relayProtocol'] ?? remote?['relayProtocol'] ?? 'none';

          selectedPairInfo =
              'localType=$localType, remoteType=$remoteType, protocol=$protocol, relayProtocol=$relayProtocol';
          break;
        }
      }

      if (selectedPairInfo != null) {
        lastSelectedPair = selectedPairInfo;
        log('Selected candidate pair: $selectedPairInfo', tag: 'STATS');
      } else {
        log('No nominated/succeeded candidate pair found in getStats().', tag: 'STATS');
      }
    } catch (e) {
      log('Could not retrieve getStats() on hangup: $e', tag: 'STATS-ERROR');
    }
  }

  /// Copy all logs to clipboard
  Future<void> copyLogsToClipboard() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Odoo WebRTC Audio Call Debug Logs ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Candidate Summary: host=$localHostCount srflx=$localSrflxCount relay=$localRelayCount');
    if (lastDiagnosis != null) {
      buffer.writeln('Diagnosis: $lastDiagnosis');
    }
    if (lastSelectedPair != null) {
      buffer.writeln('Selected Pair: $lastSelectedPair');
    }
    buffer.writeln('----------------------------------------');
    for (final line in _logs) {
      buffer.writeln(line);
    }
    buffer.writeln('=== End of Logs ===');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  /// Clear log buffer
  void clear() {
    _logs.clear();
    resetCounters();
  }
}
