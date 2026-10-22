import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/data/providers/auth_api_provider.dart';
import '../../../auth/domain/models/api_user_model.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';

final callLogsFutureProvider =
    FutureProvider.autoDispose<List<CallModel>>((ref) async {
  final signaling = ref.watch(callSignalingServiceProvider);
  return signaling.fetchHistory(limit: 50);
});

class CallsTab extends ConsumerStatefulWidget {
  const CallsTab({super.key});

  @override
  ConsumerState<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends ConsumerState<CallsTab> {
  int _filterIndex = 0; // 0: All, 1: Missed

  void _initiateCall(int partnerId, String name, CallType type) {
    ref.read(callManagerProvider.notifier).startCall(
          calleePartnerId: partnerId,
          calleeName: name,
          callType: type,
        );
    if (type == CallType.video) {
      context.push('/video-call', extra: {'callee_name': name, 'partner_id': partnerId});
    } else {
      context.push('/audio-call', extra: {'callee_name': name, 'partner_id': partnerId});
    }
  }

  void _showNewCallDialog(List<ApiUserModel> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.add_call, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Start a Call',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          u.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          u.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: u.isOnline
                                ? AppColors.online
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, size: 20),
                              color: AppColors.primary,
                              onPressed: () {
                                Navigator.pop(ctx);
                                _initiateCall(u.partnerId, u.name, CallType.audio);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam_outlined, size: 22),
                              color: AppColors.accentTeal,
                              onPressed: () {
                                Navigator.pop(ctx);
                                _initiateCall(u.partnerId, u.name, CallType.video);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(callLogsFutureProvider);
    final usersState = ref.watch(usersApiProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Call Logs',
            onPressed: () => ref.invalidate(callLogsFutureProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calls_tab_fab',
        onPressed: () => _showNewCallDialog(usersState.users),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Tabs (All, Missed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterTab(0, 'All Calls', isDark),
                const SizedBox(width: 10),
                _buildFilterTab(1, 'Missed Calls', isDark),
              ],
            ),
          ),

          // Call Records List
          Expanded(
            child: historyAsync.when(
              loading: () => const ChatListSkeleton(),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load call history',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(callLogsFutureProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (calls) {
                final filtered = _filterIndex == 1
                    ? calls
                        .where((c) =>
                            c.state == CallState.missed ||
                            c.state == CallState.rejected)
                        .toList()
                    : calls;

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: _filterIndex == 1
                        ? Icons.phone_missed_rounded
                        : Icons.phone_in_talk_rounded,
                    title: _filterIndex == 1
                        ? 'No Missed Calls'
                        : 'No Call Records',
                    subtitle: _filterIndex == 1
                        ? 'You have answered all incoming calls!'
                        : 'Connect with team members with crystal clear WebRTC calls.',
                    buttonText: 'Start Call',
                    onButtonPressed: () => _showNewCallDialog(usersState.users),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(callLogsFutureProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final call = filtered[index];
                      return _buildCallTile(call, isDark);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label, bool isDark) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildCallTile(CallModel call, bool isDark) {
    final isVideo = call.callType == CallType.video;
    final isMissed =
        call.state == CallState.missed || call.state == CallState.rejected;
    final partnerName = call.callee.name;
    final partnerId = call.callee.partnerId;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isMissed
              ? AppColors.error.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isMissed ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
        title: Text(
          partnerName,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isMissed
                ? AppColors.error
                : (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              isMissed
                  ? Icons.call_missed_rounded
                  : (call.state == CallState.ended
                      ? Icons.call_made_rounded
                      : Icons.call_received_rounded),
              size: 15,
              color: isMissed ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('MMM d, h:mm a').format(call.startTime),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            if (call.durationFormatted != null && call.duration > 0) ...[
              const SizedBox(width: 6),
              Text(
                '• ${call.durationFormatted}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
            color: isVideo ? AppColors.accentTeal : AppColors.primary,
            size: 22,
          ),
          tooltip: 'Call Back',
          onPressed: () => _initiateCall(partnerId, partnerName, call.callType),
        ),
      ),
    );
  }
}
