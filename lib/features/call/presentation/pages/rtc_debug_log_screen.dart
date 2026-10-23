import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/call_provider.dart';
import '../../data/services/rtc_call_service.dart';

class RtcDebugLogScreen extends ConsumerStatefulWidget {
  const RtcDebugLogScreen({super.key});

  @override
  ConsumerState<RtcDebugLogScreen> createState() => _RtcDebugLogScreenState();
}

class _RtcDebugLogScreenState extends ConsumerState<RtcDebugLogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = 'ALL';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLogColor(String line) {
    if (line.contains('[DIAGNOSIS]') || line.contains('>>> DIAGNOSIS:')) {
      return const Color(0xFFFFB300); // Amber
    }
    if (line.contains('ERROR') || line.contains('failed') || line.contains('EXCEPTION') || line.contains('FAILED')) {
      return const Color(0xFFFF5252); // Red
    }
    if (line.contains('ICE: RTCIceConnectionStateConnected') || line.contains('Connected')) {
      return const Color(0xFF69F0AE); // Light green
    }
    if (line.contains('[ICE') || line.contains('GATHER')) {
      return const Color(0xFF40C4FF); // Light blue
    }
    if (line.contains('[SIGNAL')) {
      return const Color(0xFFB388FF); // Light purple
    }
    if (line.contains('[STATS')) {
      return const Color(0xFFFFD740); // Gold
    }
    return const Color(0xFFE0E0E0);
  }

  List<String> _filterLogs(List<String> logs) {
    if (_filter == 'ALL') return logs;
    if (_filter == 'ICE') {
      return logs.where((l) => l.contains('ICE') || l.contains('GATHER')).toList();
    }
    if (_filter == 'SIGNAL') {
      return logs.where((l) => l.contains('SIGNAL') || l.contains('ODOO-API')).toList();
    }
    if (_filter == 'DIAGNOSIS') {
      return logs.where((l) => l.contains('DIAGNOSIS') || l.contains('STATS')).toList();
    }
    return logs;
  }

  @override
  Widget build(BuildContext context) {
    final logger = ref.watch(rtcLoggerProvider);
    final rtcService = ref.watch(rtcCallServiceProvider);
    final filteredLogs = _filterLogs(logger.logs);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'RTC Live Diagnostics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy all logs to clipboard',
            icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
            onPressed: () async {
              await logger.copyLogsToClipboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logs copied to clipboard! Ready to paste.'),
                    backgroundColor: Color(0xFF10B981),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            onPressed: () => logger.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Diagnostics Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Candidate Summary row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CANDIDATES: host=${logger.localHostCount} | srflx=${logger.localSrflxCount} | relay=${logger.localRelayCount}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rtcService.status == CallStatus.connected
                            ? const Color(0xFF059669)
                            : const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ICE: ${rtcService.iceConnectionState.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (logger.lastDiagnosis != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF78350F).withValues(alpha: 0.8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.troubleshoot_rounded, color: Color(0xFFFBBF24), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'AUTOMATIC DIAGNOSIS',
                              style: TextStyle(
                                color: Color(0xFFFBBF24),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          logger.lastDiagnosis!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (logger.lastSelectedPair != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Selected Pair: ${logger.lastSelectedPair}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Filter chips
                Row(
                  children: [
                    _buildFilterChip('ALL'),
                    const SizedBox(width: 6),
                    _buildFilterChip('ICE'),
                    const SizedBox(width: 6),
                    _buildFilterChip('SIGNAL'),
                    const SizedBox(width: 6),
                    _buildFilterChip('DIAGNOSIS'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _autoScroll = !_autoScroll),
                      child: Row(
                        children: [
                          Icon(
                            _autoScroll ? Icons.lock_outline : Icons.lock_open,
                            size: 14,
                            color: _autoScroll ? const Color(0xFF10B981) : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Auto-scroll',
                            style: TextStyle(
                              fontSize: 11,
                              color: _autoScroll ? const Color(0xFF10B981) : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          // 2. Logs List View
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet. Start or join a call to inspect WebRTC events.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final line = filteredLogs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: SelectableText(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: _getLogColor(line),
                            height: 1.35,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
