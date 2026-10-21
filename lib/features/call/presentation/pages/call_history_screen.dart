import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';

final callHistoryFutureProvider = FutureProvider.autoDispose<List<CallModel>>((ref) async {
  final signaling = ref.watch(callSignalingServiceProvider);
  return signaling.fetchHistory(limit: 50);
});

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(callHistoryFutureProvider);
    final callManager = ref.read(callManagerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Call Logs',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(callHistoryFutureProvider);
            },
          ),
        ],
      ),
      body: historyAsync.when(
        data: (calls) {
          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_missed, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'No call records found',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: calls.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08)),
            itemBuilder: (context, index) {
              final call = calls[index];
              final isVideo = call.callType == CallType.video;
              final isMissed = call.state == CallState.missed || call.state == CallState.rejected;
              final partnerName = call.callee.name;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.purple1.withValues(alpha: 0.25),
                  child: Text(
                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                title: Text(
                  partnerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      isMissed
                          ? Icons.call_missed
                          : (call.state == CallState.ended ? Icons.call_made : Icons.call_received),
                      size: 14,
                      color: isMissed ? Colors.redAccent : Colors.greenAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(call.startTime),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    if (call.durationFormatted != null && call.duration > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${call.durationFormatted})',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    isVideo ? Icons.videocam_outlined : Icons.phone_outlined,
                    color: AppColors.purple1,
                  ),
                  onPressed: () async {
                    final success = await callManager.startCall(
                      calleePartnerId: call.callee.partnerId,
                      callType: call.callType,
                    );
                    if (success && context.mounted) {
                      if (isVideo) {
                        context.push('/video-call');
                      } else {
                        context.push('/audio-call');
                      }
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }
}
